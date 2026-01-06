module Interactions (applyBlastIO, gaussianCompressionIO, gaussianExpansionIO)  where 

import GlossConfig
    ( blastKickRadiusPx
    , blastKickStrengthPx
    , warpGaussSigmaPx
    , warpGaussStrengthPx
    )
import Vec (Vec2, vsub, vmag, vscale, vadd, vmag2)
import qualified Data.Vector.Mutable as MV
import Control.Monad (forM_)
import HubbleExpansion (Galaxy (galaxyVel, galaxyAcc, galaxyPos))



applyBlastIO :: Float -> Vec2 -> MV.IOVector (Galaxy Vec2) -> IO ()
applyBlastIO sc pos gs = do
    let scaleVal = realToFrac sc
        radius = blastKickRadiusPx / scaleVal
        strength = blastKickStrengthPx / scaleVal
        n = MV.length gs
    forM_ [0..n - 1] $ \i -> do
        g <- MV.read gs i
        let offset = vsub (galaxyPos g) pos
            dist = vmag offset
        if dist <= radius && dist > 1.0e-9
            then
                let falloff = 1 - dist / radius
                    dir = vscale (1 / dist) offset
                    kick = vscale (strength * falloff) dir
                    v' = vadd (galaxyVel g) kick
                    a' = vadd (galaxyAcc g) kick
                in MV.write gs i g { galaxyVel = v', galaxyAcc = a' }
            else pure ()

gaussianExpansionIO :: Float -> Vec2 -> MV.IOVector (Galaxy Vec2) -> IO ()
gaussianExpansionIO = gaussianDisplacementIO 1

gaussianCompressionIO :: Float -> Vec2 -> MV.IOVector (Galaxy Vec2) -> IO ()
gaussianCompressionIO = gaussianDisplacementIO (-1)

gaussianDisplacementIO :: Double -> Float -> Vec2 -> MV.IOVector (Galaxy Vec2) -> IO ()
gaussianDisplacementIO sign sc x gs = do
    let scaleVal = realToFrac sc
        sigmaWorld = warpGaussSigmaPx / scaleVal
        ampWorld = warpGaussStrengthPx / scaleVal
        sigmaSq = sigmaWorld * sigmaWorld
        n = MV.length gs
    forM_ [0..n - 1] $ \i -> do
        g <- MV.read gs i
        let p = galaxyPos g
            r = vsub p x
            d2 = vmag2 r
        if d2 <= 1.0e-12
            then pure ()
            else
                let f = sign * ampWorld * exp (-d2 / (2 * sigmaSq))
                    newPos = vadd p (vscale (f / sqrt d2) r)
                in MV.write gs i g { galaxyPos = newPos }
