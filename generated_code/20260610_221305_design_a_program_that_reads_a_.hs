import Codec.Picture                -- image handling
import Codec.Picture.Types          -- pixel access
import Control.Concurrent           -- threads & delay
import Control.Monad                (forever, unless, when)
import Data.List                    (sortOn)
import Data.Ord                     (Down(..))
import Data.Word                    (Word8)
import System.Exit                  (exitSuccess)
import System.IO.Unsafe             (unsafePerformIO)

-- OpenCV bindings (opencv package)
import qualified OpenCV as CV
import qualified OpenCV.VideoIO as CV

-- Linear algebra for 3‑D rendering (linear package)
import Linear.V3 (V3(..))
import Linear.Metric (dot, normalize)

-- SDL2 for audio & window (sdl2 package)
import qualified SDL
import qualified SDL.Mixer as Mixer

-- | Number of dominant colors to extract per frame
paletteSize :: Int
paletteSize = 5

-- | Simple K‑means clustering on RGB pixels (very naive but fast enough for demo)
kmeans :: Int -> [(Word8,Word8,Word8)] -> [(Word8,Word8,Word8)]
kmeans k pts = go (take k pts) 0
  where
    eucl (r1,g1,b1) (r2,g2,b2) =
      sqrt $ fromIntegral $ (r1-r2)^2 + (g1-g2)^2 + (b1-b2)^2
    assign pts centers = map (\p -> snd $ minimum [(eucl p c, i) | (i,c) <- zip [0..] centers]) pts
    meanCluster pts idx = 
      let cs = [p | (p,i) <- zip pts (assign pts centers), i==idx]
          (r,g,b, n) = foldr (\(r,g,b) (sr,sg,sb,cnt) -> (sr+fromIntegral r, sg+fromIntegral g, sb+fromIntegral b, cnt+1))
                            (0,0,0,0) cs
      in if n==0 then (0,0,0) else (round $ r/ fromIntegral n,
                                    round $ g/ fromIntegral n,
                                    round $ b/ fromIntegral n)
    step centers = map (meanCluster pts) [0..k-1]
    go centers i
      | i>10 = centers
      | otherwise = let newc = step centers
                    in if newc == centers then centers else go newc (i+1)

-- | Convert a colour to a frequency (C‑major scale, 4 octaves)
colorToFreq :: (Word8,Word8,Word8) -> Double
colorToFreq (r,g,b) = baseFreq * (2 ** (fromIntegral idx / 12))
  where
    hue = fromIntegral r / 255 * 360        -- crude hue from red channel
    scale = [261.63,293.66,329.63,349.23,392.00,440.00,493.88,523.25] -- C major
    idx = round $ (hue / 360) * fromIntegral (length scale * 4)
    baseFreq = scale !! (idx `mod` length scale)

-- | Play a short tone for a given frequency using SDL Mixer
playTone :: Double -> IO ()
playFreq :: Double -> IO ()
playFreq f = void $ Mixer.playChannel (-1) tone 0
  where
    -- generate a 0.2s sine wave buffer
    sampleRate = 44100
    len = floor $ 0.2 * fromIntegral sampleRate
    tone = Mixer.loadWAV $ unsafePerformIO $ do
      let sinWave i = floor $ 32767 * sin (2*pi * f * fromIntegral i / fromIntegral sampleRate) :: Int16
          wav = SDL.AudioSpec (SDL.Frequency sampleRate) SDL.Signed16BitLittleEndian SDL.Stereo 4096
      pure $ Mixer.Chunk wav (map sinWave [0..len-1])

-- | Produce a simple fractal height map from colour values
fractalHeight :: (Word8,Word8,Word8) -> Double -> Double
fractalHeight (r,g,b) t = 
  let c = fromIntegral (r + g + b) / (3*255)
  in sin (t*0.5) * c + cos (t*0.3) * (1-c)

-- | Render a point cloud representing the fractal landscape
renderLandscape :: [(Word8,Word8,Word8)] -> Double -> SDL.Renderer -> IO ()
renderLandscape palette t renderer = do
  let width = 800; height = 600
  SDL.clear renderer
  mapM_ (drawPoint renderer width height) (zip [0..] palette)
  SDL.present renderer
  where
    drawPoint rend w h (i,(r,g,b)) = do
      let x = fromIntegral i / fromIntegral (length palette) * fromIntegral w
          y = fromIntegral h/2 + fractalHeight (r,g,b) t * 100
          col = SDL.V4 r g b 255
      SDL.rendererDrawColor rend SDL.$= col
      SDL.drawPoint rend (SDL.P (SDL.V2 (round x) (round y)))

main :: IO ()
main = do
  -- initialise video capture
  cam <- CV.newVideoCapture 0 CV.VideoCaptureProperties
  ok <- CV.videoCaptureIsOpened cam
  unless ok $ putStrLn "Cannot open webcam" >> exitSuccess

  -- initialise SDL window and audio
  SDL.initialize [SDL.InitVideo, SDL.InitAudio]
  Mixer.openAudio Mixer.defaultAudio 44100 Mixer.AudioS16Sys 2 4096
  window <- SDL.createWindow "Synesthetic Fractal" SDL.defaultWindow {SDL.windowInitialSize = SDL.V2 800 600}
  renderer <- SDL.createRenderer window (-1) SDL.defaultRenderer

  let loop t = do
        frame <- CV.videoCaptureRead cam
        when (null frame) $ putStrLn "Empty frame" >> exitSuccess
        -- convert to JuicyPixels Image
        img <- CV.convertMat frame >>= CV.exposeImage
        let pixels = [ (r,g,b) | CV.PixelRGB r g b <- CV.unpackRGB img ]
            palette = take paletteSize $ sortOn Down $ kmeans paletteSize pixels
        mapM_ (playTone . colorToFreq) palette
        renderLandscape palette t renderer
        -- handle quit event
        events <- SDL.pollEvents
        let quit = any (\e -> case SDL.eventPayload e of
                                 SDL.QuitEvent -> True
                                 SDL.KeyboardEvent k -> SDL.keyboardEventKeyMotion k == SDL.Pressed &&
                                                        SDL.keysymKeycode (SDL.keyboardEventKeysym k) == SDL.KeycodeEscape) events
        unless quit $ loop (t+0.016)

  loop 0
  SDL.destroyRenderer renderer
  SDL.destroyWindow window
  Mixer.closeAudio
  SDL.quit