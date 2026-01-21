module NearestNeighbors (nearestNeighbors) where

import qualified Data.Vector.Mutable as MV
import HubbleExpansion (Galaxy(galaxyPos))
import Vec (Vec (vmag2, vsub))

nearestNeighbors :: Vec a => MV.IOVector (Galaxy a) -> MV.IOVector (Maybe (a, Double)) -> IO ()
nearestNeighbors gs out = do
    let n = MV.length gs
    go 0 n
    where
        go i n
            | i >= n = pure ()
            | otherwise = do
                g <- MV.read gs i
                let p = galaxyPos g
                result <- nearestFor i p gs n
                MV.write out i result
                go (i + 1) n

data Best a = Best
    { bestFound :: !Bool
    , bestPos :: !a
    , bestD2 :: !Double
    }

nearestFor :: Vec a => Int -> a -> MV.IOVector (Galaxy a) -> Int -> IO (Maybe (a, Double))
nearestFor i p gs n = do
    best <- go 0 (Best False p (1 / 0))
    pure (if bestFound best then Just (bestPos best, bestD2 best) else Nothing)
    where
        go j best
            | j >= n = pure best
            | j == i = go (j + 1) best
            | otherwise = do
                g <- MV.read gs j
                let op = galaxyPos g
                    d2 = vmag2 (vsub p op)
                    best' =
                        if d2 < bestD2 best
                            then Best True op d2
                            else best
                go (j + 1) best'
