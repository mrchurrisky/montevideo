module Test.TDispatch where

import Test.HUnit

import Control.Lens hiding (op)
import qualified Data.Map as M
import Data.Ratio
import qualified Data.Vector as V

import Util
import Synths
import Dispatch.Abbrevs
import Dispatch.Join
import Dispatch.Internal.Join
import Dispatch.Museq
import Dispatch.Transform
import Dispatch.Types


test_module_dispatch :: Test
test_module_dispatch = TestList [
    TestLabel "testOverlap" testOverlap
  , TestLabel "testPrevPhase0" testPrevPhase0
  , TestLabel "testNextPhase0" testNextPhase0
  , TestLabel "museqIsValid" testMuseqIsValid
  , TestLabel "testStack" testStack
  , TestLabel "testRev" testRev
  , TestLabel "testEarlyAndLate" testEarlyAndLate
  , TestLabel "testFastAndSlow" testFastAndSlow
  , TestLabel "testDenseAndSparse" testDenseAndSparse
  , TestLabel "testExplicitReps" testExplicitReps
  , TestLabel "testAppend" testAppend
  , TestLabel "testCat" testCat
  , TestLabel "testRep" testRep
  , TestLabel "testMuseqsDiff" testMuseqsDiff
  , TestLabel "testArc" testArc
  , TestLabel "testOverParams" testOverParams
  , TestLabel "testBoundaries" testBoundaries
  , TestLabel "testPartitionArcAtTimes" testPartitionArcAtTimes
  , TestLabel "testMerge" testMerge
  , TestLabel "testMeta" testMeta
  , TestLabel "testMuseqNamesAreValid" testMuseqNamesAreValid
  , TestLabel "testIntNameEvents" testIntNameEvents
  , TestLabel "testNameAnonEvents" testNameAnonEvents
  , TestLabel "testMultiPartition" testMultiPartition
  , TestLabel "testHold" testHold
  , TestLabel "test_timeToPlayThrough" test_timeToPlayThrough
  ]

test_timeToPlayThrough :: Test
test_timeToPlayThrough = TestCase $ do
  assertBool "1" $ 1 == timeToPlayThrough mempty
  assertBool "1" $ 2 == timeToPlayThrough
    (sup .~ 1 $ mmh 2 $ pre2 "" $ [ (0, "a") ] )
  assertBool "1" $ 2 == timeToPlayThrough
    (dur .~ 1 $ mmh 2 $ pre2 "" $ [ (0, "a") ] )

testHold :: Test
testHold = TestCase $ do
  assertBool "1" $ hold 10 [(2,"a"), (7::Int,"b")]
    == [((2,7),"a"), ((7,12),"b")]

testMultiPartition :: Test
testMultiPartition = TestCase $ do
  assertBool "1" $ multiPartition [(1,2), (1,3)
                                  ,(2,1), (2::Int, 0::Int)]
                               == [(1, [2,3])
                                  ,(2, [1,0])]

testOverlap :: Test
testOverlap = TestCase $ do
  assertBool "no overlap" $ not
    $ overlap (0,1) (2,3::Int)
  assertBool "no overlap" $ not
    $ overlap (2,3) (0,1::Int)
  assertBool "one inside"
    $ overlap (0,1) (-1,2::Int)
  assertBool "one inside"
    $ overlap (-1,2) (0,1::Int)
  assertBool "equal"
    $ overlap (0,2) (0,2::Int)
  assertBool "equal"
    $ overlap (0,2) (0,2::Int)
  assertBool "left-equal"
    $ overlap (0,1) (0,2::Int)
  assertBool "left-equal"
    $ overlap (0,2) (0,1::Int)
  assertBool "right-equal"
    $ overlap (1,2) (0,2::Int)
  assertBool "right-equal"
    $ overlap (0,2) (1,2::Int)
  assertBool "instantaneous, equal"
    $ overlap (0,0) (0,0::Int)
  assertBool "instantaneous, equal"
    $ overlap (0,0) (0,0::Int)
  assertBool "instantaneous, not equal" $ not
    $ overlap (0,0) (1,1::Int)
  assertBool "instantaneous, not equal" $ not
    $ overlap (1,1) (0,0::Int)
  assertBool "one instant, left-equal"
    $ overlap (0,0) (0,1::Int)
  assertBool "one instant, left-equal"
    $ overlap (0,1) (0,0::Int)
  assertBool "one instant, right-equal"
    $ overlap (1,1) (0,1::Int)
  assertBool "one instant, right-equal"
    $ overlap (0,1) (1,1::Int)
  assertBool "one instant, inside"
    $ overlap (1,1) (0,2::Int)
  assertBool "one instant, inside"
    $ overlap (0,2) (1,1::Int)
  assertBool "one instant, outside on right" $ not
    $ overlap (3,3) (0,2::Int)
  assertBool "one instant, outside on right" $ not
    $ overlap (0,2) (3,3::Int)
  assertBool "one instant, outside on left" $ not
    $ overlap (3,3) (10,12::Int)
  assertBool "one instant, outside on left" $ not
    $ overlap (10,12) (3,3::Int)

