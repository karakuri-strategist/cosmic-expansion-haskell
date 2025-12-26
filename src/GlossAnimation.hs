module GlossAnimation (runGloss) where

import Data.Vector (Vector)
import qualified Data.Vector as V
import Graphics.Gloss hiding (Vector)
import Graphics.Gloss.Interface.Pure.Game (Event)
import Graphics.Gloss.Interface.IO.Game
    ( playIO
    , Event(EventKey)
    , KeyState(Down)
    , Key(Char, SpecialKey)
    , SpecialKey(KeySpace)
    )
import Text.Printf (printf)
import Complexity (complexity)
import GlossConfig
    ( timeWidth
    , complexityWindow
    , debugWindow
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
import InitialGalaxies (initialGalaxiesDisk, initialGalaxiesRandomDisk)
import ScaleFactors (linear, slowEarlierFastLate, matterEra, oscillating, bounceLike)
import Vec (magVec)
import NearestNeighbors ( nearestNeighbors )

data World = World
    { worldGalaxies :: Vector Galaxy
    , worldTime :: Time
    , worldScale :: Float
    , worldFrames :: Int
    , worldAccum :: DeltaTime
    , worldFps :: Double
    , worldCompAccum :: DeltaTime
    , worldComplexity :: Double
    , worldDebug :: Bool
    , worldDebugAccum :: DeltaTime
    , worldAvgSpeed :: Double
    , worldMaxSpeed :: Double
    , worldMaxAccel :: Double
    , worldExpansionRate :: Double
    , worldPaused :: Bool
    }

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
        (avgSpeed, maxSpeed, maxAccel) = calcStats gs
        expansionRate = calcExpansionRate scaleEqsConfig (Time 0)
    pure $ World gs (Time 0) (calcScale gs) 0 (DeltaTime 0) 0 (DeltaTime 0) compVal False (DeltaTime 0) avgSpeed maxSpeed maxAccel expansionRate False

scaleEqsConfig :: Scale
scaleEqsConfig = bounceLike

initialGalaxiesConfig :: IO (Vector Galaxy)
initialGalaxiesConfig = initialGalaxiesRandomDisk


withAccelerations :: Scale -> Vector Galaxy -> Vector Galaxy
withAccelerations scale gs =
    let scaleVals = scaleAt scale (Time 0)
        accs = V.imap (\i g -> nextAccel i g gs scaleVals) gs
    in V.zipWith (\g a -> g { galaxyAcc = a }) gs accs

drawWorld :: World -> Picture
drawWorld world =
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
        neighbors = nearestNeighbors gs
        linkDist = maxLinkDistPx / sc
        colorDist = maxColorDistPx / sc
        haloR = haloRadiusPx / sc
        dotR = dotRadiusPx / sc
        pics = V.toList $ V.imap (\i g -> drawGalaxyWith g (neighbors V.! i) linkDist colorDist haloR dotR) gs
        worldPic = scale sc sc $ Pictures pics
        timePic = drawTime timeVal
        debugPic =
            if debugEnabled
                then Pictures [drawFps fpsVal, drawDebug avgSpeed maxSpeed maxAccel expansionRate compVal]
                else Blank
    in Pictures [worldPic, timePic, debugPic]

drawWorldIO :: World -> IO Picture
drawWorldIO w = pure (drawWorld w)

drawGalaxyWith :: Galaxy -> Maybe (Vector Double, Double) -> Float -> Float -> Float -> Float -> Picture
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

toPoint :: Vector Double -> (Float, Float)
toPoint v = (realToFrac (v V.! 0), realToFrac (v V.! 1))

handleEvent :: Event -> World -> World
handleEvent (EventKey (SpecialKey KeySpace) Down _ _) world =
    world { worldPaused = not (worldPaused world) }
handleEvent (EventKey (Char key) Down _ _) world
    | key == 'd' || key == 'D' = world { worldDebug = not (worldDebug world) }
handleEvent _ world = world

handleEventIO :: Event -> World -> IO World
handleEventIO (EventKey (Char key) Down _ _) world
    | key == 'r' || key == 'R' = restartWorld world
handleEventIO e w = pure (handleEvent e w)

restartWorld :: World -> IO World
restartWorld world = do
    fresh <- initialWorld
    pure fresh
        { worldDebug = worldDebug world
        , worldPaused = worldPaused world
        }

stepWorld :: Scale -> Float -> World -> World
stepWorld scale dt world =
    if worldPaused world
        then world
        else
    let dt' = DeltaTime (realToFrac dt)
        gs = worldGalaxies world
        t = worldTime world
        sc = worldScale world
        frames = worldFrames world
        acc = worldAccum world
        fpsVal = worldFps world
        compAcc = worldCompAccum world
        compVal = worldComplexity world
        debugAcc = worldDebugAccum world
        gs' = velocityVerlet dt' t gs scale
        t' = advanceTime t dt'
        targetSc = calcScale gs'
        sc' = smoothScale sc targetSc
        acc' = addDelta acc dt'
        frames' = frames + 1
        (fpsVal', acc'', frames'') =
            if unDeltaTime acc' >= unDeltaTime fpsWindow
                then (fromIntegral frames' / unDeltaTime acc', DeltaTime 0, 0)
                else (fpsVal, acc', frames')
        compAcc' = addDelta compAcc dt'
        (compVal', compAcc'') =
            if unDeltaTime compAcc' >= unDeltaTime complexityWindow
                then (complexity $ V.map galaxyPos gs', DeltaTime 0)
                else (compVal, compAcc')
        debugAcc' = addDelta debugAcc dt'
        (avgSpeed, maxSpeed, maxAccel, expansionRate, debugAcc'') =
            if unDeltaTime debugAcc' >= unDeltaTime debugWindow
                then
                    let (avgSpeed', maxSpeed', maxAccel') = calcStats gs'
                        expansionRate' = calcExpansionRate scale t'
                    in (avgSpeed', maxSpeed', maxAccel', expansionRate', DeltaTime 0)
                else
                    ( worldAvgSpeed world
                    , worldMaxSpeed world
                    , worldMaxAccel world
                    , worldExpansionRate world
                    , debugAcc'
                    )
    in world
        { worldGalaxies = gs'
        , worldTime = t'
        , worldScale = sc'
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
        }

stepWorldIO :: Float -> World -> IO World
stepWorldIO dt w = pure (stepWorld scaleEqsConfig dt w)

calcScale :: Vector Galaxy -> Float
calcScale gs =
    let maxRad = max 1.0e-6 $ V.maximum $ V.map (magVec . galaxyPos) gs
    in windowRadiusPx / realToFrac maxRad

smoothScale :: Float -> Float -> Float
smoothScale current target = current + (target - current) * 0.05

calcStats :: Vector Galaxy -> (Double, Double, Double)
calcStats gs =
    let speeds = V.map (magVec . galaxyVel) gs
        accs = V.map (magVec . galaxyAcc) gs
        count = fromIntegral (V.length gs)
        totalSpeed = V.sum speeds
        avgSpeed = if count == 0 then 0 else totalSpeed / count
        maxSpeed = if V.null speeds then 0 else V.maximum speeds
        maxAccel = if V.null accs then 0 else V.maximum accs
    in (avgSpeed, maxSpeed, maxAccel)

calcExpansionRate :: Scale -> Time -> Double
calcExpansionRate scale time =
    let at = HE.a scale time
        at' = HE.a' scale time
    in if at == 0 then 0 else at' / at

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
