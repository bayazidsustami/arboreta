-- Self-Modifying Musical Cellular Automaton & ASCII Quilt
-- Each live cell plays a pitch mapped to its 8-neighbor density.
-- When overall soundscape harmony falls below a threshold, the script
-- rewrites its own source code on disk to adapt survival/birth rules.

module Main where

import Control.Concurrent (threadDelay)
import Control.Exception (catch, SomeException)
import Control.Monad (when, forM_)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.List (intercalate, group, sort, isPrefixOf)
import System.CPUTime (getCPUTime)
import System.Environment (getProgName)
import System.IO (hFlush, stdout, readFile, writeFile)

--------------------------------------------------------------------------------
-- 1. MUTABLE RULE DEFINITIONS (Targeted for self-rewriting)
--------------------------------------------------------------------------------

-- REWRITE_TARGET_START
birthRules :: [Int]
birthRules = [3]

surviveRules :: [Int]
surviveRules = [2, 3]

harmonyThreshold :: Double
harmonyThreshold = 0.60
-- REWRITE_TARGET_END

--------------------------------------------------------------------------------
-- 2. GRID & SOUND MAPPINGS
--------------------------------------------------------------------------------

width, height :: Int
width = 32
height = 16

type Grid = [[Bool]]

-- Pitch mapping: Neighbor count (0-8) -> (Glyph, Pitch Name, Frequency Hz)
pitchMap :: Int -> (Char, String, Int)
pitchMap n = case n `mod` 9 of
  0 -> ('·', "C4", 261)
  1 -> ('░', "D4", 293)
  2 -> ('▒', "E4", 329)
  3 -> ('▓', "G4", 392)
  4 -> ('█', "A4", 440)
  5 -> ('♪', "C5", 523)
  6 -> ('♫', "D5", 587)
  7 -> ('♬', "E5", 659)
  _ -> ('☸', "G5", 783)

--------------------------------------------------------------------------------
-- 3. CELLULAR AUTOMATON ENGINE & HARMONY ANALYSIS
--------------------------------------------------------------------------------

-- Toroidal neighbor count
neighbors :: Grid -> Int -> Int -> Int
neighbors g x y = length
  [ () | dx <- [-1..1], dy <- [-1..1]
       , (dx, dy) /= (0,0)
       , let nx = (x + dx) `mod` width
       , let ny = (y + dy) `mod` height
       , g !! ny !! nx ]

-- Evolve automaton by 1 generation
stepGrid :: Grid -> Grid
stepGrid g =
  [[ nextCell (g !! y !! x) (neighbors g x y) | x <- [0..width-1] ] | y <- [0..height-1] ]
  where
    nextCell True  n = n `elem` surviveRules
    nextCell False n = n `elem` birthRules

-- Measure soundscape harmony: proportion of consonant densities (2, 3, 4, 5)
calcHarmony :: Grid -> Double
calcHarmony g =
  let activeDensities = [ neighbors g x y | y <- [0..height-1], x <- [0..width-1], g !! y !! x ]
      total = fromIntegral (length activeDensities)
      consonant = fromIntegral . length . filter (`elem` [2, 3, 4, 5]) $ activeDensities
  in if total == 0 then 1.0 else consonant / total

--------------------------------------------------------------------------------
-- 4. VISUAL ASCII QUILT & AUDIO SYNTHESIS DISPLAY
--------------------------------------------------------------------------------

-- Render grid as a vibrant, colored ASCII patch quilt
renderQuilt :: Grid -> String
renderQuilt g = unlines
  [ concat [ renderCell x y (g !! y !! x) | x <- [0..width-1] ] | y <- [0..height-1] ]
  where
    renderCell x y alive
      | not alive = "\ESC[90m . \ESC[0m"
      | otherwise =
          let n = neighbors g x y
              (sym, note, _) = pitchMap n
              color = 31 + (n `mod` 6) -- ANSI foreground colors 31-36
          in "\ESC[1;" ++ show color ++ "m" ++ [sym] ++ note ++ "\ESC[0m"

