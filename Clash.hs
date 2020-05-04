{-# LANGUAGE CPP #-}

{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module Main where

#include "MachDeps.h"
#define HDLSYN Other

import Clash.Driver
import Clash.Driver.Types
import Clash.GHC.Evaluator
import Clash.GHC.GenerateBindings
import Clash.GHC.NetlistTypes
import Clash.Backend
import Clash.Backend.SystemVerilog
import Clash.Backend.VHDL
import Clash.Backend.Verilog
import Clash.Netlist.BlackBox.Types
import Clash.Annotations.BitRepresentation.Internal (buildCustomReprs)
import Clash.Util

import Control.DeepSeq
import qualified Data.Time.Clock as Clock

import Util (OverridingBool(..))

genSystemVerilog
  :: String
  -> IO ()
genSystemVerilog = doHDL (initBackend WORD_SIZE_IN_BITS HDLSYN True False Nothing (AggressiveXOptBB False) :: SystemVerilogState)

genVHDL
  :: String
  -> IO ()
genVHDL = doHDL (initBackend WORD_SIZE_IN_BITS HDLSYN True False Nothing (AggressiveXOptBB False):: VHDLState)

genVerilog
  :: String
  -> IO ()
genVerilog = doHDL (initBackend WORD_SIZE_IN_BITS HDLSYN True False Nothing (AggressiveXOptBB False):: VerilogState)

doHDL
  :: HasCallStack
  => Backend s
  => s
  -> String
  -> IO ()
doHDL b src = do
  startTime <- Clock.getCurrentTime
  pd      <- primDirs b
  (bindingsMap,tcm,tupTcm,topEntities,primMap,reprs,domainConfs) <- generateBindings Auto pd ["."] [] (hdlKind b) src Nothing
  prepTime <- startTime `deepseq` bindingsMap `deepseq` tcm `deepseq` reprs `deepseq` Clock.getCurrentTime
  let prepStartDiff = reportTimeDiff prepTime startTime
  putStrLn $ "Loading dependencies took " ++ prepStartDiff

  generateHDL (buildCustomReprs reprs) domainConfs bindingsMap (Just b) primMap tcm tupTcm
    (ghcTypeToHWType WORD_SIZE_IN_BITS True) evaluator topEntities Nothing
    defClashOpts{opt_cachehdl = False, opt_dbgLevel = DebugSilent}
    (startTime,prepTime)

main :: IO ()
main = genVHDL "./examples/FIR.hs"
