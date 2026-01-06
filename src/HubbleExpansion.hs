{-# LANGUAGE BangPatterns #-}

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

import Data.Vector (Vector)
import qualified Data.Vector as V
import qualified Data.Vector.Mutable as MV
import Control.Monad (forM_)
import PhysicsConfig (gravityG)
import Vec (Vec (vscale, vzero), vadd, vmag, vsub)

velocityVerlet :: Vec a => DeltaTime -> Time -> MV.IOVector (Galaxy a) -> MV.IOVector a -> MV.IOVector a -> MV.IOVector a -> Scale -> IO ()
velocityVerlet dt t gs bufA0 bufVHalf bufPos scaleEqs = do
    let n = MV.length gs
        dtSeconds = unDeltaTime dt
        scaleVals0 = scaleAt scaleEqs t
        scaleVals1 = scaleAt scaleEqs (advanceTime t dt)
    -- Strang split: half drag, full conservative (velocity Verlet), half drag.
    forM_ [0..n - 1] $ \i -> do
        g <- MV.read gs i
        a0 <- accelPosFromGalaxiesIO i (galaxyPos g) gs scaleVals0
        let aDrag0 = accelDrag g scaleVals0
            vHalf = vadd (galaxyVel g) (vscale (dtSeconds / 2) aDrag0)
            pos' = vadd (galaxyPos g)
                    (vadd (vscale dtSeconds vHalf)
                          (vscale (dtSeconds * dtSeconds / 2) a0))
        MV.write bufA0 i a0
        MV.write bufVHalf i vHalf
        MV.write bufPos i pos'
    forM_ [0..n - 1] $ \i -> do
        g <- MV.read gs i
        pos' <- MV.read bufPos i
        aPos1 <- accelPosFromPosIO i pos' bufPos gs scaleVals1
        a0 <- MV.read bufA0 i
        v0h <- MV.read bufVHalf i
        let vConservative = vadd v0h
                (vscale (dtSeconds / 2) (vadd a0 aPos1))
            aDrag1 = accelDragVel vConservative scaleVals1
            vNext = vadd vConservative (vscale (dtSeconds / 2) aDrag1)
            aNext = vadd aPos1 aDrag1
        MV.write gs i g { galaxyPos = pos', galaxyVel = vNext, galaxyAcc = aNext }

accelPosFromGalaxiesIO :: Vec a => Int -> a -> MV.IOVector (Galaxy a) -> (Double, Double, Double) -> IO a
accelPosFromGalaxiesIO i currPos gs (at, _a't, a''t) = do
    let n = MV.length gs
    gForceSum <- sumOthersIO i n $ \j -> do
        g <- MV.read gs j
        pure (gravitationalForceMag currPos g)
    let gForce = vscale (-gravityG / at ** 3) gForceSum
        backgroundAcceleration = vscale (a''t / at) currPos
    pure (vadd gForce (vscale (-1) backgroundAcceleration))

accelPosFromPosIO :: Vec a => Int -> a -> MV.IOVector a -> MV.IOVector (Galaxy a) -> (Double, Double, Double) -> IO a
accelPosFromPosIO i currPos posBuf gs (at, _a't, a''t) = do
    let n = MV.length posBuf
    gForceSum <- sumOthersIO i n $ \j -> do
        otherPos <- MV.read posBuf j
        mass <- galaxyMass <$> MV.read gs j
        pure (gravitationalForceMagPosMass currPos otherPos mass)
    let gForce = vscale (-gravityG / at ** 3) gForceSum
        backgroundAcceleration = vscale (a''t / at) currPos
    pure (vadd gForce (vscale (-1) backgroundAcceleration))

sumOthersIO :: Vec a => Int -> Int -> (Int -> IO a) -> IO a
sumOthersIO i n f = go 0 vzero
    where
        go j !acc
            | j >= n = pure acc
            | j == i = go (j + 1) acc
            | otherwise = do
                val <- f j
                let !acc' = vadd acc val
                go (j + 1) acc'

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
accelDrag galaxy scaleVals =
    accelDragVel (galaxyVel galaxy) scaleVals

accelDragVel :: Vec a => a -> (Double, Double, Double) -> a
accelDragVel vel (at, a't, _a''t) =
    vscale (-(2 * a't / at)) vel


gravitationalForceMag :: Vec a => a -> Galaxy a -> a
gravitationalForceMag pos galaxy =
    let distVec = vsub pos (galaxyPos galaxy)
        scalars = unMass (galaxyMass galaxy) / (vmag distVec)**3
    in vscale scalars distVec

gravitationalForceMagPosMass :: Vec a => a -> a -> Mass -> a
gravitationalForceMagPosMass pos otherPos mass =
    let distVec = vsub pos otherPos
        scalars = unMass mass / (vmag distVec)**3
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
  { galaxyPos :: !a
  , galaxyVel :: !a
  , galaxyAcc :: !a
  , galaxyMass :: {-# UNPACK #-} !Mass
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