-- Summarize current soundscape audio frequencies
renderSoundscape :: Grid -> String
renderSoundscape g =
  let notes = [ note ++ "(" ++ show hz ++ "Hz)"
              | y <- [0..height-1], x <- [0..width-1]
              , g !! y !! x
              , let (_, note, hz) = pitchMap (neighbors g x y) ]
      grouped = map (\grp -> (head grp, length grp)) . group . sort $ notes
      formatted = intercalate "  " [ n ++ "x" ++ show c | (n, c) <- grouped ]
  in if null formatted then "Silence..." else formatted

--------------------------------------------------------------------------------
-- 5. SELF-MODIFYING SOURCE CODE ENGINE
--------------------------------------------------------------------------------

-- Reads own script file, mutates rules to restore harmony, and overwrites source
rewriteSelf :: IO ()
rewriteSelf = do
  prog <- getProgName
  catch (do
    src <- readFile prog
    -- Generate mutated rule sets
    rng <- newIORef =<< getCPUTime
    bChoice <- randomRange rng 1 4
    sChoice1 <- randomRange rng 2 4
    sChoice2 <- randomRange rng 3 5

    let newBirth   = "birthRules = [" ++ show bChoice ++ "]"
        newSurvive = "surviveRules = [" ++ show sChoice1 ++ ", " ++ show sChoice2 ++ "]"
        mutated = replaceLine "birthRules =" newBirth
                . replaceLine "surviveRules =" newSurvive $ src

    -- Write updated code back to source file
    seq (length mutated) (writeFile prog mutated)
    putStrLn "\ESC[1;33m>>> DISHARMONY DETECTED: Self-rewriting source code on disk! <<<\ESC[0m"
    ) (\(_ :: SomeException) -> putStrLn "\ESC[33m(Source code mutation skipped: read-only environment)\ESC[0m")

replaceLine :: String -> String -> String -> String
replaceLine prefix newLine text = unlines $ map update (lines text)
  where
    update l | prefix `isPrefixOf` l = newLine
             | otherwise             = l

--------------------------------------------------------------------------------
-- 6. PSEUDO-RANDOM GENERATOR & INITIALIZATION
--------------------------------------------------------------------------------

randomRange :: IORef Integer -> Int -> Int -> IO Int
randomRange ref low high = do
  seed <- readIORef ref
  let next = (1103515245 * seed + 12345) `mod` 2147483648
  writeIORef ref next
  return $ low + fromIntegral (next `mod` fromIntegral (high - low + 1))

initGrid :: IO Grid
initGrid = do
  ref <- newIORef =<< getCPUTime
  sequence [ sequence [ (== 1) <$> randomRange ref 0 2 | _ <- [0..width-1] ] | _ <- [0..height-1] ]

--------------------------------------------------------------------------------
-- 7. MAIN EXECUTION LOOP
--------------------------------------------------------------------------------

main :: IO ()
main = do
  putStr "\ESC[2J" -- Clear terminal screen
  grid <- initGrid
  loop grid 0

loop :: Grid -> Int -> IO ()
loop g gen = do
  putStr "\ESC[H" -- Move cursor home
  putStrLn "\ESC[1;36m=== SELF-MODIFYING CELLULAR AUTOMATON SOUNDSCAPE QUILT ===\ESC[0m"
  putStrLn $ "Generation: " ++ show gen ++ " | Active Rules: Birth=" ++ show birthRules ++ " Survive=" ++ show surviveRules
  putStrLn "--------------------------------------------------------------------------------"
  
  -- Display ASCII visual quilt
  putStr (renderQuilt g)
  putStrLn "--------------------------------------------------------------------------------"
  
  -- Audio & Soundscape readout
  let harm = calcHarmony g
  putStrLn $ "Soundscape: " ++ renderSoundscape g
  putStrLn $ "Harmony Rating: " ++ show (fromIntegral (round (harm * 100) :: Int) / 100)
          ++ " / " ++ show harmonyThreshold

  -- Play terminal audio chime for soundscape pulse
  when (any or g) $ putStr "\a"
  hFlush stdout

  -- Trigger self-modification when disharmony persists
  when (harm < harmonyThreshold && gen > 3) rewriteSelf

  threadDelay 300000 -- 300ms frame tick
  loop (stepGrid g) (gen + 1)