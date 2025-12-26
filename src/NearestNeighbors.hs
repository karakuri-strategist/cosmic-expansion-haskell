module NearestNeighbors (nearestNeighbors) where

import Data.Vector (Vector)
import qualified Data.Vector as V
import HubbleExpansion ( Galaxy(galaxyPos) )
import Vec ( subVec, magVecSquared )

nearestNeighbors :: Vector Galaxy -> Vector (Maybe (Vector Double, Double))
nearestNeighbors gs = V.imap (\i g -> nearestFor i g gs) gs

nearestFor :: Int -> Galaxy -> Vector Galaxy -> Maybe (Vector Double, Double)
nearestFor i galaxy gs = V.ifoldl' step Nothing gs
    where
        p = galaxyPos galaxy
        step best j other =
            if i == j
                then best
                else let d2 = magVecSquared (subVec p (galaxyPos other))
                     in case best of
                            Nothing -> Just (op, d2)
                            Just (_, bestD2) -> if d2 < bestD2 then Just (op, d2) else best
            where
                op = galaxyPos other