import           Control.Monad                (forM_)
import           Data.Complex
import qualified Data.Vector.Storable         as V
import qualified Data.Vector.Unboxed          as U
import           Data.Word
import           System.Environment           (getArgs)
import           System.Exit                  (die)

-- audio
import qualified Sound.PortAudio              as PA
import qualified Sound.PortAudio.Stream       as PS

-- FFT
import           Numeric.FFT                  (fft)

-- vector graphics
import           Diagrams.Prelude
import           Diagrams.Backend.SVG.CmdLine (svg)

-- settings
frameRate :: Int
frameRate = 30                     -- frames per second

bufferSize :: Int
bufferSize = 1024                  -- samples per FFT

type Sample = Double

-- map frequency bin to a brushstroke style
brushstroke :: Int -> Diagram B
brushstroke i
  | i `mod` 3 == 0 = lc red   $ strokeP (fromSegments [straight (V2 0 0), straight (V2 1 0)]) # lwG (0.5 + fromIntegral i * 0.001)
  | i `mod` 3 == 1 = lc blue  $ vrule 1 # lwG (0.3 + fromIntegral i * 0.001) # translateX (fromIntegral i * 0.01)
  | otherwise      = lc green $ hrule 1 # lwG (0.2 + fromIntegral i * 0.001) # translateY (fromIntegral i * 0.01)

-- convert complex spectrum magnitude to visual intensity
intensity :: Double -> Double
intensity x = min 1 (sqrt x / 10)

-- build a single frame from a chunk of audio samples
frameFromChunk :: V.Vector Sample -> Diagram B
frameFromChunk chunk =
  let win = V.map (* hammingWindow) chunk
      hammingWindow = \x -> 0.54 - 0.46 * cos (2 * pi * x / fromIntegral (V.length chunk - 1))
      spectrum = fft $ V.map (:+ 0) win
      mags = V.map magnitude spectrum
      styled = zipWith (\i m -> brushstroke i # opacity (intensity m)) [0..] (V.toList mags)
   in mconcat styled # centerXY # pad 1.2

-- main loop: capture audio, generate frames, write to SVG
main :: IO ()
main = do
  args <- getArgs
  case args of
    [outFile] -> runAudio outFile
    _         -> die "Usage: livepaint <output.svg>"

runAudio :: FilePath -> IO ()
runAudio outFile = do
  PA.initialize
  let sr = PA.defaultSampleRate
      ch = 1
      fmt = PA.Float32
  stream <- PS.openDefaultStream
              (PA.StreamParameters Nothing (Just 0) fmt ch sr False)
              (PA.StreamParameters Nothing (Just 0) fmt ch sr False)
              (Just (fromIntegral bufferSize))
              (Just (fromIntegral bufferSize))
              Nothing
  PS.start stream
  frames <- collectFrames stream []
  PS.stop stream
  PA.terminate
  let diagram = vcat (map frameFromChunk frames) # bg white
  renderSVG outFile (mkWidth 1920) diagram

collectFrames :: PS.Stream -> [V.Vector Sample] -> IO [V.Vector Sample]
collectFrames stream acc = do
  eof <- PS.isActive stream
  if not eof
    then return (reverse acc)
    else do
      buf <- PS.readStream stream bufferSize
      let vec = V.convert (buf :: V.Vector Float)
      let samples = V.map realToFrac vec
      collectFrames stream (samples:acc)