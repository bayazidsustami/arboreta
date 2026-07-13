import Control.Concurrent
import Control.Concurrent.MVar
import Control.Monad (when, void, forever)
import Data.Bits ((.|.))
import Data.Word (Word8)
import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS
import Foreign.C.Types (CInt)
import Graphics.OpenCV
import qualified Sound.PortMidi as PM
import Graphics.Gloss
import Graphics.Gloss.Data.Color
import System.Exit (exitFailure)

-- | Simple harmonic minor scale starting at C4 (MIDI 60)
scale :: [Int]
scale = [0,2,3,5,7,8,10,12]  -- semitone offsets

-- Map a hue (0-360) to a MIDI note in the scale across several octaves
hueToMidi :: Double -> Int
hueToMidi hue =
  let base = 60  -- C4
      octave = floor (hue / 60)      -- 0..5
      degree = floor ((hue - fromIntegral (octave*60)) / 8.5714) `mod` length scale
  in base + octave*12 + scale !! degree

-- Extract average hue from a frame (HSV)
averageHue :: Mat ('S '[ 'D, 'D]) ('S 3) ('S Word8) -> IO Double
averageHue img = do
    hsv <- cvtColor img BGR HSV
    let (rows, cols) = matSize hsv
        total = fromIntegral (rows * cols) :: Double
    hChannel <- splitChannels hsv >>= (\vs -> pure $ vs !! 0)
    vals <- VS.toList <$> unsafeFreezeMat hChannel
    let sumHue = fromIntegral (sum (map fromIntegral vals)) :: Double
    pure $ sumHue / total  -- average hue 0..179, scale to 0..360
  where
    splitChannels = (>>= V.toList . V.mapM unsafeCoerceMat) . csplitChannels

-- Play a MIDI note with given velocity
playMidi :: PM.Stream -> Int -> Int -> IO ()
playMidi stream note vel = do
    let msg = PM.PMEvent (PM.PMMsg 0x90 (fromIntegral note) (fromIntegral vel)) 0
    void $ PM.writeShort stream msg
    threadDelay 200000  -- 200 ms note length
    let off = PM.PMEvent (PM.PMMsg 0x80 (fromIntegral note) 0) 0
    void $ PM.writeShort stream off

-- Visualizer state
data Vis = Vis { angle :: Float, depth :: Int, amp :: Float }

-- Draw fractal tree based on amplitude
drawTree :: Vis -> Picture
drawTree v = translate (-400) (-300) $ color white $ drawBranch 0 0 (degToRad (angle v)) (depth v) (amp v)
  where
    degToRad a = a * pi / 180
    drawBranch x y a d aamp
      | d <= 0 = mempty
      | otherwise =
          let len = 20 + aamp * 100
              x' = x + len * cos a
              y' = y + len * sin a
              branch = line [(x,y),(x',y')]
              left  = drawBranch x' y' (a - 0.3) (d-1) (aamp*0.7)
              right = drawBranch x' y' (a + 0.3) (d-1) (aamp*0.7)
          in pictures [branch, left, right]

-- Main loop: capture, process, audio, update visualizer
main :: IO ()
main = do
    -- Init webcam
    cap <- newVideoCapture 0 >>= \c -> maybe (putStrLn "Cannot open camera" >> exitFailure) pure c
    -- Init MIDI
    PM.initialize
    nDevices <- PM.countDevices
    when (nDevices == 0) $ putStrLn "No MIDI devices found"
    stream <- PM.openOutput 0 PM.defaultStreamConfig
    -- Shared amplitude for visualization
    ampVar <- newMVar 0.0
    -- Audio thread
    _ <- forkIO $ forever $ do
        a <- readMVar ampVar
        let vel = max 30 (min 127 (floor (a * 127)))
        playMidi stream 60 vel  -- constant note C4, velocity from amp
    -- Gloss window
    let render vis = drawTree vis
        update _ = return ()  -- no time-stepped changes
        handle _ = return ()
    forkIO $ forever $ do
        ok <- videoCaptureGrab cap
        when ok $ do
            frame <- videoCaptureRetrieve cap
            hue <- averageHue frame
            let midiNote = hueToMidi (hue * 2)  -- scale hue 0..360
            playMidi stream midiNote 100
            let amplitude = fromIntegral (abs (hue - 90)) / 90  -- dummy amp
            swapMVar ampVar amplitude
            threadDelay 33000  -- ~30 FPS
    let initVis = Vis { angle = 90, depth = 10, amp = 0 }
    glossLoop initVis render handle update

-- Simple Gloss loop with mutable state
glossLoop :: Vis -> (Vis -> Picture) -> (Event -> IO ()) -> (Float -> IO Vis) -> IO ()
glossLoop initVis draw handle update = do
    visVar <- newMVar initVis
    let display = InWindow "Synesthetic Visualizer" (800,600) (100,100)
    playIO display black 60 (readMVar visVar) draw (\e _ -> handle e >> return ()) (\dt _ -> update dt)
    
-- Helper to open video capture
newVideoCapture :: Int -> IO (Maybe VideoCapture)
newVideoCapture idx = do
    cap <- videoCapture idx
    isOpened <- videoCaptureIsOpened cap
    pure $ if isOpened then Just cap else Nothing