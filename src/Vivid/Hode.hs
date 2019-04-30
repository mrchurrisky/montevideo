{-# LANGUAGE ScopedTypeVariables #-}

module Vivid.Hode where

import           Data.Map (Map)
import qualified Data.Map as M
import           Data.Set (Set)
import qualified Data.Set as S

import Hode.Hode
import Hode.Util.Misc

import Vivid.Dispatch.Types


baseRslt :: Rslt
baseRslt = mkRslt $ M.fromList _baseRslt

aWhenPlays, aFreq, aPlaying, aNBoop, aMmho, aPre2 :: Addr
aWhenPlays = -3
aFreq = -5
aPlaying = -7
aNBoop = -9
aMmho = -11
aPre2 = -13

aParamTplts :: [Addr]
aParamTplts = [aFreq]

_baseRslt :: [(Addr,RefExpr)]
_baseRslt =
  [( 0,Phrase' "")
  ,(-1,Phrase' "when")
  ,(-2,Phrase' "plays")
  ,(-3,Tplt' [0,-1,-2,0])
  ,(-4,Phrase' "freq")
  ,(-5,Tplt' [-4,0])
  ,(-6,Phrase' "playing")
  ,(-7,Tplt' [-6,0])
  ,(-8,Phrase' "nBoop")
  ,(-9,Tplt' [-8,0])
  ,(-10,Phrase' "mmho")
  ,(-11,Tplt' [0,-10,0])
  ,(-12,Phrase' "pre2")
  ,(-13,Tplt' [-12,0])
  ,(-14,Phrase' "plays")
  ,(-15,Tplt' [-14,0]) ]

phraseToString :: Rslt -> Addr -> Either String String
phraseToString r a =
  prefixLeft ("phraseToFloat at " ++ show a ++ ": ") $ do
  verifyVariety r a (Just PhraseCtr, Just 0)
  val0 <- addrToExpr r a
  let Phrase val1 = val0
  Right val1

phraseToFloat :: Rslt -> Addr -> Either String Float
phraseToFloat r a =
  prefixLeft ("phraseToFloat at " ++ show a ++ ": ") $ do
  verifyVariety r a (Just PhraseCtr, Just 0)
  val0 <- addrToExpr r a
  let Phrase val1 = val0
  Right (read val1 :: Float)

evalSynthParam :: Rslt -> Addr -> Either String Msg
evalSynthParam r a =
  prefixLeft ("evalParam at " ++ show a ++ ": ") $ do
  fits <- let h = HMap $ M.singleton RoleTplt $ HOr $
                map (HExpr . Addr) aParamTplts
          in hMatches r h a
  if fits then Right () else Left $
    "Is not a unary parameter relationship (e.g. \"#freq 500\"."
  param <- subExpr r  a [RoleTplt, RoleMember 1]
           >>= phraseToString r
  value <- subExpr r  a [RoleMember 1]
           >>= phraseToFloat r
  Right $ M.singleton param value

evalParamEvent :: Rslt -> Addr -> Either String (String, Float, Msg)
evalParamEvent r a =
  prefixLeft ("evalParamEvent at " ++ show a ++ ": ") $ do
  fits <- let h = HMap $ M.singleton RoleTplt $ HOr $
                [HExpr $ Addr aWhenPlays]
          in hMatches r h a
  if fits then Right () else Left $
    "Is not a unary parameter relationship (e.g. \"#freq 500\"."

  name :: String <- fills r (RoleMember 1, a)
                    >>= phraseToString r
  time :: Float <- fills r (RoleMember 2, a)
                   >>= phraseToFloat r
  msg :: Msg <- fills r (RoleMember 3, a)
                >>= evalSynthParam r
  Right (name,time,msg)

evalEventTriples :: Rslt -> Addr -> Either String [(String, Float, Msg)]
evalEventTriples r a =
  prefixLeft ("evalEventTriples at " ++ show a ++ ": ") $ do
  hosts <- (<$>) S.toList $ hExprToAddrs r mempty $
    HMap $ M.fromList [ (RoleTplt, HExpr $ Addr aWhenPlays)
                      , (RoleMember 1, HExpr $ Addr a) ]
  ifLefts $ map (evalParamEvent r) hosts

--evalMuseqMsg :: Rslt -> Addr -> Either String (Museq String Msg)
--evalMuseqMsg r a =
--  prefixLeft ("evalMuseqMsg at " ++ show a ++ ": ") $ do
--  verifyVariety r a (Just RelCtr, Just 2)
--
--  tplt <- fills r (RoleTplt, a)
--  verifyVariety r tplt (Just TpltCtr, Just 3)
--
--  m1_dur <- fills r (RoleMember 1, a)
--  dur0 :: Float <- phraseToFloat r m1_dur

