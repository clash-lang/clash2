{-|
  Copyright  :  (C) 2012-2016, University of Twente,
                    2017     , Myrtle Software Ltd
                    2018     , Google Inc.
  License    :  BSD2 (see the file LICENSE)
  Maintainer :  Christiaan Baaij <christiaan.baaij@gmail.com>

  Utility functions to generate Primitives
-}

{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}

module Clash.Primitives.Util
  ( generatePrimMap
  , hashCompiledPrimMap
  , constantArgs
  ) where

import           Data.Aeson.Extra       (decodeOrErr)
import qualified Data.ByteString.Lazy   as LZ
import qualified Data.HashMap.Lazy      as HashMap
import qualified Data.HashMap.Strict    as HashMapStrict
import           Data.Maybe             (fromMaybe)
import qualified Data.Set               as Set
import           Data.Hashable          (hash)
import           Data.List              (isSuffixOf, sort)
import qualified Data.Text              as TS
import           Data.Text.Lazy         (Text)
import qualified Data.Text.Lazy.IO      as T
import           Data.Traversable       (mapM)
import           GHC.Stack              (HasCallStack)
import qualified System.Directory       as Directory
import qualified System.FilePath        as FilePath
import           System.IO.Error        (tryIOError)

import           Clash.Primitives.Types
  ( Primitive(BlackBox), CompiledPrimitive, ResolvedPrimitive, ResolvedPrimMap
  , includes, template, TemplateSource(TFile, TInline), Primitive(..)
  , UnresolvedPrimitive, CompiledPrimMap)
import           Clash.Netlist.Types    (BlackBox(..))
import           Clash.Netlist.BlackBox.Util
  (walkElement)
import           Clash.Netlist.BlackBox.Types
  (Element(Const, Lit))

hashCompiledPrimitive :: CompiledPrimitive -> Int
hashCompiledPrimitive (Primitive {name, primType}) = hash (name, primType)
hashCompiledPrimitive (BlackBoxHaskell {function}) = fst function
hashCompiledPrimitive (BlackBox {name, kind, outputReg, libraries, imports, includes, template}) =
  hash (name, kind, outputReg, libraries, imports, includes', hashBlackbox template)
    where
      includes' = map (\(nms, bb) -> (nms, hashBlackbox bb)) includes
      hashBlackbox (BBTemplate bbTemplate) = hash bbTemplate
      hashBlackbox (BBFunction bbName bbHash _bbFunc) = hash (bbName, bbHash)

-- | Hash a compiled primitive map. It needs a separate function (as opposed to
-- just 'hash') as it might contain (obviously unhashable) Haskell functions. This
-- function takes the hash value stored with the function instead.
hashCompiledPrimMap :: CompiledPrimMap -> Int
hashCompiledPrimMap cpm = hash (map hashCompiledPrimitive orderedValues)
  where
    -- TODO: switch to 'normal' map instead of hashmap?
    orderedKeys   = sort (HashMap.keys cpm)
    orderedValues = map (cpm HashMapStrict.!) orderedKeys

resolveTemplateSource
  :: HasCallStack
  => FilePath
  -> TemplateSource
  -> IO Text
resolveTemplateSource _metaPath (TInline text) =
  return text
resolveTemplateSource metaPath (TFile path) =
  let path' = FilePath.replaceFileName metaPath path in
  either (error . show) id <$> (tryIOError $ T.readFile path')

-- | Replace file pointers with file contents
resolvePrimitive'
  :: HasCallStack
  => FilePath
  -> UnresolvedPrimitive
  -> IO ResolvedPrimitive
resolvePrimitive' _metaPath (Primitive name primType) =
  return $ Primitive name primType
resolvePrimitive' metaPath BlackBox{template=t, includes=i, ..} = do
  let resolvedIncludes = mapM (traverse (traverse (traverse (resolveTemplateSource metaPath)))) i
      resolved         = traverse (traverse (resolveTemplateSource metaPath)) t
  BlackBox name kind warning outputReg libraries imports <$> resolvedIncludes <*> resolved
resolvePrimitive' metaPath (BlackBoxHaskell bbName funcName t) =
  BlackBoxHaskell bbName funcName <$> (mapM (resolveTemplateSource metaPath) t)

-- | Interprets contents of json file as list of @Primitive@s.
resolvePrimitive
  :: HasCallStack
  => FilePath
  -> IO [ResolvedPrimitive]
resolvePrimitive fileName = do
  let decode = fromMaybe [] . decodeOrErr fileName
  prims <- decode <$> LZ.readFile fileName
  mapM (resolvePrimitive' fileName) prims

-- | Generate a set of primitives that are found in the primitive definition
-- files in the given directories.
generatePrimMap
  :: HasCallStack
  => [FilePath]
  -- ^ Directories to search for primitive definitions
  -> IO ResolvedPrimMap
generatePrimMap filePaths = do
  primitiveFiles <- fmap concat $ mapM
     (\filePath -> do
         fpExists <- Directory.doesDirectoryExist filePath
         if fpExists
           then
             fmap ( map (FilePath.combine filePath)
                  . filter (isSuffixOf ".json")
                  ) (Directory.getDirectoryContents filePath)
           else
             return []
     ) filePaths

  primitives <- fmap concat $ mapM resolvePrimitive primitiveFiles
  return $ HashMap.fromList $ zip (map name primitives) primitives

-- | Determine what argument should be constant / literal
constantArgs :: TS.Text -> CompiledPrimitive -> Set.Set Int
constantArgs nm BlackBox {template = BBTemplate template} =
  Set.fromList (fromIntForce ++ concatMap (walkElement getConstant) template)
 where
  getConstant (Lit i)      = Just i
  getConstant (Const i)    = Just i
  getConstant _            = Nothing

  -- Ensure that if the "Integer" arguments are constants, that they are reduced
  -- to literals, so that the buildin rules can properly fire.
  --
  -- Only in the the case that "Integer" arguments are truly variables should
  -- the blackbox rules fire.
  fromIntForce
    | nm == "Clash.Sized.Internal.BitVector.fromInteger#"  = [2]
    | nm == "Clash.Sized.Internal.BitVector.fromInteger##" = [0,1]
    | nm == "Clash.Sized.Internal.Index.fromInteger#"      = [1]
    | nm == "Clash.Sized.Internal.Signed.fromInteger#"     = [1]
    | nm == "Clash.Sized.Internal.Unsigned.fromInteger#"   = [1]
    | otherwise = []
constantArgs _ _ = Set.empty
