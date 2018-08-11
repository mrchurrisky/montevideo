{-# LANGUAGE ScopedTypeVariables, ViewPatterns #-}

module Vivid.Jbb.Distrib.Transform where

import Control.Lens (over, _1)
import qualified Data.Vector as V

import Vivid.Jbb.Util
import Vivid.Jbb.Distrib.Museq
import Vivid.Jbb.Distrib.Types


-- | example:
-- > x
-- [(1,"gobot"),(2,"gobot"),(3,"gobot"),(4,"gobot"),(5,"gobot"),(6,"gobot")]
-- > divideAtMaxima fst [3,5] $ V.fromList x
-- [[(1,"gobot"),(2,"gobot")]
-- ,[(3,"gobot"),(4,"gobot")]]
divideAtMaxima :: forall a b. Ord b
               => (a->b) -> [b] -> V.Vector a -> [V.Vector a]
divideAtMaxima view tops stuff = reverse $ go [] tops stuff where
  go :: [V.Vector a] -> [b] -> V.Vector a -> [V.Vector a]
  -- even if `stuff` is empty, keep going, because the resulting
  -- series of empty lists is important for the interleaving in append'
  go acc []     _               = acc
  go acc (t:ts) vec             =
    let (lt,gte) = V.partition ((< t) . view) vec
    in go (lt : acc) ts gte

-- | if L is the length of time such that `m` finishes at phase 0,
-- divide the events of L every multiple of _dur.
-- See the test suite for an example.
explicitReps :: forall a. Museq a -> [V.Vector (RTime,a)]
explicitReps m = unsafeExplicitReps (timeToRepeat m) m

-- | PITFALL: I don't know what this will do if
-- `totalDuration` is not an integer multiple of `timeToRepeat m`
unsafeExplicitReps :: forall a.
  RTime -> Museq a -> [V.Vector (RTime,a)]
unsafeExplicitReps totalDuration m =
  let sups = round $ totalDuration / (_sup m)
        -- It takes a duration equal to this many multiples of _sup m
        -- for m to finish at phase 0.
        -- It's already an integer; `round` is just to prove that to GHC.
      durs = round $ totalDuration / (_dur m)
      indexed = zip [0..sups-1]
        $ repeat $ _vec m :: [(Int,V.Vector (RTime,a))]
      adjustTimes :: (Int,V.Vector (RTime,a))
                  ->      V.Vector (RTime,a)
      adjustTimes (idx,v) = V.map f v where
        f = over _1 $ (+) (fromIntegral idx * _sup m)
      spread = map adjustTimes indexed :: [V.Vector (RTime,a)]
        -- the times in `spread` range from 0 to `timeToRepat m`
      concatted = V.concat spread :: V.Vector (RTime,a)
      reps = divideAtMaxima fst [fromIntegral i * _dur m
                                | i <- [1..durs]] concatted
        :: [V.Vector (RTime,a)]
  in reps

-- | the `sup`-aware append
append :: forall a. Museq a -> Museq a -> Museq a
append x y =
  let durs = lcmRatios (dursToRepeat x) (dursToRepeat y)
        -- Since x and y both have to finish at the same time,
        -- they must run through this many durs.
      ixs, iys :: [(Int,V.Vector (RTime,a))]
      ixs = zip [0..] $ unsafeExplicitReps (durs * _dur x) x
      iys = zip [1..] $ unsafeExplicitReps (durs * _dur y) y
        -- ixs uses a 0 because it starts with no ys before it
        -- iys uses a 1 because it starts with 1 (_dur x) worth of x before it

      -- next, space out the xs to make room for the ys, and vice versa
      adjustx :: (Int,V.Vector (RTime,a))
              ->      V.Vector (RTime,a)
      adjustx (idx,v) = V.map f v where
        f = over _1 $ (+) (fromIntegral idx * _dur y)
      adjusty :: (Int,V.Vector (RTime,a))
              ->      V.Vector (RTime,a)
      adjusty (idx,v) = V.map f v where
        f = over _1 $ (+) (fromIntegral idx * _dur x)
      xs, ys :: [V.Vector (RTime,a)]
      xs = map adjustx ixs
      ys = map adjusty iys
  in Museq { _sup = durs * (_dur x + _dur y)
           , _dur = _dur x + _dur y
           , _vec = V.concat $ interleave xs ys }

-- | todo : speed this up dramatically by computing start times once, rather
-- than readjusting the whole series each time a new copy is folded into it.
cat :: [Museq a] -> Museq a
cat = foldl1 append

-- | todo : this ought to accept positive nonintegers
repeat' :: Int -> Museq a -> Museq a
repeat' k = cat . replicate k

-- todo next >>> make sup-aware
stackAsIfEqualLength :: Museq a -> Museq a -> Museq a
stackAsIfEqualLength m n =
  sortMuseq $ Museq { _dur = _dur m, _sup = _sup m
                    , _vec = (V.++) (_vec m) (_vec n)}

-- todo next >>> make sup-aware
stack :: Museq a -> Museq a -> Museq a
stack a b = let lcm = lcmRatios (_dur a) (_dur b)
                a' = repeat' (round $ lcm / _dur a) a
                b' = repeat' (round $ lcm / _dur b) b
            in stackAsIfEqualLength a' b'

-- >>>
-- TODO ? stack' might waste space; see comment in `Museq.timeToRepeat`.
-- | Play both at the same time.
-- PITFALL: The choice of the resulting Museq's _dur is arbitrary.
-- Here it's set to that of the first; for something else just use `set dur`.
stack' :: Museq a -> Museq a -> Museq a
stack' x y = let tx = timeToRepeat x
                 ty = timeToRepeat y
                 t = lcmRatios tx ty
                 xs = unsafeExplicitReps tx x
                 ys = unsafeExplicitReps ty y
             in x

-- todo ? sorting in `rev` is overkill; faster would be to move the
-- elements at time=1, if they exist, to time=0
rev :: Museq a -> Museq a
rev = sortMuseq . over vec g
  where g = V.reverse . V.map (over _1 f)
        f x = if 1-x < 1 then 1-x else 0

-- todo ? sorting in `early` or `late` is overkill too
early :: RDuration -> Museq a -> Museq a
early t m = sortMuseq $ over vec (V.map $ over _1 f) m
  where t' = let pp0 = prevPhase0 0 (_dur m) t
             in t - pp0
        f s = let s' = s - t' / _dur m
              in if s' < 0 then s'+1 else s'

late :: RDuration -> Museq a -> Museq a
late t m = sortMuseq $ over vec (V.map $ over _1 f) m
  where t' = let pp0 = prevPhase0 0 (_dur m) t
             in t - pp0
        f s = let s' = s + t' / _dur m
              in if s' >= 1 then s'-1 else s'

fast :: Rational -> Museq a -> Museq a
fast d = over dur (/d)

slow :: Rational -> Museq a -> Museq a
slow d = over dur (*d)

dense :: forall a. Rational -> Museq a -> Museq a
dense d m = let cd = ceiling d :: Int
                indexedMs = zip [0..cd-1] $ repeat m :: [(Int,Museq a)]
                shiftedMs :: [Museq a]
                shiftedMs = map (\(idx,msq) ->
                                   over vec (V.map $ over _1
                                            $ (/d) . (+ fromIntegral idx))
                                   msq)
                            indexedMs
                in Museq { _dur = _dur m
                         , _sup = _sup m
                         , _vec = V.filter ((< 1) . fst)
                                  $ V.concat $ map _vec shiftedMs}