testPrevPhase0 :: Test
testPrevPhase0 = TestCase $ do
  assertBool "" $ prevPhase0 0 10 11 == (10 :: Double)
  assertBool "" $ prevPhase0 0 10 10 == (10 :: Double)
  assertBool "" $ prevPhase0 0 20 41 == (40 :: Double)
  assertBool "" $ prevPhase0 0 20 59 == (40 :: Double)

testNextPhase0 :: Test
testNextPhase0 = TestCase $ do
  assertBool "" $ nextPhase0 0 10 11 == (20 :: Double)
  assertBool "" $ nextPhase0 0 10 10 == (10 :: Double)
  assertBool "" $ nextPhase0 0 20 41 == (60 :: Double)
  assertBool "" $ nextPhase0 0 20 59 == (60 :: Double)

testMuseqIsValid :: Test
testMuseqIsValid = TestCase $ do
  assertBool "valid, empty"               $ museqIsValid
    $ (mkMuseqFromEvs 3 [] :: Museq String ())
  assertBool "invalid, zero length" $ not $ museqIsValid
    $ (mkMuseqFromEvs 0 [] :: Museq String ())
  assertBool "valid, nonempty"            $ museqIsValid
    $ mkMuseqFromEvs 1 [mkEv0 "1" 0 () ]
  assertBool "invalid, time > _sup" $ not $ museqIsValid
    $ mkMuseqFromEvs 1 [mkEv0 "1" 2 () ]

testStack :: Test
testStack = TestCase $ do
  let a = mkMuseqH 1 [("a", RTime 0, "a")]
      b = mkMuseqH 1 [("a", RTime 0, "b")]
      c = mkMuseqH 1 [("a", RTime 0, "c")]
  assertBool "1" $ stack [a,b,c] ==
    Museq {_dur = 1, _sup = 1, _vec = V.fromList
            [ Event "a"   (0, 1) "a"
            , Event "aa"  (0, 1) "b"
            , Event "aaa" (0, 1) "c" ] }

  let y = mkMuseqFromEvs 2 [mkEv () 0 3 "()"]
      z = mkMuseqFromEvs 3 [mkEv "z" 1 2 "z"]
  assertBool "stack" $ stack2 y z ==
    (dur .~ (_dur z))
    ( mkMuseqFromEvs 6 [ mkEv "()"  0 3 "()"
                       , mkEv "az" 1 2 "z"
                       , mkEv "()"  2 5 "()"
                       , mkEv "az" 4 5 "z"
                       , mkEv "()"  4 7 "()"] )
  assertBool "stack" $ stack2 (dur .~ 1 $ y) z ==
    (dur .~ _dur z)
    ( mkMuseqFromEvs 6 [ mkEv "()"  0 3 "()"
                       , mkEv "az" 1 2 "z"
                       , mkEv "()"  2 5 "()"
                       , mkEv "az" 4 5 "z"
                       , mkEv "()"  4 7 "()" ] )
  assertBool "stack, where timeToRepeat differs from timeToPlayThrough"
    $ stack2 (sup .~ 1 $ y) z ==
    (dur .~ _dur z)
    ( sup .~ 6 $
      mkMuseqFromEvs 3 [ mkEv "()"  0 3 "()"
                       , mkEv "az"  1 2 "z"
                       , mkEv "()"  1 4 "()"
                       , mkEv "()"  2 5 "()"

    -- If I used timeToRepeat instead of timeToPlayThrough,
    -- this redundant second half would not be present.
                       , mkEv "()"  3 6 "()"
                       , mkEv "az"  4 5 "z"
                       , mkEv "()"  4 7 "()"
                       , mkEv "()"  5 8 "()" ] )

