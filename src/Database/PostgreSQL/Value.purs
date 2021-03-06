module Database.PostgreSQL.Value where

import Control.Error.Util (note)
import Control.Monad.Eff (kind Effect)
import Control.Monad.Error.Class (throwError)
import Control.Monad.Except (runExcept)

import Data.Array as Array
import Data.Bifunctor (bimap, lmap)
import Data.ByteString (ByteString)
import Data.DateTime (DateTime)
import Data.DateTime.Instant (Instant)
import Data.Either (Either)
import Data.Foreign (Foreign, isNull, readArray, readBoolean, readChar, readInt, readNumber, readString, toForeign, unsafeFromForeign)
import Data.JSDate(readDate, toDateTime, fromDateTime)
import Data.List (List)
import Data.List as List
import Data.Maybe (Maybe(..))
import Data.Traversable (traverse)

import Prelude

-- | Convert things to SQL values.
class ToSQLValue a where
    toSQLValue :: a -> Foreign

-- | Convert things from SQL values.
class FromSQLValue a where
    fromSQLValue :: Foreign -> Either String a

instance toSQLValueBoolean :: ToSQLValue Boolean where
    toSQLValue = toForeign

instance fromSQLValueBoolean :: FromSQLValue Boolean where
    fromSQLValue = lmap show <<< runExcept <<< readBoolean

instance toSQLValueChar :: ToSQLValue Char where
    toSQLValue = toForeign

instance fromSQLValueChar :: FromSQLValue Char where
    fromSQLValue = lmap show <<< runExcept <<< readChar

instance toSQLValueInt :: ToSQLValue Int where
    toSQLValue = toForeign

instance fromSQLValueInt :: FromSQLValue Int where
    fromSQLValue = lmap show <<< runExcept <<< readInt

instance toSQLValueNumber :: ToSQLValue Number where
    toSQLValue = toForeign

instance fromSQLValueNumber :: FromSQLValue Number where
    fromSQLValue = lmap show <<< runExcept <<< readNumber

instance toSQLValueString :: ToSQLValue String where
    toSQLValue = toForeign

instance fromSQLValueString :: FromSQLValue String where
    fromSQLValue = lmap show <<< runExcept <<< readString

instance toSQLValueArray :: (ToSQLValue a) => ToSQLValue (Array a) where
    toSQLValue = toForeign <<< map toSQLValue

instance fromSQLValueArray :: (FromSQLValue a) => FromSQLValue (Array a) where
    fromSQLValue = traverse fromSQLValue <=< lmap show <<< runExcept <<< readArray

instance toSQLValueList :: (ToSQLValue a) => ToSQLValue (List a) where
    toSQLValue = toForeign <<< Array.fromFoldable <<< map toSQLValue

instance fromSQLValueList :: (FromSQLValue a) => FromSQLValue (List a) where
    fromSQLValue = map List.fromFoldable <<< traverse fromSQLValue <=< lmap show <<< runExcept <<< readArray

instance toSQLValueByteString :: ToSQLValue ByteString where
    toSQLValue = toForeign

instance fromSQLValueByteString :: FromSQLValue ByteString where
    fromSQLValue x
        | unsafeIsBuffer x = pure $ unsafeFromForeign x
        | otherwise = throwError "FromSQLValue ByteString: not a buffer"

instance toSQLValueInstant :: ToSQLValue Instant where
    toSQLValue = instantToString

instance fromSQLValueDateTime :: FromSQLValue DateTime where
    fromSQLValue = join <<< (bimap show ((note "JSDate gave invalid DateTime") <<< toDateTime) ) <<< runExcept <<< readDate

instance toSQLValueDateTime :: ToSQLValue DateTime where
    toSQLValue = toForeign <<< fromDateTime

instance toSQLValueMaybe :: (ToSQLValue a) => ToSQLValue (Maybe a) where
    toSQLValue Nothing = null
    toSQLValue (Just x) = toSQLValue x

instance fromSQLValueMaybe :: (FromSQLValue a) => FromSQLValue (Maybe a) where
    fromSQLValue x | isNull x  = pure Nothing
                   | otherwise = Just <$> fromSQLValue x

instance toSQLValueForeign :: ToSQLValue Foreign where
    toSQLValue = id

instance fromSQLValueForeign :: FromSQLValue Foreign where
    fromSQLValue = pure

foreign import null :: Foreign
foreign import instantToString :: Instant -> Foreign
foreign import unsafeIsBuffer :: ∀ a. a -> Boolean
