{-# LANGUAGE DeriveGeneric #-}

module BBQ.SG.Meta (
  Meta(..)
, Email(..)
, Contact(..)
, Date(..)
) where
import Data.List (sort, group)
import System.FilePath (FilePath)
import BBQ.SG.Misc
import Data.Serialize
import GHC.Generics (Generic)
-- Haskell's Date lib is awkward to use

type Day   = Int
type Year  = Int
type Month = Int

data Date = Date_ {
    _day    :: Maybe Day,
    _month  :: Month,
    _year   :: Year
} deriving (Eq, Generic)

instance Serialize Date

instance Show Date where
    show (Date_ d m y) = show y ++ "." ++ show m ++ showMaybe d

instance Ord Date where
    compare (Date_ d1 m1 y1) (Date_ d2 m2 y2) =
        case compare y1 y2 of
            EQ  -> case compare m1 m2 of
                EQ  -> compare d1 d2                
                neq -> neq
            neq -> neq

data Email = Email String String deriving (Eq, Generic)

instance Serialize Email

instance Show Email where
    show (Email name domain) = "<" ++ name ++ " \\AT " ++ domain ++ ">"

data Contact = Contact_ {
    _name   :: String,
    _email  :: Email
} deriving (Eq, Generic)

instance Serialize Contact

instance Show Contact where
    show (Contact_ name email) = name ++ "  " ++ show email

data Meta = Meta_ {
    _title  :: Maybe String,
    _date   :: Maybe Date,
    _author :: Maybe Contact,
    _tags   :: [String],
    _path   :: FilePath
} deriving (Show, Eq, Generic)

instance Serialize Meta

emptyMeta = Meta_ Nothing Nothing Nothing [] ""
