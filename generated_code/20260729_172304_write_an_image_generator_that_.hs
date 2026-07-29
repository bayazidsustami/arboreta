-- Dynamic Stained Glass Window Generator
-- Translates real-time system call latencies into warped Voronoi stained glass.

import Control.Concurrent
import Control.Monad
import Data.ByteString (ByteString)
import qualified Data.ByteString as B
import qualified Data.ByteString.Char8 as BC
import Data.Word (Word8)
import System.CPUTime
import System.IO

-- Image dimensions
imgWidth, imgHeight :: Int
imgWidth = 600
imgHeight = 600

-- Seed sites for Voronoi glass cells
sites :: [(Double, Double)]
sites = [(fromIntegral (x * 110 + 55 + ((y `mod` 2) * 35)), fromIntegral (y * 110 + 55))
        | x <- [0..5], y <- [0..5]]

-- Stained glass palette (RGB normalized)
cellColors :: [(Double, Double, Double)]
cellColors =
  [ (0.85, 0.15, 0.20), (0.10, 0.45, 0.85), (0.95, 0.75, 0.10)
  , (0.20, 0.75, 0.35), (0.65, 0.20, 0.75), (0.95, 0.45, 0.15)
  , (0.15, 0.65, 0.65), (0.85, 0.25, 0.55)
  ]

-- Probe real-time kernel latency and thread scheduling jitter
probeSyscallLatencies :: IO (Double, Double)
probeSyscallLatencies = do
  mvar <- newEmptyMVar
  -- Fork competing threads to trigger real system call context switching
  forM_ [1..8] $ \_ -> forkIO $ do
    t1 <- getCPUTime
    threadDelay 200 -- Kernel sleep syscall
    t2 <- getCPUTime
    putMVar mvar (fromIntegral (t2 - t1) / 1e8)

  samples <- replicateM 8 (takeMVar mvar)
  let avgLatency = sum samples / fromIntegral (length samples)
  let contention = sqrt $ sum [ (s - avgLatency)**2 | s <- samples ] / fromIntegral (length samples)
  return (avgLatency, contention)

-- Compute pixel color based on perturbed Voronoi boundaries
renderPixel :: Double -> Double -> Int -> Int -> (Word8, Word8, Word8)
renderPixel avgLat contention x y =
  let px = fromIntegral x
      py = fromIntegral y

      -- Warping equations driven by latency and thread contention
      warpX = px + sin (py * 0.02 + avgLat) * (12.0 + contention * 8.0)
      warpY = py + cos (px * 0.02 + contention) * (12.0 + avgLat * 8.0)

      -- Distance calculations to locate Voronoi cells and lead borders
      dists = insertionSort [ (distSq (warpX, warpY) s, idx) | (idx, s) <- zip [0..] sites ]
      (d1, closestIdx) = head dists
      (d2, _)          = dists !! 1

      distDiff  = sqrt d2 - sqrt d1
      leadWidth = 2.5 + contention * 0.8

  in if distDiff < leadWidth
     then (25, 25, 30) -- Dark lead border
     else
       let (r, g, b) = cellColors !! (closestIdx `mod` length cellColors)
           -- Radial translucency effect
           shade = max 0.35 (1.0 - (sqrt d1 / 160.0))
           r' = floor (r * shade * 255)
           g' = floor (g * shade * 255)
           b' = floor (b * shade * 255)
       in (r', g', b')

distSq :: (Double, Double) -> (Double, Double) -> Double
distSq (x1, y1) (x2, y2) = (x1 - x2)**2 + (y1 - y2)**2

insertionSort :: Ord a => [a] -> [a]
insertionSort = foldr insert []
  where insert x [] = [x]
        insert x (y:ys) | x <= y    = x : y : ys
                        | otherwise = y : insert x ys

-- Render pixel matrix to binary PPM format
generatePPM :: Double -> Double -> ByteString
generatePPM avgLat contention =
  let header = BC.pack $ "P6\n" ++ show imgWidth ++ " " ++ show imgHeight ++ "\n255\n"
      pixels = B.pack [ c | y <- [0..imgHeight-1]
                          , x <- [0..imgWidth-1]
                          , let (r, g, b) = renderPixel avgLat contention x y
                          , c <- [r, g, b] ]
  in B.append header pixels

main :: IO ()
main = do
  putStrLn "Probing syscall latency & thread contention..."
  (avgLat, contention) <- probeSyscallLatencies
  putStrLn $ "Avg Latency Factor: " ++ show avgLat
  putStrLn $ "Contention Variance: " ++ show contention
  putStrLn "Generating stained_glass.ppm..."
  B.writeFile "stained_glass.ppm" (generatePPM avgLat contention)
  putStrLn "Done! Output saved to stained_glass.ppm"