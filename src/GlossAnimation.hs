module GlossAnimation (runGloss) where

import Data.Vector (Vector)
import qualified Data.Vector as V
import Graphics.Gloss hiding (Vector)
import Graphics.Gloss.Interface.Pure.Game (play,Event)

import HubbleExpansion

data World = World
    { worldGalaxies :: Vector Galaxy
    , worldTime :: Double
    , worldScale :: Float
    }

runGloss :: IO ()
runGloss = play displayUniverse background fps initialWorld drawWorld handleEvent stepWorld

displayUniverse :: Display
displayUniverse = InWindow "Hubble Expansion" (900, 700) (50, 50)

background :: Color
background = black

fps :: Int
fps = 60

initialWorld :: World
initialWorld =
    let gs = withAccelerations initialGalaxies
    in World gs 0 (calcScale gs)

scaleEqs :: Scale
scaleEqs = (\_ -> 1, \_ -> 0, \_ -> 0)

initialGalaxies :: Vector Galaxy
initialGalaxies =
    let n = 50
        mass = 1
        v0 = 0.15
        toGalaxy i =
            let frac = fromIntegral i / fromIntegral n
                ang = frac * 2 * pi
                r = 150 * sqrt frac
                pos = V.fromList [r * cos ang, r * sin ang]
                vel = V.fromList [-sin ang * v0, cos ang * v0]
            in (pos, vel, zeroVec, mass)
    in V.generate n toGalaxy

zeroVec :: Vector Double
zeroVec = V.replicate 2 0

withAccelerations :: Vector Galaxy -> Vector Galaxy
withAccelerations gs =
    let accs = V.imap (\i g -> nextAccel i g gs 0 scaleEqs) gs
    in V.zipWith (\(p,v,_,m) a -> (p,v,a,m)) gs accs

drawWorld :: World -> Picture
drawWorld (World gs _ sc) =
    scale sc sc $ Pictures $ V.toList $ V.map drawGalaxy gs

drawGalaxy :: Galaxy -> Picture
drawGalaxy (p,_,_,_) =
    let (x,y) = toPoint p
        link = Color (greyN 0.35) $ Line [(0, 0), (x, y)]
        dot = Color white $ Translate x y $ circleSolid 2
    in Pictures [link, dot]

toPoint :: Vector Double -> (Float, Float)
toPoint v = (realToFrac (v V.! 0), realToFrac (v V.! 1))

handleEvent :: Event -> World -> World
handleEvent _ w = w

stepWorld :: Float -> World -> World
stepWorld dt (World gs t sc) =
    let dt' = realToFrac dt
        gs' = velocityVerlet dt' t gs scaleEqs
        t' = t + dt'
        target = calcScale gs'
        sc' = smoothScale sc target
    in World gs' t' sc'

calcScale :: Vector Galaxy -> Float
calcScale gs =
    let maxRad = max 1.0e-6 $ V.maximum $ V.map (magVec . galaxyPos) gs
    in windowRadius / realToFrac maxRad

smoothScale :: Float -> Float -> Float
smoothScale current target = current + (target - current) * 0.05

windowRadius :: Float
windowRadius = 315

galaxyPos :: Galaxy -> Vector Double
galaxyPos (p,_,_,_) = p
