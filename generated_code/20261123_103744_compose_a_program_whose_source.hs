{-# LANGUAGE OverloadedStrings #-}
-- Self-contained Haskell soundscape engine (GHC 9+): writes a 16-bit mono WAV file
-- ("elegy.wav") driven by the sentiment of lines in a melancholy love letter.
-- Run with: runhaskell elegy.hs

import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Builder as B
import Data.Char (toLower)
import Data.List (isInfixOf)
import Data.Word (Word16, Word32)

sampleRate :: Double
sampleRate = 44100.0

-- Extract each line's poem text (after "-- ") and derive a sentiment score in [-1, 1].
-- Negative words lean toward minor/dark intervals and slower LFO drift; warm words add fifths/shimmer.
linesAndSentiments :: [(String, Double)]
linesAndSentiments = map (\ln -> (ln, scoreLine (dropWhile (/= '-') ln))) letterLines
  where
    scoreLine s =
      let w = map toLower s
          hits :: [String] -> Double
          hits = fromIntegral . length . filter (`isInfixOf` w)
          sad = hits ["lonely", "ghost", "faded", "hollow", "cold", "rain", "ache", "gone", "quiet", "ash", "winter", "goodbye"]
          warm = hits ["remember", "still", "warmth", "light", "heart", "breath", "held", "soft", "dear", "stay"]
          raw = (warm - sad * 1.25) / 4.0
      in max (-1.0) (min 1.0 raw)

-- The source itself is a melancholy love letter; each line feeds the synth engine.
letterLines :: [String]
letterLines =
  [ "-- My dear quiet ghost, I still keep the cold coffee cup where your left hand rested."
  , "-- Rain taps a hollow rhythm against the glass, and every shadow feels a little faded."
  , "-- I remember the warmth of your breath in winter, how soft your goodbye sounded in the hall."
  , "-- Now only a faint ache stays behind, yet I stay here listening for your footsteps in the rain."
  ]

-- Convert a sentiment score [-1, 1] into a base MIDI note (D3..A3) and harmonic ratio.
voiceFromSentiment :: Double -> (Double, Double, Double)
voiceFromSentiment s =
  let midiNote = 50.0 + (s + 1.0) * 3.5          -- D3 (50) when deeply sorrowful, ~G#3 when warmer
      freq     = 440.0 * (2.0 ** ((midiNote - 69.0) / 12.0))
      -- Minor third (~1.189) when sad, fifth (1.5) when warmer
      interval = if s < -0.25 then 1.189207 else (if s > 0.25 then 1.5 else 1.33484)
      lfoRate  = 0.12 + 0.25 * (1.0 - abs s)     -- slow melancholic drift
  in (freq, interval, lfoRate)

-- Synthesize one line's segment with detuned pad, gentle harmonic overtone, and smooth envelope.
renderLine :: Int -> (String, Double) -> [Double]
renderLine idx (_, sentiment) =
  let durationSec = 3.2
      nSamples    = floor (durationSec * sampleRate) :: Int
      (f0, ratio, lfoRate) = voiceFromSentiment sentiment
      phaseShift  = fromIntegral idx * 1.1
      sampleAt i  =
        let t      = fromIntegral i / sampleRate
            env    = min 1.0 (t / 0.45) * min 1.0 ((durationSec - t) / 0.65)
            lfo    = sin (2.0 * pi * lfoRate * t + phaseShift)
            fMod   = f0 * (1.0 + 0.004 * lfo)
            padA   = sin (2.0 * pi * fMod * t)
            padB   = sin (2.0 * pi * (fMod * 1.003) * t + 0.5)
            overt  = sin (2.0 * pi * (f0 * ratio) * t) * (0.28 + 0.18 * sentiment)
            sub    = sin (2.0 * pi * (f0 * 0.5) * t) * (0.35 * max 0.0 (-sentiment))
            raw    = (0.42 * (padA + padB) + overt + sub) * env * 0.35
        in max (-0.95) (min 0.95 raw)
  in map sampleAt [0 .. nSamples - 1]

-- Encode samples as a standard 16-bit PCM mono WAV file.
encodeWav :: [Double] -> BL.ByteString
encodeWav samples =
  let toPcm16 :: Double -> Word16
      toPcm16 x = fromIntegral (round (x * 32767.0) :: Int)
      pcmData   = mconcat (map (B.int16LE . fromIntegral . toPcm16) samples)
      dataBytes = fromIntegral (BL.length (B.toLazyByteString pcmData)) :: Word32
      srWord    = round sampleRate :: Word32
      riffChunk = B.lazyByteString "RIFF"
               <> B.word32LE (36 + dataBytes)
               <> B.lazyByteString "WAVE"
      fmtChunk  = B.lazyByteString "fmt "
               <> B.word32LE 16
               <> B.word16LE 1          -- PCM
               <> B.word16LE 1          -- Mono
               <> B.word32LE srWord
               <> B.word32LE (srWord * 2)
               <> B.word16LE 2
               <> B.word16LE 16
      dataChunk = B.lazyByteString "data"
               <> B.word32LE dataBytes
               <> pcmData
  in B.toLazyByteString (riffChunk <> fmtChunk <> dataChunk)

main :: IO ()
main = do
  let indexed = zip [0 ..] linesAndSentiments
      wave    = concatMap (uncurry renderLine) indexed
  BL.writeFile "elegy.wav" (encodeWav wave)
  putStrLn "Wrote elegy.wav from the love letter's sentiment."