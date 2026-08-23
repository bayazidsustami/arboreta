import Control.Concurrent (threadDelay)
import Control.MonButton (void) -- Fallback, but standard Control.Monad is better
import Control.Monad (forever, forM_)
import System.IO (hFlush, stdout, hSetBuffering, BufferMode(NoBuffering))
import GHC.Stats (getRTSStats, RTSStats(..), GCDetails(..))
import System.Random (randomRIO)

-- | Character palette representing visual degradation from healthy density to visual decay.
healthyChars, decayingChars :: String
healthyChars  = " .:-=+*#%@"
decayingChars = " ...,,;:~!- "

-- | Map a 0.0 - 1.0 intensity value and a corruption factor to an ASCII character.
renderChar :: Double -> Double -> Char
renderChar intensity decayThreshold =
  if decayThreshold > 0.7
    then decayingChars !! pIdx decayingChars
    else healthyChars !! pIdx healthyChars
  where
    pIdx palette = floor (intensity * fromIntegral (length palette - 1))

-- | Generates an animated frame based on memory allocated and thread count metrics.
generateFrame :: Double -> Int -> Int -> Int -> IO String
generateFrame memMB gcCount width height = do
  let memFactor = min 1.0 (memMB / 1024.0)  -- Normalize to ~1GB threshold
  let churn = fromIntegral (gcCount `mod` 50) / 50.0
  
  rows <- forM [0 .. height - 1] $ \y -> do
    cols <- forM [0 .. width - 1] $ \x -> do
      noise <- randomRIO (0.0, 1.0) :: IO Double
      let fx = fromIntegral x / fromIntegral width
      let fy = fromIntegral y / fromIntegral height
      
      -- Wave equations modulated by memory allocation and GC churn
      let wave1 = sin (fx * 10.0 + memFactor * 5.0) * cos (fy * 10.0 + churn * 3.0)
      let wave2 = cos (fx * 5.0 - churn * 10.0) * sin (fy * 5.0 + memFactor * 2.0)
      let rawIntensity = (wave1 + wave2 + 2.0) / 4.0
      
      -- Blend with memory pressure to create decay artifacts
      let intensity = max 0.0 (min 1.0 (rawIntensity * (1.0 - memFactor * 0.5)))
      let decay = noise * memFactor
      
      return $ renderChar intensity decay
    return cols
  return $ unlines rows

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStr "\ESC[2J" -- Clear terminal screen
  
  let width = 80
  let height = 24

  forever $ do
    stats <- getRTSStats
    let memMB = fromIntegral (allocatedBytes stats) / (1024 * 1024)
    let gcCount = gcs (gc stats)
    
    frame <- generateFrame memMB (fromIntegral gcCount) width height
    
    -- Reset cursor to top-left and print frame
    putStr "\ESC[H"
    putStr frame
    
    -- HUD Status Line
    putStrLn $ " [SYSTEM MEMORY ALLOCATED: " ++ show (round memMB :: Int) ++ " MB | GC CHURN COUNT: " ++ show gcCount ++ "] "
    hFlush stdout
    
    threadDelay 100000 -- ~10 FPS update rate