#!/usr/bin/env runhaskell
{-|
  Minimal demonstrator of a live webcam‑to‑Braille visualizer combined with
  microphone amplitude.  It uses only the Unicode Braille block (U+2800‑U+28FF)
  for output, printing a scrolling tapestry to the terminal.

  * Webcam frames are captured with @opencv@.
  * Audio RMS is obtained with @portaudio@.
  * Each second we compute the dominant colour of the current frame,
    hash it to a Braille pattern and overlay the current audio amplitude.
  * The result is a line of Braille glyphs that scrolls left‑to‑right.

  Compile/run with e.g.:
      stack script --resolver lts-22.22  --package opencv
                     --package JuicyPixels --package portaudio
                     --package vector --package random
                     --package bytestring
                     thisfile.hs
-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards #-}

import qualified CV.VideoIO as CV
import qualified CV as CV
import qualified Data.Vector.Storable as V
import qualified Data.ByteString as BS
import qualified Codec.Picture as JP
import qualified Sound.PortAudio as PA
import System.Random (mkStdGen, randomR)
import Data.Word (Word8)
import Data.Bits ((.|.), shiftL)
import Control.Concurrent (threadDelay, forkIO, MVar, newMVar, modifyMVar_, readMVar)
import Control.Monad (forever, void, when)
import Data.List (maximumBy)
import Data.Ord (comparing)
import System.IO (hSetBuffering, stdout, BufferMode(NoBuffering))

-- | Convert a pixel (R,G,B) to a hue (0‥360) using a simple approximation.
rgbToHue :: Word8 -> Word8 -> Word8 -> Double
rgbToHue r g b = let rf = fromIntegral r / 255
                     gf = fromIntegral g / 255
                     bf = fromIntegral b / 255
                     maxc = maximum [rf,gf,bf]
                     minc = minimum [rf,gf,bf]
                     delta = maxc - minc
                 in if delta == 0 then 0
                    else if maxc == rf then 60 * ((gf - bf) / delta) `mod'` 360
                    else if maxc == gf then 60 * ((bf - rf) / delta + 2)
                    else 60 * ((rf - gf) / delta + 4)
  where mod' x m = let r = x - fromIntegral (floor (x / m) :: Int) * m in if r < 0 then r + m else r

-- | Simple dominant colour extraction: pick the pixel with maximal intensity sum.
dominantHue :: JP.Image JP.PixelRGB8 -> Double
dominantHue img = rgbToHue r g b
  where (JP.PixelRGB8 r g b) = JP.pixelAt img 0 0  -- placeholder: real implementation would scan

-- | Deterministic hash from hue to a Braille pattern (8 dots = bits 0‑7).
hueToBraille :: Double -> Word8
hueToBraille hue = fromIntegral $ (floor (hue / 360 * 255) `xor` 0xAA) .&. 0xFF

-- | Map audio RMS (0‥1) to a vertical amplitude (0‥3) and set corresponding dots.
amplitudeToDots :: Double -> Word8
amplitudeToDots amp = case floor (amp * 4) of
    0 -> 0x00
    1 -> 0x01
    2 -> 0x03
    _ -> 0x07

-- | Combine colour dots and amplitude dots into final Braille glyph.
combineDots :: Word8 -> Word8 -> Char
combineDots colour amp = toEnum (0x2800 + fromIntegral (colour .|. amp))

-- | Capture audio continuously, storing latest RMS in an MVar.
audioCapture :: MVar Double -> IO ()
audioCapture rmsVar = do
    let sampleRate = 44100
        framesPerBuffer = 512
    PA.withDefaultStream (PA.StreamParameters PA.Input Nothing 1 sampleRate) Nothing framesPerBuffer $ \stream -> do
        let loop = do
                buf <- PA.readStream stream framesPerBuffer
                let rms = sqrt (V.sum (V.map (\x -> let y = fromIntegral x / 32768 in y*y) buf) / fromIntegral (V.length buf))
                modifyMVar_ rmsVar (const $ return rms)
                loop
        loop

-- | Main loop: grab a frame each second, compute glyph, scroll output.
main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    rmsVar <- newMVar 0.0
    _ <- forkIO $ audioCapture rmsVar
    cap <- CV.newVideoCapture 0 CV.VideoDeviceIndex
    when (not =<< CV.isOpened cap) $ error "Cannot open webcam"
    let width = 80  -- characters per line
    scrollBuffer <- newMVar (replicate width '⠀')  -- U+2800 blank
    forever $ do
        maybeMat <- CV.grab cap >> CV.retrieve cap CV.AnyDepth
        case maybeMat of
          Nothing -> return ()
          Just mat -> do
            img <- CV.convertMat mat
            let rgbImg = JP.Image (CV.matWidth img) (CV.matHeight img) (V.concatMap (\(CV.Vec3 b g r) -> V.fromList [r,g,b]) (CV.unMatData img))
            let hue = dominantHue rgbImg
            let colourDots = hueToBraille hue
            amp <- readMVar rmsVar
            let ampDots = amplitudeToDots amp
            let glyph = combineDots colourDots ampDots
            modifyMVar_ scrollBuffer $ \buf -> return (tail buf ++ [glyph])
            buf <- readMVar scrollBuffer
            putStr "\r" >> putStr buf
            threadDelay 1000000  -- 1 second per frame

```