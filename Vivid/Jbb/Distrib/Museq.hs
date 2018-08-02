module Vivid.Jbb.Distrib.Museq where

import Control.Lens
import Control.Monad.ST
import qualified Data.Vector as V
import Data.Vector.Algorithms.Intro (sortBy)
import Data.Vector.Mutable
import Data.Vector.Algorithms.Search (binarySearchP)

import Vivid
import Vivid.Jbb.Distrib.Types


sortMuseq :: Museq -> Museq
sortMuseq = vec %~
  \v -> runST $ do v' <- V.thaw v
                   let compare' ve ve' = compare (fst ve) (fst ve')
                   sortBy compare' v'
                   V.freeze v'

museqIsValid :: Museq -> Bool
museqIsValid mu = a && b && c && d where
  a = if V.length (_vec mu) == 0 then True
      else fst (V.head $ _vec mu) == 0
  b = if V.length (_vec mu) == 0 then True
      else fst (V.last $ _vec mu) < _dur mu
  c = mu == sortMuseq mu
  d = _dur mu > 0
