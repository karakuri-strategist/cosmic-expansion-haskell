{-# LANGUAGE BangPatterns #-}

module GlossAnimation (runGloss) where

import Data.Vector (Vector)
import qualified Data.Vector as V
import qualified Data.Vector.Mutable as MV
import Control.Monad (forM)
import Graphics.Gloss hiding (Vector)
import Graphics.Gloss.Interface.Pure.Game (Event)
import Graphics.Gloss.Interface.IO.Game
    ( playIO
    , Event(EventKey, EventMotion)
    , KeyState(Down, Up)
    , Key(Char, SpecialKey, MouseButton)
    , MouseButton(LeftButton, RightButton, MiddleButton)
    , SpecialKey(KeySpace)
    )
import System.Exit (exitSuccess)
import Text.Printf (printf)
import Complexity (complexity)
import GlossConfig
    ( timeWidth
    , complexityWindow
    , debugWindow
    , neighborWindow
    , dotRadiusPx
    , padding
    , textScale
    , fpsTarget
    , fpsWindow
    , haloRadiusPx
    , maxColorDistPx
    , maxLinkDistPx
    , windowHalfH
    , windowHalfW
    , windowHeightPx
    , windowPosX
    , windowPosY
    , windowRadiusPx
    , windowTitle
    , windowWidthPx
    )
import qualified HubbleExpansion as HE (a, a')
import HubbleExpansion
    ( DeltaTime(..)
    , Galaxy
    , Scale
    , Time(..)
    , addDelta
    , advanceTime
    , galaxyAcc
    , galaxyPos
    , galaxyVel
    , nextAccel
    , scaleAt
    , unDeltaTime
    , velocityVerlet
    )
import InitialGalaxies (initialGalaxiesDisk, initialGalaxiesRandomDisk, initialGalaxiesClusteredDisk)
import ScaleFactors (scaleToUse)
import Vec ( Vec2 (Vec2), vmag)
import NearestNeighbors ( nearestNeighbors )
import Interactions (applyBlastIO, gaussianCompressionIO, gaussianExpansionIO)

data World = World
    { worldGalaxies :: MV.IOVector (Galaxy Vec2)
    , worldPosBuf :: MV.IOVector Vec2
    , worldA0Buf :: MV.IOVector Vec2
    , worldVHalfBuf :: MV.IOVector Vec2
    , worldTime :: Time
    , worldScale :: Float
    , worldScaleVel :: Float
    , worldFrames :: Int
    , worldAccum :: DeltaTime
    , worldFps :: Double
    , worldCompAccum :: DeltaTime
    , worldComplexity :: !Double
    , worldDebug :: Bool
    , worldDebugAccum :: DeltaTime
    , worldAvgSpeed :: !Double
    , worldMaxSpeed :: !Double
    , worldMaxAccel :: !Double
    , worldExpansionRate :: !Double
    , worldPaused :: Bool
    , worldResetScale :: Bool
    , worldWarpMode :: WarpMode
    , worldMousePos :: Maybe Vec2
    , worldNeighborAccum :: DeltaTime
    , worldNeighbors :: Vector (Maybe (Vec2, Double))
    }

data WarpMode
    = WarpNone
    | WarpExpand
    | WarpCompress

runGloss :: IO ()
runGloss = do
    world0 <- initialWorld
    playIO displayUniverse background fps world0 drawWorldIO handleEventIO stepWorldIO

displayUniverse :: Display
displayUniverse = InWindow windowTitle (windowWidthPx, windowHeightPx) (windowPosX, windowPosY)

background :: Color
background = black

fps :: Int
fps = fpsTarget

initialWorld :: IO World
initialWorld = do
    gs0 <- initialGalaxiesConfig
    let gs = withAccelerations scaleEqsConfig gs0
        compVal = complexity $ V.map galaxyPos gs
        (avgSpeed, maxSpeed, maxAccel) = calcStatsVector gs
        expansionRate = calcExpansionRate scaleEqsConfig (Time 0)
        neighbors = nearestNeighbors gs
        n = V.length gs
    gsM <- V.thaw gs
    posBuf <- MV.new n
    a0Buf <- MV.new n
    vHalfBuf <- MV.new n
    pure $ World gsM posBuf a0Buf vHalfBuf (Time 0) (calcScaleVector gs) 0 0 (DeltaTime 0) 0 (DeltaTime 0) compVal False (DeltaTime 0) avgSpeed maxSpeed maxAccel expansionRate False True WarpNone Nothing (DeltaTime 0) neighbors

scaleEqsConfig :: Scale
scaleEqsConfig = scaleToUse

initialGalaxiesConfig :: IO (Vector (Galaxy Vec2))
initialGalaxiesConfig = initialGalaxiesRandomDisk


withAccelerations :: Scale -> Vector (Galaxy Vec2) -> Vector (Galaxy Vec2)
withAccelerations scale gs =
    let scaleVals = scaleAt scale (Time 0)
        accs = V.imap (\i g -> nextAccel i g gs scaleVals) gs
    in V.zipWith (\g a -> g { galaxyAcc = a }) gs accs

drawWorldIO :: World -> IO Picture
drawWorldIO world = do
    let gs = worldGalaxies world
        sc = worldScale world
        fpsVal = worldFps world
        compVal = worldComplexity world
        timeVal = worldTime world
        debugEnabled = worldDebug world
        avgSpeed = worldAvgSpeed world
        maxSpeed = worldMaxSpeed world
        maxAccel = worldMaxAccel world
        expansionRate = worldExpansionRate world
        neighbors = worldNeighbors world
        linkDist = maxLinkDistPx / sc
        colorDist = maxColorDistPx / sc
        haloR = haloRadiusPx / sc
        dotR = dotRadiusPx / sc
        n = MV.length gs
    pics <- forM [0..n - 1] $ \i -> do
        g <- MV.read gs i
        let neighbor = neighbors V.! i
        pure (drawGalaxyWith g neighbor linkDist colorDist haloR dotR)
    let worldPic = scale sc sc $ Pictures pics
        timePic = drawTime timeVal
        debugPic =
            if debugEnabled
                then Pictures [drawFps fpsVal, drawDebug avgSpeed maxSpeed maxAccel expansionRate compVal]
                else Blank
    pure (Pictures [worldPic, timePic, debugPic])

drawGalaxyWith :: (Galaxy Vec2) -> Maybe (Vec2, Double) -> Float -> Float -> Float -> Float -> Picture
drawGalaxyWith galaxy neighbor linkDist colorDist haloR dotR =
    let (x,y) = toPoint (galaxyPos galaxy)
        (linePic, col) = case neighbor of
            Nothing -> (Blank, coolColor)
            Just (np, distSq) ->
                let (nx, ny) = toPoint np
                    d = realToFrac (sqrt distSq)
                    t = clamp01 (1 - d / colorDist)
                    lineVisible = d < linkDist
                    lineColor = withAlpha 0.35 $ greyN 0.7
                    line = if lineVisible then Color lineColor $ Line [(x, y), (nx, ny)] else Blank
                in (line, mixColors t (1 - t) warmColor coolColor)
        glow = Color (withAlpha 0.12 col) $ Translate x y $ circleSolid haloR
        dot = Color col $ Translate x y $ circleSolid dotR
    in Pictures [linePic, glow, dot]

coolColor :: Color
coolColor = makeColor 0.35 0.7 1.0 1.0

warmColor :: Color
warmColor = makeColor 1.0 0.6 0.2 1.0

clamp01 :: Float -> Float
clamp01 x
    | x < 0 = 0
    | x > 1 = 1
    | otherwise = x

toPoint :: Vec2 -> (Float, Float)
toPoint (Vec2 x y) = (realToFrac x, realToFrac y)

handleEvent :: Event -> World -> World
handleEvent (EventKey (SpecialKey KeySpace) Down _ _) world =
    world { worldPaused = not (worldPaused world) }
handleEvent (EventKey (MouseButton LeftButton) Down _ _) world =
    world { worldWarpMode = WarpCompress }
handleEvent (EventKey (MouseButton LeftButton) Up _ _) world =
    world { worldWarpMode = WarpNone }
handleEvent (EventKey (MouseButton RightButton) Down _ _) world =
    world { worldWarpMode = WarpExpand }
handleEvent (EventKey (MouseButton RightButton) Up _ _) world =
    world { worldWarpMode = WarpNone }
handleEvent (EventKey (Char key) Down _ _) world
    | key == 'd' || key == 'D' = world { worldDebug = not (worldDebug world) }
handleEvent (EventMotion (x, y)) world =
    let sc = worldScale world
        pos = Vec2 (realToFrac x / realToFrac sc) (realToFrac y / realToFrac sc)
    in world { worldMousePos = Just pos }
handleEvent _ world = world

handleEventIO :: Event -> World -> IO World
handleEventIO (EventKey (Char key) Down _ _) world
    | key == 'q' || key == 'Q' = exitSuccess
    | key == 'r' || key == 'R' = restartWorld world
handleEventIO (EventKey (MouseButton MiddleButton) Down _ (x, y)) world = do
    let sc = worldScale world
        pos = Vec2 (realToFrac x / realToFrac sc) (realToFrac y / realToFrac sc)
    applyBlastIO sc pos (worldGalaxies world)
    pure world
handleEventIO e w = pure (handleEvent e w)

restartWorld :: World -> IO World
restartWorld world = do
    fresh <- initialWorld
    pure fresh
        { worldDebug = worldDebug world
        , worldPaused = worldPaused world
        , worldResetScale = True
        , worldWarpMode = WarpNone
        , worldMousePos = Nothing
        }

stepWorldIO :: Float -> World -> IO World
stepWorldIO dt world =
    if worldPaused world
        then pure world
        else do
            let dt' = DeltaTime (realToFrac dt)
                gs = worldGalaxies world
                t = worldTime world
                sc = worldScale world
                scVel = worldScaleVel world
                frames = worldFrames world
                acc = worldAccum world
                fpsVal = worldFps world
                compAcc = worldCompAccum world
                compVal = worldComplexity world
                debugAcc = worldDebugAccum world
            velocityVerlet dt' t gs (worldA0Buf world) (worldVHalfBuf world) (worldPosBuf world) scaleEqsConfig
            applyWarpIO world gs
            let t' = advanceTime t dt'
            targetSc <- calcScaleIO gs
            let (sc', scVel') =
                    if worldResetScale world
                        then (targetSc, 0)
                        else smoothScale dt sc scVel targetSc
                acc' = addDelta acc dt'
                frames' = frames + 1
                (fpsVal', acc'', frames'') =
                    if unDeltaTime acc' >= unDeltaTime fpsWindow
                        then (fromIntegral frames' / unDeltaTime acc', DeltaTime 0, 0)
                        else (fpsVal, acc', frames')
                compAcc' = addDelta compAcc dt'
            (compVal', compAcc'') <-
                if unDeltaTime compAcc' >= unDeltaTime complexityWindow
                    then do
                        gsSnap <- snapshotGalaxies gs
                        let compVal'' = complexity $ V.map galaxyPos gsSnap
                            !compVal''' = compVal''
                        pure (compVal''', DeltaTime 0)
                    else pure (compVal, compAcc')
            let debugAcc' = addDelta debugAcc dt'
            (avgSpeed, maxSpeed, maxAccel, expansionRate, debugAcc'') <-
                if unDeltaTime debugAcc' >= unDeltaTime debugWindow
                    then do
                        (avgSpeed', maxSpeed', maxAccel') <- calcStatsIO gs
                        let expansionRate' = calcExpansionRate scaleEqsConfig t'
                            !avgSpeed'' = avgSpeed'
                            !maxSpeed'' = maxSpeed'
                            !maxAccel'' = maxAccel'
                            !expansionRate'' = expansionRate'
                        pure (avgSpeed'', maxSpeed'', maxAccel'', expansionRate'', DeltaTime 0)
                    else pure
                        ( worldAvgSpeed world
                        , worldMaxSpeed world
                        , worldMaxAccel world
                        , worldExpansionRate world
                        , debugAcc'
                        )
            let neighborAcc = worldNeighborAccum world
                neighborAcc' = addDelta neighborAcc dt'
            (neighbors', neighborAcc'') <-
                if unDeltaTime neighborAcc' >= unDeltaTime neighborWindow
                    then do
                        gsSnap <- snapshotGalaxies gs
                        let neighbors'' = nearestNeighbors gsSnap
                        pure (neighbors'', DeltaTime 0)
                    else pure (worldNeighbors world, neighborAcc')
            pure world
                { worldTime = t'
                , worldScale = sc'
                , worldScaleVel = scVel'
                , worldFrames = frames''
                , worldAccum = acc''
                , worldFps = fpsVal'
                , worldCompAccum = compAcc''
                , worldComplexity = compVal'
                , worldDebugAccum = debugAcc''
                , worldAvgSpeed = avgSpeed
                , worldMaxSpeed = maxSpeed
                , worldMaxAccel = maxAccel
                , worldExpansionRate = expansionRate
                , worldResetScale = False
                , worldNeighborAccum = neighborAcc''
                , worldNeighbors = neighbors'
                }

snapshotGalaxies :: MV.IOVector (Galaxy Vec2) -> IO (Vector (Galaxy Vec2))
snapshotGalaxies gs =
    V.generateM (MV.length gs) (MV.read gs)

calcScaleVector :: Vector (Galaxy Vec2) -> Float
calcScaleVector gs =
    let maxRad = max 1.0e-6 $ V.maximum $ V.map (vmag . galaxyPos) gs
    in windowRadiusPx / realToFrac maxRad

calcScaleIO :: MV.IOVector (Galaxy Vec2) -> IO Float
calcScaleIO gs = do
    let n = MV.length gs
        go i maxRad
            | i >= n = pure maxRad
            | otherwise = do
                g <- MV.read gs i
                let r = vmag (galaxyPos g)
                    maxRad' = max maxRad r
                go (i + 1) maxRad'
    maxRad <- go 0 1.0e-6
    pure (windowRadiusPx / realToFrac maxRad)

smoothScale :: Float -> Float -> Float -> Float -> (Float, Float)
smoothScale dt current _vel target =
    let lambda = 6
        alpha = 1 - exp (-lambda * dt)
        current' = current + (target - current) * alpha
    in (current', 0)

calcStatsVector :: Vector (Galaxy Vec2) -> (Double, Double, Double)
calcStatsVector gs =
    let speeds = V.map (vmag . galaxyVel) gs
        accs = V.map (vmag . galaxyAcc) gs
        count = fromIntegral (V.length gs)
        totalSpeed = V.sum speeds
        avgSpeed = if count == 0 then 0 else totalSpeed / count
        maxSpeed = if V.null speeds then 0 else V.maximum speeds
        maxAccel = if V.null accs then 0 else V.maximum accs
    in (avgSpeed, maxSpeed, maxAccel)

calcStatsIO :: MV.IOVector (Galaxy Vec2) -> IO (Double, Double, Double)
calcStatsIO gs = do
    let n = MV.length gs
        go i totalSpeed maxSpeed maxAccel
            | i >= n = do
                let count = fromIntegral n
                    avgSpeed = if count == 0 then 0 else totalSpeed / count
                pure (avgSpeed, maxSpeed, maxAccel)
            | otherwise = do
                g <- MV.read gs i
                let speed = vmag (galaxyVel g)
                    accel = vmag (galaxyAcc g)
                    totalSpeed' = totalSpeed + speed
                    maxSpeed' = max maxSpeed speed
                    maxAccel' = max maxAccel accel
                go (i + 1) totalSpeed' maxSpeed' maxAccel'
    go 0 0 0 0

calcExpansionRate :: Scale -> Time -> Double
calcExpansionRate scale time =
    let at = HE.a scale time
        at' = HE.a' scale time
    in if at == 0 then 0 else at' / at

applyWarpIO :: World -> MV.IOVector (Galaxy Vec2) -> IO ()
applyWarpIO world gs =
    case (worldWarpMode world, worldMousePos world) of
        (WarpExpand, Just pos) -> gaussianExpansionIO (worldScale world) pos gs
        (WarpCompress, Just pos) -> gaussianCompressionIO (worldScale world) pos gs
        _ -> pure ()

drawFps :: Double -> Picture
drawFps fpsVal =
    let label = printf "FPS %.1f" fpsVal
    in Translate (-windowHalfW + padding) (windowHalfH - padding) $
        Scale textScale textScale $
        Color white $
        Text label

drawTime :: Time -> Picture
drawTime (Time t) =
    let label = printf "Time %.2f" t
    in Translate (windowHalfW - timeWidth) (windowHalfH - padding) $
        Scale textScale textScale $
        Color white $
        Text label

drawDebug :: Double -> Double -> Double -> Double -> Double -> Picture
drawDebug avgSpeed maxSpeed maxAccel expansionRate complexVal =
    let lineHeight = 18 :: Float
        startX = -windowHalfW + padding
        startY = windowHalfH - padding - 30
        lines =
            [ printf "Avg speed %.3f" avgSpeed
            , printf "Max speed %.3f" maxSpeed
            , printf "Max accel %.3f" maxAccel
            , printf "Expansion rate %.5f" expansionRate
            , printf "Complexity %.3f" complexVal
            ]
        drawLine idx txt =
            Translate startX (startY - fromIntegral idx * lineHeight) $
                Scale textScale textScale $
                Color (greyN 0.9) $
                Text txt
    in Pictures $ zipWith drawLine [0..] lines
