-- |
-- Custom Watercolor Memory Allocator Visualizer in Haskell
-- 
-- Memory Model & Visualization Mechanics:
-- 1. Allocations generate dynamic, spreading watercolor blooms (cyan/magenta/blue).
-- 2. Leaks deposit hydrophobic, high-viscosity oil stains (amber/burnt orange) that resist washing.
-- 3. Memory fragmentation computes fractal Julia-set perturbations across the address space.
-- 4. Garbage Collection triggers a torrential atmospheric rainstorm, washing away unreferenced ink.

import System.IO
import Control.Concurrent (threadDelay)
import Control.Monad (forM_, when, replicateM_)
import Data.IORef
import Data.List (foldl')
import Data.Bits (xor, shiftL, shiftR)

-- ============================================================================
-- 1. Deterministic Pure PRNG (Self-contained, no external package dependencies)
-- ============================================================================

type Seed = Int

nextRandom :: Seed -> (Int, Seed)
nextRandom s = 
  let s' = (s * 1103515245 + 12345) `mod` 2147483647
  in (s', s')

randomFloat :: Seed -> (Float, Seed)
randomFloat s = 
  let (r, s') = nextRandom s
  in (fromIntegral r / 2147483647.0, s')

-- ============================================================================
-- 2. Memory Allocator & State Architecture
-- ============================================================================

data BlockStatus = Free | Allocated Int | Leaked Int
  deriving (Eq, Show)

data MemoryEngine = MemoryEngine
  { ramBlocks  :: [BlockStatus]  -- Linear memory representation
  , totalSize  :: Int            -- Total heap capacity
  , leakPointers :: [Int]        -- Active persistent oil stain addresses
  , stepCounter :: Int           -- Allocation age tracker
  }

initEngine :: Int -> MemoryEngine
initEngine size = MemoryEngine (replicate size Free) size [] 0

-- Custom allocation scheme
allocMem :: MemoryEngine -> Int -> (MemoryEngine, Maybe Int)
allocMem engine reqSize =
  case findFreeSlot (ramBlocks engine) reqSize 0 of
    Just idx ->
      let newBlocks = take idx (ramBlocks engine) 
                   ++ replicate reqSize (Allocated (stepCounter engine))
                   ++ drop (idx + reqSize) (ramBlocks engine)
          eng' = engine { ramBlocks = newBlocks, stepCounter = stepCounter engine + 1 }
      in (eng', Just idx)
    Nothing -> (engine, Nothing)
  where
    findFreeSlot [] _ _ = Nothing
    findFreeSlot xs len currIdx
      | length (take len xs) == len && all (== Free) (take len xs) = Just currIdx
      | otherwise = findFreeSlot (tail xs) len (currIdx + 1)

-- Force a memory leak (Creates an oil stain)
leakMem :: MemoryEngine -> Int -> MemoryEngine
leakMem engine idx =
  case ramBlocks engine !! idx of
    Allocated tag ->
      let newBlocks = take idx (ramBlocks engine) ++ [Leaked tag] ++ drop (idx + 1) (ramBlocks engine)
      in engine { ramBlocks = newBlocks, leakPointers = idx : leakPointers engine }
    _ -> engine

-- Garbage Collector: Torrential rainstorm clear mechanism
runGC :: MemoryEngine -> (MemoryEngine, Int)
runGC engine =
  let (cleanedBlocks, freedCount) = foldr clean ([], 0) (ramBlocks engine)
  in (engine { ramBlocks = cleanedBlocks }, freedCount)
  where
    clean (Allocated _) (acc, c) = (Free : acc, c + 1)
    clean st (acc, c)            = (st : acc, c)

-- Calculate fragmentation factor (gaps / total allocated)
calcFragmentation :: MemoryEngine -> Float
calcFragmentation engine =
  let blks = ramBlocks engine
      gaps = length $ filter (\(a,b) -> a /= Free && b == Free) (zip blks (tail blks))
      totalAlloc = length $ filter (/= Free) blks
  in if totalAlloc == 0 then 0.0 else fromIntegral gaps / fromIntegral (totalSize engine)

-- ============================================================================
-- 3. Watercolor & Fractal Rendering Canvas
-- ============================================================================

width, height :: Int
width = 60
height = 22

type RGB = (Float, Float, Float)

-- Fractal generator driven by fragmentation index
fractalPattern :: Int -> Int -> Float -> Float
fractalPattern x y frag =
  let cx = (fromIntegral x / fromIntegral width - 0.5) * (1.5 + frag * 2.0)
      cy = (fromIntegral y / fromIntegral height - 0.5) * (1.5 + frag * 2.0)
      julia zN n
        | n >= 10 || magnitudeSq zN > 4.0 = fromIntegral n / 10.0
        | otherwise = julia (squareComplex zN `addComplex` (-0.7, 0.27015 + frag * 0.1)) (n + 1)
      squareComplex (r, i) = (r*r - i*i, 2*r*i)
      addComplex (r1, i1) (r2, i2) = (r1+r2, i1+i2)
      magnitudeSq (r, i) = r*r + i*i
  in julia (cx, cy) 0

-- Renders memory status into dynamic watercolor palette
renderCanvas :: MemoryEngine -> Seed -> Bool -> String
renderCanvas engine seed isRaining =
  let frag = calcFragmentation engine
      grid = [ [ computePixel x y engine frag seed isRaining | x <- [0..width-1] ] | y <- [0..height-1] ]
  in "\ESC[H" ++ unlines (map (concatMap ansiRGB) grid) ++ "\ESC[0m"

computePixel :: Int -> Int -> MemoryEngine -> Float -> Seed -> Bool -> RGB
computePixel x y engine frag seed isRaining =
  let idx = (y * width + x) `mod` totalSize engine
      st = ramBlocks engine !! idx
      fVal = fractalPattern x y frag
      (noise, _) = randomFloat (seed + x * 31 + y * 97)
      
      -- Base colors for watercolor bloom
      baseRGB = case st of
        Free         -> (0.05, 0.08 + fVal * 0.15, 0.12 + fVal * 0.2) -- Deep watercolor paper background
        Allocated t  -> 
          let hue = fromIntegral (t * 37 `mod` 255) / 255.0
          in (0.2 + 0.6 * hue, 0.4 + 0.4 * (1.0 - hue), 0.8)         -- Blooming soft ink
        Leaked _     -> (0.85, 0.55, 0.1)                          -- Viscous persistent oil stain

      -- Apply rainstorm overlay if GC active
      rainOverlay (r, g, b) =
        if isRaining && noise > 0.6
        then (min 1.0 (r + 0.3), min 1.0 (g + 0.5), min 1.0 (b + 0.6))
        else (r, g, b)

  in rainOverlay baseRGB

-- Convert 0..1 RGB floats to ANSI 24-bit background color block
ansiRGB :: RGB -> String
ansiRGB (r, g, b) =
  let r' = floor (max 0.0 (min 1.0 r) * 255) :: Int
      g' = floor (max 0.0 (min 1.0 g) * 255) :: Int
      b' = floor (max 0.0 (min 1.0 b) * 255) :: Int
  in "\ESC[48;2;" ++ show r' ++ ";" ++ show g' ++ ";" ++ show b' ++ "m "

-- ============================================================================
-- 4. Main Event Loop & Interactive Simulation
-- ============================================================================

main :: IO ()
main = do
  hSetEncoding stdout utf8
  hSetBuffering stdout NoBuffering
  putStr "\ESC[2J\ESC[?25l" -- Clear screen and hide cursor

  let engine = initEngine (width * height)
  stateRef <- newIORef (engine, 42)

  -- Run visualization loop
  simulationLoop stateRef 0

simulationLoop :: IORef (MemoryEngine, Seed) -> Int -> IO ()
simulationLoop stateRef step = do
  (eng, s) <- readIORef stateRef
  let (rVal, s') = randomFloat s
  
  -- Dynamic Memory Lifecycle Actions
  let (eng1, isRaining) = case step `mod` 120 of
        -- Trigger GC (Torrential Rainstorm) every 120 ticks
        110 -> 
          let (cleaned, _) = runGC eng
          in (cleaned, True)
        _   -> 
          if rVal < 0.65
          then 
            -- Allocate blooming memory chunks
            let allocSize = floor (rVal * 15) + 1
                (e', _) = allocMem eng allocSize
            in (e', False)
          else if rVal < 0.85 && not (null $ ramBlocks eng)
          then
            -- Create persistent oil stain (leak)
            let leakTarget = floor (rVal * fromIntegral (width * height - 1))
            in (leakMem eng leakTarget, False)
          else (eng, False)

  -- Update state reference
  writeIORef stateRef (eng1, s')

  -- Render canvas output to stdout
  let frame = renderCanvas eng1 s' isRaining
  putStr frame
  
  -- Visual HUD Overlay
  let fragPct = floor (calcFragmentation eng1 * 100) :: Int
  let leaks = length (leakPointers eng1)
  putStrLn $ "\ESC[37;40m [Memory Allocation Watercolor] Step: " ++ show step 
          ++ " | Frag: " ++ show fragPct ++ "%"
          ++ " | Oil Stains (Leaks): " ++ show leaks
          ++ if isRaining then " | \ESC[36m*** GC RAINSTORM WASHING INK ***\ESC[37m" else ""

  hFlush stdout
  threadDelay 50000 -- 50ms frame time (~20 FPS)
  
  simulationLoop stateRef (step + 1)