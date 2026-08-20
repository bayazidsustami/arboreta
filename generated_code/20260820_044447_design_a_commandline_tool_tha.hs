import Control.Concurrent (threadDelay)
import Control.Monad (forever, when)
import System.Console.ANSI
import System.IO
import System.Random (randomRIO)

-- Simulated Memory System
data MemStats = MemStats
  { totalAlloc :: Double
  , activeAlloc :: Double
  , leakAmount :: Double
  }

-- Tree Aesthetic Structure
data Branch = Branch
  { length' :: Int
  , angle :: Double
  , hasVine :: Bool
  , subBranches :: [Branch]
  }

-- Generate dynamic tree with memory-bound vine parasites
growBonsai :: Int -> Double -> Branch
growBonsai depth leakRatio = grow depth 0.0
  where
    grow 0 _ = Branch 1 0.0 False []
    grow d a =
      Branch
        { length' = d + 1
        , angle = a
        , hasVine = (fromIntegral d / 5.0) < leakRatio
        , subBranches =
            if d > 1
              then [grow (d - 1) (a - 0.4), grow (d - 1) (a + 0.4)]
              else []
        }

-- Frame buffer rendering engine
renderBonsai :: Branch -> Bool -> IO ()
renderBonsai tree isGC = do
  clearScreen
  setCursorPosition 0 0
  putStrLn "=== ASCII MEMORY BONSAI MONITOR ==="
  putStrLn "Green: Healthy Foliage | Red '~': Leak Vines | Magenta '*': GC Blossom Fall\n"
  
  -- Render Tree Canvas
  drawBranch 12 15 tree
  
  -- Trigger Blossom Shower on Garbage Collection
  when isGC $ do
    setCursorPosition 16 5
    setSGR [SetColor Foreground Vivid Magenta]
    putStrLn "* * * GARBAGE COLLECTION: BLOSSOMS FALLING * * *"
    setSGR [Reset]
  
  setCursorPosition 18 0
  hFlush stdout

drawBranch :: Int -> Int -> Branch -> IO ()
drawBranch x y b = do
  let char = if hasVine b then '~' else '|'
  let color = if hasVine b then Red else Green
  
  setCursorPosition y x
  setSGR [SetColor Foreground Vivid color]
  putChar char
  
  -- Render sub-branches recursively
  case subBranches b of
    [left, right] -> do
      drawBranch (max 0 (x - 2)) (max 2 (y - 1)) left
      drawBranch (x + 2) (max 2 (y - 1)) right
    _ -> return ()
  setSGR [Reset]

-- Telemetry Loop Simulation
simulateMemory :: MemStats -> IO (MemStats, Bool)
simulateMemory (MemStats alloc active leak) = do
  -- Simulate memory allocation fluctuations
  deltaAlloc <- randomRIO (0.5, 2.5)
  shouldLeak <- (< (0.3 :: Double)) <$> randomRIO (0, 1)
  
  let newLeak = if shouldLeak then leak + 0.5 else leak
  let newAlloc = alloc + deltaAlloc
  let newActive = active + deltaAlloc + newLeak
  
  -- Trigger GC if allocated memory breaches threshold
  if newActive > 15.0
    then return (MemStats 5.0 4.0 0.0, True) -- GC sweeps memory and destroys vines
    else return (MemStats newAlloc newActive newLeak, False)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  hideCursor
  
  let initialStats = MemStats 2.0 2.0 0.0
  
  forever $ do
    loop initialStats
  where
    loop stats = do
      (nextStats, isGC) <- simulateMemory stats
      let leakRatio = leakAmount nextStats / max 1.0 (activeAlloc nextStats)
      let tree = growBonsai 4 leakRatio
      
      renderBonsai tree isGC
      threadDelay 400000 -- 400ms ticks
      loop nextStats