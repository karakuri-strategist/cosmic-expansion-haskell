module GlossConfig
    ( windowTitle
    , windowWidthPx
    , windowHeightPx
    , windowPosX
    , windowPosY
    , windowHalfW
    , windowHalfH
    , fpsTarget
    , windowRadiusPx
    , haloRadiusPx
    , dotRadiusPx
    , maxLinkDistPx
    , maxColorDistPx
    , fpsWindow
    , complexityWindow
    , debugWindow
    , textScale
    , padding
    , timeWidth
    ) where

import HubbleExpansion (DeltaTime(..))

windowTitle :: String
windowTitle = "Hubble Expansion"

windowWidthPx :: Int
windowWidthPx = 900

windowHeightPx :: Int
windowHeightPx = 700

windowPosX :: Int
windowPosX = 50

windowPosY :: Int
windowPosY = 50

windowHalfW :: Float
windowHalfW = fromIntegral windowWidthPx / 2

windowHalfH :: Float
windowHalfH = fromIntegral windowHeightPx / 2

fpsTarget :: Int
fpsTarget = 60

windowRadiusPx :: Float
windowRadiusPx = 315

haloRadiusPx :: Float
haloRadiusPx = 7

dotRadiusPx :: Float
dotRadiusPx = 2.5

maxLinkDistPx :: Float
maxLinkDistPx = 60

maxColorDistPx :: Float
maxColorDistPx = 90

fpsWindow :: DeltaTime
fpsWindow = DeltaTime 0.1

complexityWindow :: DeltaTime
complexityWindow = DeltaTime 0.5

debugWindow :: DeltaTime
debugWindow = DeltaTime 0.5

textScale :: Float
textScale = 0.12

padding :: Float
padding = 20

timeWidth :: Float
timeWidth = 220
