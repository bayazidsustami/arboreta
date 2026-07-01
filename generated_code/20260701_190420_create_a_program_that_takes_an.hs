import System.IO (stdin, hGetContents)
import Data.Bits (xor)
import Data.Char (ord)
import Numeric (showHex)
import Text.Printf (printf)

-- Parameters
gridWidth, gridHeight :: Int
gridWidth  = 80
gridHeight = 30
frames :: Int
frames = 60
walkLength :: Int
walkLength = 200

-- Unicode block characters representing intensity / hue
blocks :: [String]
blocks = ["░","▒","▓","█"]

-- Simple deterministic LCG PRNG
nextRand :: Int -> Int
nextRand s = (1103515245 * s + 12345) `mod` 0x100000000

-- Hash input text to a seed
hashText :: String -> Int
hashText = foldl (\h c -> (h `xor` ord c) * 16777619) 0

-- Generate walk positions for a given frame
walkPositions :: Int -> [(Int,Int,Int)]  -- (x,y,step)
walkPositions seed = go seed (gridWidth `div` 2, gridHeight `div` 2) 0 []
  where
    go _ _ n acc | n >= walkLength = acc
    go s (x,y) n acc =
      let s' = nextRand s
          dir = s' `mod` 4
          (dx,dy) = case dir of
                      0 -> (1,0); 1 -> (-1,0); 2 -> (0,1); _ -> (0,-1)
          nx = (x + dx) `mod` gridWidth
          ny = (y + dy) `mod` gridHeight
      in go s' (nx,ny) (n+1) ((nx,ny,n):acc)

-- Build a grid of characters from walk data
buildGrid :: [(Int,Int,Int)] -> [[String]]
buildGrid ws = [[ charAt x y | x <- [0..gridWidth-1]] | y <- [0..gridHeight-1]]
  where
    -- map step number to hue index (0..3)
    stepToIdx n = (n * length blocks) `div` walkLength `mod` length blocks
    -- pick the darkest block visited most recently
    charAt x y = case lookup (x,y) latest of
                   Just idx -> blocks !! idx
                   Nothing  -> " "
    latest = [ ((x,y), stepToIdx n) | (x,y,n) <- reverse ws ]

-- Encode a single frame as SVG <text> element
frameToSVG :: Int -> [[String]] -> String
frameToSVG fid grid =
  let txt = concatMap (\row -> concat row ++ "<br/>") grid
  in printf "<g id='f%d' visibility='hidden'><text x='10' y='20' font-family='monospace' font-size='12'>%s</text></g>" fid txt

-- Build SMIL animation to cycle frames
animationSMIL :: Int -> String
animationSMIL n =
  let dur = fromIntegral n * 0.1 :: Double
  in printf "<animate attributeName='visibility' values='%s' keyTimes='%s' dur='%.1fs' repeatCount='indefinite'/>"
        (concatMap (\i -> if i==0 then "visible;hidden" else "hidden") [0..n-1])
        (concatMap (\i -> printf "%.3f;" (fromIntegral i / fromIntegral n)) [0..n])
        dur

main :: IO ()
main = do
  txt <- hGetContents stdin
  let seed = hashText txt
      frameSeeds = take frames $ iterate nextRand seed
      grids = map (buildGrid . walkPositions) frameSeeds
      svgFrames = zipWith frameToSVG [0..] grids
      smil = animationSMIL frames
      svgContent = unlines $
        [ "<?xml version='1.0' encoding='UTF-8'?>"
        , "<svg xmlns='http://www.w3.org/2000/svg' width='800' height='400'>"
        ] ++ svgFrames ++
        [ "<g>"
        , smil
        , "</g>"
        , "</svg>"
        ]
  putStrLn svgContent