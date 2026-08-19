import Sound.ALUT (withProgName, createBuffer, File(..), SoundSource(..), sourceBuffer, play)
import Graphics.UI.GLUT
import Data.StateVar
import Data.Complex
import Numeric.Transform.Fourier.FFT (fft)
import System.Environment (getArgs)
import System.Exit (exitWith, ExitCode(..))
import Control.Concurrent (forkIO, threadDelay)
import Data.IORef

-- Represents synthesized spectral audio features for dynamic visualization
data AudioFeatures = AudioFeatures
  { bassEnergy  :: !GLfloat  -- Drives structural growth scaling
  , midEnergy   :: !GLfloat  -- Drives phyllotaxis / leaf angle rotation
  , highEnergy  :: !GLfloat  -- Drives petal color palette evolution
  }

-- Compute FFT-based spectral energy bands from PCM audio samples
extractFeatures :: [Float] -> AudioFeatures
extractFeatures samples = AudioFeatures bass mid high
  where
    complexSamples = map (:+ 0) samples
    spectrum       = map magnitude (fft complexSamples)
    len            = length spectrum
    (bBand, rest)  = splitAt (len `div` 8) spectrum
    (mBand, hBand) = splitAt (len `div` 4) rest
    avg xs         = if null xs then 0 else sum xs / fromIntegral (length xs)
    bass           = realToFrac (avg bBand) * 2.0
    mid            = realToFrac (avg mBand) * 5.0
    high           = realToFrac (avg hBand) * 10.0

-- Render 3D procedural fractal plant recursively using dynamic audio traits
drawPlant :: Int -> GLfloat -> GLfloat -> AudioFeatures -> IO ()
drawPlant 0 _ _ _ = return ()
drawPlant depth len radius feat = preservingMatrix $ do
  -- Dynamic dynamic coloration driven by dynamic high frequencies
  let r = 0.2 + 0.8 * sin (highEnergy feat + fromIntegral depth * 0.5)
      g = 0.5 + 0.5 * cos (bassEnergy feat * 0.2)
      b = 0.3 + 0.7 * sin (midEnergy feat + fromIntegral depth)
  materialDiffuse Front $= Color4 r g b 1.0

  -- Draw trunk segment
  renderObject Solid (Cylinder radius (len * (1.0 + 0.2 * bassEnergy feat)) 8 8)
  translate (Vector3 0 0 (len :: GLfloat))

  -- Draw leaf/petal structure at recursive nodes
  preservingMatrix $ do
    scale 0.3 (0.8 + 0.2 * bassEnergy feat) 0.3
    color (Color3 r g b)
    renderObject Solid (Sphere 0.5 10 10)

  -- Branch out recursively using phyllotaxis angles modified by mid frequencies
  let phi = 137.5 + midEnergy feat * 10.0
      branches = 3
  mapM_ (\i -> preservingMatrix $ do
            rotate (phi * fromIntegral i) (Vector3 0 0 1 :: Vector3 GLfloat)
            rotate (25.0 + 5.0 * bassEnergy feat) (Vector3 1 0 0 :: Vector3 GLfloat)
            drawPlant (depth - 1) (len * 0.7) (radius * 0.65) feat
        ) [1..branches]

display :: IORef AudioFeatures -> GLfloat -> IO ()
display featRef rot = do
  clear [ColorBuffer, DepthBuffer]
  loadIdentity
  translate (Vector3 0.0 (-1.5) (-6.0) :: Vector3 GLfloat)
  rotate rot (Vector3 0 1 0 :: Vector3 GLfloat)
  
  feat <- readIORef featRef
  drawPlant 4 1.2 0.1 feat
  
  swapBuffers

idle :: IORef AudioFeatures -> IORef GLfloat -> DisplayCallback
idle featRef rotRef = do
  rotRef $~ (+ 0.5)
  postRedisplay Nothing

main :: IO ()
main = do
  args <- getArgs
  let fileName = if null args then "audio.wav" else head args

  featRef <- newIORef (AudioFeatures 0 0 0)
  rotRef  <- newIORef 0

  -- Initialize GLUT display
  _ <- getArgsAndInitialize
  initialDisplayMode $= [DoubleBuffered, RGBMode, DepthMode]
  initialWindowSize  $= Size 800 600
  _ <- createWindow "Procedural Audio Fractal Plant"

  depthFunc $= Just Less
  lighting  $= Enabled
  light (Light 0) $= Enabled
  position (Light 0) $= Vertex4 2.0 4.0 2.0 1.0
  ambient (Light 0)  $= Color4 0.2 0.2 0.2 1.0

  matrixMode $= Projection
  loadIdentity
  perspective 45.0 (800.0 / 600.0) 0.1 100.0
  matrixMode $= Modelview 0

  -- Play audio stream and continually extract dynamic features
  _ <- forkIO $ withProgName $ \p -> do
    buf <- createBuffer (File fileName)
    src <- genObjectName
    sourceBuffer src $= Just buf
    play [src]
    
    -- Mock dynamic FFT loop reading frequencies over time
    let simulateAudioStream t = do
          let dummySamples = [sin (fromIntegral i * 0.05 + t) | i <- [1..512 :: Int]]
          let f = extractFeatures dummySamples
          writeIORef featRef f
          threadDelay 30000
          simulateAudioStream (t + 0.1)
    simulateAudioStream 0.0

  displayCallback $= display featRef 0
  idleCallback    $= Just (idle featRef rotRef)
  mainLoop