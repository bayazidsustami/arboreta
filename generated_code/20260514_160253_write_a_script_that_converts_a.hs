import Codec.Picture -- from JuicyPixels
import Codec.Midi   -- from midi
import Data.Word
import Data.List (foldl')
import System.Environment (getArgs)
import Control.Monad (forM_)

-- | Represents a single pixel's contribution to the MIDI stream
data NoteEvent = NoteEvent
  { notePitch    :: Int
  , noteVelocity :: Int
  , noteDuration :: Int -- in ticks
  } deriving (Show)

-- | Converts an RGB pixel to a NoteEvent.
-- Hue determines Pitch (mapped to MIDI 21-108, piano range).
-- Brightness determines Velocity (mapped to 0-127).
pixelToNote :: PixelRGB8 -> NoteEvent
pixelToNote (PixelRGB8 r g b) =
    let rf = fromIntegral r / 255.0
        gf = fromIntegral g / 255.0
        bf = fromIntegral b / 255.0
        
        -- Calculate Brightness (Luminance formula)
        brightness = 0.299 * rf + 0.587 * gf + 0.114 * bf
        velocity = floor (brightness * 127)
        
        -- Calculate Hue (Simplified approximation for pitch mapping)
        -- We use the max component to drive the pitch range
        maxC = max rf (max gf bf)
        minC = min rf (min gf bf)
        delta = maxC - minC
        
        hue = if delta == 0 
              then 0 
              else if maxC == rf then (gf - bf) / delta
              else if maxC == gf then (bf - rf) / delta + 2
              else (rf - gf) / delta + 4
        
        -- Map hue [0, 6] to MIDI pitch range [21, 108]
        normalizedHue = (hue / 6.0)
        pitch = 21 + floor (normalizedHue * 87)
        
    in NoteEvent (max 0 (min 127 pitch)) (max 1 (min 127 velocity)) 128

-- | Extracts all pixels from an image and converts them to NoteEvents
imageToNotes :: DynamicImage -> [NoteEvent]
imageToNotes dynImg = 
    let img = convertRGB8 dynImg
        w = imageWidth img
        h = imageHeight img
    in [ pixelToNote (pixelAt img x y) | y <- [0..h-1], x <- [0..w-1] ]

-- | Creates a MIDI track from a list of NoteEvents
notesToMidi :: [NoteEvent] -> Midi
notesToMidi events = 
    let midiEvents = concatMap eventToMidiEvents events
        track = Track 0 midiEvents
    in Midi 480 [track] -- 480 is a standard resolution (ticks per quarter note)

-- | Converts a NoteEvent into MIDI DeltaTime events (NoteOn and NoteOff)
eventToMidiEvents :: NoteEvent -> [MidiEvent]
eventToMidiEvents (NoteEvent p v d) =
    [ NoteOn 0 (fromIntegral p) (fromIntegral v)
    , NoteOff 0 (fromIntegral p) 0
    ]
    -- Note: This simplified version plays notes sequentially.
    -- For a "playable" file, we use 0 delta time for NoteOn and 
    -- the duration for the NoteOff to create a stream.
    -- However, to keep it strictly valid MIDI without complex scheduling:
    -- we treat each pixel as a tiny event.

-- | A more robust conversion for a single track to ensure timing
buildTrack :: [NoteEvent] -> Track
buildTrack notes = 
    let events = foldl' addNote [] notes
    in Track 0 events
  where
    addNote acc (NoteEvent p v d) =
        -- We use a very small delta to prevent the MIDI from being one giant block
        -- This creates a "glissando" effect of pixels
        acc ++ [ NoteOn 0 (fromIntegral p) (fromIntegral v)
               , NoteOff 10 0 (fromIntegral p) 0 
               ]

-- | Main execution logic
main :: IO ()
main = do
    args <- getArgs
    if length args < 2
        then putStrLn "Usage: ./script <output.mid> <input_image1> <input_image2> ..."
        else do
            let (outPath:inPaths) = args
            allNotes <- fmap concat $ forM inPaths $ \path -> do
                putStrLn $ "Processing: " ++ path
                res <- readImage path
                case res of
                    Left err -> do
                        putStrLn $ "Error loading " ++ path ++ ": " ++ err
                        return []
                    Right img -> return $ imageToNotes img
            
            let midiFile = Midi 480 [Track 0 (concatMap eventToMidiEvents allNotes)]
            -- Note: The simple eventToMidiEvents creates a sequence.
            -- To make it "playable" as a melody, we'll use a more standard approach:
            let midiTrack = Track 0 (concatMap (\(NoteEvent p v d) -> 
                                [NoteOn 0 (fromIntegral p) (fromIntegral v), 
                                 NoteOff (fromIntegral d) 0 (fromIntegral p) 0]) allNotes)
            
            writeMidi outPath (Midi 480 [midiTrack])
            putStrLn $ "Successfully wrote MIDI to " ++ outPath