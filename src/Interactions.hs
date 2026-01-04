module Interactions (applyBlast, gaussianCompression, gaussianExpansion)  where 

import GlossConfig
    ( blastKickRadiusPx
    , blastKickStrengthPx
    , warpGaussSigmaPx
    , warpGaussStrengthPx
    )
import Vec (Vec2, vsub, vmag, vscale, vadd, vmag2)
import Data.Vector as V
import HubbleExpansion (Galaxy (galaxyVel, galaxyAcc, galaxyPos))



applyBlast :: Float -> Vec2 -> Vector (Galaxy Vec2) -> Vector (Galaxy Vec2)
applyBlast sc pos =
    let scaleVal = realToFrac sc
        radius = blastKickRadiusPx / scaleVal
        strength = blastKickStrengthPx / scaleVal
    in V.map (\g ->
        let offset = vsub (galaxyPos g) pos
            dist = vmag offset
        in if dist <= radius && dist > 1.0e-9
            then
                let falloff = 1 - dist / radius
                    dir = vscale (1 / dist) offset
                    kick = vscale (strength * falloff) dir
                    v' = vadd (galaxyVel g) kick
                    a' = vadd (galaxyAcc g) kick
                in g { galaxyVel = v', galaxyAcc = a' }
            else g
        )

gaussianExpansion = gaussianDisplacement 1

gaussianCompression = gaussianDisplacement (-1)

gaussianDisplacement :: Double -> Float -> Vec2 -> Vector (Galaxy Vec2) -> Vector (Galaxy Vec2)
gaussianDisplacement sign sc x =
    let scaleVal = realToFrac sc
        sigmaWorld = warpGaussSigmaPx / scaleVal
        ampWorld = warpGaussStrengthPx / scaleVal
        sigmaSq = sigmaWorld * sigmaWorld
    in V.map (\g ->
        let p = galaxyPos g
            r = vsub p x
            d2 = vmag2 r
        in if d2 <= 1.0e-12
            then g
            else
                let f = sign * ampWorld * exp (-d2 / (2 * sigmaSq))
                    newPos = vadd p (vscale (f / sqrt d2) r)
                in g { galaxyPos = newPos }
        )
