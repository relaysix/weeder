{-# LANGUAGE OverloadedStrings, RecordWildCards #-}

module Stack(Stack(..), parseStack, buildStack) where

import Data.Yaml
import Data.List.Extra
import Control.Exception
import qualified Data.Text as T
import qualified Data.HashMap.Strict as Map
import qualified Data.ByteString.Char8 as BS
import System.Process
import Data.Functor
import Prelude


data Stack = Stack
    {stackPackages :: [FilePath]
    ,stackDistDir :: FilePath
    }

cmd :: String -> [String] -> IO ()
cmd = callProcess

cmdStdout :: String -> [String] -> IO String
cmdStdout exe args = readCreateProcess (proc exe args) ""


buildStack :: FilePath -> IO ()
buildStack file = cmd "stack" ["build","--stack-yaml=" ++ file,"--test","--bench","--no-run-tests","--no-run-benchmarks"]

-- | Note that in addition to parsing the stack.yaml file it also runs @stack@ to
--   compute the dist-dir.
parseStack :: Maybe FilePath -> FilePath -> IO Stack
parseStack distDir file = do
    stackDistDir <- case distDir of
        Nothing -> fst . line1 <$> cmdStdout "stack" ["path","--dist-dir","--stack-yaml=" ++ file]
        Just x -> return x
    stackPackages <- f . decodeYaml <$> cmdStdout "stack" ["query","locals","--stack-yaml=" ++ file]
    return Stack{..}
    where
        decodeYaml = either throw id . decodeEither' . BS.pack
        fromObject (Object x) = x
        fromString (String s) = T.unpack s
        f = map (fromString . (Map.! "path") . fromObject) . Map.elems . fromObject
