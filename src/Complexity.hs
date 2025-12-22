module Complexity where

complexity rs = sqrt (sum [r**2 | r <- rs]) * sum [1/r | r <- rs]

distance (x1,y1) (x2,y2) = sqrt ((x2-x1)^2 + (y2-y1)^2)

distancesBetween = perCombination distance 

perCombination f [] = []
perCombination f (x:[]) = []
perCombination f (x:xs) = map (f x) xs ++ perCombination f xs

sillyDistribution x = (0,0) : sillyDistro 0 x
    where
        sillyDistro prevAngle x =
            let nextAngle = prevAngle + 0.2
                nextMag = log (1 + nextAngle)
                nextVec = (cos nextAngle * nextMag, sin nextAngle * nextMag)
            in if x <= 1
                then [nextVec]
                else nextVec : sillyDistro nextAngle (x-1)

                