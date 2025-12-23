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
    , fpsScale
    , fpsPadding
    , complexityWidth
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
fpsWindow = DeltaTime 0.5

complexityWindow :: DeltaTime
complexityWindow = DeltaTime 0.5

debugWindow :: DeltaTime
debugWindow = DeltaTime 0.5

fpsScale :: Float
fpsScale = 0.12

fpsPadding :: Float
fpsPadding = 20

complexityWidth :: Float
complexityWidth = 220
