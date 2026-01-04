module InitialGalaxies
    ( initialGalaxies
    , initialGalaxiesDisk
    , initialGalaxiesRandomDisk
    , initialGalaxiesClusteredDisk
    ) where

import Data.Vector (Vector)
import qualified Data.Vector as V
import HubbleExpansion (Galaxy(..), Mass(..))
import System.Random (newStdGen, randomRs, mkStdGen)
import Vec (Vec2(Vec2), vadd, vzero)

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
    let n = 50
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

initialGalaxiesClusteredDisk :: IO (Vector (Galaxy Vec2))
initialGalaxiesClusteredDisk = do
    gen <- newStdGen
    let n = 120
        mass = Mass 1
        v0 = 0.08
        clusters = 4
        rMax = 150
        clusterRadius = 35
        vals = randomRs (0.0, 1.0) gen
        (centerVals, rest0) = splitAt (2 * clusters) vals
        (choiceVals, rest1) = splitAt n rest0
        (posVals, rest2) = splitAt (2 * n) rest1
        (velVals, _) = splitAt (2 * n) rest2
        centers = map toDiskPos (toPairs centerVals)
        posPairs = toPairs posVals
        velPairs = toPairs velVals
        toDiskPos (u, v) =
            let r = rMax * sqrt u
                ang = 2 * pi * v
            in Vec2 (r * cos ang) (r * sin ang)
        toGalaxy choice (u, v) (vu, vv) =
            let clusterIdx = min (clusters - 1) (floor (choice * fromIntegral clusters))
                center = centers !! clusterIdx
                r = clusterRadius * sqrt u
                ang = 2 * pi * v
                offset = Vec2 (r * cos ang) (r * sin ang)
                pos = vadd center offset
                vMag = v0 * (0.2 + 0.8 * vu)
                vAng = 2 * pi * vv
                vel = Vec2 (vMag * cos vAng) (vMag * sin vAng)
            in Galaxy
                { galaxyPos = pos
                , galaxyVel = vel
                , galaxyAcc = vzero
                , galaxyMass = mass
                }
    pure $ V.fromList $ zipWith3 toGalaxy choiceVals posPairs velPairs

toPairs :: [a] -> [(a, a)]
toPairs (x:y:rest) = (x, y) : toPairs rest
toPairs _ = []
