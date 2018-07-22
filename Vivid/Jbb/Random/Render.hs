{-# LANGUAGE DataKinds
           , ExtendedDefaultRules
           , FlexibleContexts
           , ScopedTypeVariables
           , ConstrainedClassMethods
           #-}

module Vivid.Jbb.Random.Render where

import qualified Data.Map as M

import Vivid
import Vivid.Jbb.Random.Types
import Vivid.Jbb.Random.RandomSignal
import Vivid.Jbb.Random.RandomSynth


type RenderTarget = SDBody' TheAbParams Signal
  -- ^ Rendering turns abstract signals into this type.

class RenderSig a where
  renderSig :: a -> (M.Map AbSigName Signal -> RenderTarget)

instance RenderSig AbSig where
  renderSig (AbSigFormula abFormula) = renderSig abFormula
  renderSig (AbSigGen abGen) = renderSig abGen
  renderSig (AbSig abSigName) = renderSig abSigName
  renderSig (AbV abParam) = renderSig abParam
  renderSig (AbConst f) = const $ toSig f

instance RenderSig AbFormula where
  renderSig (AbProd x y) m = renderSig x m ~* renderSig y m
  renderSig (AbSum x y) m = renderSig x m ~+ renderSig y m

instance RenderSig AbGen where
  renderSig (AbSin (AbSinMsg freq phase)) = \m -> 
    sinOsc (freq_ $ renderSig freq m, phase_ $ renderSig phase m)
  renderSig (AbSaw (AbSawMsg freq)) = \m -> 
    saw (freq_ $ renderSig freq m)

instance RenderSig AbSigName where
  renderSig name = \m -> toSig $ (M.!) m name
    -- confusingly, toSig converts a signal to an SDBody'

instance RenderSig AbParam where
  renderSig AP1 = const $ toSig (V :: V "AP1")
  renderSig AP2 = const $ toSig (V :: V "AP2")
  renderSig AP3 = const $ toSig (V :: V "AP3")
  renderSig AP4 = const $ toSig (V :: V "AP4")
  renderSig AP5 = const $ toSig (V :: V "AP5")
  renderSig AP6 = const $ toSig (V :: V "AP6")
  renderSig AP7 = const $ toSig (V :: V "AP7")
  renderSig AP8 = const $ toSig (V :: V "AP8")
