module InitialGalaxies
    ( initialGalaxies
    , initialGalaxiesDisk
    , initialGalaxiesRandomDisk
    ) where

import Data.Vector (Vector)
import qualified Data.Vector as V
import HubbleExpansion (Galaxy(..), Mass(..))
import System.Random (newStdGen, randomRs, mkStdGen)
import Vec (Vec2(Vec2), vzero)

initialGalaxies :: Vector (Galaxy Vec2)
initialGalaxies =
    let n = 50
        mass = Mass 1
        v0 = 0.15
        toGalaxy i =
            let frac = fromIntegral i / fromIntegral n
                ang = frac * 2 * pi
                r = 150 * sqrt frac
                pos = Vec2 (r * cos ang) (r * sin ang)
                vel = Vec2 (-sin ang * v0) (cos ang * v0)
            in Galaxy
                { galaxyPos = pos
                , galaxyVel = vel
                , galaxyAcc = vzero
                , galaxyMass = mass
                }
    in V.generate n toGalaxy

initialGalaxiesDisk :: Vector (Galaxy Vec2)
initialGalaxiesDisk =
    let n = 80
        mass = Mass 1
        v0 = 0.12
        rings = 10
        base = n `div` rings
        extra = n `mod` rings
        toGalaxy i =
            let (ring, idx) = i `divMod` base
                ring' = if ring >= rings then rings - 1 else ring
                extraOffset = if ring >= rings then i - (rings * base) else 0
                count = base + if ring' < extra then 1 else 0
                idx' = if ring >= rings then extraOffset else idx
                frac = fromIntegral idx' / fromIntegral (max 1 count)
                ang = frac * 2 * pi
                r = 25 + fromIntegral ring' * 15
                pos = Vec2 (r * cos ang) (r * sin ang)
                vel = Vec2 (-sin ang * v0) (cos ang * v0)
            in Galaxy
                { galaxyPos = pos
                , galaxyVel = vel
                , galaxyAcc = vzero
                , galaxyMass = mass
                }
    in V.generate n toGalaxy

initialGalaxiesRandomDisk :: IO (Vector (Galaxy Vec2))
initialGalaxiesRandomDisk = do
    gen <- newStdGen
    let n = 80
        mass = Mass 1
        v0 = 0.12
        rMax = 150
        vals = take (2 * n) $ randomRs (0.0, 1.0) gen
        pairs = toPairs vals
        toGalaxy (u, v) =
            let r = rMax * sqrt u
                ang = 2 * pi * v
                pos = Vec2 (r * cos ang) (r * sin ang)
                vel = Vec2 (-sin ang * v0) (cos ang * v0)
            in Galaxy
                { galaxyPos = pos
                , galaxyVel = vel
                , galaxyAcc = vzero
                , galaxyMass = mass
                }
    pure $ V.fromList $ map toGalaxy pairs

toPairs :: [a] -> [(a, a)]
toPairs (x:y:rest) = (x, y) : toPairs rest
toPairs _ = []
