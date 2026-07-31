{-# LANGUAGE MagicHash #-}
-- Self-Referential AST Manifold Raymarcher
-- Compiles and runs with: ghc -O2 Main.hs +RTS -T -rtsopts && ./Main

import GHC.Stats
import System.IO
import Control.Concurrent (threadDelay)
import Data.Char (ord)

-- Binary AST proxy generated from self-source character vector
selfAST :: String
selfAST = "module Main where import GHC.Stats import System.IO..."

-- Topology manifold SDF: maps AST topology and real-time host memory allocation into 3D metric space
manifoldSDF :: Double -> (Double, Double, Double) -> Double
manifoldSDF mem (x, y, z) =
  let astTopology = sum [fromIntegral (ord c) | c <- take 64 selfAST] * 1e-4
      deformation = sin (mem * 1e-6 + x * 3.0) * 0.35
      sphere      = sqrt (x*x + y*y + z*z) - (1.1 + deformation)
      octahedron  = (abs x + abs y + abs z) - (1.3 + astTopology)
  in max sphere octahedron

-- Raymarching engine stepping through ray vector
march :: Double -> (Double, Double, Double) -> Double -> Double
march mem (dx, dy, dz) t
  | t > 5.0   = 5.0
  | d < 0.008 = t
  | otherwise = march mem (dx, dy, dz) (t + max d 0.015)
  where
    (px, py, pz) = (dx * t, dy * t, dz * t - 2.3)
    d = manifoldSDF mem (px, py, pz)

-- Render manifold as frame buffer to ANSI terminal output
renderFrame :: Double -> String
renderFrame mem = unlines
  [ [ charAt (march mem (x * 1.6, y, 1.0) 0.0)
    | x <- [-0.85, -0.81 .. 0.85] ]
  | y <- [-0.5, -0.45 .. 0.5] ]
  where
    shades = " .:-=+*#%@"
    charAt dist
      | dist >= 5.0 = ' '
      | otherwise   = shades !! (floor (dist * 2.0) `mod` length shades)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStr "\ESC[2J" -- Clear terminal display
  let loop = do
        stats <- getRTSStats
        let allocBytes = fromIntegral (allocated_bytes stats)
        putStr "\ESC[H" -- Reset cursor
        putStrLn $ "--- Host RTS Allocated Memory: " ++ show allocBytes ++ " bytes ---"
        putStrLn (renderFrame allocBytes)
        threadDelay 33000 -- ~30 FPS frame lock
        loop
  loop