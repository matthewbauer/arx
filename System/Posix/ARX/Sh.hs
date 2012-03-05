{-# LANGUAGE OverloadedStrings
           , FlexibleInstances #-}
-- | Very basic Bourne shell generation.
module System.Posix.ARX.Sh ( Val(), val, Var(), var, VarVal(..),
                             setEU, Render(..), Raw(..) ) where

import Control.Monad
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as Bytes
import Data.String
import Data.Maybe
import Data.Monoid

import qualified Blaze.ByteString.Builder as Blaze
import qualified Text.ShellEscape as Esc

import System.Posix.ARX.BlazeIsString


setEU                       ::  Blaze.Builder
setEU                        =  "set -e -u\n"


-- | Valid shell string values contain any byte but null.
newtype Val                  =  Val ByteString
 deriving (Eq, Ord, Show)
instance Render Val where
  render (Val bytes) = (Blaze.fromByteString . Esc.bytes . Esc.sh) bytes
instance Raw Val where
  raw (Val bytes)            =  bytes
instance IsString Val where
  fromString                 =  fromJust . val . fromString

val                         ::  ByteString -> Maybe Val
val bytes = guard (Bytes.all (/= '\0') bytes) >> Just (Val bytes)


-- | Valid shell variable names consist of a leading letter or underscore and
--   then any number of letters, underscores or digits.
newtype Var                  =  Var ByteString
 deriving (Eq, Ord, Show)
instance Render Var where
  render (Var bytes)         =  Blaze.fromByteString bytes
instance Raw Var where
  raw (Var bytes)            =  bytes

var                         ::  ByteString -> Maybe Var
var ""                       =  Nothing
var bytes = guard (leading h && Bytes.all body t) >> Just (Var bytes)
 where
  (h, t)                     =  (Bytes.head bytes, Bytes.tail bytes)
  body c                     =  leading c || (c >= '0' && c <= '9')
  leading c = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_'


-- | Shell strings with variable substitution.
newtype VarVal               =  VarVal [Either Var Val]
 deriving (Eq, Ord, Show)
instance Render VarVal where
  render (VarVal l)          =  (mconcat . map render) l
instance IsString VarVal where
  fromString                 =  VarVal . (:[]) . Right . fromString


instance Render (Either Var Val) where
  render (Left var)          =  mconcat ["\"$", render var, "\""]
  render (Right val)         =  render val

instance Render [Val] where
  render                     =  mconcat . map (mappend " " . render)

class Render t where
  render                    ::  t -> Blaze.Builder

class Raw t where
  raw                       ::  t -> ByteString

