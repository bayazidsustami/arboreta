{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards #-}

-- A minimal yet functional prototype that
--  * captures webcam frames (opencv)
--  * extracts a simple dominant colour (average)
--  * maps the colour to a MIDI note (custom scale)
--  * outputs a scrolling Braille mosaic to the terminal
--  * plays the note via the system beep (simple fallback)

import qualified OpenCV as CV
import qualified OpenCV.VideoIO as CV
import qualified OpenCV.Core.Types as CV
import qualified OpenCV.TypeLevel as CV
import qualified Data.Vector as V
import qualified Data.Word as W
import qualified Data.ByteString as BS
import System.IO (hSetBuffering, BufferMode(NoBuffering), stdout)
import Control.Monad (when, void, forever)
import Control.Concurrent (threadDelay, forkIO, MVar, newMVar, modifyMVar_, readMVar)
import System.Console.ANSI (clearScreen, setCursorPosition)

-- Braille Unicode block starts at 0x2800.
brailleBase :: Int
brailleBase = 0x2800

-- Simple 2‑row, 4‑column Braille cell pattern.
type BrailleRow = [Bool]   -- 4 dots per column, 2 rows => 8 bits

-- Convert a list of 8 Booleans to a Braille character.
brailleChar :: [Bool] -> Char
brailleChar bits = toEnum $ brailleBase + bitsToInt bits
  where
    bitsToInt = foldl (\acc b -> acc*2 + if b then 1 else 0) 0 . reverse

-- Custom scale: C D E F G A B (MIDI notes 60‑66)
scale :: [Int]
scale = [60,62,64,65,67,69,71]

-- Map an RGB colour to a note index (0‑6) by luminance.
colourToNote :: (W.Word8,W.Word8,W.Word8) -> Int
colourToNote (r,g,b) = floor $ (luma / 255) * fromIntegral (length scale - 1)
  where
    luma = 0.2126 * fromIntegral r + 0.7152 * fromIntegral g + 0.0722 * fromIntegral b

-- Play a note using the system beep (very crude).
playNote :: Int -> IO ()
playNote midi = void $ CV.system $ "play -n synth 0.2 sine " ++ show (midiFreq midi) ++ " >/dev/null 2>&1"
  where
    midiFreq n = 440 * (2 ** ((fromIntegral n - 69) / 12))

-- Generate a Braille cell from the note (simple visual encoding).
noteToBraille :: Int -> BrailleRow
noteToBraille n = map (testBit n) [0..7]   -- use note bits as dot pattern

-- Main loop: capture, process, render, sound.
main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  cam <- CV.newVideoCapture 0 CV.VideoCaptureAny
  ok  <- CV.isOpened cam
  when (not ok) $ error "Cannot open webcam"
  mosaicVar <- newMVar ([] :: [Char])   -- scrolling line of Braille chars
  _ <- forkIO $ forever $ do
        frame <- CV.read cam
        case frame of
          Nothing -> return ()
          Just img -> do
            avgCol <- averageColour img
            let noteIdx = colourToNote avgCol
                midi    = scale !! noteIdx
                cell    = brailleChar $ noteToBraille noteIdx
            modifyMVar_ mosaicVar $ \xs -> return $ take 80 (xs ++ [cell])
            playNote midi
            threadDelay 200000   -- 5 fps
  forever $ do
        clearScreen
        setCursorPosition 0 0
        mosaic <- readMVar mosaicVar
        putStrLn mosaic
        threadDelay 50000

-- Compute the average colour of an image (BGR order from OpenCV).
averageColour :: CV.Mat ('CV.S '[ 'CV.Height, 'CV.Width]) ('CV.S 3) ('CV.S CV.Word8) -> IO (W.Word8,W.Word8,W.Word8)
averageColour mat = do
  let (h,w) = CV.matSize mat
      total = fromIntegral (h * w) :: Double
      (bSum,gSum,rSum) = CV.foldl' (\(b,g,r) pix ->
                         let [b',g',r'] = CV.toList pix
                         in (b + fromIntegral b', g + fromIntegral g', r + fromIntegral r')) (0,0,0) mat
  return (round $ bSum/total, round $ gSum/total, round $ rSum/total)