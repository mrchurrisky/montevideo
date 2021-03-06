{-# LANGUAGE ScopedTypeVariables, ViewPatterns #-}

module Dispatch.Transform (
    rev                    -- ^               Museq l a -> Museq l a
  , early, late            -- ^ RDuration  -> Museq l a -> Museq l a
  , fast,slow,dense,sparse -- ^ Rational   -> Museq l a -> Museq l a
  , rotate, rep            -- ^ Rational   -> Museq l a -> Museq l a

  , overParams   -- ^ [(ParamName, Float -> Float)] -> Museq l Msg -> Museq l Msg
  , switchParams -- ^ [(ParamName, ParamName)]      -> Museq l Msg -> Museq l Msg
  , keepParams   -- ^ [ParamName]                   -> Museq l Msg -> Museq l Msg
  , dropParams   -- ^ [ParamName]                   -> Museq l Msg -> Museq l Msg
  ) where

import Control.Lens
import Data.Fixed (mod')
import qualified Data.Map as M
import qualified Data.Set as S
import qualified Data.Vector as V

import Dispatch.Museq
import Dispatch.Types


-- todo ? sorting in `rev` is overkill; faster would be to move the
-- elements at time=1, if they exist, to time=0
rev :: Museq l a -> Museq l a -- the name "reverse" is taken
rev m = vec %~ sortIt . g $ m where
  g :: V.Vector (Ev l a) -> V.Vector (Ev l a)
  g = V.reverse . V.map (over evArc f) where
    s = _sup m
    f (x,y) = if x > 0
              then (s-x, (s-x) + (y-x))
              else (x,y)
  sortIt :: V.Vector (Ev l a) -> V.Vector (Ev l a)
  sortIt v = let (a,b) = V.partition ((==) 0 . fst . _evArc) v
             in a V.++ b

-- todo ? sorting in `early` or `late` is overkill, similar to `rev`
early, late :: RDuration -> Museq l a -> Museq l a
early t m =
  vec %~ (sortIt . V.map (evArc %~ shift)) $ m where
  shift :: (RTime,RTime) -> (RTime,RTime)
  shift (x,y) = (x',x' + (y-x)) where
    x' = shiftStart x where
      shiftStart :: RTime -> RTime
      shiftStart rt = mod' (rt - t) (_sup m)
  sortIt v = let (a,b) = V.partition ((>=) t . fst . _evArc ) v
             in a V.++ b
late t = early (-t)

fast,slow,dense,sparse :: Rational -> Museq l a -> Museq l a
fast d m = let f = (/ (RTime d))
               g (x,y) = (f x, f y)
  in over dur f $ over sup f $ over vec (V.map $ over evArc g) $ m
slow d m = let f = (* (RTime d))
               g (x,y) = (f x, f y)
  in over dur f $ over sup f $ over vec (V.map $ over evArc g) $ m
dense d m = let f = (/ (RTime d))
                g (x,y) = (f x, f y)
  in              over sup f $ over vec (V.map $ over evArc g) $ m
sparse d m = let f = (* (RTime d))
                 g (x,y) = (f x, f y)
  in              over sup f $ over vec (V.map $ over evArc g) $ m


-- | I'm not sure what a fractional rotation means, so I have not tested it.
rotate, rep :: Rational -> Museq l a -> Museq l a
rotate t = fast t . sparse t
rep n = slow n . dense n


-- | = (something) -> Museq Msg -> Museq Msg
overParams :: [(ParamName, Float -> Float)] -> Museq l Msg -> Museq l Msg
overParams fs = fmap $ M.mapWithKey g
  where g :: ParamName -> Float -> Float
        g k v = maybe v ($v) $ M.lookup k $ M.fromList fs

switchParams :: [(ParamName, ParamName)] -> Museq l Msg -> Museq l Msg
switchParams fs = fmap $ M.mapKeys g where
  g :: ParamName -> ParamName
  g k = maybe k id $ M.lookup k $ M.fromList fs

keepParams :: [ParamName] -> Museq l Msg -> Museq l Msg
keepParams ps = over vec $ V.filter (not . null . view evData)
                 . (V.map $ over evData $ flip M.restrictKeys $ S.fromList ps)

dropParams :: [ParamName] -> Museq l Msg -> Museq l Msg
dropParams ps = over vec $ V.filter (not . null . view evData)
                 . (V.map $ over evData $ flip M.withoutKeys $ S.fromList ps)
