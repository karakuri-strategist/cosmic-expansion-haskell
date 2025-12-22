module HubbleExpansion where

import Data.Vector (Vector)
import qualified Data.Vector as V


velocityVerlet :: Double -> Double -> Vector Galaxy -> Scale -> Vector Galaxy
velocityVerlet dt t gs scaleEqs = V.imap evolveGalaxy gs
    where
        evolveGalaxy :: Int -> Galaxy -> Galaxy
        evolveGalaxy i g@(p,v,a,m) =
            let nexPos = sumVecs $ V.fromList [p, multVec dt v, multVec (dt**2/2) a]
                nexAccel = nextAccel i g gs t scaleEqs
                nexVel = addVec v (multVec (dt/2) (addVec a nexAccel))
            in (nexPos, nexVel, nexAccel,m)

-- Takes one galaxy, all the other galaxies, the current time, the scale equations and returns the next acceleration for that galaxy
nextAccel :: Int -> Galaxy -> Vector Galaxy -> Double -> Scale -> Vector Double
nextAccel i (prevPos,prevVel,_,_) galaxies t (a,a',a'')  =
    let (at, a't, a''t) = (a t, a' t, a'' t)
        gForceSum = sumOthers i (length prevPos) galaxies (gravitationalForceMag prevPos)
        gForce = multVec (-g / at**3) gForceSum
        hubbleFriction = multVec (2 * a't / at) prevVel
        backgroundAcceleration = multVec (a''t / at) prevPos
    in sumVecs $ V.fromList [gForce, multVec (-1) hubbleFriction, multVec (-1) backgroundAcceleration]


gravitationalForceMag :: V.Vector Double -> Galaxy -> V.Vector Double
gravitationalForceMag pos (oPos,_,_,mass) = 
    let distVec = subVec pos oPos
        scalars = mass / (magVec distVec)**3
    in multVec scalars distVec

-- Sum contributions from all j != i without allocating a new vector
sumOthers :: Int -> Int -> V.Vector Galaxy -> (Galaxy -> V.Vector Double) -> V.Vector Double
sumOthers i dims gs f =
  V.ifoldl' (\acc j g -> if i == j then acc else addVec acc $ f g) (V.replicate dims 0) gs

addVec :: Num c => Vector c -> Vector c -> Vector c
addVec v1 v2 = V.zipWith (\x1 x2 -> x1 + x2) v1 v2

subVec :: Num c => Vector c -> Vector c -> Vector c
subVec v1 v2 = V.zipWith (\x1 x2 -> x1 - x2) v1 v2

magVec :: Vector Double -> Double
magVec v = sqrt (V.foldl' (\acc x -> acc + x^2) 0 v)

multVec :: Num b => b -> Vector b -> Vector b
multVec d = V.map (\x -> x*d)

sumVecs :: Vector (Vector Double) -> Vector Double
sumVecs vs = V.foldl1' (\acc v -> addVec acc v) vs

-- Tuple containing the scale factor equation and it's first and second derivatives
type Scale = (Double -> Double, Double -> Double, Double -> Double)

-- Position, velocity, acceleration and mass
type Galaxy = (V.Vector Double, V.Vector Double, V.Vector Double, Double)

g = 1