{-|
  A self‑contained Haskell program that:

  * Captures audio from the default input device.
  * Performs an FFT on short windows to find the dominant frequency.
  * Detects beats by simple energy‑based thresholding.
  * Uses the dominant frequency to mutate an L‑system grammar.
  * Renders the current L‑system as a mandala‑like fractal with Diagrams.
  * Saves a high‑resolution PNG every time a beat is detected.

  Build with: @cabal install portaudio dsp fftw diagrams-cairo@ or the
  equivalent @stack@ setup.  The program needs the PortAudio runtime
  libraries installed on the system.

  The implementation favours clarity and compactness over production‑grade
  robustness – it is meant as a demonstrator rather than a polished
  application.
-}
module Main where

import Control.Concurrent       (threadDelay, forkIO, killThread)
import Control.Monad            (forever, when, void)
import Data.Complex             (magnitude)
import Data.List                (maximumBy)
import Data.Ord                 (comparing)
import Data.Time.Clock          (getCurrentTime, diffUTCTime)
import System.Directory         (createDirectoryIfMissing)
import System.FilePath          ((</>))
import System.IO                (hSetBuffering, BufferMode(NoBuffering), stdout)

import qualified Sound.PortAudio as PA
import qualified Numeric.FFT.Vector.Unnormalized as FFT
import qualified Data.Vector.Storable as VS
import qualified Data.Vector as V

import Diagrams.Prelude
import Diagrams.Backend.Cairo (Cairo, renderCairo)

-- Audio parameters ----------------------------------------------------------

sampleRate :: Double
sampleRate = 44100          -- Hz

frameSize :: Int
frameSize = 2048           -- samples per FFT

-- Simple beat detection -----------------------------------------------------

energyThreshold :: Double
energyThreshold = 1.5     -- factor above moving average

type EnergyHistory = [Double]   -- last N energies

historyLength :: Int
historyLength = 43            -- ~1 second at 23 ms frames

-- L‑system ------------------------------------------------------------------

type Symbol = Char
type Rules  = Symbol -> Symbol

baseAxiom :: String
baseAxiom = "F"

-- Produce a new rule set from a dominant frequency (0‑20000 Hz)
freqToRules :: Double -> Rules
freqToRules f = \c -> case c of
    'F' -> if f < 400 then "F[+F]F[-F]F"
         else if f < 800 then "F[+F]F"
         else if f < 1200 then "F[-F]F"
         else "F"
    '+' -> "+"
    '-' -> "-"
    '[' -> "["
    ']' -> "]"
    _   -> [c]

-- Expand the L‑system a given number of iterations
expand :: Rules -> Int -> String -> String
expand _ 0 s = s
expand r n s = expand r (n-1) (concatMap r s)

-- Interpret the string as turtle graphics commands ---------------------------

type TurtleState = (P2 Double, Double)   -- position, heading in radians

turtleStep :: Double -> TurtleState -> Char -> TurtleState
turtleStep step (pos, ang) cmd = case cmd of
    'F' -> (pos .+^ (r2 (step * cos ang, step * sin ang)), ang)
    '+' -> (pos, ang + turn)
    '-' -> (pos, ang - turn)
    _   -> (pos, ang)
  where turn = pi/6   -- 30°

renderMandala :: String -> Diagram B
renderMandala str = mconcat $ map drawSegment (zip (scanl step initState cmds) cmds)
  where
    step st c = turtleStep 5 st c
    initState = ((0,0), 0)
    cmds = filter (`elem` "F+-") str
    drawSegment ((p,_), c) = case c of
      'F' -> fromVertices [p, p .+^ r2 (5 * cos a, 5 * sin a)]
             # lc green # lwG 0.5
        where a = angleBetween p (p .+^ r2 (5 * cos a, 5 * sin a))
      _   -> mempty

-- Audio capture -------------------------------------------------------------

bufferSize :: Int
bufferSize = frameSize

audioCallback :: PA.StreamCallback Double Double
audioCallback _ input _ _ = do
    let vec = VS.convert $ PA.inputBuffer input
    pure $ PA.CallbackResultContinue vec

-- Helper: compute dominant frequency from a window -------------------------

dominantFreq :: VS.Vector Double -> Double
dominantFreq samples =
    let fftRes = FFT.fft $ VS.map (:+ 0) samples
        mags   = VS.map magnitude fftRes
        maxIdx = VS.maxIndex mags
        bin    = fromIntegral maxIdx
    in bin * sampleRate / fromIntegral (VS.length samples)

-- Energy of a frame ---------------------------------------------------------

frameEnergy :: VS.Vector Double -> Double
frameEnergy v = VS.sum $ VS.map (\x -> x*x) v / fromIntegral (VS.length v)

-- Main -----------------------------------------------------------------------

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    createDirectoryIfMissing True "mandalas"

    -- initialise PortAudio
    PA.withDefaultStream (PA.StreamSpec 0 1 sampleRate bufferSize) Nothing audioCallback $ \stream -> do
        putStrLn "Listening..."
        PA.startStream stream

        let loop hist rules n = do
                -- read a frame
                buf <- PA.readStream stream bufferSize
                let samples = VS.fromList $ map realToFrac buf
                    energy  = frameEnergy samples
                    dominant = dominantFreq samples

                -- update energy history
                let hist' = take historyLength $ energy : hist
                    avgE  = sum hist' / fromIntegral (length hist')
                    beat  = energy > energyThreshold * avgE

                -- mutate rules on each frame
                let rules' = freqToRules dominant

                when beat $ do
                    let iter = 5 + (floor $ dominant / 200) `mod` 4
                        ax   = expand rules' iter baseAxiom
                        dia  = renderMandala ax # bg white # pad 1.1
                    t <- getCurrentTime
                    let fname = "mandalas" </> ("mandala_" ++ show (round $ utcTimeToPOSIXSeconds t) ++ ".png")
                    renderCairo fname (500,500) dia
                    putStrLn $ "Saved " ++ fname

                threadDelay 20000  -- ~20 ms per loop
                loop hist' rules' (n+1)

        loop [] (freqToRules 0) 0
        PA.stopStream stream

-- Helper to convert UTCTime to seconds since epoch
utcTimeToPOSIXSeconds :: RealFrac a => a -> a
utcTimeToPOSIXSeconds = realToFrac . toRational . (`diffUTCTime` read "1970-01-01 00:00:00 UTC") . realToFrac

-}