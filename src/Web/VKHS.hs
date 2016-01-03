{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE FlexibleInstances #-}
module Web.VKHS where

import Data.List
import Data.Maybe
import Data.Time
import Data.Either
import Control.Applicative
import Control.Monad
import Control.Monad.State (MonadState, execState, evalStateT, StateT(..))
import Control.Monad.Cont
import Control.Monad.Reader

import Data.ByteString.Char8 (ByteString)
import qualified Data.ByteString.Char8 as BS

import Web.VKHS.Error
import Web.VKHS.Types
import Web.VKHS.Login as Login
import Web.VKHS.Client as Client
import Web.VKHS.Monad

import Debug.Trace

{- Test -}

data State = State {
    cs :: ClientState
  , ls :: LoginState
  }

instance ToLoginState State where
  toLoginState = ls
instance ToClientState State where
  toClientState = cs

initialState :: IO State
initialState = State <$> Client.defaultState <*> pure Login.defaultState

newtype VK r a = VK { unVK :: Guts VK (StateT State IO) r a }
  deriving(MonadIO, Functor, Applicative, Monad, MonadState State, MonadReader (r -> VK r r) , MonadCont)

instance MonadClient (VK r) State
instance MonadVK (VK r) r
instance MonadLogin (VK r) r State

type Guts x m r a = ReaderT (r -> x r r) (ContT r m) a

runVK :: VK r r -> StateT State IO r
runVK m = runContT (runReaderT (unVK (catch m)) undefined) return

test_loop :: VK (R VK a) (R VK a) -> StateT State IO (ResultDescription a)
test_loop m = do
  res <- runVK m
  case res of
    UnexpectedInt e k -> liftIO (putStrLn "Int!") >> test_loop (k 0)
    _ -> return (describeResult res)

test_run = initialState >>= evalStateT (test_loop $ do
  a <- initialAction
  trace (show a) $ do
  r <- actionRequest a
  return $ Fine r )

