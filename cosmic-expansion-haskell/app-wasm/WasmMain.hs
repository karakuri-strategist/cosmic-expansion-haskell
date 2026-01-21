{-# LANGUAGE ForeignFunctionInterface #-}

module Main (main) where

import Control.Monad (forM_)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Vector (Vector)
import qualified Data.Vector as V
import qualified Data.Vector.Mutable as MV
import Foreign.C.String (CString)
import Foreign.C.Types (CDouble(..), CInt(..))
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray)
import Foreign.Ptr (Ptr, nullPtr, plusPtr)
import Foreign.StablePtr (StablePtr, deRefStablePtr, freeStablePtr, newStablePtr)
import Foreign.Storable (pokeElemOff, sizeOf)
import HubbleExpansion
    ( DeltaTime(..)
    , Galaxy(..)
    , Scale(..)
    , Time(..)
    , addDelta
    , advanceTime
    , nextAccel
    , scaleAt
    , unDeltaTime
    , velocityVerlet
    )
import InitialGalaxies (initialGalaxiesRandomDiskN)
import Interactions (applyBlastIO, gaussianCompressionIO, gaussianExpansionIO)
import ScaleFactors (availableScales)
import Vec (Vec2(Vec2))
import NearestNeighbors (nearestNeighbors)

data SimState = SimState
    { simGalaxies :: MV.IOVector (Galaxy Vec2)
    , simNeighbors :: MV.IOVector (Maybe (Vec2, Double))
    , simPosBuf :: MV.IOVector Vec2
    , simA0Buf :: MV.IOVector Vec2
    , simVHalfBuf :: MV.IOVector Vec2
    , simTime :: IORef Time
    , simNeighborAccum :: IORef DeltaTime
    , simPositionsPtr :: Ptr CDouble
    , simNeighborDistsPtr :: Ptr CDouble
    , simCount :: Int
    , simScale :: Scale
    }

foreign export ccall initState :: CInt -> CInt -> IO (StablePtr SimState)
foreign export ccall stepState :: StablePtr SimState -> CDouble -> IO ()
foreign export ccall applyBlastState :: StablePtr SimState -> CDouble -> CDouble -> CDouble -> IO ()
foreign export ccall warpState :: StablePtr SimState -> CInt -> CDouble -> CDouble -> CDouble -> IO ()
foreign export ccall writePositions :: StablePtr SimState -> IO ()
foreign export ccall writeNeighborDistances :: StablePtr SimState -> IO ()
foreign export ccall positionsPtr :: StablePtr SimState -> IO (Ptr CDouble)
foreign export ccall neighborDistancesPtr :: StablePtr SimState -> IO (Ptr CDouble)
foreign export ccall stateCount :: StablePtr SimState -> IO CInt
foreign export ccall freeState :: StablePtr SimState -> IO ()
foreign export ccall hsInit :: IO ()
foreign export ccall hsExit :: IO ()

foreign import ccall "hs_init" c_hs_init :: Ptr CInt -> Ptr (Ptr CString) -> IO ()
foreign import ccall "hs_exit" c_hs_exit :: IO ()

main :: IO ()
main = pure ()

hsInit :: IO ()
hsInit = c_hs_init nullPtr nullPtr

hsExit :: IO ()
hsExit = c_hs_exit

initState :: CInt -> CInt -> IO (StablePtr SimState)
initState nRaw scaleIndex = do
    let n = max 1 (fromIntegral nRaw)
        idx = fromIntegral scaleIndex
        scaleEq = if idx >= 0 && idx < length availableScales
                  then availableScales !! idx
                  else head availableScales -- Default to first if out of bounds

    gs0 <- initialGalaxiesRandomDiskN n
    let scaleVals = scaleAt scaleEq (Time 0)
        accs = V.imap (\i g -> nextAccel i g gs0 scaleVals) gs0
        gs1 = V.zipWith (\g a -> g { galaxyAcc = a }) gs0 accs
    gsM <- V.thaw gs1
    neighM <- MV.new n
    nearestNeighbors gsM neighM
    posBuf <- MV.new n
    a0Buf <- MV.new n
    vHalfBuf <- MV.new n
    posPtr <- mallocArray (3 * n)
    let neighDistPtr = posPtr `plusPtr` (2 * n * sizeOfDouble)
    timeRef <- newIORef (Time 0)
    neighborAcc <- newIORef (DeltaTime 0)
    newStablePtr $ SimState gsM neighM posBuf a0Buf vHalfBuf timeRef neighborAcc posPtr neighDistPtr n scaleEq

stepState :: StablePtr SimState -> CDouble -> IO ()
stepState sp dtRaw = do
    state <- deRefStablePtr sp
    t <- readIORef (simTime state)
    let dt = DeltaTime (realToFrac dtRaw)
    velocityVerlet dt t (simGalaxies state) (simA0Buf state) (simVHalfBuf state) (simPosBuf state) (simScale state)
    neighborAcc <- readIORef (simNeighborAccum state)
    let neighborAcc' = addDelta neighborAcc dt
    if unDeltaTime neighborAcc' >= unDeltaTime neighborWindow
        then do
            nearestNeighbors (simGalaxies state) (simNeighbors state)
            writeIORef (simNeighborAccum state) (DeltaTime 0)
        else writeIORef (simNeighborAccum state) neighborAcc'
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
    let gs = simGalaxies state
        n = min (simCount state) (MV.length gs)
        ptr = simPositionsPtr state
    forM_ [0..n - 1] $ \i -> do
        g <- MV.read gs i
        let Vec2 x y = galaxyPos g
        pokeElemOff ptr (2 * i) (CDouble x)
        pokeElemOff ptr (2 * i + 1) (CDouble y)

writeNeighborDistances :: StablePtr SimState -> IO ()
writeNeighborDistances sp = do
    state <- deRefStablePtr sp
    let ns = simNeighbors state
        n = min (simCount state) (MV.length ns)
        ptr = simNeighborDistsPtr state
    forM_ [0..n - 1] $ \i -> do
        neighbor <- MV.read ns i
        let d2 = case neighbor of
                Nothing -> -1
                Just (_, distSq) -> distSq
        pokeElemOff ptr i (CDouble d2)

positionsPtr :: StablePtr SimState -> IO (Ptr CDouble)
positionsPtr sp = simPositionsPtr <$> deRefStablePtr sp

neighborDistancesPtr :: StablePtr SimState -> IO (Ptr CDouble)
neighborDistancesPtr sp = simNeighborDistsPtr <$> deRefStablePtr sp

stateCount :: StablePtr SimState -> IO CInt
stateCount sp = do
    state <- deRefStablePtr sp
    pure (fromIntegral (simCount state))

freeState :: StablePtr SimState -> IO ()
freeState sp = do
    state <- deRefStablePtr sp
    free (simPositionsPtr state)
    freeStablePtr sp

neighborWindow :: DeltaTime
neighborWindow = DeltaTime 0.05

sizeOfDouble :: Int
sizeOfDouble = sizeOf (undefined :: CDouble)
