import qualified Data.Vector.Storable as VS
import qualified Data.Vector as V
import System.IO (hSetBuffering, BufferMode(NoBuffering), stdout)
import Control.Concurrent (threadDelay, forkIO)
import Control.Monad (forever, when)
import Data.Complex (Complex(..))
import Data.List (foldl')
import Sound.PortAudio (withPortAudio, defaultInputDevice, StreamCallbackResult(..), Stream, openStream, startStream, readStream, closeStream, StreamParameters(..), SampleFormat(..), defaultSampleRate, framesPerBuffer)
import Numeric.FFT (fft)
import System.Random (randomRIO)

-- L‑system state
type LSys = String

-- Unicode block elements for drawing
blocks :: [Char]
blocks = " ▏▎▍▌▋▊▉█"

-- Convert a numeric value (0..1) to a block character
toBlock :: Double -> Char
toBlock v = blocks !! (min (length blocks - 1) (floor (v * fromIntegral (length blocks))))

-- Simple L‑system expansion: replace each symbol by a rule derived from a frequency bucket
expand :: LSys -> [Double] -> LSys
expand sys freqs = concatMap replace sys
  where
    replace 'F' = let p = dominantFreq freqs in "F[+F]F[-F]F"
          replace c   = [c]
    dominantFreq f = let (i,_) = V.ifoldl' (\(mi,mv) i x -> if x > mv then (i,x) else (mi,mv)) (0,0) (V.fromList f) in fromIntegral i / fromIntegral (length f)

-- Render the L‑system as a grid of block characters
render :: LSys -> IO ()
render sys = do
    let width = 80
        height = 24
        grid = replicate height (replicate width ' ')
        draw g [] _ _ = g
        draw g (c:cs) x y
          | y >= height = g
          | x >= width  = draw g cs 0 (y+1)
          | otherwise   = let g' = take y g ++ [take x (g !! y) ++ [c] ++ drop (x+1) (g !! y)] ++ drop (y+1) g
                          in draw g' cs (x+1) y
    let flat = map (toBlock . (/1000)) $ map (fromIntegral . fromEnum) sys
        finalGrid = draw grid flat 0 0
    mapM_ putStrLn finalGrid

-- Audio capture thread returning magnitude spectrum
audioThread :: (VS.Vector Double -> IO ()) -> IO ()
audioThread handler = withPortAudio $ do
    let sr = defaultSampleRate
        fps = 1024
        input = StreamParameters (defaultInputDevice) 1 Nothing
        output = Nothing
    stream <- openStream input output sr fps framesPerBuffer Nothing
    startStream stream
    let loop = do
            buf <- readStream stream framesPerBuffer
            let spectrum = VS.map magnitude $ fft $ VS.map (:+ 0) buf
                mags = VS.toList spectrum
            handler (VS.fromList mags)
            threadDelay 50000
            loop
    loop
  where magnitude (r :+ i) = sqrt (r*r + i*i)

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    let loop sys = do
            result <- newEmptyMVar
            _ <- forkIO $ audioThread (putMVar result)
            mags <- takeMVar result
            let newSys = expand sys (VS.toList mags)
            clearScreen
            render newSys
            threadDelay 200000
            loop newSys
    clearScreen
    loop "F"
  where
    clearScreen = putStr "\ESC[2J\ESC[H"