module ScaleFactors
  ( constantScale
  , slowEarlierFastLate
  , linear
  ) where

import HubbleExpansion (Scale(..), Time(..))

constantScale :: Scale
constantScale = Scale
    { a = \_ -> 1
    , a' = \_ -> 0
    , a'' = \_ -> 0
    }

p :: Double
p = 1.2
t0 :: Double
t0 = 1000
slowEarlierFastLate :: Scale
slowEarlierFastLate = Scale
    { a = \(Time t) -> 1 + (1 + t / t0) ** p
    , a' = \(Time t) -> (p / t0) * (1 + t / t0) ** (p - 1)
    , a'' = \(Time t) -> (p * (p - 1) / (t0 * t0)) * (1 + t / t0) ** (p - 2)
    }

h = 0.001
linear :: Scale
linear = Scale
    { a = \(Time t) -> 1 + h * t
    , a' = \_ -> h
    , a'' = \_ -> 0
    }
