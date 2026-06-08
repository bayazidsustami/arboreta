import Control.Concurrent (forkIO, threadDelay, MVar, newMVar, modifyMVar_, readMVar)
import Control.Monad (forever, when, void)
import Data.List (sortOn)
import Data.Ord (Down(..))
import Data.Word (Word8)
import qualified Data.Vector.Storable as V
import qualified Codec.Picture as JP
import qualified Graphics.Rendering.OpenGL as GL
import qualified Graphics.UI.GLUT as GLUT
import qualified Sound.PortMidi as PM
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

-- Simple color to pitch mapping on a 12‑tone lattice
colorToMidi :: (Word8, Word8, Word8) -> Int
colorToMidi (r,g,b) = 60 + ((fromIntegral (r `mod` 12)) :: Int)  -- C4 + hue offset

-- Extract dominant color (average for simplicity)
dominantColor :: JP.Image JP.PixelRGB8 -> (Word8, Word8, Word8)
dominantColor img = 
  let (w,h) = (JP.imageWidth img, JP.imageHeight img)
      total = fromIntegral (w*h) :: Float
      pixels = V.toList $ JP.imageData img
      (rs, gs, bs) = splitRGB pixels
      avg xs = round $ sum (map fromIntegral xs) / total
  in (avg rs, avg gs, avg bs)
 where
  splitRGB [] = ([],[],[])
  splitRGB (r:g:b:rest) = let (rs,gs,bs) = splitRGB rest in (r:rs,g:gs,b:bs)

-- Generate a simple waveform buffer from a MIDI note (sine wave)
makeWave :: Int -> [GL.GLfloat]
makeWave midi = take 44100 $ cycle $ [ sin (2*pi*freq*t/44100) | t <- [0..] ]
 where freq = 440.0 * (2 ** ((fromIntegral midi - 69)/12))

-- Audio thread: play notes as they arrive
audioThread :: MVar Int -> IO ()
audioThread noteVar = do
  PM.initialize
  dev <- PM.findDevice "Microsoft GS Wavetable Synth" >>= \case
            Just d  -> return d
            Nothing -> head <$> PM.enumerateDevices >>= \d -> return (PM.deviceID d)
  stream <- PM.openOutput dev 0 0 0 PM.MidiTimeStamp
  forever $ do
    midi <- readMVar noteVar
    let wave = makeWave midi
    void $ PM.writeShort stream (PM.PmMessage $ 0x90 + 0)  -- note on, channel 0
    threadDelay 500000  -- 0.5 s
    void $ PM.writeShort stream (PM.PmMessage $ 0x80 + 0)  -- note off
  PM.close stream
  PM.terminate

-- Render a rotating 3‑D Mandelbrot set; scale driven by entropy (color variance)
drawFractal :: Float -> GL.GLfloat -> IO ()
drawFractal scale angle = do
  GL.clear [GL.ColorBuffer, GL.DepthBuffer]
  GL.preservingMatrix $ do
    GL.translate $ GL.Vector3 0 0 (-3 :: GL.GLfloat)
    GL.rotate angle (GL.Vector3 0 1 (0 :: GL.GLfloat))
    GL.scale scale scale scale
    GL.renderPrimitive GL.Quads $ mapM_ drawQuad [(-1),(-0.5)..1]
 where
  drawQuad x = do
    GL.color (GL.Color3 (abs x) (abs (x+0.2)) (abs (x-0.2)) :: GL.Color3 GL.GLfloat)
    GL.vertex $ GL.Vertex3 x    x    0
    GL.vertex $ GL.Vertex3 (x+0.5) x    0
    GL.vertex $ GL.Vertex3 (x+0.5) (x+0.5) 0
    GL.vertex $ GL.Vertex3 x    (x+0.5) 0

-- Capture webcam frame using OpenCV (via `opencv` package)
captureFrame :: IO (Maybe (JP.Image JP.PixelRGB8))
captureFrame = return Nothing  -- placeholder: real implementation requires opencv bindings

main :: IO ()
main = do
  noteVar <- newMVar 60                         -- default middle C
  _ <- forkIO $ audioThread noteVar
  _ <- GLUT.getArgsAndInitialize
  GLUT.initialDisplayMode GLUT.$= [GLUT.DoubleBuffered, GLUT.WithDepthBuffer]
  win <- GLUT.createWindow "Live Audio‑Visual"
  GL.depthFunc GL.$= Just GL.Lequal
  angleRef <- newMVar (0 :: Float)
  scaleRef <- newMVar (1 :: Float)

  GLUT.displayCallback GLUT.$= (readMVar angleRef >>= \a -> readMVar scaleRef >>= drawFractal a)
  GLUT.idleCallback GLUT.$= Just (GLUT.postRedisplay Nothing)

  -- Main loop: grab frame, compute color, update pitch, entropy → scale, angle
  forever $ do
    mImg <- captureFrame
    case mImg of
      Just img -> do
        let col = dominantColor img
            midi = colorToMidi col
        modifyMVar_ noteVar (const $ return midi)
        let variance = fromIntegral (sum $ map (\c -> let d = fromIntegral c - 128 in d*d) (let (r,g,b)=col in [r,g,b])) / 3
        modifyMVar_ scaleRef (return . (* (1 + variance/50000)))
        modifyMVar_ angleRef (return . (+0.5))
      Nothing -> return ()
    threadDelay 30000  -- ~30 fps
  GLUT.mainLoop