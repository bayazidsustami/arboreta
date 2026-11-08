import Control.Concurrent
import Control.Monad
import Data.List
import System.IO
import System.Random
import Data.Time.Clock

-- Poetic ash decay spectrum
ashChars :: String
ashChars :: String = " .:-=+*#%@"

-- Grid dimensions
width :: Int
width :: Int = 40

height :: Int
height :: Int = 15

-- Background sorting task measuring execution time to govern decay
measureSortTime :: IO Double
measureSortTime :: IO Double = do
  gen <- newStdGen
  let nums :: [Int]
      nums = take 1200 (randoms gen :: [Int])
  start <- getCurrentTime
  let sorted :: [Int]
      sorted = sort nums
  -- Force evaluation
  _ <- evaluate (length sorted)
  end <- getCurrentTime
  let diff :: NominalDiffTime
      diff = diffUTCTime end start
  return (realToFrac diff * 1000.0) -- milliseconds

-- Update grid particles based on sorting execution time
updateGrid :: [[(Char, Int)]] -> Double -> IO [[(Char, Int)]]
updateGrid :: [[(Char, Int)]] -> Double -> IO [[(Char, Int)]]
updateGrid grid sortTime = do
  -- Decay rate influenced by sort duration
  let decayFactor :: Int
      decayFactor = max 1 (round (sortTime / 5.0))
  mapM (mapM (decayCell decayFactor)) grid
  where
    decayCell :: Int -> (Char, Int) -> IO (Char, Int)
    decayCell d (c, life)
      | life <= 0 = do
          -- Respawn new particle with poetic flair
          r <- randomRIO (0, length ashChars - 1)
          lifeR <- randomRIO (5, 20)
          return (ashChars !! r, lifeR)
      | otherwise = do
          let newLife :: Int
              newLife = life - d
              idx :: Int
              idx = min (length ashChars - 1) (max 0 (length ashChars - 1 - (newLife `div` 3)))
          return (ashChars !! idx, newLife)

-- Render grid to screen with ANSI escape codes for smooth refresh
renderGrid :: [[(Char, Int)]] -> IO ()
renderGrid :: [[(Char, Int)]] -> IO ()
renderGrid grid = do
  -- Clear screen and move cursor to top
  putStr "\ESC[2J\ESC[H"
  putStrLn "=== ASCIIPHYSICS: Poetic Ash Decay vs Sorting Workload ==="
  putStrLn "--------------------------------------------------------"
  mapM_ (putStrLn . map fst) grid
  putStrLn "--------------------------------------------------------"
  putStrLn "Sorting background workload active... Press Ctrl+C to exit."

main :: IO ()
main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  hSetBuffering stdin NoBuffering
  hSetEcho stdin False

  -- Initialize grid with random ash levels
  initGen <- newStdGen
  let initialLives :: [Int]
      initialLives = randomRs (1, 15) initGen
      initialChars :: [Char]
      initialChars = take (width * height) (cycle ashChars)
      flatGrid :: [(Char, Int)]
      flatGrid = zip initialChars initialLives
      initialGrid :: [[(Char, Int)]]
      initialGrid = take height (unfoldr (\s -> Just (splitAt width s)) flatGrid)

  -- Run simulation loop
  let loop :: [[(Char, Int)]] -> IO ()
      loop g = do
        sortTime <- measureSortTime
        g' <- updateGrid g sortTime
        renderGrid g'
        threadDelay 100000 -- 100ms frame delay
        loop g'

  loop initialGrid