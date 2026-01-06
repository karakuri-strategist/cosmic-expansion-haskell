{-# LANGUAGE ForeignFunctionInterface #-}

module Main (main) where

import Control.Monad (forM_)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Vector (Vector)
import qualified Data.Vector as V
import qualified Data.Vector.Mutable as MV
import Foreign.C.Types (CDouble(..), CInt(..))
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray)
import Foreign.Ptr (Ptr)
import Foreign.StablePtr (StablePtr, deRefStablePtr, freeStablePtr, newStablePtr)
import Foreign.Storable (pokeElemOff)
import HubbleExpansion
    ( DeltaTime(..)
    , Galaxy(..)
    , Time(..)
    , advanceTime
    , nextAccel
    , scaleAt
    , velocityVerlet
    )
import InitialGalaxies (initialGalaxiesRandomDiskN)
import Interactions (applyBlastIO, gaussianCompressionIO, gaussianExpansionIO)
import ScaleFactors (scaleToUse)
import Vec (Vec2(Vec2))

data SimState = SimState
    { simGalaxies :: MV.IOVector (Galaxy Vec2)
    , simPosBuf :: MV.IOVector Vec2
    , simA0Buf :: MV.IOVector Vec2
    , simVHalfBuf :: MV.IOVector Vec2
    , simTime :: IORef Time
    , simPositionsPtr :: Ptr CDouble
    , simCount :: Int
    }

foreign export ccall initState :: CInt -> IO (StablePtr SimState)
foreign export ccall stepState :: StablePtr SimState -> CDouble -> IO ()
foreign export ccall applyBlastState :: StablePtr SimState -> CDouble -> CDouble -> CDouble -> IO ()
foreign export ccall warpState :: StablePtr SimState -> CInt -> CDouble -> CDouble -> CDouble -> IO ()
foreign export ccall writePositions :: StablePtr SimState -> IO ()
foreign export ccall positionsPtr :: StablePtr SimState -> IO (Ptr CDouble)
foreign export ccall stateCount :: StablePtr SimState -> IO CInt
foreign export ccall freeState :: StablePtr SimState -> IO ()

main :: IO ()
main = pure ()

initState :: CInt -> IO (StablePtr SimState)
initState nRaw = do
    let n = max 1 (fromIntegral nRaw)
    gs0 <- initialGalaxiesRandomDiskN n
    let scaleVals = scaleAt scaleToUse (Time 0)
        accs = V.imap (\i g -> nextAccel i g gs0 scaleVals) gs0
        gs1 = V.zipWith (\g a -> g { galaxyAcc = a }) gs0 accs
    gsM <- V.thaw gs1
    posBuf <- MV.new n
    a0Buf <- MV.new n
    vHalfBuf <- MV.new n
    posPtr <- mallocArray (2 * n)
    timeRef <- newIORef (Time 0)
    newStablePtr $ SimState gsM posBuf a0Buf vHalfBuf timeRef posPtr n

stepState :: StablePtr SimState -> CDouble -> IO ()
stepState sp dtRaw = do
    state <- deRefStablePtr sp
    t <- readIORef (simTime state)
    let dt = DeltaTime (realToFrac dtRaw)
    velocityVerlet dt t (simGalaxies state) (simA0Buf state) (simVHalfBuf state) (simPosBuf state) scaleToUse
    writeIORef (simTime state) (advanceTime t dt)

applyBlastState :: StablePtr SimState -> CDouble -> CDouble -> CDouble -> IO ()
applyBlastState sp scaleRaw xRaw yRaw = do
    state <- deRefStablePtr sp
    let sc = realToFrac scaleRaw
        pos = Vec2 (realToFrac xRaw) (realToFrac yRaw)
    applyBlastIO sc pos (simGalaxies state)

warpState :: StablePtr SimState -> CInt -> CDouble -> CDouble -> CDouble -> IO ()
warpState sp modeRaw scaleRaw xRaw yRaw = do
    state <- deRefStablePtr sp
    let sc = realToFrac scaleRaw
        pos = Vec2 (realToFrac xRaw) (realToFrac yRaw)
    case modeRaw of
        1 -> gaussianExpansionIO sc pos (simGalaxies state)
        (-1) -> gaussianCompressionIO sc pos (simGalaxies state)
        _ -> pure ()

writePositions :: StablePtr SimState -> IO ()
writePositions sp = do
    state <- deRefStablePtr sp
    let n = simCount state
        ptr = simPositionsPtr state
        gs = simGalaxies state
    forM_ [0..n - 1] $ \i -> do
        g <- MV.read gs i
        let Vec2 x y = galaxyPos g
        pokeElemOff ptr (2 * i) (CDouble x)
        pokeElemOff ptr (2 * i + 1) (CDouble y)

positionsPtr :: StablePtr SimState -> IO (Ptr CDouble)
positionsPtr sp = simPositionsPtr <$> deRefStablePtr sp

stateCount :: StablePtr SimState -> IO CInt
stateCount sp = do
    state <- deRefStablePtr sp
    pure (fromIntegral (simCount state))

freeState :: StablePtr SimState -> IO ()
freeState sp = do
    state <- deRefStablePtr sp
    free (simPositionsPtr state)
    freeStablePtr sp
