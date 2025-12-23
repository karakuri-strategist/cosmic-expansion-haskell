module HubbleExpansion where

import Data.Vector (Vector, (!))
import qualified Data.Vector as V

velocityVerlet :: Double -> Double -> Vector Galaxy -> Scale -> Vector Galaxy
velocityVerlet t dt gs scaleEqs =
    let nextPos = V.map advancePos gs
        nextAcc = V.imap (\i g -> nextAccel i g nextPos (t + dt) scaleEqs) nextPos
    in V.imap (\i g ->
        let aNext = nextAcc ! i
            vNext = addVec (galaxyVel g) (multVec (dt/2) (addVec (galaxyAcc g) aNext))
        in g { galaxyVel = vNext, galaxyAcc = aNext }
        ) nextPos
    where
        advancePos :: Galaxy -> Galaxy
        advancePos g =
            let nexPos = sumVecs $ V.fromList
                    [ galaxyPos g
                    , multVec dt (galaxyVel g)
                    , multVec (dt**2/2) (galaxyAcc g)
                    ]
            in g { galaxyPos = nexPos }

nextAccel :: Int -> Galaxy -> Vector Galaxy -> Double -> Scale -> Vector Double
nextAccel i galaxy galaxies t (Scale a a' a'')  =
    let (at, a't, a''t) = (a t, a' t, a'' t)
        prevPos = galaxyPos galaxy
        prevVel = galaxyVel galaxy
        gForceSum = sumOthers i (length prevPos) galaxies (gravitationalForceMag prevPos)
        gForce = multVec (-g / at**3) gForceSum
        hubbleFriction = multVec (2 * a't / at) prevVel
        backgroundAcceleration = multVec (a''t / at) prevPos
    in sumVecs $ V.fromList [gForce, multVec (-1) hubbleFriction, multVec (-1) backgroundAcceleration]


gravitationalForceMag :: V.Vector Double -> Galaxy -> V.Vector Double
gravitationalForceMag pos galaxy =
    let distVec = subVec pos (galaxyPos galaxy)
        scalars = galaxyMass galaxy / (magVec distVec)**3
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

-- Scale factor equation and its first and second derivatives
data Scale = Scale
  { a :: Double -> Double
  , a' :: Double -> Double
  , a'' :: Double -> Double
  }

-- Position, velocity, acceleration and mass
data Galaxy = Galaxy
  { galaxyPos :: V.Vector Double
  , galaxyVel :: V.Vector Double
  , galaxyAcc :: V.Vector Double
  , galaxyMass :: Double
  }

g = 1
