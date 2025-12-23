module ScaleFactors where

import HubbleExpansion (Scale)

constantScale :: Scale
constantScale = (\_ -> 1, \_ -> 0, \_ -> 0)

p :: Double
p = 1.2
t0 :: Double
t0 = 1000
slowEarlierFastLate :: Scale
slowEarlierFastLate = (
    \ t -> 1 + (1 + t/t0) ** p
    , \ t -> (p / t0) * (1 + t/t0) ** (p - 1)
    , \ t -> (p * (p - 1) / (t0 * t0)) * (1 + t/t0) ** (p - 2)
    )

h = 0.001
linear :: Scale
linear = (
        \t -> 1 + h*t
        , \_ -> h
        , \_ -> 0
    )