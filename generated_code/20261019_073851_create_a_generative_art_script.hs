-- Weather-seeded 2D Labyrinth Cellular Automata Generative Art in Haskell
-- This script simulates local weather conditions (via time/arguments seed) 
-- to initialize and evolve a 2D cellular automaton, generating an intricate,
-- shifting labyrinth rendered as a scalable vector graphic (SVG) with rich gradients.

import System.Environment
import Data.Time.Clock
import Text.Printf

-- Pseudo-random number generator (Linear Congruential Generator) to keep the script self-contained
type Seed = Int

nextSeed :: Seed -> Seed
nextSeed s = (s * 1103515245 + 12345) `mod` 2147483647

randomInt :: Seed -> Int -> (Int, Seed)
randomInt s n = let s' = nextSeed s in (s' `mod` n, s')

-- Grid dimensions
width :: Int
width, height :: Int
width = 80
height = 80

type Grid = [[Int]]

-- Labyrinth CA transition rule (Maze variant: born on 3, survive on 1-5, aging states)
stepCell :: Int -> Int -> Int
stepCell state neighbors
  | state > 0 = if neighbors >= 1 && neighbors <= 5 then min 10 (state + 1) else 0
  | otherwise = if neighbors == 3 then 1 else 0

-- Count live Moore neighborhood cells with periodic boundary conditions
countNeighbors :: Grid -> Int -> Int -> Int
countNeighbors grid r c = sum [val (r + dr) (c + dc) | dr <- [-1..1], dc <- [-1..1], (dr, dc) /= (0, 0)]
  where
    val dr dc = 
      let nr = (r + dr + height) `mod` height
          nc = (c + dc + width) `mod` width
      in if (grid !! nr) !! nc > 0 then 1 else 0

-- Advance the grid by one generation
stepGrid :: Grid -> Grid
stepGrid grid = 
  [ [ stepCell ((grid !! r) !! c) (countNeighbors grid r c) | c <- [0..width-1] ] | r <- [0..height-1] ]

-- Initialize grid pseudo-randomly using the weather/time seed
initialGrid :: Seed -> Grid
initialGrid s = 
  let (_, s1) = randomInt s 100
      buildRow 0 _ rowSeed acc = (reverse acc, rowSeed)
      buildRow c r rowSeed acc = 
        let (cell, ns) = randomInt rowSeed 100
            state = if cell < 35 then 1 else 0
        in buildRow (c - 1) r ns (state : acc)
      
      buildGrid 0 _ gridSeed accGrid = (reverse accGrid, gridSeed)
      buildGrid r h gridSeed accGrid = 
        let (row, ns) = buildRow width r gridSeed []
        in buildGrid (r - 1) h ns (row : accGrid)
  in fst (buildGrid height height s1 [])

-- Run cellular automaton for specified number of steps
runCA :: Int -> Grid -> Grid
runCA 0 g = g
runCA n g = runCA (n - 1) (stepGrid g)

-- Map cell state and age to vibrant color gradients inspired by atmospheric shifts
colorForState :: Int -> String
colorForState 0 = "#090d16" -- Deep midnight atmospheric background
colorForState s = 
  let t = fromIntegral s / 10.0 :: Double
      r = round (20 + t * 220)
      g = round (100 + t * 100)
      b = round (240 - t * 140)
  in printf "rgb(%d,%d,%d)" r g b

-- Render grid to SVG string format
toSVG :: Grid -> String
toSVG grid = 
  let cellSize = 10
      svgW = width * cellSize
      svgH = height * cellSize
      rects = concat [ 
        [ printf "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"%s\" />" 
            (c * cellSize) (r * cellSize) cellSize cellSize (colorForState ((grid !! r) !! c))
        | c <- [0..width-1] ]
        | r <- [0..height-1] ]
  in unlines $ 
     [ printf "<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" viewBox=\"0 0 %d %d\" width=\"100%%\" height=\"100%%\" style=\"background:#090d16;\">" svgW svgH
     , "<defs><style>rect { shape-rendering: crispEdges; }</style></defs>"
     ] ++ rects ++ ["</svg>"]

main :: IO ()
main = do
  args <- getArgs
  -- Derive weather seed from command line argument or current system time
  seed <- case args of
    (s:_) -> return (read s :: Int)
    _     -> do
      now <- getCurrentTime
      return (fromIntegral (utctDayTime now `div` 10) + 1337)
  
  let startGrid = initialGrid seed
      finalGrid = runCA 30 startGrid
      svgContent = toSVG finalGrid
  
  writeFile "weather_labyrinth.svg" svgContent
  putStrLn "Generative art labyrinth successfully created and saved to weather_labyrinth.svg!"