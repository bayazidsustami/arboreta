{-# LANGUAGE OverloadedStrings #-}

import Data.Bits (shiftL, (.|.))
import Data.ByteString (ByteString, pack, writeFile)
import Data.Word (Word8)
import Prelude hiding (writeFile)

-- | Represents a luminosity reading from a dying star (normalized 0.0 - 1.0).
type Luminosity = Double

-- | MIDI Note representation (0-127).
type MidiNote = Word8

-- | Translates a star's fading luminosity into a pentatonic ambient MIDI note.
-- As the star dies (luminosity decreases), the pitch shifts into deeper registers.
lumiToNote :: Luminosity -> MidiNote
lumiToNote lumi = pentatonicScale !! index
  where
    -- Dorian/Minor Pentatonic multi-octave palette: C2 to C6
    pentatonicScale = [36, 38, 41, 43, 46, 48, 50, 53, 55, 58, 60, 62, 65, 67, 70, 72, 74, 77, 79, 82, 84]
    clamped = max 0.0 (min 1.0 lumi)
    index = floor (clamped * fromIntegral (length pentatonicScale - 1))

-- | Encodes a 32-bit unsigned integer into WASM LEB128 format.
encodeLEB128 :: Int -> [Word8]
encodeLEB128 val
  | val < 128 = [fromIntegral val]
  | otherwise = fromIntegral ((val `mod` 128) .|. 128) : encodeLEB128 (val `shiftR` 7)

-- | Generates executable WebAssembly ByteString from a sequence of star luminosity data.
-- The WASM module exports a function `play(index)` returning a MIDI note frequency/pitch.
compileStarToWasm :: [Luminosity] -> ByteString
compileStarToWasm luminosities = pack $ magicHeader ++ version ++ typeSection ++ funcSection ++ exportSection ++ codeSection
  where
    magicHeader = [0x00, 0x61, 0x73, 0x6d] -- \0asm
    version     = [0x01, 0x00, 0x00, 0x00] -- version 1

    notes = map lumiToNote luminosities
    numNotes = length notes

    -- Section 1: Type Section (func [] -> [i32])
    typeSection = [0x01] ++ encodeLEB128 (length typeBody) ++ typeBody
    typeBody    = [0x01, 0x60, 0x01, 0x7f, 0x01, 0x7f] -- 1 func type: (param i32) -> (result i32)

    -- Section 3: Function Section
    funcSection = [0x03, 0x02, 0x01, 0x00] -- 1 function of type 0

    -- Section 7: Export Section (exports "play")
    exportSection = [0x07] ++ encodeLEB128 (length exportBody) ++ exportBody
    exportBody    = [0x01, 0x04] ++ map (fromIntegral . fromEnum) "play" ++ [0x00, 0x00]

    -- Section 10: Code Section (generates a switch-case pattern over the star data)
    codeSection = [0x0a] ++ encodeLEB128 (length codeBody) ++ codeBody
    codeBody    = [0x01] ++ encodeLEB128 (length funcBody) ++ funcBody

    -- WASM Function Body: branching match on index to return pitch
    funcBody = [0x00] -- local decl count
      ++ concatMap (\(idx, note) -> [ 0x20, 0x00                 -- local.get 0
                                    , 0x41 ] ++ encodeLEB128 idx  -- i32.const idx
                                  ++ [0x46]                       -- i32.eq
                                  ++ [0x04, 0x7f]                 -- if i32
                                  ++ [0x41] ++ encodeLEB128 (fromIntegral note) -- i32.const note
                                  ++ [0x0f]                       -- return
                                  ++ [0x0b]                       -- end
                   ) (zip [0..] notes)
      ++ [0x41, 0x00, 0x0b] -- default return 0, end function

-- | Historical light-curve simulation of a dying Red Giant decaying into a Supernova remnant.
dyingStarData :: [Luminosity]
dyingStarData = [0.98, 0.95, 0.91, 0.85, 0.78, 0.65, 0.40, 0.99, 0.82, 0.45, 0.20, 0.08, 0.02, 0.00]

main :: IO ()
main = do
  let wasmBytes = compileStarToWasm dyingStarData
  writeFile "star_ambient.wasm" wasmBytes
  putStrLn "Compiled dying star luminosity data into 'star_ambient.wasm'."