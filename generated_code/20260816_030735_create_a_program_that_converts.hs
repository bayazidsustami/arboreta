import Sound.PortAudio
import Data.Complex
import Numeric.FFT
import Control.Concurrent (forkIO, threadDelay)
import Control.Monad (forever, when)
import Data.IORef
import System.IO
import System.Random

-- Audio configuration parameters
sampleRate :: Double
sampleRate = 44100.0

bufferSize :: Int
bufferSize = 1024

numStars :: Int
numStars = 60

-- Representing a 3D Star in our harmonic constellation
data Star = Star
  { posX :: Double
  , posY :: Double
  , posZ :: Double
  , baseFreq :: Double
  , orbitRadius :: Double
  , orbitSpeed :: Double
  , angle :: Double
  , brightness :: Double
  , spectralChar :: Char
  }

-- Main Entry Point
main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStr "\ESC[?25l" -- Hide cursor
  putStr "\ESC[2J"   -- Clear screen

  -- Initialize stars with random 3D orbits and frequency affinities
  gen <- newStdGen
  starsRef <- newIORef (initStars gen)
  fftRef <- newIORef (replicate (bufferSize `div` 2) 0.0)

  -- Initialize PortAudio for microphone input
  withPortAudio $ do
    stream <- openDefaultStream 1 0 sampleRate (Just bufferSize) audioCallback (Just fftRef)
    startStream stream
    
    -- Main render loop running at ~30 FPS
    forever $ do
      ffts <- readIORef fftRef
      stars <- readIORef starsRef
      let updatedStars = zipWith (updateStar ffts) [0..] stars
      writeIORef starsRef updatedStars
      
      renderConstellation updatedStars
      threadDelay 33000 -- ~30 FPS delay

-- Initialize stars distributed across the 3D frequency space
initStars :: StdGen -> [Star]
initStars gen = evalStars (randomRs (-1.0, 1.0) gen)
  where
    evalStars (r1:r2:r3:r4:r5:rest) =
      let freq = 100.0 + (r1 + 1.0) * 1500.0
          star = Star
            { posX = r1 * 20.0
            , posY = r2 * 20.0
            , posZ = 10.0 + r3 * 30.0
            , baseFreq = freq
            , orbitRadius = 2.0 + r4 * 8.0
            , orbitSpeed = 0.02 + r5 * 0.05
            , angle = r1 * pi
            , brightness = 0.0
            , spectralChar = '.'
            }
      in star : evalStars rest
    evalStars _ = []

-- Real-time audio callback processing PCM data into harmonic magnitudes
audioCallback :: [Float] -> IORef [Double] -> IO ()
audioCallback input fftRef = do
  let complexInput = map (\s -> realToFrac s :+ 0.0) input
      spectrum = fft complexInput
      magnitudes = map magnitude (take (bufferSize `div` 2) spectrum)
  writeIORef fftRef magnitudes

-- Update a star's position, brightness, and character based on audio FFT overtones
updateStar :: [Double] -> Int -> Star -> Star
updateStar spectrum idx star =
  let binIdx = min (length spectrum - 1) (floor (baseFreq star / (sampleRate / fromIntegral bufferSize)))
      amp = spectrum !! binIdx
      
      -- Harmonic resonance governs trajectory and brightness
      newAngle = angle star + orbitSpeed star * (1.0 + amp * 5.0)
      newX = orbitRadius star * cos newAngle
      newY = orbitRadius star * sin newAngle
      newZ = posZ star + sin (newAngle * 2.0) * amp * 2.0
      
      -- Spectral emission characters based on overtone intensity
      chars = " .':;=*#%@"
      charIdx = min (length chars - 1) (floor (amp * fromIntegral (length chars)))
      sChar = chars !! charIdx
  in star
    { posX = newX
    , posY = newY
    , posZ = max 1.0 newZ
    , angle = newAngle
    , brightness = amp
    , spectralChar = sChar
    }

-- Project 3D coordinates (X, Y, Z) into 2D ASCII terminal space with depth perspective
renderConstellation :: [Star] -> IO ()
renderConstellation stars = do
  putStr "\ESC[H" -- Move cursor to top-left
  let width = 80
      height = 24
      fov = 30.0
      
      -- Create empty screen buffer
      grid = replicate height (replicate width ' ')
      
      -- Project star coordinates
      project star =
        let projX = floor (fromIntegral width / 2.0 + (posX star / posZ star) * fov)
            projY = floor (fromIntegral height / 2.0 + (posY star / posZ star) * (fov / 2.0))
        in (projX, projY, spectralChar star)
        
      -- Draw projected stars into grid buffer
      drawPoint (x, y, c) buf =
        if x >= 0 && x < width && y >= 0 && y < height
          then replace2D x y c buf
          else buf

      buffer = foldr projectGrid grid (map project stars)
      projectGrid p buf = drawPoint p buf

  putStr $ unlines buffer

-- Helper to mutate grid cell
replace2D :: Int -> Int -> Char -> [[Char]] -> [[Char]]
replace2D x y c grid =
  let (top, row:bottom) = splitAt y grid
      (left, _:right) = splitAt x row
      newRow = left ++ [c] ++ right
  in top ++ [newRow] ++ bottom