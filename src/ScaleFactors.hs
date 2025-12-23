module ScaleFactors
  ( constantScale
  , slowEarlierFastLate
  , linear
  , matterEra
  , oscillating
  , bounceLike
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
t0 = 10
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

matterEra :: Scale
matterEra = Scale
    { a = \(Time t) -> (t + tEps) ** (2 / 3)
    , a' = \(Time t) -> (2 / 3) * (t + tEps) ** (-1 / 3)
    , a'' = \(Time t) -> (-2 / 9) * (t + tEps) ** (-4 / 3)
    }

tEps :: Double
tEps = 1.0e-3

oscillating :: Scale
oscillating = Scale
    { a = \(Time t) -> oscA0 * (1 + oscE * sin (oscOmega * t))
    , a' = \(Time t) -> oscA0 * oscE * oscOmega * cos (oscOmega * t)
    , a'' = \(Time t) -> -oscA0 * oscE * oscOmega * oscOmega * sin (oscOmega * t)
    }

oscA0 :: Double
oscA0 = 1

oscE :: Double
oscE = 0.25

-- Switch from expansion to contraction at ~60s: t = pi / (2 * omega)
oscOmega :: Double
oscOmega = pi / 120

bounceLike :: Scale
bounceLike = Scale
    { a = \(Time t) -> bounceA0 + bounceAmp * (cos (bounceOmega * t) ** 3)
    , a' = \(Time t) -> -3 * bounceAmp * bounceOmega * (cos (bounceOmega * t) ** 2) * sin (bounceOmega * t)
    , a'' = \(Time t) ->
        let c = cos (bounceOmega * t)
            s = sin (bounceOmega * t)
        in -3 * bounceAmp * bounceOmega * bounceOmega * (c ** 3 - 2 * c * s * s)
    }

bounceA0 :: Double
bounceA0 = 1

bounceAmp :: Double
bounceAmp = 0.35

-- Sharper turnaround than oscillating: half-cycle is still ~60s.
bounceOmega :: Double
bounceOmega = pi / 120
