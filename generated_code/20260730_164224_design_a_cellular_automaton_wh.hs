-- Syllable & Rhyme Poetry Cellular Automaton Tapestry
-- Parses streaming poetic text to drive a 2D CA grid rendering emotional cadence as ASCII art.

import Data.Char (toLower, isAlpha)
import Data.List (group)
import Control.Concurrent (threadDelay)
import System.IO (hFlush, stdout)

-- Grid dimensions
width, height :: Int
width = 60
height = 20

-- Represent CA state as 2D grid of Ints
type Grid = [[Int]]

-- Heuristic syllable count for a word based on vowel cluster groups
countSyllables :: String -> Int
countSyllables word =
  let w = filter isAlpha (map toLower word)
      vowels = "aeiouy"
      isVowel c = c `elem` vowels
      vowelGroups = filter (\g -> isVowel (head g)) (group (map isVowel w))
      rawCount = length vowelGroups
  in if null w then 0 else max 1 rawCount

-- Metrics derived from parsed poetry line
data LineMetrics = LineMetrics
  { totalSyllables :: Int
  , rhymeKey       :: String
  , cadenceScore   :: Int
  } deriving Show

analyzeLine :: String -> LineMetrics
analyzeLine line =
  let wordsList = words line
      sylls = sum $ map countSyllables wordsList
      lastWord = if null wordsList then "" else filter isAlpha (map toLower (last wordsList))
      rKey = reverse (take 3 (reverse lastWord))
      cadence = (sylls * 7 + length rKey * 13) `mod` 8
  in LineMetrics sylls rKey cadence

-- CA transition rule combining 8-neighbor sum with poetic state parameters
stepCell :: LineMetrics -> Grid -> Int -> Int -> Int
stepCell metrics grid x y =
  let neighbors = [ grid !! ((y + dy) `mod` height) !! ((x + dx) `mod` width)
                  | dx <- [-1, 0, 1], dy <- [-1, 0, 1], (dx, dy) /= (0, 0) ]
      sumN = sum neighbors
      current = grid !! y !! x
      syll = totalSyllables metrics
      cad = cadenceScore metrics
      nextVal = case (sumN + syll) `mod` 5 of
        0 -> (current + cad) `mod` 6
        1 -> (current + 1) `mod` 6
        2 -> if sumN > 12 then (current + 2) `mod` 6 else max 0 (current - 1)
        3 -> (sumN + syll + cad) `mod` 6
        _ -> (current + 3) `mod` 6
  in nextVal

-- Evolve entire grid according to line metrics
stepGrid :: LineMetrics -> Grid -> Grid
stepGrid metrics grid =
  [ [ stepCell metrics grid x y | x <- [0 .. width - 1] ]
  | y <- [0 .. height - 1]
  ]

-- Visual palette mapping cell state (0..5) to ASCII tapestry symbols
renderCell :: Int -> Char
renderCell val = case val `mod` 6 of
  0 -> ' '
  1 -> '.'
  2 -> ':'
  3 -> '*'
  4 -> '#'
  _ -> '@'

-- Render grid to screen as formatted ASCII string
renderGrid :: Grid -> String
renderGrid g = unlines $ map (map renderCell) g

-- Deterministic initial pattern generator
initialGrid :: Grid
initialGrid =
  [ [ (x * y + x) `mod` 6 | x <- [0 .. width - 1] ]
  | y <- [0 .. height - 1]
  ]

-- Simulated stream of poetic verses
poetryFeed :: [String]
poetryFeed = cycle
  [ "Two roads diverged in a yellow wood,"
  , "And sorry I could not travel both"
  , "And be one traveler, long I stood"
  , "And looked down one as far as I could"
  , "To where it bent in the undergrowth;"
  , ""
  , "Tyger Tyger, burning bright,"
  , "In the forests of the night;"
  , "What immortal hand or eye,"
  , "Could frame thy fearful symmetry?"
  , ""
  , "Do not go gentle into that good night,"
  , "Rage, rage against the dying of the light."
  , "Wild men who caught and sang the sun in flight,"
  , "And learn, too late, they grieved it on its way."
  ]

-- Terminal display helper
clearScreen :: IO ()
clearScreen = putStr "\ESC[2J\ESC[1;1H"

-- Main evaluation loop
loop :: Grid -> [String] -> IO ()
loop _ [] = return ()
loop grid (line:linesRest) = do
  clearScreen
  let metrics = analyzeLine line
  let newGrid = stepGrid metrics grid
  putStrLn "=== POETIC CELLULAR AUTOMATON TAPESTRY ==="
  putStrLn $ renderGrid newGrid
  putStrLn $ "Line    : " ++ line
  putStrLn $ "Metrics : Syllables=" ++ show (totalSyllables metrics)
          ++ " | RhymeKey='" ++ rhymeKey metrics ++ "'"
          ++ " | Cadence=" ++ show (cadenceScore metrics)
  hFlush stdout
  threadDelay 400000
  loop newGrid linesRest

main :: IO ()
main = loop initialGrid poetryFeed