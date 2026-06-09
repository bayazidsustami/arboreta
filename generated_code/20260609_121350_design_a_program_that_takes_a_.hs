import qualified Graphics.UI.GLUT                as GLUT
import qualified Graphics.Gloss                 as G
import qualified Graphics.Gloss.Interface.IO.Game as GI
import qualified OpenCV                         as CV
import qualified OpenCV.VideoCapture            as VC
import qualified OpenCV.VideoIO                 as VIO
import qualified OpenCV.Core.Image              as CI
import qualified OpenCV.Core.Types.Mat          as CM
import qualified Data.Vector.Storable           as VS
import qualified Sound.PortAudio                as PA
import qualified Data.IORef                     as IR
import System.Exit (exitSuccess)
import Data.Word (Word8)
import Data.List (sortOn)
import Control.Monad (void, when, forever)
import Control.Concurrent (forkIO, threadDelay)

-- | State of the program
data State = State
  { mandalaAngle :: Float          -- current rotation
  , mandalaScale :: Float          -- current scale
  , audioFreq    :: Double         -- frequency of last dominant color
  , audioPhase   :: Double         -- phase for sine wave generation
  , mousePos     :: (Int,Int)      -- last mouse position
  }

-- Microtonal scale (just a simple 12‑note equal‑tempered scale stretched over one octave)
microScale :: [Double]
microScale = [440 * (2 ** (n/12)) | n <- [0..11]]  -- A4 = 440 Hz as base

-- Map a dominant color (R,G,B) to a frequency from the microtonal scale
colorToFreq :: (Int,Int,Int) -> Double
colorToFreq (r,g,b) = microScale !! idx
  where idx = ((r + g + b) `mod` 12)

-- Compute average color of an OpenCV Mat (very rough dominant color)
avgColor :: CM.Mat ('CV.S '[h,w]) ('CV.S 3) ('CV.S Word8) -> (Int,Int,Int)
avgColor mat = (fromIntegral r, fromIntegral g, fromIntegral b)
  where
    vec = CM.toVector mat
    (r,g,b) = VS.foldl' (\(sr,sg,sb) px ->
                let (b',g',r') = CV.unVec3 px
                in (sr + fromIntegral r', sg + fromIntegral g', sb + fromIntegral b')) (0,0,0) vec
    cnt = VS.length vec
    r = r `div` cnt
    g = g `div` cnt
    b = b `div` cnt

-- Audio callback: fill buffer with a sine wave at the given frequency
audioCallback :: IR.IORef State -> PA.StreamCallback PA.StreamFloat PA.StreamFloat
audioCallback ref _ _ outFrames _ = do
  st <- IR.readIORef ref
  let freq = audioFreq st
      phase = audioPhase st
      sampleRate = 44100
      len = VS.length outFrames
      samples = [ sin (2 * pi * freq * (fromIntegral i / sampleRate) + phase) | i <- [0..len-1] ]
  VS.copy outFrames (VS.fromList samples)
  let newPhase = phase + 2 * pi * freq * fromIntegral len / sampleRate
  IR.modifyIORef' ref (\s -> s { audioPhase = newPhase })
  return PA.Continue

-- Grab frames from webcam, compute dominant color and update state
videoThread :: IR.IORef State -> VC.VideoCapture -> IO ()
videoThread ref cap = forever $ do
  maybeFrame <- VC.read cap
  case maybeFrame of
    Nothing -> return ()
    Just frame -> do
      let rgbMat = CV.cvtColor CV.bgr CV.rgb frame
          (r,g,b) = avgColor rgbMat
          f = colorToFreq (r,g,b)
      IR.modifyIORef' ref (\s -> s { audioFreq = f })
  threadDelay 30000  -- ~30 ms = ~30 fps

-- Render a simple mandala: rotating polygons whose transformation follows audio amplitude
render :: State -> G.Picture
render st = G.translate 0 0 $ G.rotate (mandalaAngle st) $ G.scale s s $ mandala
  where
    s = mandalaScale st
    mandala = G.pictures [ G.color (G.makeColorI 255 100 150 255) $ G.polygon poly
                         | i <- [0..7]
                         , let angle = fromIntegral i * 45
                               poly = [ (r * cos a, r * sin a)
                                      | j <- [0..5]
                                      , let a = angle * pi / 180 + fromIntegral j * 2 * pi / 6
                                            r = 100
                                      ] ]
    
-- Update state each tick: rotate and scale according to mouse position
update :: Float -> State -> IO State
update _dt st = return st { mandalaAngle = mandulaAngle', mandalaScale = mandulaScale' }
  where
    (mx,my) = mousePos st
    mandulaAngle' = mandalaAngle st + 0.5 * fromIntegral mx / 800
    mandulaScale' = 0.5 + 0.5 * (fromIntegral my / 600)

-- Handle mouse motion: change symmetry (here just stored)
handleEvent :: GI.Event -> State -> IO State
handleEvent (GI.EventMotion (x,y)) st = return st { mousePos = (round x, round y) }
handleEvent (GI.EventKey (GI.Char 'q') _ _ _) _ = exitSuccess
handleEvent _ st = return st

main :: IO ()
main = do
  -- Initialise webcam
  cap <- VC.openVideoCapture 0 CV.defaultCaptureProps
  maybeProp <- VC.getCaptureProp cap CV.CAP_PROP_FRAME_WIDTH
  case maybeProp of
    Nothing -> putStrLn "Cannot open webcam." >> exitSuccess
    Just _  -> return ()
  -- Initialise shared state
  stateRef <- IR.newIORef $ State 0 1 440 0 (0,0)
  -- Start audio stream
  let paSettings = PA.defaultStreamParameters
        { PA.spSampleRate = 44100
        , PA.spFramesPerBuffer = 512
        , PA.spNumChannels = 1
        }
  _ <- PA.openDefaultStream (audioCallback stateRef) paSettings
  -- Start video processing thread
  void $ forkIO $ videoThread stateRef cap
  -- Initialise Gloss window
  let display = G.InWindow "Synesthetic Mandala" (800,600) (100,100)
      bgColor = G.white
      fps = 30
  initState <- IR.readIORef stateRef
  GI.playIO display bgColor fps initState render update handleEvent