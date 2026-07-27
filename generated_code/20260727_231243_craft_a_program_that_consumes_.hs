import System.Environment (getProgName)
import GHC.Stats (getRTSStats, RTSStats(..), getRTSStatsEnabled)
import Data.Char (ord)
import Control.Concurrent (threadDelay)
import Control.Exception (catch, SomeException)
import Control.Monad (forM_)
import System.IO (hFlush, stdout)

-- Self-Similar Fractal Garden powered by Source Code Seed & GC Metrics

-- Hashes source code into a list of floating-point seeds in [0, 1]
hashSource :: String -> [Double]
hashSource src = map (\c -> fromIntegral (ord c) / 255.0) src

-- Fetches CPU time spent in GC (microseconds)
getGCTime :: IO Double
getGCTime = do
  enabled <- getRTSStatsEnabled
  if enabled
    then do
      stats <- getRTSStats
      return $ fromIntegral (gc_cpu_ns stats) / 1000.0
    else return 0.0

-- Renders a fractal tree where branch length scales with GC activity (blooming/withering)
renderTree :: Int -> Double -> Double -> [Double] -> [String]
renderTree 0 _ _ _ = ["  ."]
renderTree depth len gcTime seeds =
  let seed = if null seeds then 0.5 else head seeds
      rest = if null seeds then [] else tail seeds
      -- GC activity causes bloom (expansion) or wither (contraction)
      witherFactor = 0.5 + 0.5 * cos (gcTime * 0.001 + seed * 6.28)
      effLen = max 1 (floor (len * witherFactor))
      stem = replicate effLen '|' ++ if witherFactor > 0.7 then "🌸" else "🥀"
      subTrees = renderTree (depth - 1) (len * 0.75) gcTime rest
      indented = map ("  " ++) subTrees
  in stem : indented

main :: IO ()
main = do
  -- Read self-source code as seed input
  progName <- getProgName
  src <- catch (readFile progName) (\(_ :: SomeException) -> return "default seed fallback source code")
  let seeds = hashSource src

  putStrLn "Starting Interactive Fractal Garden..."
  forM_ [1..200] $ \frame -> do
    -- Force garbage collection pressure via memory allocation
    let !_ = sum [1 .. frame * 20000]
    gcTime <- getGCTime

    let treeLines = renderTree 5 6.0 (gcTime + fromIntegral frame * 10) seeds
    putStr "\ESC[2J\ESC[H" -- Terminal clear screen
    putStrLn $ "=== Fractal Garden | Frame: " ++ show frame ++ " | GC CPU Time: " ++ show gcTime ++ " us ==="
    mapM_ putStrLn treeLines
    hFlush stdout
    threadDelay 150000 -- Frame delay