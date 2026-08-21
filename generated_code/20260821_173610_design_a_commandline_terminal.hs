{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.MVar
import Control.Monad (forever, when)
import Data.Binary.Put (runPut, putWord16le)
import qualified Data.ByteString.Lazy as BL
import Data.Int (Int16)
import System.Environment (getArgs)
import System.IO (hPutStrLn, stderr)
import System.Process (readProcess)
import Text.Read (readMaybe)

-- | Scale frequencies (Pentatonic Minor Scale for ambient harmonies)
scale :: [Double]
scale = [130.81, 155.56, 174.61, 196.00, 233.08, 261.63, 311.13, 349.23, 392.00, 466.16]

-- | Audio Constants
sampleRate :: Double
sampleRate = 44100.0

-- | Synthesizer Voice representation
data Voice = Voice
  { freq :: Double
  , amplitude :: Double
  , decay :: Double
  , age :: Double
  }

-- | State tracking system metrics and synth voices
data SynthState = SynthState
  { voices :: [Voice]
  , systemMemory :: Double -- 0.0 to 1.0 (Usage)
  }

-- | Fetch page faults / memory state (Cross-platform attempt via vm_stat or /proc/vmstat)
getSystemMetrics :: IO (Double, Int)
getSystemMetrics = do
  -- Reading page faults via vm_stat (macOS) or procfs (Linux)
  resOSX <- tryReadProcess "vm_stat" []
  case resOSX of
    Just out -> parseOSX out
    Nothing -> do
      resLinux <- tryReadProcess "cat" ["/proc/vmstat"]
      case resLinux of
        Just out -> parseLinux out
        Nothing -> return (0.5, 5) -- Fallback mock telemetry if unsupported
  where
    tryReadProcess cmd args = do
      res <- try (readProcess cmd args "") :: IO (Either IOError String)
      return $ case res of
        Right out -> Just out
        Left _ -> Nothing

    parseOSX out = do
      let ls = lines out
          getValue key = case filter (isInfixOf key) ls of
            (x:_) -> readMaybe (filter (`elem` ('0':['1'..'9'])) x) :: Maybe Int
            _     -> Nothing
          pageFaults = maybe 10 (`mod` 50) (getValue "Page faults")
          freePages = maybe 100000 id (getValue "Pages free")
          activePages = maybe 100000 id (getValue "Pages active")
          ratio = fromIntegral activePages / fromIntegral (freePages + activePages + 1)
      return (ratio, pageFaults)

    parseLinux out = do
      let ls = lines out
          getValue key = case filter (isInfixOf key) ls of
            (x:_) -> readMaybe (last (words x)) :: Maybe Int
            _     -> Nothing
          pgFaults = maybe 10 (`mod` 50) (getValue "pgfault")
      return (0.5, pgFaults)

    isInfixOf key str = any (startsWith key) (tails str)
    startsWith [] _ = True
    startsWith (x:xs) (y:ys) = x == y && startsWith xs ys
    startsWith _ [] = False
    tails [] = [[]]
    tails xs@(_:xs') = xs : tails xs'

-- | Helper to catch IO errors safely without dependencies
try :: IO a -> IO (Either IOError a)
try act = catch (Right <$> act) (\(e :: IOError) -> return $ Left e)
  where
    catch = Control.Exception.catch

-- | Map page faults to polyphonic voices added to the state
triggerVoices :: Int -> Double -> [Voice] -> [Voice]
triggerVoices faults memUsage currentVoices = newVoices ++ currentVoices
  where
    numVoices = min 4 (faults `div` 5 + 1)
    newVoices = [ Voice
                    { freq = scale !! ((faults * i + floor (memUsage * 10)) `mod` length scale)
                    , amplitude = 0.3 / fromIntegral numVoices
                    , decay = 0.99988 - (memUsage * 0.00005) -- Ambient long decay
                    , age = 0
                    }
                | i <- [1..numVoices] ]

-- | Render a single frame (441 audio samples) and update synthesizer voices
renderFrame :: MVar SynthState -> IO BL.ByteString
renderFrame stateVar = modifyMVar stateVar $ \st -> do
  let frameSize = 441 -- 10ms frame at 44.1kHz
      dt = 1.0 / sampleRate
      
      -- Compute audio samples for the current frame
      computeSample :: Double -> Voice -> (Double, Voice)
      computeSample t v =
        let wave = sin (2 * pi * freq v * t) + 0.5 * sin (4 * pi * freq v * t) -- Sine + harmonic
            env = amplitude v * (decay v ** (age v * sampleRate))
            val = wave * env
            v' = v { age = age v + (1.0 / sampleRate) }
        in (val, v')

      -- Generate raw audio buffer
      generateBuffer [] _ acc = ([], acc)
      generateBuffer (v:vs) t acc =
        let (val, v') = computeSample t v
            (restVals, updatedVs) = generateBuffer vs t acc
        in (val : restVals, if amplitude v' * (decay v' ** (age v' * sampleRate)) > 0.001 then v' : updatedVs else updatedVs)

      renderSamples 0 _ currentVs accBytes = (currentVs, accBytes)
      renderSamples n t currentVs accBytes =
        let (vVals, activeVs) = generateBuffer currentVs t []
            -- Ambient low-pass filter effect using memory state as cut-off
            rawSum = sum vVals
            clipped = max (-1.0) (min 1.0 rawSum)
            pcmSample = floor (clipped * 32767.0) :: Int16
            byteSample = runPut (putWord16le pcmSample)
        in renderSamples (n - 1) (t + dt) activeVs (accBytes `BL.append` byteSample)

  let (nextVoices, audioChunk) = renderSamples frameSize 0.0 (voices st) BL.empty
  return (st { voices = nextVoices }, audioChunk)

-- | Telemetry background worker thread
telemetryLoop :: MVar SynthState -> IO ()
telemetryLoop stateVar = forever $ do
  (mem, faults) <- getSystemMetrics
  modifyMVar_ stateVar $ \st -> do
    let updatedVoices = triggerVoices faults mem (voices st)
    return st { systemMemory = mem, voices = take 12 updatedVoices } -- Cap at 12 polyphonic voices
  threadDelay 50000 -- Poll metrics every 50ms

-- | Audio streaming output thread
audioLoop :: MVar SynthState -> IO ()
audioLoop stateVar = forever $ do
  chunk <- renderFrame stateVar
  BL.putStr chunk
  threadDelay 9000 -- Sync audio rendering frame rate

main :: IO ()
main = do
  hPutStrLn stderr "=== Polyphonic Memory-Fault Ambient Synthesizer ==="
  hPutStrLn stderr "Pipe PCM output to sound player. Example:"
  hPutStrLn stderr "  runhaskell Main.hs | ffplay -f s16le -ar 44100 -ac 1 -"
  hPutStrLn stderr "  runhaskell Main.hs | aplay -f S16_LE -r 44100 -c 1"
  hPutStrLn stderr "Synthesizing real-time telemetry..."

  stateVar <- newMVar (SynthState [] 0.5)
  _ <- forkIO (telemetryLoop stateVar)
  audioLoop stateVar