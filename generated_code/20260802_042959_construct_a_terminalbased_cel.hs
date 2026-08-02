-- Celestial Process Map in Terminal (Haskell)
-- Queries live system processes via `ps` and projects them onto an orbiting 2D space map.
-- The process with the highest memory consumption forms a Supermassive Black Hole at center.
-- Surrounding processes act as stars flickering in brightness and speed based on CPU load.

import Control.Concurrent (threadDelay)
import Control.Monad (forM_, forever, when)
import Data.Char (isDigit)
import Data.List (sortBy)
import Data.Maybe (mapMaybe)
import Data.Ord (comparing)
import System.IO (hFlush, stdout)
import System.Process (readProcess)

-- Process entity with polar orbital parameters
data CelestialProc = CelestialProc
  { pPid   :: Int
  , pCpu   :: Double
  , pMem   :: Double
  , pCmd   :: String
  , pAngle :: Double
  , pDist  :: Double
  } deriving (Show, Eq)

-- Fixed terminal dimensions
width, height :: Int
width  = 80
height = 24

centerX, centerY :: Double
centerX = fromIntegral width / 2.0
centerY = fromIntegral height / 2.0

-- ANSI Terminal Control Strings
hideCursor, clearScreen, resetColor :: String
hideCursor  = "\ESC[?25l"
clearScreen = "\ESC[2J\ESC[H"
resetColor  = "\ESC[0m"

moveTo :: Int -> Int -> String
moveTo x y = "\ESC[" ++ show y ++ ";" ++ show x ++ "H"

-- Map process CPU usage to dynamic star color and symbol brightness
starStyle :: Double -> (String, Char)
starStyle cpu
  | cpu > 50.0  = ("\ESC[1;31m", '✹') -- Supernova (Red)
  | cpu > 20.0  = ("\ESC[1;33m", '★') -- Bright Star (Yellow)
  | cpu > 5.0   = ("\ESC[0;36m", '✦') -- Active Star (Cyan)
  | cpu > 1.0   = ("\ESC[0;37m", '*') -- Normal Star (White)
  | otherwise   = ("\ESC[2;37m", '.') -- Dim Star (Faint)

-- Parse `ps -eo pid,%cpu,%mem,comm` output lines safely
parsePsLine :: String -> Maybe (Int, Double, Double, String)
parsePsLine line = case words line of
  (pidStr : cpuStr : memStr : cmdParts) | all isDigit pidStr ->
    case (reads pidStr, reads cpuStr, reads memStr) of
      ([(pid, "")], [(cpu, "")], [(mem, "")]) ->
        Just (pid, cpu, mem, unwords cmdParts)
      _ -> Nothing
  _ -> Nothing

-- Query system processes using Unix `ps`
getProcesses :: IO [(Int, Double, Double, String)]
getProcesses = do
  raw <- readProcess "ps" ["-eo", "pid,%cpu,%mem,comm"] ""
  return $ mapMaybe parsePsLine (lines raw)

-- Main rendering loop
main :: IO ()
main = do
  putStr hideCursor
  loop 0
  where
    loop :: Int -> IO ()
    loop frame = do
      procsRaw <- getProcesses
      let sortedByMem = sortBy (comparing (\(_, _, mem, _) -> mem)) procsRaw
      
      case reverse sortedByMem of
        [] -> threadDelay 200000 >> loop (frame + 1)
        (blackHole : starProcs) -> do
          let maxStars = min 35 (length starProcs)
              visibleProcs = take maxStars starProcs
              
              -- Map process list into orbiting celestial bodies
              stars = zipWith (\idx (pid, cpu, mem, cmd) ->
                let radius = 3.0 + (fromIntegral idx / fromIntegral maxStars) * 8.0
                    -- High CPU processes revolve faster around the singularity
                    speed  = 0.03 + (cpu / 100.0) * 0.15
                    angle  = (fromIntegral frame * speed) + (fromIntegral pid * 0.2)
                in CelestialProc pid cpu mem cmd angle radius
                ) [1..] visibleProcs

          -- Render screen buffer
          putStr clearScreen
          
          -- Render celestial stars
          forM_ stars $ \s -> do
            let -- Adjust 2:1 character aspect ratio for terminal symmetry
                x = round (centerX + pDist s * 2.0 * cos (pAngle s))
                y = round (centerY + pDist s * sin (pAngle s))
            when (x >= 1 && x <= width && y >= 1 && y <= height) $ do
              let (colorCode, symbol) = starStyle (pCpu s)
              putStr $ moveTo x y ++ colorCode ++ [symbol] ++ resetColor

          -- Render Supermassive Black Hole at gravitational center
          let (bhPid, _, bhMem, bhCmd) = blackHole
              bhX = round centerX
              bhY = round centerY
          putStr $ moveTo (bhX - 1) bhY ++ "\ESC[1;35m(🕳)\ESC[0m"

          -- Render telemetry HUD overlay
          putStr $ moveTo 2 1 ++ "\ESC[1;32m★ LIVE CELESTIAL PROCESS MAP ★\ESC[0m"
          putStr $ moveTo 2 2 ++ "\ESC[2;37mBlack Hole Core [Max MEM]: PID " 
                              ++ show bhPid ++ " (" ++ bhCmd ++ ") " ++ show bhMem ++ "% MEM\ESC[0m"
          putStr $ moveTo 2 height ++ "\ESC[2;37mOrbiting Stars (PIDs): " 
                                    ++ show (length stars) ++ " | Ctrl+C to Exit\ESC[0m"
          
          hFlush stdout
          threadDelay 100000 -- ~10 FPS refresh tick
          loop (frame + 1)