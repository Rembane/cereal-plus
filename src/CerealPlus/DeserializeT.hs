-- |
-- A monad-transformer over "Data.Serialize.Get".
module CerealPlus.DeserializeT
  (
    Deserialize,
    DeserializeT,
    run,
    Result(..),
    liftGet,
  )
  where

import CerealPlus.Prelude hiding (Result(..))
import qualified Data.Serialize.Get as Cereal


-- | A deserialization monad used for pure data.
type Deserialize = DeserializeT Identity

-- | A deserialization monad transformer. 
-- Useful for mutable types, which live in monads like `IO`.
newtype DeserializeT m a = DeserializeT { run :: ByteString -> m (Result m a) }

instance (Monad m) => Monad (DeserializeT m) where
  DeserializeT runA >>= aToDeserializeTB = DeserializeT $ \bs -> runA bs >>= aToMB where
    aToMB a = case a of
      Fail msg bs -> return $ Fail msg bs
      Partial cont -> return $ Partial $ \bs -> cont bs >>= aToMB
      Done a bs -> case aToDeserializeTB a of DeserializeT runB -> runB bs
  return a = DeserializeT $ \bs -> return $ Done a bs

instance MonadTrans DeserializeT where
  lift m = DeserializeT $ \bs -> m >>= \a -> return $ Done a bs

instance (MonadIO m) => MonadIO (DeserializeT m) where
  liftIO = lift . liftIO

instance (Monad m) => Applicative (DeserializeT m) where
  pure = return
  (<*>) = ap

instance (Monad m) => Functor (DeserializeT m) where
  fmap = liftM


data Result m a = 
  Fail String ByteString |
  Partial (ByteString -> m (Result m a)) |
  Done a ByteString


liftGet :: Monad m => Cereal.Get a -> DeserializeT m a
liftGet get = DeserializeT $ \bs -> return $ convertResult $ Cereal.runGetPartial get bs 
  where
    convertResult r = case r of
      Cereal.Fail m bs -> Fail m bs
      Cereal.Partial cont -> Partial $ \bs -> return $ convertResult $ cont bs
      Cereal.Done a bs -> Done a bs
