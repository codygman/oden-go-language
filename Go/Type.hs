-- | A representation of a subset of the Go Programming Language type system,
-- based on https://golang.org/ref/spec. Types not needed in Oden are excluded.
module Go.Type where

import Go.Identifier

data StructField = StructField Identifier Type
                 deriving (Show, Eq)

data Returns = Returns [Type]
             deriving (Show, Eq)

data Parameters = Parameters [Type] Bool
                deriving (Show, Eq)

data InterfaceMethodSpec = Method Identifier Parameters Returns
                         | Embed Identifier
                         deriving (Show, Eq)

newtype KeyType = KeyType Type deriving (Eq,Show)
newtype ElementType = ElementType Type deriving (Eq,Show)

data Type = Basic Identifier Bool
          | Pointer Type
          | Array Int Type
          | Slice Type
          | Signature (Maybe Type) Parameters Returns
          | Struct [StructField]
          | Named String Identifier Type
          | Interface [InterfaceMethodSpec]
          | Map KeyType ElementType 
          | Unsupported String                        -- Temporary solution for the Importer.
          deriving (Show, Eq)
