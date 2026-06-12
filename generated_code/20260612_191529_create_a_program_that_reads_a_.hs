import qualified OpenCV as CV
import qualified OpenCV.VideoCapture as VC
import qualified OpenCV.VideoIO as VIO
import qualified OpenCV.Core.Types.Mat as Mat
import qualified OpenCV.Core.Types.Size as Size
import qualified OpenCV.Core.ArrayOps as A
import qualified OpenCV.TypeLevel as TL
import qualified OpenCV.HighGui as HG
import           OpenCV (Mat, (?!))
import           Control.Monad (when, void, forever)
import           Control.Concurrent (forkIO, threadDelay, MVar, newMVar, modifyMVar_, readMVar)
import           Data.Word (Word8)
import           Data.Vector (Vector)
import qualified Data.Vector as V
import           System.Exit (exitSuccess)
import           System.Random (mkStdGen, randomRs)
import           Graphics.Gloss
import           Graphics.Gloss.Interface.IO.Game
import           Sound.PortAudio (withAudio, openDefaultStream, Stream, StreamCallbackResult(..), defaultOutputDevice, SampleRate(..), StreamDirection(..))
import qualified Sound.PortAudio as PA
import           Data.IORef

-- | Map a color (R,G,B) to a MIDI note (0..127) using a simple linear scheme.
colorToMidi :: (Int,Int,Int) -> Int
colorToMidi (r,g,b) = (r + g + b) `mod` 128

-- | Generate a pure sine wave buffer for a given frequency and duration (seconds).
sineWave :: Double -> Double -> [Float]
sineWave freq dur = [ realToFrac (sin (2 * pi * freq * t)) | n <- [0 .. samples-1]
                                                          , let t = fromIntegral n / sr ]
  where
    sr = 44100 :: Double
    samples = floor (dur * sr)

-- | Audio thread: continuously plays tones derived from the shared midi note.
audioThread :: MVar Int -> IO ()
audioThread midiVar = withAudio $ do
    let sr = SampleRate 44100
    stream <- openDefaultStream 0 1 sr 256 (audioCallback midiVar)
    PA.startStream stream
    -- keep thread alive while the main program runs
    forever $ threadDelay 1000000

audioCallback :: MVar Int -> PA.StreamCallback Double Double
audioCallback midiVar _ _ _ = do
    note <- readMVar midiVar
    let freq = 440.0 * (2 ** ((fromIntegral note - 69) / 12))
        buf  = take 256 (sineWave freq 0.1)
    return $ Continue (V.fromList buf)

-- | State shared between video, audio and graphics.
data AppState = AppState
    { midiNote :: Int               -- current midi note
    , hue      :: Float             -- hue for kaleidoscope colour
    , seed     :: [Float]           -- deterministic seed for patterns
    }

-- | Initialise application state.
initState :: IO AppState
initState = do
    let m = 60                     -- start on middle C
    let h = 0
    let g = mkStdGen 42
    let s = map (/1000) (take 1000 (randomRs (0,360) g))
    return $ AppState m h s

-- | Extract dominant colour (average) from a Mat and convert to (Int,Int,Int).
averageColor :: Mat ('CV.S '["height", "width"] 'CV.Depth8 'CV.BGR) -> IO (Int,Int,Int)
averageColor mat = do
    let sz = CV.size mat
    let (rows,cols) = (CV.unSize (CV.height sz), CV.unSize (CV.width sz))
    vals <- A.cvMatToVector mat :: IO (Vector Word8)
    let triples = V.generate (V.length vals `div` 3) $ \i ->
            let b = fromIntegral (vals V.! (3*i))
                g = fromIntegral (vals V.! (3*i+1))
                r = fromIntegral (vals V.! (3*i+2))
            in (r,g,b)
    let (sr,sg,sb,cnt) = V.foldl' (\(ar,ag,ab,n) (r,g,b) -> (ar+r, ag+g, ab+b, n+1)) (0,0,0,0) triples
    return (sr `div` cnt, sg `div` cnt, sb `div` cnt)

-- | Build a kaleidoscopic picture based on current hue and seed.
kaleidoPicture :: Float -> [Float] -> Picture
kaleidoPicture h s = Pictures $ zipWith rotSym [0..5] s
  where
    rotSym i phase = Rotate (i*60) $ Color (makeColorHSB ((h+phase)/360) 0.8 0.9) $
                     Polygon [ (x*cos a - y*sin a, x*sin a + y*cos a)
                             | (x,y) <- shape ]
    a = pi/6
    shape = [(0,0),(100,0),(80,50),(20,50)]

-- | Update function for Gloss.
update :: Float -> AppState -> IO AppState
update _ st = return st  -- graphics does not change state itself

-- | Render function for Gloss.
render :: AppState -> IO Picture
render st = return $ kaleidoPicture (hue st) (seed st)

-- | Handle events (none needed).
handle :: Event -> AppState -> IO AppState
handle (EventKey (SpecialKey KeyEsc) Down _ _) _ = exitSuccess >> return undefined
handle _ st = return st

main :: IO ()
main = do
    -- shared midi note
    midiVar <- newMVar 60
    -- start audio
    void $ forkIO $ audioThread midiVar

    -- initialise video capture
    cap <- VC.newVideoCapture 0
    VC.videoCaptureOpen cap VIO.VideoCaptureAPIS::IO ()
    VC.videoCaptureSet cap VIO.CAP_PROP_FRAME_WIDTH 320
    VC.videoCaptureSet cap VIO.CAP_PROP_FRAME_HEIGHT 240

    -- initialise app state
    st0 <- initState
    stateRef <- newIORef st0

    -- start graphics loop in separate thread
    void $ forkIO $ playIO (InWindow "KaleidoSynesthesia" (800,800) (100,100))
                         black
                         30
                         ()
                         (\_ -> readIORef stateRef >>= render)
                         (\e _ -> readIORef stateRef >>= handle e)
                         (\_ _ -> return ())

    -- main loop: read frames, update midi and visual hue
    let loop = do
            ok <- VC.videoCaptureGrab cap
            when ok $ do
                frm <- VC.videoCaptureRetrieve cap
                col <- averageColor (frm :: Mat ('CV.S '["height","width"] 'CV.Depth8 'CV.BGR))
                let note = colorToMidi col
                modifyMVar_ midiVar (\_ -> return note)
                modifyIORef' stateRef $ \st ->
                    st { midiNote = note
                       , hue = (hue st + 0.5) `mod'` 360
                       }
            threadDelay 30000   -- ≈33 FPS
            loop
    loop
```