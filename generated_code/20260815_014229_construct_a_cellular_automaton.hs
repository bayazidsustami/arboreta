import Data.Bits (shiftR, testBit, xor, (.&.), (.|.))
import Data.Char (ord)
import Numeric (showHex)
import System.Random (mkStdGen, randomRs)

-- 1. Source Code & Compression (Run-Length Encoding for Self-Trace)
sourceCode :: String
sourceCode = "module Main where import Data.Bits; import Data.Char; main = putStrLn \"Cosmic Automaton\""

rleCompress :: String -> [(Char, Int)]
rleCompress [] = []
rleCompress (x:xs) = go x 1 xs
  where
    go c n [] = [(c, n)]
    go c n (y:ys)
      | c == y    = go c (n + 1) ys
      | otherwise = (c, n) : go y 1 ys

-- Bitwise Trace Generator: Transforms compressed source into a stream of state integers
traceStream :: String -> [Int]
traceStream src = zipWith deriveState [0..] (rleCompress src)
  where
    deriveState idx (ch, count) =
      let b = ord ch
          raw = (b `xor` (count * 31)) `xor` (idx * 17)
      in (raw `shiftR` 1) .|. ((raw .&. 1) `shiftR` 0)

-- 2. Grid & Constellation Automaton Setup
width, height, generations :: Int
width = 79
height = 24
generations = 8

type Grid = [[Char]]

emptyGrid :: Grid
emptyGrid = replicate height (replicate width ' ')

setChar :: Grid -> Int -> Int -> Char -> Grid
setChar g x y c
  | x < 0 || x >= width || y < 0 || y >= height = g
  | otherwise =
      let (top, row:bottom) = splitAt y g
          (left, _:right)   = splitAt x row
      in top ++ (left ++ c : right) ++ bottom

-- Brightness mapping based on trace energy bits
renderBrightness :: Int -> Char
renderBrightness val =
  let glyphs = " .':-*+=%@#"
      idx = val `mod` length glyphs
  in glyphs !! idx

-- 3. Celestial Tree Growth Dynamics
-- Grows constellation paths outward using bitwise directional choices derived from source trace
growConstellation :: Grid -> [Int] -> Int -> Int -> Int -> Grid
growConstellation grid [] _ _ _ = grid
growConstellation grid (t:ts) depth x y
  | depth <= 0 = grid
  | otherwise =
      let starChar = renderBrightness t
          grid'    = setChar grid x y starChar
          -- Determine branching vectors using bitwise flags in the trace state
          dx1 = if testBit t 0 then 1 else -1
          dy1 = if testBit t 1 then 1 else if testBit t 2 then -1 else 0
          dx2 = if testBit t 3 then 2 else -2
          dy2 = if testBit t 4 then 1 else -1
          
          -- Primary branch growth
          g1 = growConstellation grid' ts (depth - 1) (x + dx1) (y + dy1)
      in if testBit t 5
            -- Secondary cosmic branch split
            then growConstellation g1 ts (depth - 2) (x + dx2) (y + dy2)
            else g1

-- 4. Main Execution Pipeline
main :: IO ()
main = do
  let trace = traceStream sourceCode
      -- Seed star seeds across the cosmos using initial trace values
      seeds = zipWith (\i t -> ( (t * 13 + i * 7) `mod` width
                               , (t * 17 + i * 3) `mod` height
                               )) [0..5] trace
      
      -- Evolve cosmic canvas through automaton tree growth
      finalGrid = foldl (\g (i, (sx, sy)) -> 
                    growConstellation g (drop (i * 4) trace) generations sx sy
                  ) emptyGrid (zip [0..] seeds)

  -- Render the rendered ASCII Star Chart
  putStrLn "+" ++ replicate width '-' ++ "+"
  mapM_ (\row -> putStrLn $ "|" ++ row ++ "|") finalGrid
  putStrLn "+" ++ replicate width '-' ++ "+"