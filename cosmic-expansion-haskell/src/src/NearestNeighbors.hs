module NearestNeighbors (nearestNeighbors) where

import Data.Vector (Vector)
import qualified Data.Vector as V
import HubbleExpansion (Galaxy(galaxyPos))
import Vec (Vec (vmag2, vsub))

nearestNeighbors :: Vec a => Vector (Galaxy a) -> Vector (Maybe (a, Double))
nearestNeighbors gs =
    let positions = V.map galaxyPos gs
    in V.imap (\i p -> nearestFor i p positions) positions

data Best a = Best
    { bestFound :: !Bool
    , bestPos :: !a
    , bestD2 :: !Double
    }

nearestFor :: Vec a => Int -> a -> Vector a -> Maybe (a, Double)
nearestFor i p ps =
    let Best found pos d2 = V.ifoldl' step (Best False p (1 / 0)) ps
    in if found then Just (pos, d2) else Nothing
    where
        step best j op =
            if i == j
                then best
                else
                    let d2 = vmag2 (vsub p op)
                    in if d2 < bestD2 best
                        then Best True op d2
                        else best
