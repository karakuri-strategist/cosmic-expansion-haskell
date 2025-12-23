module HubbleExpansion
  ( Scale(..)
  , Time(..)
  , DeltaTime(..)
  , Mass(..)
  , Galaxy(..)
  , velocityVerlet
  , nextAccel
  , advanceTime
  , addDelta
  , unDeltaTime
  ) where

import Data.Vector (Vector, (!))
import qualified Data.Vector as V
import Vec (addVec, magVec, multVec, subVec, sumVecs)

velocityVerlet :: DeltaTime -> Time -> Vector Galaxy -> Scale -> Vector Galaxy
velocityVerlet dt t gs scaleEqs =
    let nextPos = V.map advancePos gs
        nextAcc = V.imap (\i g -> nextAccel i g nextPos (advanceTime t dt) scaleEqs) nextPos
    in V.imap (\i g ->
        let aNext = nextAcc ! i
            vNext = addVec (galaxyVel g) (multVec (dtSeconds / 2) (addVec (galaxyAcc g) aNext))
        in g { galaxyVel = vNext, galaxyAcc = aNext }
        ) nextPos
    where
        dtSeconds = unDeltaTime dt
        advancePos :: Galaxy -> Galaxy
        advancePos g =
            let nexPos = sumVecs $ V.fromList
                    [ galaxyPos g
                    , multVec dtSeconds (galaxyVel g)
                    , multVec (dtSeconds**2/2) (galaxyAcc g)
                    ]
            in g { galaxyPos = nexPos }

nextAccel :: Int -> Galaxy -> Vector Galaxy -> Time -> Scale -> Vector Double
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
        scalars = unMass (galaxyMass galaxy) / (magVec distVec)**3
    in multVec scalars distVec

-- Sum contributions from all j != i without allocating a new vector
sumOthers :: Int -> Int -> V.Vector Galaxy -> (Galaxy -> V.Vector Double) -> V.Vector Double
sumOthers i dims gs f =
  V.ifoldl' (\acc j g -> if i == j then acc else addVec acc $ f g) (V.replicate dims 0) gs

-- Scale factor equation and its first and second derivatives
data Scale = Scale
  { a :: Time -> Double
  , a' :: Time -> Double
  , a'' :: Time -> Double
  }

newtype Time = Time Double

newtype DeltaTime = DeltaTime Double

newtype Mass = Mass Double

-- Position, velocity, acceleration and mass
data Galaxy = Galaxy
  { galaxyPos :: V.Vector Double
  , galaxyVel :: V.Vector Double
  , galaxyAcc :: V.Vector Double
  , galaxyMass :: Mass
  }

advanceTime :: Time -> DeltaTime -> Time
advanceTime (Time tVal) (DeltaTime dtVal) = Time (tVal + dtVal)

addDelta :: DeltaTime -> DeltaTime -> DeltaTime
addDelta (DeltaTime a) (DeltaTime b) = DeltaTime (a + b)

unDeltaTime :: DeltaTime -> Double
unDeltaTime (DeltaTime dtVal) = dtVal

unMass :: Mass -> Double
unMass (Mass mVal) = mVal

g = 150
