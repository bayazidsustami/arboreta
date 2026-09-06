import Control.Concurrent (threadDelay)
import Control.Monad (forever, forM_)
import Data.Char (ord)
import Numeric (showHex)
import System.IO (hFlush, stdout)

-- | Types representing our compilation pipeline steps
type Frequency = Double      -- ^ Wi-Fi frequency signal in GHz
type Note = String           -- ^ Musical pitch representation
type ColorCode = String      -- ^ ANSI visual ink representation

-- | Phase 1: Simulate reading ambient Wi-Fi frequency spectrum (2.4GHz - 5.8GHz)
sampleWiFiFrequencies :: IO [Frequency]
sampleWiFiFrequencies = do
  -- Generates pseudo-random frequency fluctuations using system time
  t <- fmap (fromIntegral . ord . head . show) getChar
  return [ 2.412 + (sin (t + i) * 0.1) | i <- [0.0, 0.5 .. 3.5] ]

-- | Phase 2: Esoteric Compilation Strategy
-- Maps Wi-Fi EM frequencies (GHz) into musical scale degrees & ink dynamics
compileFrequencyToNote :: Frequency -> Note
compileFrequencyToNote freq
  | freq < 2.42 = "C3"
  | freq < 2.44 = "E3"
  | freq < 2.46 = "G3"
  | freq < 2.48 = "B3"
  | freq < 2.50 = "D4"
  | otherwise   = "F#4"

-- | Translate musical notes into dynamic, fluid ANSI ink-wash visual gradients
noteToInkStroke :: Note -> ColorCode
noteToInkStroke note = case note of
  "C3"  -> "\ESC[38;5;234m\9608\9608"    -- Deep charcoal black
  "E3"  -> "\ESC[38;5;238m\9619\9619"    -- Dark ink wash
  "G3"  -> "\ESC[38;5;242m\9618\9618"    -- Mid-tone fluid gray
  "B3"  -> "\ESC[38;5;248m\9617\9617"    -- Soft dilute mist
  "D4"  -> "\ESC[38;5;252m\183\183"      -- Light splatter dot
  _     -> "\ESC[38;5;255m  "            -- Pure void canvas

-- | Render the compiled real-time score to standard output
renderInkCanvas :: [(Note, ColorCode)] -> IO ()
renderInkCanvas score = do
  putStr "\ESC[2K\r" -- Clear current terminal line
  forM_ score $ \(note, stroke) -> putStr (stroke ++ " ")
  hFlush stdout

-- | Main Event Loop: Real-Time EM Frequency Compiler
main :: IO ()
main = do
  putStrLn "\ESC[2J\ESC[H--- ESOTERIC WI-FI EM COMPILED INK-WASH SCORE ---"
  forever $ do
    -- 1. Sense EM Frequencies
    freqs <- sampleWiFiFrequencies
    
    -- 2. Compile Frequencies -> Music Notes -> Generative Ink Strokes
    let notes = map compileFrequencyToNote freqs
    let strokes = map noteToInkStroke notes
    let compiledScore = zip notes strokes

    -- 3. Render Fluid Ink Visuals
    renderInkCanvas compiledScore
    
    -- Rest briefly to emulate dynamic visual flow (100ms)
    threadDelay 100000