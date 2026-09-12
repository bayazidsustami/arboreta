import Sound.PortAudio
import Foreign.C.Types
import Foreign.Ptr
import Foreign.Storable
import Control.Concurrent (forkIO, threadDelay)
import Control.Monad (when, forever)
import Data.IORef
import Data.List (sortBy)
import Data.Ord (comparing)
import System.IO (hSetBuffering, stdout, BufferMode(NoBuffering))

-- Parameters
sampleRate :: Double
sampleRate = 44100.0

bufferSize :: Int
bufferSize = 2048

termWidth, termHeight :: Int
termWidth = 80
termHeight = 24

-- Audio State: (Volume [0..1], Pitch/Frequency in Hz, Dissonance [0..1])
type AudioState = (Float, Float, Float)

-- Calculate RMS volume
calcVolume :: [Float] -> Float
calcVolume samples = sqrt (sum (map (^2) samples) / fromIntegral (length samples))

-- Estimate fundamental frequency via Zero-Crossing Rate
calcPitch :: [Float] -> Float
calcPitch samples =
  let crossings = length . filter id $ zipWith (\a b -> (a >= 0) /= (b >= 0)) samples (tail samples)
  in (fromIntegral crossings * realToFrac sampleRate) / (2.0 * fromIntegral bufferSize)

-- Measure harmonic dissonance (spectral irregularity via variance of adjacent differences)
calcDissonance :: [Float] -> Float
calcDissonance samples =
  let diffs = zipWith (\a b -> abs (a - b)) samples (tail samples)
      avg = sum diffs / fromIntegral (length diffs)
      variance = sum (map (\d -> (d - avg)^2) diffs) / fromIntegral (length diffs)
  in min 1.0 (variance * 10.0)

-- Map pitch to elevation (Y-axis: higher pitch -> higher elevation)
pitchToY :: Float -> Int
pitchToY freq =
  let minFreq = 100.0
      maxFreq = 2000.0
      clamped = max minFreq (min maxFreq freq)
      norm = (log clamped - log minFreq) / (log maxFreq - log minFreq)
  in termHeight - 1 - floor (norm * fromIntegral (termHeight - 1))

-- Render single frame to terminal
renderConstellation :: AudioState -> Int -> IO ()
renderConstellation (vol, pitch, diss) frame = do
  let starChar = case vol of
        v | v < 0.05  -> ' '
          | v < 0.15  -> '.'
          | v < 0.30  -> '*'
          | v < 0.50  -> 'O'
          | otherwise -> '@'

      starY = pitchToY pitch
      starX = (frame * 2) `mod` termWidth

      -- Black hole presence and radius driven by dissonance
      bhActive = diss > 0.25
      bhX = (termWidth `div` 2) + floor (sin (fromIntegral frame * 0.1) * 15.0)
      bhY = (termHeight `div` 2) + floor (cos (fromIntegral frame * 0.1) * 6.0)
      bhRadius = floor (diss * 8.0)

      -- Generate screen buffer
      screen = [ [ cell x y | x <- [0..termWidth-1] ] | y <- [0..termHeight-1] ]
      cell x y
        | bhActive && (x - bhX)^2 + 2 * (y - bhY)^2 <= bhRadius^2 = '0' -- Event horizon
        | bhActive && (x - bhX)^2 + 2 * (y - bhY)^2 <= (bhRadius + 2)^2 = '~' -- Accretion disk
        | x == starX && y == starY = starChar
        | otherwise = ' '

  -- Move cursor to top-left and print buffer
  putStr "\ESC[H"
  mapM_ putStrLn screen

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStr "\ESC[2J\ESC[?25l" -- Clear screen & hide cursor

  stateRef <- newIORef (0.0, 0.0, 0.0)

  withPortAudio $ do
    -- Open default audio input stream
    withDefaultStream 1 0 sampleRate bufferSize $ \stream -> do
      startStream stream

      -- Audio processing thread
      _ <- forkIO $ forever $ do
        -- Read audio buffer (mono input)
        bufPtr <- readStream stream bufferSize :: IO [Float]
        let vol = calcVolume bufPtr
            pitch = calcPitch bufPtr
            diss = calcDissonance bufPtr
        writeIORef stateRef (vol, pitch, diss)
        threadDelay 10000

      -- Main rendering loop (~30 FPS)
      let loop frame = do
            audioState <- readIORef stateRef
            renderConstellation audioState frame
            threadDelay 33000
            loop (frame + 1)

      loop 0