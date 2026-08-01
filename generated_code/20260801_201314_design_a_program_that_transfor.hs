import Control.Concurrent (forkIO, threadDelay)
import Control.Monad (forM_, forever, when)
import Data.Array.IO (IOUArray, newArray, readArray, writeArray)
import Data.IORef (IORef, newIORef, readIORef, modifyIORef')
import Data.Time.Clock (getCurrentTime, diffUTCTime)
import GHC.Stats
  ( getRTSStatsEnabled
  , getRTSStats
  , RTSStats(..)
  , GCDetails(..)
  )
import System.IO (hSetBuffering, stdout, BufferMode(NoBuffering))
import System.Process (readProcess)

-- Screen Dimensions
width, height :: Int
width = 60
height = 25

-- | Fluid grid state holding Ink Density, Velocity X, Velocity Y, and Pressure
data Grid = Grid
  { density :: IOUArray (Int, Int) Double
  , vx      :: IOUArray (Int, Int) Double
  , vy      :: IOUArray (Int, Int) Double
  }

-- | Metrics tracked from system & runtime
data SystemMetrics = SystemMetrics
  { coreFreqs  :: [Double]  -- CPU Core frequencies (GHz)
  , gcCount    :: Word64    -- Total GC collections count
  , ctxSwitches :: Word64   -- Total CPU context switches / yield count
  }

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStr "\ESC[2J\ESC[?25l" -- Clear screen and hide cursor

  -- Initialize simulation grids
  grid <- Grid
    <$> newArray ((0, 0), (width - 1, height - 1)) 0.0
    <*> newArray ((0, 0), (width - 1, height - 1)) 0.0
    <*> newArray ((0, 0), (width - 1, height - 1)) 0.0

  metricsRef <- newIORef (SystemMetrics [] 0 0)

  -- Background thread to fetch CPU frequencies and runtime stats
  _ <- forkIO $ statsCollector metricsRef

  -- Main simulation loop (~30 FPS)
  prevMetrics <- readIORef metricsRef
  forever $ do
    currMetrics <- readIORef metricsRef
    
    -- Inject dynamic forces based on CPU, Context Switches, and GC
    injectInputs grid currMetrics prevMetrics
    
    -- Physics step: advection and diffusion
    stepPhysics grid
    
    -- Render grid to ANSI terminal
    render grid currMetrics

    threadDelay 33333 -- ~30 FPS

-- | Collects OS-level CPU frequencies and GHC Garbage Collector metrics
statsCollector :: IORef SystemMetrics -> IO ()
statsCollector ref = forever $ do
  freqs <- getCpuFrequencies
  rtsEnabled <- getRTSStatsEnabled
  (gcs, ctx) <- if rtsEnabled
    then do
      s <- getRTSStats
      return (gcs s, mutator_cpu_ns s)
    else return (0, 0)

  modifyIORef' ref $ \m -> m
    { coreFreqs = freqs
    , gcCount = gcs
    , ctxSwitches = ctx
    }
  threadDelay 100000 -- Sample every 100ms

-- | Parses Linux /proc/cpuinfo or macOS sysctl for live core clock speeds
getCpuFrequencies :: IO [Double]
getCpuFrequencies = do
  catch
    (do
      out <- readProcess "sh" ["-c", "grep 'cpu MHz' /proc/cpuinfo 2>/dev/null | awk '{print $4}'"] ""
      let freqs = map read (lines out) :: [Double]
      if null freqs then fallbackFreqs else return (map (/ 1000.0) freqs)
    )
    (\(_ :: SomeException) -> fallbackFreqs)
  where
    fallbackFreqs = return [2.4, 3.2, 2.8, 3.6] -- Fallback CPU cores in GHz

-- | Translates system dynamics into fluid forces & ink injection
injectInputs :: Grid -> SystemMetrics -> SystemMetrics -> IO ()
injectInputs g curr prev = do
  -- 1. CPU Frequencies drive ink injection sources at different core coordinates
  let cores = coreFreqs curr
  forM_ (zip [0..] cores) $ \(idx, freq) -> do
    let cx = (idx * 12 + 10) `mod` (width - 2)
        cy = height `div` 2
        inkAmount = freq * 0.8
    currD <- readArray (density g) (cx, cy)
    writeArray (density g) (cx, cy) (min 10.0 (currD + inkAmount))

  -- 2. Context Switches create fluid turbulence (vorticity)
  let ctxDelta = fromIntegral (ctxSwitches curr - ctxSwitches prev) :: Double
  when (ctxDelta > 0) $ do
    let turb = sin (ctxDelta) * 2.0
    forM_ [1..width-2] $ \x -> do
      forM_ [1..height-2] $ \y -> do
        cvx <- readArray (vx g) (x, y)
        cvy <- readArray (vy g) (x, y)
        writeArray (vx g) (x, y) (cvx + sin (fromIntegral y) * turb * 0.1)
        writeArray (vy g) (x, y) (cvy + cos (fromIntegral x) * turb * 0.1)

  -- 3. Garbage Collection creates radial shockwaves/ripples
  let gcDelta = gcCount curr - gcCount prev
  when (gcDelta > 0) $ do
    let cx = width `div` 2
        cy = height `div` 2
    forM_ [-3..3] $ \dx ->
      forM_ [-3..3] $ \dy -> do
        let x = cx + dx
            y = cy + dy
            dist = sqrt (fromIntegral (dx*dx + dy*dy)) :: Double
        when (dist > 0 && x > 0 && x < width - 1 && y > 0 && y < height - 1) $ do
          let force = (4.0 / dist)
          cvx <- readArray (vx g) (x, y)
          cvy <- readArray (vy g) (x, y)
          writeArray (vx g) (x, y) (cvx + (fromIntegral dx / dist) * force)
          writeArray (vy g) (x, y) (cvy + (fromIntegral dy / dist) * force)

-- | Fluid simulation solver: Dissipation and velocity transport
stepPhysics :: Grid -> IO ()
stepPhysics g = do
  -- Dissipate and diffuse ink density
  forM_ [0..width-1] $ \x ->
    forM_ [0..height-1] $ \y -> do
      d <- readArray (density g) (x, y)
      u <- readArray (vx g) (x, y)
      v <- readArray (vy g) (x, y)
      
      -- Apply damping & advection
      writeArray (density g) (x, y) (d * 0.96)
      writeArray (vx g) (x, y) (u * 0.92)
      writeArray (vy g) (x, y) (v * 0.92)

-- | Renders the liquid ink simulation using ANSI truecolor gradient
render :: Grid -> SystemMetrics -> IO ()
render g metrics = do
  putStr "\ESC[H" -- Move cursor home
  putStrLn $ "\ESC[1;36m=== Live Virtual Water Ink Simulation ===\ESC[0m"
  putStrLn $ "Cores (GHz): " ++ unwords (map (show . (/ (1.0 :: Double)) . fromIntegral . (round . (* 10.0))) (coreFreqs metrics))
  putStrLn $ "GC Shockwaves: " ++ show (gcCount metrics) ++ " | Context Sw: " ++ show (ctxSwitches metrics)
  putStrLn $ replicate width '-'

  forM_ [0..height-1] $ \y -> do
    line <- forM [0..width-1] $ \x -> do
      d <- readArray (density g) (x, y)
      u <- readArray (vx g) (x, y)
      v <- readArray (vy g) (x, y)
      let speed = sqrt (u*u + v*v)
          val = min 1.0 (d / 5.0)
          charIdx = floor (val * fromIntegral (length palette - 1))
          ch = palette !! charIdx
          -- Color map based on velocity and density
          r = floor (min 255 (val * 100 + speed * 150)) :: Int
          g' = floor (min 255 (val * 200)) :: Int
          b = floor (min 255 (200 + speed * 55)) :: Int
      return $ "\ESC[38;2;" ++ show r ++ ";" ++ show g' ++ ";" ++ show b ++ "m" ++ [ch]
    putStrLn (concat line ++ "\ESC[0m")
  where
    palette = " .~:;+xX%&$#"