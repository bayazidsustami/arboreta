module Main where

import Control.Concurrent (threadDelay)
import Data.List (intercalate)

-- Musical notes mapped to decay states representing a gentle lullaby
notes :: [Char]
notes = "C D E G A c d e g a ~ . "

-- Cellular states: Alive, Decaying with a fading note intensity, or Dormant
type Grid = [Cell]
data Cell = Alive | Decaying Int | Dormant deriving (Show, Eq)

-- Initial peaceful configuration simulating cache warm states
initialGrid :: Grid
initialGrid = [Dormant, Dormant, Alive, Alive, Dormant, Dormant, Alive, Dormant, Dormant, Dormant]

-- Evolve the automaton: life decays into drifting musical notes, calming the cache
stepGrid :: Grid -> Grid
stepGrid g = zipWith evolve g (neighborhoods g)
  where
    evolve c neighbors
      | c == Alive = if length (filter (== Alive) neighbors) `elem` [1, 2] then Alive else Decaying 4
      | c == Decaying n = if n > 1 then Decaying (n - 1) else Dormant
      | otherwise = if length (filter (== Alive) neighbors) == 2 then Alive else Dormant

-- Compute circular 1D neighborhoods for smooth transitions
neighborhoods :: [a] -> [[a]]
neighborhoods xs = zipWith3 (\a b c -> [a, b, c]) (last xs : init xs) xs (tail xs ++ [head xs])

-- Render each cell into visual characters and drifting musical frequencies
renderCell :: Cell -> Char
renderCell Alive = '#'
renderCell (Decaying n) = notes !! (n * 2)
renderCell Dormant = '.'

-- Main entry point running the rhythmic cache lullaby simulation
main :: IO ()
main = do
  putStrLn "Initiating CPU Cache Lullaby..."
  let loop g 0 = putStrLn "Cache settled into deep, harmonious sleep."
      loop g n = do
        putStrLn $ map renderCell g
        threadDelay 250000
        loop (stepGrid g) (n - 1)
  loop initialGrid 16