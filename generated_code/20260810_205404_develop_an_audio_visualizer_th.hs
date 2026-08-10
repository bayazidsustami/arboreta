-- Gregorian Thermal Audio Visualizer
-- Translates live CPU heat maps and memory pressure into multi-phonic Gregorian chant.
-- Thermal throttling triggers key changes; memory leaks create haunting cathedral echoes.

import System.IO
import Data.Word
import Data.Int
import Data.List
import Text.Printf
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Builder as BB
import qualified Data.Sequence as Seq
import Data.Sequence (ViewL(..), (|>))

-- Audio sampling parameters
sampleRate :: Double
sampleRate = 44100.0

totalDuration :: Double
totalDuration = 20.0 -- seconds of synthesized chant

-- Modal Scale: D Dorian mode ratios (Root, 2nd, Minor 3rd, 4th, 5th, 6th, Minor 7th, Octave)
dorianRatios :: [Double]
dorianRatios = [1.0, 1.125, 1.2, 1.3333, 1.5, 1.6, 1.8, 2.0]

-- Additive Formant Synthesis modeling vocal "Aah/Ooh" Gregorian chant resonance
vocalFormant :: Double -> Double -> Double
vocalFormant freq t =
  let harmonics = [(1, 1.0), (2, 0.65), (3, 0.45), (4, 0.25), (5, 0.12), (6, 0.05)]
      vowel     = sum [ amp * sin (2 * pi * (freq * fromIntegral h) * t) | (h, amp) <- harmonics ]
      vibrato   = 1.0 + 0.006 * sin (2 * pi * 5.2 * t) -- Gentle liturgical vibrato
  in vowel * vibrato

-- Haunting Acoustic Echo Chamber (Comb/Delay filter simulating memory leak pressure)
-- High memory usage increases delay length and feedback, transforming space into a cathedral.
applyCathedralEcho :: Double -> [Double] -> [Double]
applyCathedralEcho memRatio samples =
  let delaySamples = max 1 (floor ((0.20 + memRatio * 0.75) * sampleRate))
      feedback     = min 0.95 (0.35 + memRatio * 0.58)
      initialBuf   = Seq.replicate delaySamples 0.0
  in echoLoop feedback initialBuf samples
  where
    echoLoop _ _ [] = []
    echoLoop fb buf (x:xs) =
      case Seq.viewl buf of
        Seq.EmptyL -> []
        d :< rest ->
          let outSample = x + fb * d
              newBuf    = rest |> outSample
          in outSample : echoLoop fb newBuf xs

-- Maps CPU Core Temperature to ANSI 24-bit TrueColor string
ansiThermalColor :: Double -> String
ansiThermalColor t
  | t < 45.0    = "\ESC[48;2;20;60;180m\ESC[38;2;255;255;255m" -- Cold Blue
  | t < 65.0    = "\ESC[48;2;30;160;80m\ESC[38;2;0;0;0m"       -- Normal Green
  | t < 80.0    = "\ESC[48;2;230;140;20m\ESC[38;2;0;0;0m"     -- Warm Yellow
  | t < 90.0    = "\ESC[48;2;220;40;20m\ESC[38;2;255;255;255m" -- Hot Red
  | otherwise   = "\ESC[48;2;180;0;180m\ESC[38;2;255;255;255m" -- Throttling Magenta

-- Renders 4x4 CPU Thermal Map matrix and system status to stderr
renderHeatMap :: [[Double]] -> Double -> Bool -> IO ()
renderHeatMap matrix memPct isThrottled = do
  hPutStr stderr "\ESC[H\ESC[2J" -- Clear terminal screen
  hPutStrLn stderr "===================================================="
  hPutStrLn stderr "    GREGORIAN THERMAL AUDIO VISUALIZER & SYNTH      "
  hPutStrLn stderr "===================================================="
  hPutStrLn stderr "  Live Heat Map   -> Multi-phonic Gregorian Chant"
  hPutStrLn stderr "  Memory Leaks    -> Haunting Cathedral Echo Chamber"
  hPutStrLn stderr "  Throttling      -> Tritone Key Transposition\n"
  
  mapM_ (\row -> do
    let line = concatMap (\temp -> ansiThermalColor temp ++ printf " %2.1f°C " temp ++ "\ESC[0m ") row
    hPutStrLn stderr line
    ) matrix
    
  let statusStr = if isThrottled
                    then "\ESC[1;31m[CRITICAL] THERMAL THROTTLING DETECTED! KEY MODULATED TO TRITONE!\ESC[0m"
                    else "\ESC[1;32m[SYSTEM NOMINAL] Mode: D Dorian Gregorian Organum\ESC[0m"
  hPutStrLn stderr $ "\nSystem Status: " ++ statusStr
  hPutStrLn stderr $ printf "Memory Pressure (Echo Wet/Feedback): %.1f%%\n" (memPct * 100)
  hFlush stderr

