{-# LANGUAGE DataKinds, ExtendedDefaultRules #-}

module Vivid.Jbb.Synths where

import Vivid


type MyParams =
  '["freq", "amp"
   , "fm-freq", "fm-amp"
   , "fm2-freq", "fm2-amp"
   , "nz-amp","nz-lpf"]

set' :: (Subset MyParams sdArgs
        , Real n, VividAction m)
     => String -> n -> Synth sdArgs -> m ()
set' "freq"     n s = set s (toI n :: I "freq")
set' "amp"      n s = set s (toI n :: I "amp" )
set' "fm-amp"   n s = set s (toI n :: I "fm-amp" )
set' "fm-freq"  n s = set s (toI n :: I "fm-freq" )
set' "fm2-amp"  n s = set s (toI n :: I "fm2-amp" )
set' "fm2-freq" n s = set s (toI n :: I "fm2-freq" )
set' "nz-amp"   n s = set s (toI n :: I "nz-amp" )
set' "nz-lpf"   n s = set s (toI n :: I "nz-lpf" )

-- boop is just here to demonstrate that set' can apply to multiple synthdefs
-- provided those synthdefs share the same parameters
boop :: SynthDef MyParams
boop = sd ( 0   :: I "freq"
          , 0.1 :: I "amp"
          , 0   :: I "fm-freq"  -- unused
          , 0   :: I "fm-amp"   -- unused
          , 0   :: I "fm2-freq" -- unused
          , 0   :: I "fm2-amp"  -- unused
          , 0   :: I "nz-amp"   -- unused
          , 0   :: I "nz-lpf"   -- unused
          ) $ do
  carrier <- (V::V "amp") ~* sinOsc (freq_  $ (V::V "freq"))
  out 0 [carrier, carrier]

vap :: SynthDef MyParams
vap = sd ( 0   :: I "freq"
         , 0.1 :: I "amp"
         , 0   :: I "fm-freq"
         , 0   :: I "fm-amp"
         , 0   :: I "fm2-freq"
         , 0   :: I "fm2-amp"
         , 0   :: I "nz-amp"
         , 0   :: I "nz-lpf"
         ) $ do
  nz <- (V::V "nz-amp") ~* lpf (in_ whiteNoise, freq_ (V::V "nz-lpf"))
  fm <- (V::V "fm-amp") ~* (sinOsc $ freq_ (V::V "fm-freq"))
  fm2 <- (V::V "fm2-amp") ~* (sinOsc $ freq_ (V::V "fm2-freq"))
  carrier <- (V::V "amp")
    ~* sinOsc (freq_  $ (V::V "freq") ~+ fm ~+ fm2 ~+ nz)
  out 0 [carrier, carrier]