testRev :: Test
testRev = TestCase $ do
  let a = mkMuseqFromEvs 2 [ mkEv () 0     1     "a"
                           , mkEv () (1/3) 3     "b"
                           , mkEv () (1/2) (1/2) "c" ]
  assertBool "rev" $ rev a ==
    mkMuseqFromEvs 2 [ mkEv () 0     1      "a"
                     , mkEv () (3/2) (3 /2) "c"
                     , mkEv () (5/3) (13/3) "b" ]

testEarlyAndLate :: Test
testEarlyAndLate = TestCase $ do
  let a = mkMuseqFromEvs 10 [ mkEv () 0 11 "a"
                            , mkEv () 1 2 "b"]
  assertBool "early" $ _vec (early 1 a) ==
    V.fromList [ mkEv () 0 1 "b"
               , mkEv () 9 20 "a"]

  let a' = mkMuseqFromEvs 10 [ mkEv () 0 11 "a"
                             , mkEv () 1 2 "b"]
  assertBool "late" $ _vec (late 1 a') ==
    V.fromList [ mkEv () 1 12 "a"
               , mkEv () 2 3 "b"]

testFastAndSlow :: Test
testFastAndSlow = TestCase $ do
  let a = mkMuseqFromEvs 10 [mkEv () 0 20 "a",mkEv () 2 2 "b"]
  assertBool "fast" $ (fast 2 a) ==
    mkMuseqFromEvs 5 [mkEv () 0 10 "a",mkEv () 1 1 "b"]
  assertBool "slow" $ (slow 2 a) ==
    mkMuseqFromEvs 20 [mkEv () 0 40 "a",mkEv () 4 4 "b"]

testDenseAndSparse :: Test
testDenseAndSparse = TestCase $ do
  let x = mkMuseqFromEvs 10 [mkEv () 0 15 "a",mkEv () 2 2 "b"]
  assertBool "dense" $ dense 2 x ==
    (dur .~ 10) (mkMuseqFromEvs 5 [mkEv () 0 (15/2) "a",mkEv () 1 1 "b"])
  assertBool "sparse" $ sparse 2 x ==
    (dur .~ 10) (mkMuseqFromEvs 20 [mkEv () 0 30 "a",mkEv () 4 4 "b"])

testExplicitReps :: Test
testExplicitReps = TestCase $ do

  let y = Museq {_dur = 3, _sup = 4,
                 _vec = V.fromList [ ev4 "" 0 3 ()
                                   , ev4 "" 1 1 () ] }

  assertBool "unsafeExplicitReps" $ unsafeExplicitReps 24 y ==
    [ V.fromList [ ev4 "" 0  3  ()
                 , ev4 "" 1  1  () ]
    , V.fromList [ ev4 "" 4  7  ()
                 , ev4 "" 5  5  () ]
    , V.fromList [ ev4 "" 8  11 () ]
    , V.fromList [ ev4 "" 9  9  () ]
    , V.fromList [ ev4 "" 12 15 ()
                 , ev4 "" 13 13 () ]
    , V.fromList [ ev4 "" 16 19 ()
                 , ev4 "" 17 17 () ]
    , V.fromList [ ev4 "" 20 23 () ]
    , V.fromList [ ev4 "" 21 21 () ]
    ]

  assertBool "explicitReps" $ explicitReps y ==
    [ V.fromList [ ev4 "" 0 3  ()
                 , ev4 "" 1 1  () ]
    , V.fromList [ ev4 "" 4 7  ()   -- starts at 3
                 , ev4 "" 5 5  () ]
    , V.fromList [ ev4 "" 8 11 () ] -- starts at 6
    , V.fromList [ ev4 "" 9 9  () ] -- starts at 9
    ]

testAppend :: Test
testAppend = TestCase $ do
    let a = mkMuseqFromEvs 1 [mkEv () 0 1 "a"]
        a2  = a {_sup = RTime $ 2}
        a12 = a {_sup = RTime $ 1%2}
        a32 = a {_sup = RTime $ 3%2}
        b = mkMuseqFromEvs 1 [mkEv () 0 0 "b"]
    assertBool "testAppend" $ append a b ==
      mkMuseqFromEvs 2 [mkEv () 0 1 "a", mkEv () 1 1 "b"]
    assertBool "testAppend" $ append a2 b ==
      let m = mkMuseqFromEvs 2 [mkEv () 0 1 "a"
                               ,mkEv () 1 1 "b"
                               ,mkEv () 3 3 "b"]
      in m {_sup = 4}
    assertBool "testAppend" $ append a12 b ==
      mkMuseqFromEvs 2 [mkEv () 0 1 "a"
                       ,mkEv () (1%2) (3%2) "a"
                       , mkEv () 1 1 "b"]
    assertBool "testAppend" $ append a32 b ==
      let m = mkMuseqFromEvs 2 [ mkEv () 0 1 "a"
                               , mkEv () 1 1 "b"
                               , mkEv () (2+1/2) (3+1/2) "a"
                               , mkEv () 3 3 "b", mkEv () 5 5 "b"]
      in m {_sup = 6}

testCat :: Test
testCat = TestCase $ do
  let a = mkMuseqH 1 [("a", RTime 0, "a")]
      b = mkMuseqH 1 [("b", RTime 0, "b")]
      c = mkMuseqH 1 [("c", RTime 0, "c")]
  assertBool "1" $ cat [a,b,c] ==
    mkMuseq 3  [ ("a", RTime 0, RTime 1, "a")
               , ("b", RTime 1, RTime 2, "b")
               , ("c", RTime 2, RTime 3, "c") ]
  assertBool "1" $ cat [a, dur .~ 2 $ b] ==
    mkMuseq 3  [ ("a", RTime 0, RTime 1, "a")
               , ("b", RTime 1, RTime 2, "b")
               , ("b", RTime 2, RTime 3, "b") ]

testRep :: Test
testRep = TestCase $ do
  let a = mkMuseqFromEvs 6 [mkEv () 0 7 "a"]
  assertBool "rep int" $ rep 2 a ==
    (dur .~ 12) (mkMuseqFromEvs 6 [mkEv () 0 7 "a"])
  assertBool "rep fraction" $ rep (3/2) a ==
    (dur .~ 9) (mkMuseqFromEvs 6 [mkEv () 0 7 "a"])

testMuseqsDiff :: Test
testMuseqsDiff = TestCase $ do
  let msg = M.singleton "amp" 1
      m3 = M.fromList [("a", mkMuseqFromEvs 10
                             [ mkEv0 "1" 0  (Note Boop msg)])
                      ,("b", mkMuseqFromEvs 15 [ mkEv0 "1" 0  (Note Boop msg)
                                               , mkEv0 "2" 10 (Note Boop msg)
                                               ] ) ]
      m2 = M.fromList [("a", mkMuseqFromEvs 10
                             [ mkEv0 "2" 0  (Note Vap msg) ])
                      ,("b", mkMuseqFromEvs 15
                             [ mkEv0 "2" 0  (Note Boop msg)
                             , mkEv0 "3" 10 (Note Boop msg)
                             ] ) ]
  assertBool "museqDiff" $ museqsDiff m3 m2 == ( [ (Boop,"1") ]
                                               , [ (Boop,"3")
                                                 , (Vap ,"2")
                                                 ] )
  assertBool "museqDiff" $ museqsDiff m2 m3 == ( [ (Boop,"3")
                                                 , (Vap ,"2") ]
                                               , [ (Boop,"1")
                                                 ] )

testArc :: Test
testArc = TestCase $ do
  let m = mkMuseqFromEvs 5 [ Event () (0,6) "a"
                   , Event () (2,4) "b"]
  -- arguments to arc : time0 tempoPeriod from to museq
  assertBool "arc 0" $ arc 100 2  200 210  m
    == [ ( Event () (200,202) "a" )
       , ( Event () (200,210) "a" )
       , ( Event () (204,208) "b" )]
  assertBool "arc 1" $ arc 101 2  200 210  m
    == [ ( Event () (200,203) "a")
       , ( Event () (201,210) "a")
       , ( Event () (205,209) "b")]
  assertBool "arc 1" $ arc 101 2  200 220  m
    == [ ( Event () (200,203) "a")
       , ( Event () (201,213) "a")
       , ( Event () (205,209) "b")
       , ( Event () (211,220) "a")
       , ( Event () (215,219) "b")]

testOverParams :: Test
testOverParams = TestCase $ do
  let m = mkMuseqFromEvs 2 [ mkEv0 () 0 $ M.singleton "freq" 100
                           , mkEv0 () 1 $ M.singleton "amp"  0.1 ]
  assertBool "overParams" $ overParams [("freq",(+1))] m
    == mkMuseqFromEvs 2 [ mkEv0 () 0 $ M.singleton "freq" 101
                        , mkEv0 () 1 $ M.singleton "amp" 0.1]
  assertBool "switchParams" $ switchParams [("freq","guzzle")] m
    == mkMuseqFromEvs 2 [ mkEv0 () 0 $ M.singleton "guzzle" 100
                        , mkEv0 () 1 $ M.singleton "amp" 0.1]
  assertBool "keepParams" $ keepParams ["freq"] m
    == mkMuseqFromEvs 2 [mkEv0 () 0 $ M.singleton "freq" 100]
  assertBool "dropParams" $ dropParams ["freq"] m
    == mkMuseqFromEvs 2 [mkEv0 () 1 $ M.singleton "amp" 0.1]

testBoundaries :: Test
testBoundaries = TestCase $ do
  assertBool "boundaries" $ boundaries [(0,1),(1,1),(2,3::Int)]
    == [0,1,1,2,3]

testPartitionArcAtTimes :: Test
testPartitionArcAtTimes = TestCase $ do
  assertBool "partitionArcAtTimes" $ partitionArcAtTimes [0,2,2,5,10::Int]
    (0,5)
    == [(0,2),(2,2),(2,5)]

-- This was written for the old Museq, where labels were attached
-- in the wrong place. That was changed in the "one-museq" branch,
-- but the test was not updated to use the new type.
--testPartitionAndGroupEventsAtBoundaries :: Test
--testPartitionAndGroupEventsAtBoundaries = TestCase $ do
--  assertBool "partitionAndGroupEventsAtBoundaries" $
--    partitionAndGroupEventsAtBoundaries [0, 1, 1, 2, 3, 4 :: Int]
--      [ ((0,3),"a")
--      , ((2,4),"b") ]
--    == [((0,1),"a")
--       ,((1,1),"a")
--       ,((1,2),"a")
--       ,((2,3),"a")
--       ,((2,3),"b")
--       ,((3,4),"b")
--       ]

testMerge :: Test
testMerge = TestCase $ do
  let a  = Museq { _dur = 2, _sup = 2,
                   _vec = V.fromList [ mkEv "a" 0 1 "a" ] }
      bc = Museq { _dur = 3, _sup = 3,
                   _vec = V.fromList [ mkEv "b" 0 1 "b"
                                     , mkEv "c" 1 2 "c" ] }
      op = Museq { _dur = 3, _sup = 1.5,
                   _vec = V.singleton $ mkEv "op" 0 1 $ (++) "-" }
  assertBool "merge" $ merge (++) a bc
    == Museq { _dur = 3, _sup = 6,
               _vec = V.fromList [ mkEv "ab" 0 1 "ab"
                                 , mkEv "ac" 4 5 "ac" ] }
  assertBool "apply" $ (labelsToStrings op <*> labelsToStrings bc)
    == Museq { _dur = 3, _sup = 3,
               _vec = V.fromList [ mkEv "opb" 0 1  "-b"
                                 , mkEv "opc" 1.5 2  "-c" ] }

  let a' = Museq { _dur = 2, _sup = 2,
                   _vec = V.fromList [ mkEv "a" 0 1
                                       $ M.fromList [ ("amp",2)
                                                    , ("freq",2)] ] }
      bc' = Museq { _dur = 3, _sup = 3,
                    _vec = V.fromList [ mkEv "b" 0 1 $ M.singleton "amp" 0
                                      , mkEv "c" 1 2 $ M.singleton "freq" 0] }
  assertBool "merge0" $ merge0 a' bc'
    == Museq { _dur = 3, _sup = 6,
               _vec = V.fromList [ mkEv "ab" 0 1 $ M.fromList [("amp",2)
                                                              ,("freq",2)]
                                 , mkEv "ac" 4 5 $ M.fromList [("amp",2)
                                                              ,("freq",2)] ] }
  assertBool "merge0a" $ merge0a a' bc'
    == Museq { _dur = 3, _sup = 6,
               _vec = V.fromList [ mkEv "ab" 0 1 $ M.fromList [("amp",2)
                                                              ,("freq",2)]
                                 , mkEv "ac" 4 5 $ M.fromList [("amp",2)
                                                              ,("freq",0)] ] }