-- Simulates CPU thermals and memory leak state over continuous time 't'
getSystemState :: Double -> ([[Double]], Double, Bool)
getSystemState t =
  let heat x y = 42.0 + 32.0 * sin (t * 0.4 + x + y) + 18.0 * sin (t * 1.1 + x * y)
      matrix   = [[ heat (fromIntegral r) (fromIntegral c) | c <- [1..4]] | r <- [1..4]]
      maxTemp  = maximum (map maximum matrix)
      isThrottled = maxTemp > 82.0
      memUsage = min 0.98 (0.25 + 0.03 * t + 0.1 * (1.0 + sin (t * 0.3)))
  in (matrix, memUsage, isThrottled)

-- Synthesizes multi-phonic Gregorian chant audio frame at time 't'
synthesizeFrame :: Double -> Double
synthesizeFrame t =
  let (matrix, _, isThrottled) = getSystemState t
      avgTemp  = sum (map sum matrix) / 16.0
      
      -- Fundamental frequency: D3 (146.83 Hz) or Throttled Tritone Ab3 (207.65 Hz)
      baseFreq = if isThrottled then 207.65 else 146.83
      
      -- Voice 1: Cantus Firmus (Tenor Drone)
      tenor = vocalFormant baseFreq t * 0.35
      
      -- Voice 2: Vox Organalis (Parallel 5th or 4th organum responding to avg heat)
      organumInterval = if avgTemp > 65.0 then 1.5 else 1.3333
      organum = vocalFormant (baseFreq * organumInterval) t * 0.25
      
      -- Voice 3: Melodic Chant line stepping through Dorian scale driven by thermals
      noteIdx = floor (avgTemp * 0.25) `mod` length dorianRatios
      chantRatio = dorianRatios !! noteIdx
      melodicVoice = vocalFormant (baseFreq * chantRatio * 2.0) t * 0.25
      
      -- Voice 4: High Soprano Octave Drone
      soprano = vocalFormant (baseFreq * 4.0) t * 0.10
      
      rawMix = tenor + organum + melodicVoice + soprano
  in max (-1.0) (min 1.0 rawMix)

-- Constructs 16-bit PCM RIFF WAV Header
wavHeader :: Int -> BB.Builder
wavHeader numSamples =
  let dataSize = numSamples * 2
      fileSize = 36 + dataSize
  in BB.string7 "RIFF"
  <> BB.word32LE (fromIntegral fileSize)
  <> BB.string7 "WAVEfmt "
  <> BB.word32LE 16
  <> BB.word16LE 1
  <> BB.word16LE 1
  <> BB.word32LE (floor sampleRate)
  <> BB.word32LE (floor sampleRate * 2)
  <> BB.word16LE 2
  <> BB.word16LE 16
  <> BB.string7 "data"
  <> BB.word32LE (fromIntegral dataSize)

-- Convert sample float (-1.0 to 1.0) into 16-bit Little-Endian PCM builder
sampleToWord16 :: Double -> BB.Builder
sampleToWord16 s =
  let val :: Int16
      val = floor (s * 32000.0)
  in BB.int16LE val

main :: IO ()
main = do
  let numSamples = floor (totalDuration * sampleRate)
      timeSteps  = [fromIntegral i / sampleRate | i <- [0 .. numSamples - 1]]
      
      -- Step 1: Synthesize Gregorian Multi-phonic Audio
      rawSamples = map synthesizeFrame timeSteps
      
      -- Step 2: Apply Acoustic Echo Chamber driven by Memory Pressure
      (_, finalMem, _) = getSystemState (totalDuration * 0.6)
      processedSamples = applyCathedralEcho finalMem rawSamples
      
      -- Step 3: Display ANSI CPU Heatmap visualizer preview on terminal (stderr)
      (sampleMatrix, memPct, throttled) = getSystemState 12.0
      
  renderHeatMap sampleMatrix memPct throttled
  
  -- Step 4: Stream 16-bit WAV PCM Audio data directly to stdout
  let headerBuilder  = wavHeader numSamples
      sampleBuilders = BB.toLazyByteString $ mconcat (map sampleToWord16 processedSamples)
      fullWav        = BB.toLazyByteString headerBuilder <> sampleBuilders
      
  BL.hPut stdout fullWav
  hFlush stdout