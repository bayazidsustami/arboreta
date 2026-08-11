-- SolarisMem: An Astronomical System Memory Constellation Generator
-- Translates Linux process IDs into star coordinates and memory dynamics into solar flares.

module Main where

import Control.Concurrent (threadDelay)
import Control.Monad (forever)
import Data.Char (isDigit)
import Data.List (sortBy)
import Data.Ord (comparing)
import System.CPUTime (getCPUTime)
import System.Directory (doesDirectoryExist, listDirectory)
import System.IO (hFlush, stdout)

-- Configuration for display viewport
viewportWidth, viewportHeight :: Int
viewportWidth = 80
viewportHeight = 24

-- Stellar representation driven by process memory
data Star = Star
  { starPid    :: Int
  , starX      :: Int
  , starY      :: Int
  , starSymbol :: Char
  } deriving (Show)

-- Inspect active Linux /proc PIDs or fallback to system-derived process IDs
getPids :: IO [Int]
getPids = do
  hasProc <- doesDirectoryExist "/proc"
  if hasProc
    then do
      entries <- listDirectory "/proc"
      let pids = [read e | e <- entries, all isDigit e, not (null e)]
      return $ if null pids then defaultPids else pids
    else return defaultPids
  where
    defaultPids = [1, 42, 108, 256, 512, 1024, 1337, 2048, 4096, 8192]

-- Map Process ID to celestial coordinates and memory volatility symbol
pidToStar :: Int -> Integer -> Star
pidToStar pid volatility = Star pid posX posY flareSymbol
  where
    -- Derive deterministic Right Ascension / Declination mapping from PID
    posX = (pid * 2654435761) `mod` viewportWidth
    posY = (pid * 1597334677) `mod` viewportHeight

    -- Memory volatility cycles modulate solar flare intensity
    flareCycle = ["*", ".", "+", "o", "O", "@", "#", "~"]
    symbolIndex = fromIntegral ((toInteger pid + volatility) `mod` fromIntegral (length flareCycle))
    flareSymbol = flareCycle !! symbolIndex

-- Sample high-precision CPU time as a dynamic volatility source
getVolatility :: IO Integer
getVolatility = do
  t <- getCPUTime
  return (t `div` 50000000)

-- Calculate Euclidean distance between two stars
starDistance :: Star -> Star -> Double
starDistance s1 s2 = sqrt $ fromIntegral ((starX s1 - starX s2) ^ (2 :: Int) + (starY s1 - starY s2) ^ (2 :: Int))

-- Rasterize the constellation map and connecting nebular vectors
renderMap :: [Star] -> String
renderMap stars = unlines [ [ pixelAt x y | x <- [0 .. viewportWidth - 1] ] | y <- [0 .. viewportHeight - 1] ]
  where
    -- Active star nodes at target coordinates
    starsAt x y = filter (\s -> starX s == x && starY s == y) stars

    -- Calculate constellation links between proximate process nodes
    closestPairs = [ (s1, s2) | s1 <- take 20 stars, s2 <- take 20 stars, starPid s1 < starPid s2, starDistance s1 s2 < 12.0 ]

    -- Check if coordinate intersects a constellation vector
    isOnVector px py = any (\(s1, s2) -> isPointOnLine px py (starX s1, starY s1) (starX s2, starY s2)) closestPairs

    isPointOnLine px py (x1, y1) (x2, y2)
      | px < min x1 x2 || px > max x1 x2 || py < min y1 y2 || py > max y1 y2 = False
      | x1 == x2 = px == x1
      | y1 == y2 = py == y1
      | otherwise = abs ((y2 - y1) * px - (x2 - x1) * py + x2 * y1 - y2 * x1) < 12

    -- Determine render character for screen matrix
    pixelAt x y = case starsAt x y of
      (s : _) -> starSymbol s
      []      -> if isOnVector x y then '-' else ' '

-- Main event loop: updates viewport in real time
main :: IO ()
main = do
  -- Terminal setup: hide cursor and clear screen
  putStr "\ESC[?25l\ESC[2J"
  forever $ do
    pids <- getPids
    volatility <- getVolatility
    let stars = map (`pidToStar` volatility) (take 35 pids)

    -- Reset cursor position and render canvas
    putStr "\ESC[1;1H"
    putStrLn "=== STELLAR MEMORY MAP: REAL-TIME CONSTELLATIONS ==="
    putStr (renderMap stars)
    putStrLn "Legend: [* . + o O @ # ~] Process Flares | [-] Constellation Links"
    hFlush stdout

    -- Frame refresh rate (~15 FPS)
    threadDelay 66000