testMeta :: Test
testMeta = TestCase $ do
  let a = Museq { _dur = 2, _sup = 2,
                  _vec = V.fromList [ mkEv "a" 0 1 "a" ] }
      f = Museq { _dur = 3, _sup = 3,
                  _vec = V.fromList [ mkEv "f" 0 1 $ fast 2
                                    , mkEv "g" 2 3 $ early $ 1/4 ] }
  assertBool "meta" $ meta f a
    == Museq { _dur = 2, _sup = 6,
               _vec = V.fromList [ mkEv "fa" 0     0.5 "a"
                                 , mkEv "ga" 2     2.75 "a"
                                 , mkEv "fa" 3     3.5 "a"
                                 , mkEv "ga" 5.75  6 "a" ] }

testMuseqNamesAreValid :: Test
testMuseqNamesAreValid = TestCase $ do
  assertBool "empty Museq has valid names" $ museqMaybeNamesAreValid $
    mkMuseqFromEvs 10 ([] :: [Ev (Maybe String) ()])
  assertBool "Museq without names has valid names"
    $ museqMaybeNamesAreValid
    $ mkMuseqFromEvs 10 [ mkEv (Nothing :: Maybe String) 0 10 ()
                        , mkEv (Nothing :: Maybe String) 0 10 () ]
  assertBool "Museq with overlapping like names is not valid" $ not $
    museqMaybeNamesAreValid $ mkMuseqFromEvs 10 [ mkEv (Just "1") 0  6 ()
                                                , mkEv (Just "1") 4 10 () ]
  assertBool "Museq with non-overlapping like names is valid" $
    museqMaybeNamesAreValid $ mkMuseqFromEvs 10 [ mkEv (Just "1") 0 4  ()
                                                , mkEv (Just "1") 6 10 () ]
  assertBool "Museq with overlapping unlike names is valid" $
    museqMaybeNamesAreValid $ mkMuseqFromEvs 10 [ mkEv (Just "1") 0 6 ()
                                                , mkEv (Just "2") 4 10 () ]
  assertBool "Museq with wrapped overlap is not valid" $ not $
    museqMaybeNamesAreValid $ mkMuseqFromEvs 10 [ mkEv (Just "1") 0 4 ()
                                                , mkEv (Just "1") 6 12 () ]

testIntNameEvents :: Test
testIntNameEvents = TestCase $ do
  assertBool "intNameEvents, no overlap" $
    intNameEvents 10 [mkEv () 0  1 (),  mkEv () 2 3 ()]
    ==               [mkEv  1 0  1 (),  mkEv  1 2 3 ()]
  assertBool "intNameEvents, ordinary overlap" $
    intNameEvents 10 [mkEv () 0 2 (),  mkEv () 1 3 ()]
    ==               [mkEv  1 0 2 (),  mkEv  2 1 3 ()]
  assertBool "intNameEvents, wrapped overlap" $
    intNameEvents 10 [mkEv () 0 2 (),  mkEv () 5 11 ()]
    ==               [mkEv  1 0 2 (),  mkEv  2 5 11 ()]

testNameAnonEvents :: Test
testNameAnonEvents = TestCase $ do
  let m = mkMuseqFromEvs 10 [ mkEv (Just "1") 0 1 ()
                            , mkEv Nothing    0 1 () ]
  assertBool "testNameAnonEvents" $ nameAnonEvents m
    ==    mkMuseqFromEvs 10 [ mkEv "1"  0 1 ()
                            , mkEv "a1" 0 1 () ]
