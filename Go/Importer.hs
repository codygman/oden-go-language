module Go.Importer where
-- | This module queries the Go importer for available definitions in Go
-- packages in the system and converts those definitions to the Oden type
-- system.
--
-- All Go types and constructs are not support by Oden (yet) so it returns
-- 'UnsupportedTypesWarning's for those types which it ignores.
-- {-# LANGUAGE ForeignFunctionInterface #-}
-- {-# LANGUAGE OverloadedStrings        #-}
-- {-# LANGUAGE ScopedTypeVariables      #-}
-- module Go.Importer (
--   PackageImportError(..),
--   UnsupportedTypesWarning(..),
--   importer
-- ) where

-- import           Oden.Core.Definition
-- import           Oden.Core.Typed
-- import           Oden.Core.Package

-- import           Go.Type               as G
-- import qualified Go.Identifier         as GI
-- import           Oden.Identifier
-- import           Oden.Imports
-- import           Oden.Metadata
-- import           Oden.Predefined
-- import           Oden.QualifiedName         (PackageName(..), QualifiedName(..))
-- import           Oden.SourceInfo
-- import qualified Oden.Type.Polymorphic      as Poly

-- import           Control.Applicative        hiding (Const)
-- import           Control.Monad
-- import           Control.Monad.Except
-- import           Control.Monad.State

-- import           Data.Aeson
-- import           Data.Aeson.Types
-- import           Data.ByteString.Lazy.Char8 (pack)
-- import qualified Data.HashMap.Strict        as HM
-- import qualified Data.Set                   as Set
-- import qualified Data.Text                  as T

-- import           Foreign.C.String
-- foreign import ccall "GetPackage" c_GetPackage :: CString -> IO CString

-- optOrNull :: FromJSON a => HM.HashMap T.Text Value -> T.Text -> Parser (Maybe a)
-- o `optOrNull` k = case HM.lookup k o of
--                     Just Null -> return Nothing
--                     Just v -> parseJSON v
--                     Nothing -> return Nothing

-- instance FromJSON StructField where
--   parseJSON (Object o) = StructField <$> o .: "name" <*> o .: "type"
--   parseJSON v = fail ("Unexpected: " ++ show v)

-- instance FromJSON GI.Identifier where
--   parseJSON (String s) = return (GI.Identifier (T.unpack s))
--   parseJSON v = fail ("Expecting a string but got: " ++ show v)

-- instance FromJSON Type where
--   parseJSON (Object o) = do
--     kind :: String <- o .: "kind"
--     case kind of
--       "basic"         -> Basic <$> o .: "name" <*> o .: "untyped"
--       "pointer"       -> Pointer <$> o .: "inner"
--       "interface"     -> return (Interface [])
--       "array"         -> G.Array <$> o .: "length"
--                                  <*> o .: "inner"
--       "slice"         -> Slice <$> o .: "inner"
--       "signature"     -> do
--         isVariadic <- o .: "variadic"
--         receiver <- o `optOrNull` "recv"
--         params <- o .: "params"
--         returns <- o .: "returns"
--         return (Signature receiver (Parameters params isVariadic) (Returns returns))
--       "struct"        -> Struct <$> o .: "fields"
--       "named"         -> Named <$> o .: "pkg" <*> o .: "name" <*> o .: "underlying"
--       "unsupported"   -> Unsupported <$> o .: "name"
--       k -> fail ("Unknown kind: " ++ k)
--   parseJSON v = fail ("Unexpected: " ++ show v)

-- data PackageObject = Func String Type
--                    | Var String Type
--                    | Const String Type
--                    | NamedType String Type
--                    deriving (Show, Eq)

-- nameOf :: PackageObject -> String
-- nameOf (Func n _) = n
-- nameOf (Var n _) = n
-- nameOf (Const n _) = n
-- nameOf (NamedType n _ ) = n

-- typeOf :: PackageObject -> Type
-- typeOf (Func _ t) = t
-- typeOf (Var _ t) = t
-- typeOf (Const _ t) = t
-- typeOf (NamedType _ t) = t

-- instance FromJSON PackageObject where
--   parseJSON (Object o) = do
--     t :: String <- o .: "objectType"
--     case t of
--       "func"       -> Func <$> o .: "name" <*> o .: "type"
--       "var"        -> Var <$> o .: "name" <*> o .: "type"
--       "const"      -> Const <$> o .: "name" <*> o .: "type"
--       "named_type" -> NamedType <$> o .: "name" <*> o .: "type"
--       _ -> fail ("Unknown object type: " ++ t)
--   parseJSON v = fail $ "Expected JSON object for PackageObject but got: " ++ show v

-- data GoPackage
--   = GoPackage String [PackageObject]
--   deriving (Show, Eq)

-- instance FromJSON GoPackage where
--   parseJSON (Object o) =
--     GoPackage <$> o .: "name" <*> o .: "objects"
--   parseJSON v = fail $ "Expected JSON object for GoPackage but got: " ++ show v

-- data PackageResponse
--   = ErrorResponse String | PackageResponse GoPackage
--   deriving (Show, Eq)

-- instance FromJSON PackageResponse where
--   parseJSON (Object o) = ErrorResponse <$> o .: "error"
--                        <|> PackageResponse <$> o .: "package"
--   parseJSON v = fail $ "Expected JSON object for PackageResponse but got: " ++ show v

-- decodeResponse :: String -> String -> Either PackageImportError GoPackage
-- decodeResponse pkgPath s = either (Left . ForeignPackageImportError pkgPath) Right $ do
--   value <- eitherDecode (pack s)
--   case value of
--     ErrorResponse err -> Left err
--     PackageResponse pkg' -> Right pkg'

-- missing :: Metadata SourceInfo
-- missing = Metadata Missing

-- type Converter = StateT Int (Except String)

-- fresh :: Converter Poly.TVar
-- fresh = do
--   n <- get
--   modify (+ 1)
--   return (Poly.TV ("_g" ++ show n))

-- convertType :: G.Type -> Converter Poly.Type
-- -- TODO: Add, or map, "Untyped constant" concept to Oden type system.
-- convertType (Basic (GI.Identifier "bool") False) = return typeBool
-- convertType (Basic (GI.Identifier "int") False) = return typeInt
-- convertType (Basic (GI.Identifier "rune") False) = return typeInt
-- convertType (Basic (GI.Identifier "float64") False) = return typeFloat64
-- convertType (Basic (GI.Identifier "float") True) = return typeFloat64
-- convertType (Basic (GI.Identifier "string") False) = return typeString
-- convertType (Basic (GI.Identifier "nil") False) = throwError "nil constants"
-- convertType (Basic n False) = throwError ("Basic type: " ++ show n)
-- convertType (Basic n True) = throwError ("Basic untyped: " ++ show n)
-- convertType (Pointer _) = throwError "Pointers"
-- convertType (G.Array _ _) = throwError "Arrays"
-- convertType (Slice t) = Poly.TSlice missing <$> convertType t
-- convertType Interface{} = do
--   t <- fresh
--   return $ Poly.TVar missing t
-- convertType (Signature (Just _) _ _) = throwError "Methods (functions with receivers)"
-- convertType (Signature Nothing (Parameters params isVariadic) (Returns ret)) = do
--   ps <- mapM convertType params
--   catchError (wrapReturns ps <$> mapM convertType ret)
--              (const $ return (Poly.TForeignFn missing isVariadic ps [typeUnit]))
--   where
--   wrapReturns ps [] = Poly.TForeignFn missing isVariadic ps [typeUnit] -- no return type
--   wrapReturns ps rs = Poly.TForeignFn missing isVariadic ps rs
-- convertType (Named pkgName (GI.Identifier n) t@Struct{}) =
--   Poly.TNamed missing (FQN (ForeignPackageName pkgName) (Identifier n)) <$> convertType t
-- convertType (Named _ _ t) = convertType t
-- convertType (Struct fields) = do
--   fields' <- foldM convertField (Poly.REmpty (Metadata Missing)) fields
--   return (Poly.TRecord missing fields')
--   where
--   convertField row (StructField (GI.Identifier name) goType) =
--     Poly.RExtension missing (Identifier name) <$> convertType goType <*> return row
-- convertType (Unsupported n) = throwError n

-- convertPackage :: GoPackage -> (TypedPackage, [UnsupportedMessage])
-- convertPackage (GoPackage pkgName objs) =
--   (TypedPackage (PackageDeclaration missing (ForeignPackageName pkgName)) [] allDefs, allMessages)
--   where
--   (allDefs, allMessages) = foldl addObject ([], []) objs
--   addObject (defs, msgs) (NamedType name goType) =
--     let identifier = Identifier name in
--     case runExcept (runStateT (convertType goType) 0) of
--          Left u -> (defs, (identifier, u) : msgs)
--          Right (type', _) ->
--            (TypeDefinition missing (FQN (ForeignPackageName name) identifier) [] type' : defs, msgs)
--   addObject (defs, msgs) obj =
--     let n = Identifier (nameOf obj)
--     in case runExcept (runStateT (convertType $ typeOf obj) 0) of
--          Left u -> (defs, (n, u) : msgs)
--          Right (ct, _) ->
--            let sc = Poly.Forall missing [] Set.empty ct
--            in (ForeignDefinition missing (FQN (ForeignPackageName pkgName) n) sc : defs, msgs)

-- importer :: ForeignImporter
-- importer pkgPath = do
--   cs <- newCString pkgPath
--   pkg' <- decodeResponse pkgPath <$> (c_GetPackage cs >>= peekCString)
--   return (convertPackage <$> pkg')
