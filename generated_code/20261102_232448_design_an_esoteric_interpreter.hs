module Main where

import Data.List (foldl')
import qualified Data.Map as M

-- Represents a simplified git commit with metrics driving our esoteric machine
data Commit = Commit {
    commitHash :: String,
    additions  :: Int,
    deletions  :: Int,
    msgLength  :: Int
} deriving (Show, Eq)

-- A single cell representing a patch in the digital moss garden
data Moss = Moss {
    moisture     :: Double,
    sporeDensity :: Double,
    age          :: Int
} deriving (Show, Eq)

type Point = (Int, Int)
type Garden = M.Map Point Moss

-- The primordial moss spore at the origin
initialGarden :: Garden
initialGarden = M.singleton (0, 0) (Moss 1.0 1.0 0)

-- Interprets a git commit as environmental factors shifting the moss garden
stepGarden :: Garden -> Commit -> Garden
stepGarden g (Commit _ adds dels mlen) = 
    let moistureBoost = fromIntegral mlen / 20.0
        -- Evolve existing moss patches: increase age and adjust moisture based on commit message length
        aged = M.map (\cell -> cell { moisture = min 5.0 (moisture cell + moistureBoost), age = age cell + 1 }) g
        -- High addition counts cause the moss to spread to adjacent coordinates
        spreadCoords = if adds > dels then [(x + dx, y + dy) | (x, y) <- M.keys g, (dx, dy) <- [(1,0), (0,1), (-1,0), (0,-1)]] else []
        -- Integrate new growth patches into the garden grid
        grown = foldl' (\acc p -> M.insertWith (\new old -> old { sporeDensity = sporeDensity old + 0.3 }) p (Moss 0.8 0.4 0) acc) aged spreadCoords
    in grown

-- Renders the digital moss garden into ASCII art based on moss vitality (moisture * sporeDensity)
renderGarden :: Garden -> String
renderGarden g = 
    let xs = map fst (M.keys g)
        ys = map snd (M.keys g)
        minX = if null xs then 0 else minimum xs
        maxX = if null xs then 0 else maximum xs
        minY = if null ys then 0 else minimum ys
        maxY = if null ys then 0 else maximum ys
        
        cellChar m = 
            let vitality = moisture m * sporeDensity m
            in if vitality > 4.0 then '#' 
               else if vitality > 2.0 then '*' 
               else if vitality > 0.5 then '.' 
               else ' '
               
        row y = [maybe ' ' cellChar (M.lookup (x, y) g) | x <- [minX..maxX]]
    in unlines [row y | y <- [minY..maxY]]

-- A sample git history stream acting as the program source code
sampleCommits :: [Commit]
sampleCommits = [
    Commit "a1b2c3d" 15 2  12,
    Commit "e4f5g6h" 40 5  28,
    Commit "i7j8k9l" 3  18 10,
    Commit "m0n1o2p" 25 4  20,
    Commit "q3r4s5t" 55 12 45
  ]

main :: IO ()
main = do
    putStrLn "=== Digital Moss Garden Git Interpreter ==="
    let finalGarden = foldl' stepGarden initialGarden sampleCommits
    putStrLn (renderGarden finalGarden)