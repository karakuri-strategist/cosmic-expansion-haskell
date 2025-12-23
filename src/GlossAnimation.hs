module GlossAnimation (runGloss) where

import Data.Vector (Vector)
import qualified Data.Vector as V
import Graphics.Gloss hiding (Vector)
import Graphics.Gloss.Interface.Pure.Game (Event)
import Graphics.Gloss.Interface.IO.Game (playIO)
import Text.Printf (printf)
import Complexity (complexity)
import GlossConfig
    ( complexityWidth
    , complexityWindow
    , dotRadiusPx
    , fpsPadding
    , fpsScale
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
import HubbleExpansion
    ( DeltaTime(..)
    , Galaxy
    , Scale
    , Time(..)
    , addDelta
    , advanceTime
    , galaxyAcc
    , galaxyPos
    , nextAccel
    , unDeltaTime
    , velocityVerlet
    )
import InitialGalaxies (initialGalaxiesDisk, initialGalaxiesRandomDisk)
import ScaleFactors (linear)
import Vec (magVec, subVec)

data World = World
    { worldGalaxies :: Vector Galaxy
    , worldTime :: Time
    , worldScale :: Float
    , worldFrames :: Int
    , worldAccum :: DeltaTime
    , worldFps :: Double
    , worldCompAccum :: DeltaTime
    , worldComplexity :: Double
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
    pure $ World gs (Time 0) (calcScale gs) 0 (DeltaTime 0) 0 (DeltaTime 0) compVal

scaleEqsConfig :: Scale
scaleEqsConfig = linear

initialGalaxiesConfig :: IO (Vector Galaxy)
initialGalaxiesConfig = initialGalaxiesRandomDisk


withAccelerations :: Scale -> Vector Galaxy -> Vector Galaxy
withAccelerations scale gs =
    let accs = V.imap (\i g -> nextAccel i g gs (Time 0) scale) gs
    in V.zipWith (\g a -> g { galaxyAcc = a }) gs accs

drawWorld :: World -> Picture
drawWorld (World gs _ sc _ _ fpsVal _ compVal) =
    let neighbors = nearestNeighbors gs
        linkDist = maxLinkDistPx / sc
        colorDist = maxColorDistPx / sc
        haloR = haloRadiusPx / sc
        dotR = dotRadiusPx / sc
        pics = V.toList $ V.imap (\i g -> drawGalaxyWith g (neighbors V.! i) linkDist colorDist haloR dotR) gs
        worldPic = scale sc sc $ Pictures pics
        fpsPic = drawFps fpsVal
        compPic = drawComplexity compVal
    in Pictures [worldPic, fpsPic, compPic]

drawWorldIO :: World -> IO Picture
drawWorldIO w = pure (drawWorld w)

drawGalaxyWith :: Galaxy -> Maybe (Vector Double, Double) -> Float -> Float -> Float -> Float -> Picture
drawGalaxyWith galaxy neighbor linkDist colorDist haloR dotR =
    let (x,y) = toPoint (galaxyPos galaxy)
        (linePic, col) = case neighbor of
            Nothing -> (Blank, coolColor)
            Just (np, dist) ->
                let (nx, ny) = toPoint np
                    d = realToFrac dist
                    t = clamp01 (1 - d / colorDist)
                    lineVisible = d < linkDist
                    lineColor = withAlpha 0.35 $ greyN 0.7
                    line = if lineVisible then Color lineColor $ Line [(x, y), (nx, ny)] else Blank
                in (line, mixColors t (1 - t) warmColor coolColor)
        glow = Color (withAlpha 0.12 col) $ Translate x y $ circleSolid haloR
        dot = Color col $ Translate x y $ circleSolid dotR
    in Pictures [linePic, glow, dot]

nearestNeighbors :: Vector Galaxy -> Vector (Maybe (Vector Double, Double))
nearestNeighbors gs = V.imap (\i g -> nearestFor i g gs) gs

nearestFor :: Int -> Galaxy -> Vector Galaxy -> Maybe (Vector Double, Double)
nearestFor i galaxy gs = V.ifoldl' step Nothing gs
    where
        p = galaxyPos galaxy
        step best j other =
            if i == j
                then best
                else let d = magVec (subVec p (galaxyPos other))
                     in case best of
                            Nothing -> Just (op, d)
                            Just (_, bestD) -> if d < bestD then Just (op, d) else best
            where
                op = galaxyPos other

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
handleEvent _ w = w

handleEventIO :: Event -> World -> IO World
handleEventIO e w = pure (handleEvent e w)

stepWorld :: Scale -> Float -> World -> World
stepWorld scale dt (World gs t sc frames acc fpsVal compAcc compVal) =
    let dt' = DeltaTime (realToFrac dt)
        gs' = velocityVerlet dt' t gs scale
        t' = advanceTime t dt'
        target = calcScale gs'
        sc' = smoothScale sc target
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
    in World gs' t' sc' frames'' acc'' fpsVal' compAcc'' compVal'

stepWorldIO :: Float -> World -> IO World
stepWorldIO dt w = pure (stepWorld scaleEqsConfig dt w)

calcScale :: Vector Galaxy -> Float
calcScale gs =
    let maxRad = max 1.0e-6 $ V.maximum $ V.map (magVec . galaxyPos) gs
    in windowRadiusPx / realToFrac maxRad

smoothScale :: Float -> Float -> Float
smoothScale current target = current + (target - current) * 0.05

drawFps :: Double -> Picture
drawFps fpsVal =
    let label = printf "FPS %.1f" fpsVal
    in Translate (-windowHalfW + fpsPadding) (windowHalfH - fpsPadding) $
        Scale fpsScale fpsScale $
        Color white $
        Text label

drawComplexity :: Double -> Picture
drawComplexity compVal =
    let label = printf "Complexity %.3f" compVal
    in Translate (windowHalfW - complexityWidth) (windowHalfH - fpsPadding) $
        Scale fpsScale fpsScale $
        Color white $
        Text label
