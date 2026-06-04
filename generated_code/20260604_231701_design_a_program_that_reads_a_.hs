import Codec.Picture                 ( PixelRGB8(..), generateImage, pixelAt )
import Codec.Picture.Types           ( mutableCopy )
import Control.Concurrent            ( forkIO, threadDelay )
import Control.Monad                  ( forever, when )
import Data.List                      ( sortOn )
import Data.Ord                       ( Down(..) )
import Data.Word                      ( Word8 )
import qualified Data.Vector as V
import System.Exit                    ( exitFailure )
import System.IO.Unsafe               ( unsafePerformIO )
import Graphics.Gloss                ( Color, Gloss.Picture(..), Picture, Display(..)
                                      , black, blank, color, display, makeColor
                                      , line, lineLoop, rotate, scale, translate )
import Graphics.Gloss.Interface.IO.Game ( Event(..), PlayState(..), playIO )
import OpenCV                        as CV
import OpenCV.VideoIO                 ( VideoCapture
                                      , VideoCaptureDevice(..)
                                      , VideoCaptureProps(..)
                                      , VideoCaptureOpenMode(..)
                                      , openVideoCapture
                                      , readFrameM
                                      , vectorFromMat
                                      , withVideoCapture )
import System.Random                  ( randomRIO )
import Sound.PortAudio                (Pa, PaDevice(..), PaStream, defaultOutputDevice
                                      , openStream, startStream, writeStream, withPa)

-- | Parameters --------------------------------------------------------------

frameWidth, frameHeight :: Int
frameWidth  = 320
frameHeight = 240

paletteSize :: Int
paletteSize = 5        -- number of dominant colors to extract

-- | Mapping a color to a MIDI note (C major scale, 2 octaves) ----------------

scaleNotes :: [Int]
scaleNotes = [60,62,64,65,67,69,71,72,74,76,77,79,81,83,84] -- C4..C6

colorToNote :: PixelRGB8 -> Int
colorToNote (PixelRGB8 r g b) = scaleNotes !! idx
  where
    lum = fromIntegral r + fromIntegral g + fromIntegral b :: Int
    idx = (lum * (length scaleNotes - 1)) `div` (255*3)

-- | Simple audio synthesis: generate a short sine wave buffer for a note ----

sampleRate :: Double
sampleRate = 44100

duration :: Double
duration = 0.2   -- seconds per note

freqOfMidi :: Int -> Double
freqOfMidi n = 440.0 * 2 ** ((fromIntegral n - 69) / 12)

sineWave :: Int -> V.Vector Float
sineWave midi = V.generate nSamples (\i -> realToFrac (sin (2 * pi * freq * t i)))
  where
    freq = freqOfMidi midi
    nSamples = floor (duration * sampleRate)
    t i = fromIntegral i / sampleRate

playNote :: Pa -> Int -> IO ()
playNote pa midi = do
    let buf = sineWave midi
    stream <- openStream Nothing (Just defaultOutputDevice) 1 0 (fromIntegral sampleRate) Nothing Nothing
    startStream stream
    writeStream stream buf
    return ()

-- | Extract dominant colors using a very naive histogram ---------------------

dominantColors :: Mat ('S '[ 'D, 'D]) ('S '[3]) ('S Word8) -> IO [PixelRGB8]
dominantColors mat = do
    vec <- vectorFromMat mat
    let pixels = V.toList $ V.map (\[b,g,r] -> PixelRGB8 r g b) vec
        clustered = take paletteSize $ sortOn (Down . pixelLum) pixels
    return clustered
  where
    pixelLum (PixelRGB8 r g b) = fromIntegral r + fromIntegral g + fromIntegral b

-- | Generate a mandala segment based on a color ------------------------------

mandalaSegment :: Float -> Color -> Picture
mandalaSegment angle col =
    color col $
    rotate angle $
    lineLoop [ (cos a, sin a) | i <- [0..7], let a = 2 * pi * fromIntegral i / 8 ]

-- | Global state -------------------------------------------------------------

data State = State
    { cam        :: VideoCapture
    , paEnv      :: Pa
    , currentCol :: PixelRGB8
    , timeAcc    :: Float
    }

-- | Main loop ---------------------------------------------------------------

update :: Float -> State -> IO State
update dt st = do
    mframe <- readFrameM (cam st)
    newSt <- case mframe of
        Nothing -> return st
        Just mat -> do
            cols <- dominantColors mat
            let col = head cols
            let note = colorToNote col
            _ <- forkIO $ playNote (paEnv st) note
            return st { currentCol = col, timeAcc = timeAcc st + dt }
    return newSt

render :: State -> IO Picture
render st = do
    let PixelRGB8 r g b = currentCol st
        col = makeColor (fromIntegral r/255) (fromIntegral g/255) (fromIntegral b/255) 1
        segs = [ mandalaSegment (a * 30) col | a <- [0..11] ]
    return $ pictures segs

-- | Entry point -------------------------------------------------------------

main :: IO ()
main = do
    -- initialise webcam
    cap <- openVideoCapture
                (VideoCaptureDevice 0)
                (VideoCaptureOpenMode Nothing Nothing Nothing)
    maybe (putStrLn "Cannot open camera" >> exitFailure) return cap

    -- initialise audio
    pa <- withPa $ \_ -> return undefined  -- PortAudio auto‑initialises

    let initState = State { cam = cap, paEnv = pa
                          , currentCol = PixelRGB8 0 0 0
                          , timeAcc = 0 }

    playIO (InWindow "Audio‑Visual Poem" (800,600) (10,10))
           black 60 initState render (\_ _ s -> return s) update