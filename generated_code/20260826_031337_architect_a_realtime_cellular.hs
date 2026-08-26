import Control.Concurrent (threadDelay, forkIO)
import Control.Monad (forever, replicateM)
import Data.Array.IO
import Data.Bits (xor)
import Data.Char (ord)
import GHC.Stats
import System.IO (hSetBuffering, stdout, BufferMode(NoBuffering))
import System.Random (randomRIO)

-- Configuration Constants
width, height :: Int
width = 60
height = 20

-- Palette for rendering cellular automata dynamic states
palette :: String
palette = " .:-=+*#%@"

-- Convert systemic allocation/fragmentation metrics into a seed threshold
getFragmentationSeed :: IO Double
getFragmentationSeed = do
  enabled <- getRTSStatsEnabled
  if enabled
    then do
      stats <- getRTSStats
      let allocated = fromIntegral (allocatedBytes stats) :: Double
          inUse = fromIntegral (gcdetails_live_bytes (gc stats)) :: Double
      return $ if allocated > 0 then min 1.0 (max 0.1 (1.0 - (inUse / allocated))) else 0.4
    else do
      -- Fallback heuristic utilizing heap allocations if detailed RTS stats are disabled
      dummyData <- replicateM 1000 (randomRIO (1 :: Int, 100))
      let pseudoEntropy = sum dummyData
      return $ fromIntegral (pseudoEntropy `mod` 50 + 20) / 100.0

-- Initialize grid state using system fragmentation metrics as probability density
initGrid :: IO (IOUArray (Int, Int) Int)
initGrid = do
  p <- getFragmentationSeed
  grid <- newArray ((0,0), (height-1, width-1)) 0
  forM_ [(r, c) | r <- [0..height-1], c <- [0..width-1]] $ \(r, c) -> do
    rVal <- randomRIO (0.0, 1.0)
    let state = if rVal < p then floor (rVal * 9) + 1 else 0
    writeArray grid (r, c) state
  return grid

-- Count alive neighbors (states > 0)
countNeighbors :: IOUArray (Int, Int) Int -> Int -> Int -> IO Int
countNeighbors grid r c = do
  let offsets = [(-1,-1), (-1,0), (-1,1), (0,-1), (0,1), (1,-1), (1,0), (1,1)]
  fmap sum $ mapM (\(dr, dc) -> do
    let nr = (r + dr) `mod` height
        nc = (c + dc) `mod` width
    val <- readArray grid (nr, nc)
    return $ if val > 0 then 1 else 0
    ) offsets

-- Step the Cellular Automaton based on custom multi-state rules
stepGrid :: IOUArray (Int, Int) Int -> IO (IOUArray (Int, Int) Int)
stepGrid current = do
  next <- newArray ((0,0), (height-1, width-1)) 0
  forM_ [(r, c) | r <- [0..height-1], c <- [0..width-1]] $ \(r, c) -> do
    val <- readArray current (r, c)
    n <- countNeighbors current r c
    let newVal = case (val, n) of
          (0, 3)     -> 1
          (v, 2)     -> v
          (v, 3)     -> v
          (v, _) | v > 0 -> (v + 1) `mod` 10
          _          -> 0
    writeArray next (r, c) newVal
  return next

-- Render the visual tapestry to the terminal
renderVisuals :: IOUArray (Int, Int) Int -> IO ()
renderVisuals grid = do
  putStr "\ESC[H" -- Move cursor to top-left
  forM_ [0..height-1] $ \r -> do
    rowStr <- mapM (\c -> do
      val <- readArray grid (r, c)
      return $ palette !! (val `mod` length palette)
      ) [0..width-1]
    putStrLn rowStr

-- Generative Bytebeat Sound Generator based on active CA states
audioThread :: IOUArray (Int, Int) Int -> IO ()
audioThread grid = do
  hSetBuffering stdout NoBuffering
  let play t = do
        -- Extract active cell counts to influence audio phase
        cVal <- readArray grid (t `mod` height, (t * 3) `mod` width)
        let note = (t * (cVal + 5)) `xor` (t `div` 64) `xor` (t >> 3)
            sample = toEnum (note `mod` 256) :: Char
        putChar sample
        threadDelay 125 -- ~8kHz PCM bytebeat stream rate
        play (t + 1)
  play 0

-- Main Loop running both auditory and visual threads
main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStr "\ESC[2J\ESC[?25l" -- Clear screen and hide cursor
  grid <- initGrid
  _ <- forkIO (audioThread grid)
  
  let loop g = do
        renderVisuals g
        threadDelay 80000 -- ~12 FPS refresh rate
        nextG <- stepGrid g
        loop nextG
        
  loop grid

-- Utility Helper for Monadic Loops over Grid Coordinates
forM_ :: [a] -> (a -> IO ()) -> IO ()
forM_ = flip mapM_