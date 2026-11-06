import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.Word
import Data.Bits
import Text.Printf

-- Atmospheric reading containing timestamp (seconds) and barometric pressure (hPa)
data PressureReading = PressureReading
    { timestamp :: Double
    , pressure  :: Double
    } deriving (Show, Eq)

-- Simulate a live stream of weather station barometric readings
-- Displays a stable pressure transitioning into a sharp barometric drop (approaching storm)
simulateAtmosphere :: [PressureReading]
simulateAtmosphere = 
    [ PressureReading t p | (t, p) <- zip [0, 15 .. 600] 
        [ 1013.25, 1013.1, 1012.9, 1012.6, 1012.2, 1011.5
        , 1010.2, 1008.5, 1005.8, 1001.2, 995.4, 988.1
        , 980.0, 972.5, 966.0, 961.2, 958.0, 956.5
        , 956.0, 956.2, 957.0, 958.5, 960.0, 962.0
        , 964.5, 967.0, 970.0, 973.5, 977.0, 981.0
        , 985.0, 989.0, 993.0, 997.0, 1001.0, 1005.0
        , 1008.0, 1010.0, 1011.5, 1012.5, 1013.0
        ]
    ]

-- Detect storm conditions by monitoring rapid barometric pressure drops over a sliding window
isStormApproaching :: [PressureReading] -> Bool
isStormApproaching readings = 
    let window = drop (length readings - 8) readings
        diffs = zipWith (\a b -> pressure b - pressure a) window (tail window)
        avgDrop = sum diffs / fromIntegral (length diffs)
    in avgDrop < -1.2 -- Significant negative pressure derivative threshold

-- Convert frequency in Hertz to microtonal MIDI note number and 14-bit pitch bend
freqToMicrotonalMIDI :: Double -> (Word8, Word16)
freqToMicrotonalMIDI freq =
    let exactNote = 69 + 12 * logBase 2 (freq / 440.0)
        baseNote = round exactNote :: Int
        centOffset = (exactNote - fromIntegral baseNote) * 100.0
        -- Pitch bend range: +/- 2 semitones (200 cents maps to 0..16383, center at 8192)
        bendUnits = round (8192 + (centOffset / 200.0) * 8192) :: Int
        clampedBend = max 0 (min 16383 bendUnits)
        clampedNote = max 0 (min 127 baseNote)
    in (fromIntegral clampedNote, fromIntegral clampedBend)

-- Map barometric pressure to a microtonal pentatonic scale frequency
pressureToFrequency :: Double -> Double
pressureToFrequency p =
    -- Map lower pressure to lower, ethereal drone frequencies with microtonal jitter
    let baseFreq = 110.0 * (p / 1013.25) ** 1.8
        ratios = [1.0, 9/8, 5/4, 3/2, 7/4] -- Just intonation intervals
        scaleFactor = ratiosise (round (p * 10) `mod` length ratios)
    in baseFreq * scaleFactor
  where
    ratiosise i = [1.0, 1.125, 1.25, 1.5, 1.75] !! i

-- Encode integer into MIDI Variable Length Quantity (VLV)
encodeVLV :: Int -> [Word8]
encodeVLV val =
    let worker 0 acc = acc
        worker v acc =
            let b = fromIntegral (v .&. 0x7F)
                v' = v `shiftR` 7
                b' = if null acc then b else b .|. 0x80
            in worker v' (b' : acc)
    in if val == 0 then [0] else worker val []

-- Construct a Standard MIDI File (SMF Format 0) ByteString
buildMidiFile :: [(Double, Double)] -> BL.ByteString
buildMidiFile notes = 
    let ticksPerQuarter = 480
        -- Header chunk: MThd (6 bytes length, format 0, 1 track, division)
        header = BS.pack [ 0x4D, 0x54, 0x68, 0x64, 0, 0, 0, 6, 0, 0, 0, 1, 0, fromIntegral (ticksPerQuarter `div` 256), fromIntegral (ticksPerQuarter `mod` 256) ]
        
        -- Build track events
        -- Tempo meta-event: 120 BPM -> 500,000 microseconds per quarter note
        tempoEvent = [0, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20]
        
        -- Generate Note On / Note Off / Pitch Bend event stream
        eventStream = concatMap noteToEvents notes
        endTrack = [0, 0xFF, 0x2F, 0x00]
        
        trackData = tempoEvent ++ eventStream ++ endTrack
        trackLen = length trackData
        trackHeader = BS.pack [ 0x4D, 0x54, 0x72, 0x6B
                              , fromIntegral (trackLen `shiftR` 24)
                              , fromIntegral ((trackLen `shiftR` 16) .&. 0xFF)
                              , fromIntegral ((trackLen `shiftR` 8) .&. 0xFF)
                              , fromIntegral (trackLen .&. 0xFF)
                              ]
    in BL.fromChunks [header, trackHeader, BS.pack trackData]
  where
    noteToEvents (freq, durationSecs) =
        let (note, bend) = freqToMicrotonalMIDI freq
            durationTicks = round (durationSecs * 240) :: Int
            bendLSB = fromIntegral (bend .&. 0x7F)
            bendMSB = fromIntegral ((bend `shiftR` 7) .&. 0x7F)
            -- Pitch bend message (Channel 1: 0xE0), Note On (0x90), Note Off (0x80)
            pitchBendMsg = [0, 0xE0, bendLSB, bendMSB]
            noteOnMsg    = [0, 0x90, note, 64] -- velocity 64
            noteOffMsg   = encodeVLV durationTicks ++ [0x80, note, 0]
        in pitchBendMsg ++ noteOnMsg ++ noteOffMsg

main :: IO ()
main = do
    putStrLn "Scanning local atmospheric weather stations..."
    let stream = simulateAtmosphere
    
    if isStormApproaching stream
        then do
            putStrLn "WARNING: Rapid barometric drop detected! Approaching storm confirmed."
            putStrLn "Synthesizing microtonal MIDI lullaby..."
            
            -- Translate atmospheric pressure series into frequencies and durations
            let lullabyNotes = [ (pressureToFrequency (pressure r), 1.2) | r <- stream ]
                midiData = buildMidiFile lullabyNotes
                filename = "storm_lullaby.mid"
            
            BL.writeFile filename midiData
            printf "Microtonal lullaby successfully written to '%s'. Sweet dreams amidst the thunder.\n" filename
        else
            putStrLn "Atmospheric pressure stable. Skies are clear; lullaby generator standing by."