{-# LANGUAGE ViewPatterns #-}

module Random.RandomSynth where

import qualified Data.Map as M

import Random.Types
import Random.RandomSignal
import Random.MentionsSig
import Util (unique)


randAbSynth :: RandConstraints -> IO AbSynth
randAbSynth cs0 = -- TODO : prune cs <$>
  go cs0 M.empty where
  go :: RandConstraints -> AbSynth -> IO AbSynth
  go cs m = if namedSignals cs >= maxSignals cs
            then return m
            else do s <- randAbSig cs
                    let namedSignals' = namedSignals cs + 1
                        cs' = cs {namedSignals = namedSignals'}
                        m' = M.insert (sigName cs' namedSignals') s m
                    go cs' m'

-- TODO : debug `prune`; it seems to strip everything but the last
-- | After pruning, every remaining signal influences the last one
prune :: RandConstraints -> AbSynth -> AbSynth
prune cs m0 =
  let theUnused = unused cs [maximum $ M.keys m0] m0
      deleteKeys :: Ord k => [k] -> M.Map k a -> M.Map k a
      deleteKeys ks m = foldl (flip M.delete) m ks
  in deleteKeys (M.keys theUnused) m0

-- | Produces an AbSynth containing only the unused signals
unused :: RandConstraints -> [AbSigName] -> AbSynth -> AbSynth
unused _ [] all0 = all0
unused cs (u:used) m =
  let newMentions = allMentions cs u
      m' = M.delete u m
      remainingLeads = unique
        $ filter (flip elem $ M.keys m) -- delete irrelevant keys
        $ newMentions ++ used
  in unused cs remainingLeads m'

sigName :: RandConstraints -> Int -> AbSigName
sigName (namedSignals -> k) n =
  if n > 0 && n <= min k 8
  then theAbSigNames !! (n - 1)
  else error $ show n ++ " is not the number of an AbSigName."
