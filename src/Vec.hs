module Vec
  ( addVec
  , subVec
  , magVec
  , magVecSquared
  , multVec
  , sumVecs
  , distVec
  , zeroVec
  ,vmag
  , Vec(vadd,vsub,vscale,vmag2,vzero,vdist)
  , Vec2(Vec2)
  ,Vec3(Vec3)
  ) where

import Data.Vector (Vector)
import qualified Data.Vector as V

data Vec2 = Vec2 !Double !Double

data Vec3 = Vec3 !Double !Double !Double

class Vec v where
  vadd :: v -> v -> v
  vsub :: v -> v -> v
  vscale :: Double -> v -> v
  vmag2 :: v -> Double
  vzero :: v
  vdist :: v -> v -> Double

vmag :: Vec v => v -> Double
vmag = sqrt . vmag2

instance Vec Vec2 where
  vadd (Vec2 ax ay) (Vec2 bx by) = Vec2 (ax + bx) (ay + by)
  vsub (Vec2 ax ay) (Vec2 bx by) = Vec2 (ax - bx) (ay - by)
  vscale s (Vec2 x y) = Vec2 (s * x) (s * y)
  vmag2 (Vec2 x y) = x * x + y * y
  vzero = Vec2 0 0

  vdist (Vec2 x1 y1) (Vec2 x2 y2) = sqrt ((x1 - y1)**2 + (x2 - y2)**2)

addVec :: Num c => Vector c -> Vector c -> Vector c
addVec v1 v2 = V.zipWith (\x1 x2 -> x1 + x2) v1 v2

subVec :: Num c => Vector c -> Vector c -> Vector c
subVec v1 v2 = V.zipWith (\x1 x2 -> x1 - x2) v1 v2

magVec :: Vector Double -> Double
magVec v = sqrt (V.foldl' (\acc x -> acc + x^2) 0 v)

magVecSquared :: Vector Double -> Double
magVecSquared v = V.foldl' (\acc x -> acc + x^2) 0 v

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
