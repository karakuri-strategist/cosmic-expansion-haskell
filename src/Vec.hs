module Vec
  ( addVec
  , subVec
  , magVec
  , multVec
  , sumVecs
  , distVec
  , zeroVec
  ) where

import Data.Vector (Vector)
import qualified Data.Vector as V

addVec :: Num c => Vector c -> Vector c -> Vector c
addVec v1 v2 = V.zipWith (\x1 x2 -> x1 + x2) v1 v2

subVec :: Num c => Vector c -> Vector c -> Vector c
subVec v1 v2 = V.zipWith (\x1 x2 -> x1 - x2) v1 v2

magVec :: Vector Double -> Double
magVec v = sqrt (V.foldl' (\acc x -> acc + x^2) 0 v)

multVec :: Num b => b -> Vector b -> Vector b
multVec d = V.map (\x -> x * d)

sumVecs :: Vector (Vector Double) -> Vector Double
sumVecs vs =
    case V.uncons vs of
        Nothing -> V.empty
        Just (v0, rest) -> V.foldl' addVec v0 rest

distVec :: V.Vector Double -> V.Vector Double -> Double
distVec a b = sqrt $ V.sum $ V.zipWith (\x y -> (x - y) * (x - y)) a b

zeroVec :: Int -> Vector Double
zeroVec dims = V.replicate dims 0
