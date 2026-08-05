import Control.Concurrent (threadDelay)
import Control.Monad (forM_)
import Data.Bits (xor)
import System.IO (hFlush, hSetBuffering, hSetEcho, stdin, stdout, BufferMode(..))
import System.Random (randomRIO)

-- ============================================================================
-- CPU Instruction Pipeline Generative Art Engine
-- ============================================================================
-- Simulates CPU pipeline execution state and maps low-level hardware events
-- into a real-time ANSI terminal generative canvas:
--   1. Pipeline Execution: Smooth fluid color waves representing instruction flow.
--   2. Cache Misses: Ink-bleed diffusion waves distorting regional color fields.
--   3. Branch Mispredictions: Recursive fractal fractures growing across paths.
-- ============================================================================

-- Canvas dimensions
width :: Int
width = 80

height :: Int
height = 30

-- State of the simulated CPU Pipeline
data PipelineState = PipelineState
  { fetchPC          :: !Word
  , cacheMiss        :: !Bool
  , branchMispredict :: !Bool
  , cycleCount       :: !Int
  }

-- State of a single visual canvas pixel cell
data Cell = Cell
  { cellChar :: !Char
  , cellR    :: !Int
  , cellG    :: !Int
  , cellB    :: !Int
  , inkBleed :: !Float  -- Intensity of cache miss ink diffusion
  , fracture :: !Int    -- Structural fractal depth from branch mispredictions
  }

type Canvas = [[Cell]]

-- Initialize pristine dark canvas
initCanvas :: Canvas
initCanvas = replicate height [Cell ' ' 10 12 25 0.0 0 | _ <- [1..width]]

-- Telemetry generator simulating CPU execution events
nextCPU :: PipelineState -> IO PipelineState
nextCPU state = do
  r1 <- randomRIO (1, 100) :: IO Int
  r2 <- randomRIO (1, 100) :: IO Int
  let pc = fetchPC state + 4
      cMiss = r1 < 18        -- 18% chance of cache miss
      bMis  = r2 < 12        -- 12% chance of branch misprediction
  return $ PipelineState pc cMiss bMis (cycleCount state + 1)

-- Evolve generative canvas buffer driven by hardware signals
updateCanvas :: PipelineState -> Canvas -> IO Canvas
updateCanvas cpu canvas = do
  -- Event origin points
  missX <- randomRIO (0, width - 1)
  missY <- randomRIO (0, height - 1)
  fracX <- randomRIO (10, width - 11)
  fracY <- randomRIO (5, height - 6)

  let cMiss = cacheMiss cpu
      bMis  = branchMispredict cpu
      cyc   = cycleCount cpu

  return $ mapWithPos (\y row ->
    mapWithPos (\x cell ->
      let
        -- 1. Base Pipeline Wavefield (smooth instruction stream flow)
        wave = sin (fromIntegral (x + cyc) * 0.1) + cos (fromIntegral (y - cyc) * 0.1)
        baseR = truncate (127.5 + 127.5 * sin (wave + fromIntegral cyc * 0.05))
        baseG = truncate (64.0 + 64.0 * cos (wave * 0.5))
        baseB = truncate (180.0 + 75.0 * sin (fromIntegral (x + y) * 0.08))

        -- 2. Cache Miss: Radial Ink Bleed Diffusion
        dxMiss = fromIntegral (x - missX)
        dyMiss = fromIntegral (y - missY)
        distMiss = sqrt (dxMiss * dxMiss + dyMiss * dyMiss)
        newBleed = if cMiss && distMiss < 8.0
                   then min 1.0 (inkBleed cell + (1.0 - distMiss / 8.0))
                   else inkBleed cell * 0.92  -- Dissipate over cycles

        -- 3. Branch Misprediction: Fractal Fractures
        dxFrac = abs (x - fracX)
        dyFrac = abs (y - fracY)
        isFractal = bMis && ((dxFrac `xor` dyFrac) `mod` 7 == 0 || (x + y * 3) `mod` 11 == 0)
        newFrac = if isFractal then 5 else max 0 (fracture cell - 1)

        -- Composite RGB color synthesis
        finalR = if newFrac > 0 then 255 else truncate (fromIntegral baseR * (1.0 - newBleed * 0.7))
        finalG = if newFrac > 0 then 220 else truncate (fromIntegral baseG * (1.0 - newBleed * 0.5))
        finalB = if newFrac > 0 then 100 else truncate (fromIntegral baseB + newBleed * 100.0)

        -- Dynamic character glyph selection
        glyph | newFrac > 0 = pickFractalChar (x + y + cyc)
              | newBleed > 0.4 = pickInkChar newBleed
              | otherwise = pickPipeChar (baseR + baseG)
      in Cell glyph (min 255 finalR) (min 255 finalG) (min 255 finalB) newBleed newFrac
    ) row
  ) canvas

-- Helper: Map with 0-indexed element coordinates
mapWithPos :: (Int -> a -> b) -> [a] -> [b]
mapWithPos f xs = zipWith f [0..] xs

-- Visual glyph mapping functions
pickFractalChar :: Int -> Char
pickFractalChar n = let chars = "╱╲╳┼╌╎⚡⁜" in chars !! (n `mod` length chars)

pickInkChar :: Float -> Char
pickInkChar b = let chars = " ░▒▓█" in chars !! min 4 (truncate (b * 5.0))

pickPipeChar :: Int -> Char
pickPipeChar v = let chars = "·.  -~+*oO#" in chars !! (v `mod` length chars)

-- Double-buffered render to terminal with 24-bit TrueColor ANSI escape sequences
render :: Canvas -> IO ()
render canvas = do
  putStr "\ESC[H" -- Move cursor to top-left (0,0)
  forM_ canvas $ \row -> do
    forM_ row $ \cell -> do
      let r = cellR cell
          g = cellG cell
          b = cellB cell
      putStr $ "\ESC[38;2;" ++ show r ++ ";" ++ show g ++ ";" ++ show b ++ "m" ++ [cellChar cell]
    putStrLn "\ESC[0m"
  hFlush stdout

-- Main real-time telemetry animation loop
main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  hSetBuffering stdin NoBuffering
  hSetEcho stdin False
  putStr "\ESC[2J\ESC[?25l" -- Clear terminal display & hide cursor
  
  let initState = PipelineState 0x80000000 False False 0
  loop initState initCanvas
  where
    loop cpu canvas = do
      cpu'    <- nextCPU cpu
      canvas' <- updateCanvas cpu' canvas
      render canvas'
      threadDelay 50000 -- ~20 FPS frame synchronization
      loop cpu' canvas'