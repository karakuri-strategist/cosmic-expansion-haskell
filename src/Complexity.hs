module Complexity (complexity) where

import qualified Data.Vector as V
import Vec (distVec)

-- Vector-based complexity: pairwise distances between all points.
complexity :: V.Vector (V.Vector Double) -> Double
complexity ps =
    let (sumSq, sumInv) = pairSums ps
    in sqrt sumSq * sumInv

pairSums :: V.Vector (V.Vector Double) -> (Double, Double)
pairSums ps =
    V.ifoldl' step (0, 0) ps
    where
        step (sumSq, sumInv) i p =
            let (sqAdd, invAdd) = V.ifoldl' (inner p i) (0, 0) ps
            in (sumSq + sqAdd, sumInv + invAdd)
        inner p i (sqAcc, invAcc) j q =
            if j <= i
                then (sqAcc, invAcc)
                else let d = distVec p q
                     in (sqAcc + d * d, invAcc + 1 / d)
