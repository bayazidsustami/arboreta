module Main where

import Control.Concurrent (threadDelay)
import Control.Monad (forM_)
import Data.Char (ord)
import Data.List (foldl')
import System.Exit (ExitCode(..))
import System.IO (hSetBuffering, stdout, BufferMode(..))
import System.Process (readProcessWithExitCode)

-- ============================================================================
-- ESOTERIC COMPILER: RAW GIT HISTORY -> FLUID DYNAMICS SIMULATION
--
-- This script compiles git commits into physical fluid dynamics:
-- 1. Git commit messages are compiled into thermal currents (heat/buoyancy).
-- 2. Deleted lines of code are compiled into ink density dissolving in water.
-- 3. Run Eulerian fluid simulation (advection, diffusion, thermal buoyancy).
-- ============================================================================

-- Grid dimensions for simulation visualization
width, height :: Int
width = 60
height = 25

-- Representation of Parsed Git Commit Artifacts
data Commit = Commit
  { commitMsg    :: String
  , linesDeleted :: Int
  , linesAdded   :: Int
  } deriving (Show)

-- 2D Grid structure for fluid fields
newtype Grid a = Grid { unGrid :: [[a]] }

mkGrid :: a -> Grid a
mkGrid val = Grid $ replicate height (replicate width val)

getGrid :: Grid a -> Int -> Int -> a
getGrid (Grid g) x y = (g !! (y `mod` height)) !! (x `mod` width)

updateGrid :: Grid a -> (Int -> Int -> a -> a) -> Grid a
updateGrid (Grid g) f = Grid
  [ [ f x y (valAt x y) | x <- [0..width-1] ]
  | y <- [0..height-1]
  ]
  where valAt x y = (g !! y) !! x

-- Git History Extractor with Fallback Demo Data
fetchGitHistory :: IO [Commit]
fetchGitHistory = do
  (code, out, _) <- readProcessWithExitCode "git" ["log", "--stat", "--oneline", "-n", "10"] ""
  case code of
    ExitSuccess | not (null out) -> return (parseGitLog out)
    _ -> return demoCommits

parseGitLog :: String -> [Commit]
parseGitLog str = go (lines str)
  where
    go [] = []
    go (l:ls)
      | not (null l) && head l /= ' ' =
          let msg = unwords (drop 1 (words l))
              (dels, adds, rest) = extractStats ls
          in Commit msg dels adds : go rest
      | otherwise = go ls

    extractStats (l:ls)
      | "file changed" `elem` words l || "files changed" `elem` words l =
          (parseStat "-" l, parseStat "+" l, ls)
      | otherwise = extractStats ls
    extractStats [] = (0, 0, [])

    parseStat sym line =
      case filter (\w -> sym `elem` w) (words line) of
        (w:_) -> read (takeWhile (`elem` ['0'..'9']) w)
        []    -> 0

demoCommits :: [Commit]
demoCommits =
  [ Commit "refactor: dissolve monolithic architecture into light" 45 12
  , Commit "fix: memory leak in soul engine" 120 5
  , Commit "feat: introduce infinite fluid currents" 8 89
  , Commit "chore: burn old legacy scripts" 230 2
  ]

-- The Fluid Simulation State
data FluidState = FluidState
  { inkDensity  :: Grid Float
  , heatCurrent :: Grid Float
  , velX        :: Grid Float
  , velY        :: Grid Float
  }

initFluid :: FluidState
initFluid = FluidState (mkGrid 0) (mkGrid 0) (mkGrid 0) (mkGrid 0)

-- Compilation Stage: Translate Git Commits -> Physical Impulses
compileCommitHistory :: [Commit] -> FluidState -> FluidState
compileCommitHistory commits state = foldl' injectCommit state (zip [0..] commits)
  where
    injectCommit st (idx, c) =
      let cx = (idx * 13 + 7) `mod` width
          cy = (idx * 7 + 3) `mod` height
          
          -- Message length & ASCII values generate thermal velocity & heat
          thermalEnergy = fromIntegral (sum (map ord (commitMsg c))) / 120.0
          
          -- Deleted lines generate ink dropping into the medium
          inkValue = fromIntegral (linesDeleted c) * 0.4
          
      in st
        { inkDensity = updateGrid (inkDensity st) $ \x y v ->
            if abs (x - cx) <= 2 && abs (y - cy) <= 2
            then v + inkValue
            else v
        , heatCurrent = updateGrid (heatCurrent st) $ \x y v ->
            if abs (x - cx) <= 3 && abs (y - cy) <= 3
            then v + thermalEnergy
            else v
        }

-- Physical Fluid Engine: Advection, Thermal Buoyancy & Dissipation
stepSimulation :: FluidState -> FluidState
stepSimulation st =
  let
    -- Heat generates upward thermal currents (buoyancy)
    newVy = updateGrid (velY st) $ \x y vy ->
      let heat = getGrid (heatCurrent st) x y
      in (vy - heat * 0.06) * 0.98

    newVx = updateGrid (velX st) $ \x y vx ->
      vx * 0.98

    -- Advect ink according to velocity vectors
    advect grid = updateGrid grid $ \x y _ ->
      let vx = getGrid newVx x y
          vy = getGrid newVy x y
          srcX = round (fromIntegral x - vx) `mod` width
          srcY = round (fromIntegral y - vy) `mod` height
      in getGrid grid srcX srcY * 0.96 -- ink dissipation

    -- Heat rises and diffuses upwards
    coolHeat = updateGrid (heatCurrent st) $ \x y h ->
      let hBelow = getGrid (heatCurrent st) x ((y + 1) `mod` height)
      in (h * 0.7 + hBelow * 0.25) * 0.94

  in st
    { inkDensity  = advect (inkDensity st)
    , heatCurrent = coolHeat
    , velX        = newVx
    , velY        = newVy
    }

-- ASCII Rendering Pipeline
renderFrame :: FluidState -> String
renderFrame st = "\ESC[H" ++ unlines [ [ charFor x y | x <- [0..width-1] ] | y <- [0..height-1] ]
  where
    palette = " .':;ilwWMB@"
    numChars = length palette
    
    charFor x y =
      let ink  = getGrid (inkDensity st) x y
          heat = getGrid (heatCurrent st) x y
          val  = ink + heat * 0.5
          idx  = min (numChars - 1) (max 0 (floor (val * fromIntegral numChars / 20.0)))
      in palette !! idx

-- Executable Entry Point
main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStr "\ESC[2J" -- Clear screen
  commits <- fetchGitHistory
  let initialState = compileCommitHistory commits initFluid
  
  -- Animation Loop (120 frames)
  let loop state frame
        | frame > 120 = putStrLn "\n[Compilation complete: Git history fully dissolved into fluid dynamics.]"
        | otherwise   = do
            putStr (renderFrame state)
            threadDelay 50000 -- ~20 FPS
            loop (stepSimulation state) (frame + 1)
            
  loop initialState 0