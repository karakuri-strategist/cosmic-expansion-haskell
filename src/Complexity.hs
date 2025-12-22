module Complexity where

import Data.Vector (Vector, fromList)

complexity rs = sqrt (sum [r**2 | r <- rs]) * sum [1/r | r <- rs]

distance (x1,y1) (x2,y2) = sqrt ((x2-x1)^2 + (y2-y1)^2)

distancesBetween = perCombination distance 

perCombination f [] = []
perCombination f (x:[]) = []
perCombination f (x:xs) = map (f x) xs ++ perCombination f xs

sillyDistribution :: (Ord t, Num t, Floating b) => t -> [Vector b]
sillyDistribution x = fromList [0,0] : sillyDistro 0 x
    where
        sillyDistro prevAngle x =
            let nextAngle = prevAngle + 0.2
                nextMag = log (1 + nextAngle)
                nextVec = fromList [cos nextAngle * nextMag, sin nextAngle * nextMag]
            in if x <= 1
                then [nextVec]
                else nextVec : sillyDistro nextAngle (x-1)

                