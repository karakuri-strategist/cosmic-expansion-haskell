module GlossAnimation (runGloss) where

import Data.Vector (Vector)
import qualified Data.Vector as V
import Graphics.Gloss hiding (Vector)
import Graphics.Gloss.Interface.Pure.Game (Event)
import Graphics.Gloss.Interface.IO.Game (playIO)
import Text.Printf (printf)
import Complexity (complexity)
import HubbleExpansion
import InitialGalaxies (initialGalaxiesDisk)
import ScaleFactors (linear)

data World = World
    { worldGalaxies :: Vector Galaxy
    , worldTime :: Double
    , worldScale :: Float
    , worldFrames :: Int
    , worldAccum :: Double
    , worldFps :: Double
    , worldCompAccum :: Double
    , worldComplexity :: Double
    }

runGloss :: IO ()
runGloss = do
    world0 <- initialWorld
    playIO displayUniverse background fps world0 drawWorldIO handleEventIO stepWorldIO

displayUniverse :: Display
displayUniverse = InWindow "Hubble Expansion" (900, 700) (50, 50)

background :: Color
background = black

fps :: Int
fps = 60

initialWorld :: IO World
initialWorld = do
    gs0 <- initialGalaxiesConfig
    let gs = withAccelerations scaleEqsConfig gs0
        compVal = complexity $ V.map galaxyPos gs
    pure $ World gs 0 (calcScale gs) 0 0 0 0 compVal

scaleEqsConfig :: Scale
scaleEqsConfig = linear

initialGalaxiesConfig :: IO (Vector Galaxy)
initialGalaxiesConfig = pure initialGalaxiesDisk


withAccelerations :: Scale -> Vector Galaxy -> Vector Galaxy
withAccelerations scale gs =
    let accs = V.imap (\i g -> nextAccel i g gs 0 scale) gs
    in V.zipWith (\(p,v,_,m) a -> (p,v,a,m)) gs accs

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
drawGalaxyWith (p,_,_,_) neighbor linkDist colorDist haloR dotR =
    let (x,y) = toPoint p
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
nearestFor i (p,_,_,_) gs =
    V.ifoldl' step Nothing gs
    where
        step best j (op,_,_,_) =
            if i == j
                then best
                else let d = magVec (subVec p op)
                     in case best of
                            Nothing -> Just (op, d)
                            Just (_, bestD) -> if d < bestD then Just (op, d) else best

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
    let dt' = realToFrac dt
        gs' = velocityVerlet dt' t gs scale
        t' = t + dt'
        target = calcScale gs'
        sc' = smoothScale sc target
        acc' = acc + dt'
        frames' = frames + 1
        (fpsVal', acc'', frames'') =
            if acc' >= fpsWindow
                then (fromIntegral frames' / acc', 0, 0)
                else (fpsVal, acc', frames')
        compAcc' = compAcc + dt'
        (compVal', compAcc'') =
            if compAcc' >= complexityWindow
                then (complexity $ V.map galaxyPos gs', 0)
                else (compVal, compAcc')
    in World gs' t' sc' frames'' acc'' fpsVal' compAcc'' compVal'

stepWorldIO :: Float -> World -> IO World
stepWorldIO dt w = pure (stepWorld scaleEqsConfig dt w)

calcScale :: Vector Galaxy -> Float
calcScale gs =
    let maxRad = max 1.0e-6 $ V.maximum $ V.map (magVec . galaxyPos) gs
    in windowRadius / realToFrac maxRad

smoothScale :: Float -> Float -> Float
smoothScale current target = current + (target - current) * 0.05

windowRadius :: Float
windowRadius = 315

haloRadiusPx :: Float
haloRadiusPx = 7

dotRadiusPx :: Float
dotRadiusPx = 2.5

maxLinkDistPx :: Float
maxLinkDistPx = 60

maxColorDistPx :: Float
maxColorDistPx = 90

fpsWindow :: Double
fpsWindow = 0.5

complexityWindow :: Double
complexityWindow = 0.5

fpsScale :: Float
fpsScale = 0.12

fpsPadding :: Float
fpsPadding = 20

drawFps :: Double -> Picture
drawFps fpsVal =
    let label = printf "FPS %.1f" fpsVal
    in Translate (-halfW + fpsPadding) (halfH - fpsPadding) $
        Scale fpsScale fpsScale $
        Color white $
        Text label

halfW :: Float
halfW = 450

halfH :: Float
halfH = 350

complexityWidth :: Float
complexityWidth = 220

drawComplexity :: Double -> Picture
drawComplexity compVal =
    let label = printf "Complexity %.3f" compVal
    in Translate (halfW - complexityWidth) (halfH - fpsPadding) $
        Scale fpsScale fpsScale $
        Color white $
        Text label

galaxyPos :: Galaxy -> Vector Double
galaxyPos (p,_,_,_) = p
