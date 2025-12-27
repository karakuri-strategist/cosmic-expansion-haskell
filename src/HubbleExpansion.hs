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
  , scaleAt
  ) where

import Data.Vector (Vector, (!))
import qualified Data.Vector as V
import PhysicsConfig (gravityG)
import Vec (Vec (vscale, vzero), vadd, vmag, vsub)

velocityVerlet :: Vec a => DeltaTime -> Time -> Vector (Galaxy a) -> Scale -> Vector (Galaxy a)
velocityVerlet dt t gs scaleEqs =
    -- Split acceleration into position-dependent and velocity-dependent parts:
    -- position is advanced with a_pos only, and drag is applied explicitly to velocity.
    let scaleVals0 = scaleAt scaleEqs t
        scaleVals1 = scaleAt scaleEqs (advanceTime t dt)
        aPos0 = V.imap (\i g -> accelPos i g gs scaleVals0) gs
        nextPos = V.imap (\i g ->
            let pos' = vadd (galaxyPos g)
                        (vadd (vscale dtSeconds (galaxyVel g))
                              (vscale (dtSeconds * dtSeconds / 2) (aPos0 ! i)))
            in g { galaxyPos = pos' }
            ) gs
    in V.imap (\i g ->
        let g0 = gs ! i
            aPos1 = accelPos i g nextPos scaleVals1
            aDrag0 = accelDrag g0 scaleVals0
            vNext = vadd (galaxyVel g0)
                (vadd (vscale (dtSeconds / 2) (vadd (aPos0 ! i) aPos1))
                      (vscale dtSeconds aDrag0))
            aNext = vadd aPos1 aDrag0
        in g { galaxyVel = vNext, galaxyAcc = aNext }
        ) nextPos
    where
        dtSeconds = unDeltaTime dt

nextAccel :: Vec a => Int -> Galaxy a -> Vector (Galaxy a) -> (Double, Double, Double) -> a
nextAccel i galaxy galaxies (at, a't, a''t) =
    vadd
        (accelPos i galaxy galaxies (at, a't, a''t))
        (accelDrag galaxy (at, a't, a''t))

accelPos :: Vec a => Int -> Galaxy a -> Vector (Galaxy a) -> (Double, Double, Double) -> a
accelPos i galaxy galaxies (at, _a't, a''t) =
    let currPos = galaxyPos galaxy
        gForceSum = sumOthers i galaxies (gravitationalForceMag currPos)
        gForce = vscale (-gravityG / at ** 3) gForceSum
        backgroundAcceleration = vscale (a''t / at) currPos
    in vadd gForce (vscale (-1) backgroundAcceleration)

accelDrag :: Vec a => Galaxy a -> (Double, Double, Double) -> a
accelDrag galaxy (at, a't, _a''t) =
    let currVel = galaxyVel galaxy
    in vscale (-(2 * a't / at)) currVel


gravitationalForceMag :: Vec a => a -> Galaxy a -> a
gravitationalForceMag pos galaxy =
    let distVec = vsub pos (galaxyPos galaxy)
        scalars = unMass (galaxyMass galaxy) / (vmag distVec)**3
    in vscale scalars distVec

-- Sum contributions from all j != i without allocating a new vector
sumOthers :: Vec a => Int -> V.Vector (Galaxy a) -> (Galaxy a -> a) -> a
sumOthers i gs f =
  V.ifoldl' (\acc j g -> if i == j then acc else vadd acc $ f g) vzero gs

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
data Galaxy a = Galaxy
  { galaxyPos :: a
  , galaxyVel :: a
  , galaxyAcc :: a
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

scaleAt :: Scale -> Time -> (Double, Double, Double)
scaleAt (Scale a a' a'') t = (a t, a' t, a'' t)
