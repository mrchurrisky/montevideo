{-# LANGUAGE DataKinds #-}

module Vivid.Jbb.Dispatch.Act where

import Control.Concurrent (forkIO, ThreadId)
import Control.Concurrent.MVar
import Control.DeepSeq
import Control.Lens (over, _1)
import Data.List ((\\))
import qualified Data.Map as M
import qualified Data.Vector as V

import Vivid
import Vivid.Jbb.Dispatch.Config (frameDuration)
import Vivid.Jbb.Dispatch.Types
import Vivid.Jbb.Dispatch.Instances
import Vivid.Jbb.Dispatch.Msg
import Vivid.Jbb.Dispatch.Museq
import Vivid.Jbb.Synths
import Vivid.Jbb.Util


-- TODO ? `act` might never get used
act :: SynthRegister -> Time -> Action
     -> IO (SynthRegister -> SynthRegister)
act reg t a@(Send _ _ _) = actSend reg t a >> return id
act reg t a@(Free _ _)   = actFree reg t a
act reg t a@(New _ _)    = actNew  reg   a

actNew :: SynthRegister -> Action -> IO (SynthRegister -> SynthRegister)
actNew reg (New Boop name) = case M.lookup name $ _boops reg of
    Nothing -> do s <- synth boop ()
                  return $ over boops $ M.insert name s
    _ -> do writeTimeAndError $ "There is already a Boop named " ++ name
            return id
actNew reg (New Vap name) = case M.lookup name $ _vaps reg of
    Nothing -> do s <- synth vap ()
                  return $ over vaps $ M.insert name s
    _ -> do writeTimeAndError $ "There is already a Vap named " ++ name
            return id
actNew reg (New Sqfm name) = case M.lookup name $ _sqfms reg of
    Nothing -> do s <- synth sqfm ()
                  return $ over sqfms $ M.insert name s
    _ -> do writeTimeAndError $ "There is already a Sqfm named " ++ name
            return id
actNew _ (Send _ _ _) = error $ "actNew received a Send."
actNew _ (Free _ _)   = error $ "actNew received a Free."

actFree :: SynthRegister -> Time -> Action
         -> IO (SynthRegister -> SynthRegister)
actFree reg when (Free Boop name) = case M.lookup name $ _boops reg of
  Nothing -> do writeTimeAndError
                  $ "There is no Boop named " ++ name ++ "to free."
                return id
  Just s -> do doScheduledAt (Timestamp when) $ set' s $ Msg' (0 :: I "amp")
               doScheduledAt (Timestamp $ when + frameDuration / 2) $ free s
               return $ over boops $ M.delete name
actFree reg when (Free Vap name) = case M.lookup name $ _vaps reg of
  Nothing -> do writeTimeAndError
                  $ "There is no Vap named " ++ name ++ "to free."
                return id
  Just s -> do doScheduledAt (Timestamp when) $ set' s $ Msg' (0 :: I "amp")
               doScheduledAt (Timestamp $ when + frameDuration / 2) $ free s
               return $ over vaps $ M.delete name
actFree reg when (Free Sqfm name) = case M.lookup name $ _sqfms reg of
  Nothing -> do writeTimeAndError
                  $ "There is no Sqfm named " ++ name ++ "to free."
                return id
  Just s -> do doScheduledAt (Timestamp when) $ set' s $ Msg' (0 :: I "amp")
               doScheduledAt (Timestamp $ when + frameDuration / 2) $ free s
               return $ over sqfms $ M.delete name
actFree _ _ (Send _ _ _) = error "actFree received a Send."
actFree _ _ (New _ _)    = error "actFree received a New."

actSend :: SynthRegister -> Time -> Action -> IO ()
actSend reg when (Send Boop name msg) = case M.lookup name $ _boops reg of
  Nothing -> writeTimeAndError $ " The name " ++ name ++ " is not in use.\n"
  Just synth -> doScheduledAt (Timestamp when) $ set' synth $ boopMsg msg
actSend reg when (Send Vap name msg) = case M.lookup name $ _vaps reg of
  Nothing -> writeTimeAndError $ " The name " ++ name ++ " is not in use.\n"
  Just synth -> doScheduledAt (Timestamp when) $ set' synth $ vapMsg msg
actSend reg when (Send Sqfm name msg) = case M.lookup name $ _sqfms reg of
  Nothing -> writeTimeAndError $ " The name " ++ name ++ " is not in use.\n"
  Just synth -> doScheduledAt (Timestamp when) $ set' synth $ sqfmMsg msg
actSend _ _ (Free _ _) = error "actFree received a Send."
actSend _ _ (New _ _)  = error "actFree received a New."

replace :: Dispatch -> MuseqName -> Museq Action -> IO ()
replace dist newName newMuseq = do
  masOld <- readMVar $ mMuseqs dist
  replaceAll dist $ M.insert newName newMuseq masOld

replaceAll :: Dispatch -> M.Map MuseqName (Museq Action) -> IO ()
replaceAll dist masNew = do
  time0  <-      takeMVar $ mTime0       dist
  tempoPeriod <- takeMVar $ mTempoPeriod dist
  masOld <-      takeMVar $ mMuseqs      dist
  reg <-        takeMVar $ mReg         dist
  now <- unTimestamp <$> getTime

  let when = nextPhase0 time0 frameDuration now + 2 * frameDuration
        -- `when` = the start of the first not-yet-rendered frame
      toFree, toCreate :: [(SynthDefEnum, SynthName)]
      (toFree,toCreate) = museqsDiff masOld masNew

  newTransform  <- mapM (actNew  reg)      $ map (uncurry New)  toCreate
  freeTransform <- mapM (actFree reg when) $ map (uncurry Free) toFree

  putMVar (mTime0       dist) time0       -- unchnaged
  putMVar (mTempoPeriod dist) tempoPeriod -- unchanged
  putMVar (mMuseqs      dist) masNew
  putMVar (mReg         dist) $ foldl (.) id newTransform reg

  forkIO $ do wait $ when - now -- delete register's synths when it's safe
              reg <-takeMVar $ mReg dist
              putMVar (mReg dist) $ foldl (.) id freeTransform reg

  return ()

-- | todo ? this `chTempoPeriod` does not offer melodic continuity
chTempoPeriod :: Dispatch -> Duration -> IO ()
chTempoPeriod disp dur = swapMVar (mTempoPeriod disp) dur >> return ()

startDispatchLoop :: Dispatch -> IO ThreadId
startDispatchLoop dist = do
  tryTakeMVar $ mTime0 dist -- empty it, just in case
  (+(frameDuration * (-0.8))) . unTimestamp <$> getTime
    -- subtract nearly an entire frameDuration so it starts sooner
    >>= putMVar (mTime0 dist)
  forkIO $ dispatchLoop dist

dispatchLoop :: Dispatch -> IO ()
dispatchLoop dist = do
  time0  <-      takeMVar $ mTime0       dist
  tempoPeriod <- takeMVar $ mTempoPeriod dist
  museqsMap <-   takeMVar $ mMuseqs      dist
  reg <-        takeMVar $ mReg         dist
  now <- unTimestamp <$> getTime

  let np0 = nextPhase0 time0 frameDuration now
      startRender = np0 + frameDuration
      evs = concatMap f $ M.elems museqsMap :: [(Time,Action)] where
        f :: Museq a -> [(Time, a)]
        f = arc time0 tempoPeriod startRender $ startRender + frameDuration

  -- debugging
    --  deepseq (time0, tempoPeriod, museqsMap, reg, now, np0, startRender)
    --    (return evs)

    --  let rNow = now - time0
    --      rNp0 = np0 - time0
    --      rStartRender = startRender - time0
    --      rEvs = flip map evs $ over _1 (+(-time0))

    --  putStrLn $ "\nNow: " ++ show rNow ++ "\nnp0: " ++ show rNp0
    --    ++ "\nstartRender: " ++ show rStartRender
    --    ++ "\ntempoPeriod: " ++ show tempoPeriod
    --    ++ "\nmuseqsMap: " ++ concatMap ((++"\n") . show) (M.toList $ museqsMap)

    --  putStrLn $ "\nlength evs: " ++ show (length evs) ++ "\nevs: "
    --    ++ concatMap (\(t,a) -> "\n" ++ show (t-time0) ++ ": " ++ show a) evs
    --    ++ "\nThat's all of them?\n"

  mapM_ (uncurry $ actSend reg) evs

  putMVar (mTime0       dist) time0
  putMVar (mTempoPeriod dist) tempoPeriod
  putMVar (mMuseqs      dist) museqsMap
  putMVar (mReg         dist) reg

  wait $ np0 - now
  dispatchLoop dist

showEvs evs = concatMap (\(t,a) -> "\n" ++ show t ++ ": " ++ show a) evs