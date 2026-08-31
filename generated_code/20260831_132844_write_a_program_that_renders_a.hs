import Sound.PortAudio
import Data.Complex
import Data.Array.Storable
import Foreign.Storable
import Foreign.Marshal.Array
import Foreign.Ptr
import Control.Monad (when, forever)
import Control.Concurrent (threadDelay, forkIO, newMVar, readMVar, swapMVar)
import System.Console.ANSI
import System.IO (hFlush, stdout, hSetBuffering, BufferMode(NoBuffering))

-- Audio Configuration
sampleRate :: Double
sampleRate = 44100.0

framesPerBuffer :: Sunsigned long
framesPerBuffer = 512

-- Screen Dimensions
width, height :: Int
width = 80
height = 40

type Grid = [[Bool]]

-- | Simple FFT implementation for power-of-2 input sizes
fft :: [Complex Double] -> [Complex Double]
fft [] = []
fft [x] = [x]
fft xs = zipWith (+) evens combined ++ zipWith (-) evens combined
  where
    n = length xs
    evens = fft [xs !! i | i <- [0, 2 .. n-1]]
    odds  = fft [xs !! i | i <- [1, 3 .. n-1]]
    twiddles = [exp (0 :+ (-2 * pi * fromIntegral k / fromIntegral n)) | k <- [0 .. n `div` 2 - 1]]
    combined = zipWith (*) twiddles odds

-- | Calculate energy across low, mid, and high frequency bands
getBandEnergies :: [Double] -> (Double, Double, Double)
getBandEnergies samples = (lowEnergy, midEnergy, highEnergy)
  where
    n = length samples
    complexSamples = map (:+ 0.0) samples
    spectrum = map magnitude (take (n `div` 2) $ fft complexSamples)
    
    specLen = length spectrum
    lowCut  = specLen `div` 8
    midCut  = specLen `div` 2

    lowEnergy  = sum (take lowCut spectrum) / fromIntegral lowCut
    midEnergy  = sum (take (midCut - lowCut) (drop lowCut spectrum)) / fromIntegral (midCut - lowCut)
    highEnergy = sum (drop midCut spectrum) / fromIntegral (specLen - midCut)

-- | Count living neighbors for a cellular automaton cell (toroidal grid)
countNeighbors :: Grid -> Int -> Int -> Int
countNeighbors grid x y = length [ () | dx <- [-1..1], dy <- [-1..1]
                                 , (dx, dy) /= (0,0)
                                 , grid !! ((y + dy) `mod` height) !! ((x + dx) `mod` width) ]

-- | Advance the cellular automaton state using audio-driven dynamic rules
stepCA :: (Double, Double, Double) -> Grid -> Grid
stepCA (low, mid, high) grid =
  [ [ nextState x y (grid !! y !! x) | x <- [0..width-1] ] | y <- [0..height-1] ]
  where
    -- Audio energy thresholds dynamically modify survival and birth parameters
    birthThreshold    = if low > 15.0 then 2 else 3
    survivalMin       = if mid > 10.0 then 1 else 2
    survivalMax       = if high > 5.0 then 4 else 3

    nextState x y alive
      | alive && n >= survivalMin && n <= survivalMax = True
      | not alive && n == birthThreshold            = True
      | otherwise                                  = False
      where n = countNeighbors grid x y

-- | Render the CA grid to ASCII with audio-reactive character intensity
renderGrid :: (Double, Double, Double) -> Grid -> String
renderGrid (low, mid, high) grid = unlines [ [ charFor x y | x <- [0..width-1] ] | y <- [0..height-1] ]
  where
    charFor x y
      | grid !! y !! x = if (low + mid) > 20.0 then '#' else '*'
      | otherwise     = if high > 8.0 then '.' else ' '

-- | Initial random/structured seed pattern
initialGrid :: Grid
initialGrid = [ [ (x * y + x + y) `mod` 7 == 0 | x <- [0..width-1] ] | y <- [0..height-1] ]

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  hideCursor
  clearScreen

  audioMVar <- newMVar (0.0, 0.0, 0.0)

  withPortAudio $ do
    -- Audio stream capture setup
    let inputParams = StreamParameters
          { streamDevice = defaultInputDevice
          , streamChannelCount = 1
          , streamSampleFormat = Float32
          , streamSuggestedLatency = 0.05
          }

    withStream (Just inputParams) Nothing sampleRate framesPerBuffer [] (\_ inputPtr _ -> do
        case inputPtr of
          Just ptr -> do
            samples <- peekArray (fromIntegral framesPerBuffer) (castPtr ptr :: Ptr Float)
            let doubleSamples = map realToFrac samples
            let energies = getBandEnergies doubleSamples
            _ <- swapMVar audioMVar energies
            return Continue
          Nothing -> return Continue
      ) $ \stream -> do
        startStream stream

        -- Main Cellular Automaton animation loop
        let loop grid = do
              energies <- readMVar audioMVar
              setCursorPosition 0 0
              putStr (renderGrid energies grid)
              hFlush stdout
              threadDelay 50000 -- ~20 FPS loop rate
              let nextGrid = stepCA energies grid
              loop nextGrid

        loop initialGrid