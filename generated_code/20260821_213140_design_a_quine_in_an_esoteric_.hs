import Data.Char (ord)
import Text.Printf (printf)

-- ASCII Art Template representing a musical staff with notes
-- The formatting doubles as the structured data and render template.
template :: [String]
template =
  [ "-- Harmonious Ambient Staff Quine --",
    "G |---(E)---(G)---(B)---(D)---|",
    "E |----(C)---(E)---(G)---(C)--|",
    "C |---(G)---(B)---(D)---(F)---|",
    "A |----(E)---(G)---(B)---(E)--|",
    "E |---(C)---(E)---(G)---(B)---|",
    "-- Non-repeating Ambient Generator --"
  ]

-- Generates a non-repeating, harmonious ambient frequency sequence based on irrational ratios
ambientFrequency :: Int -> Double
ambientFrequency n = 220.0 * (1.059463094359 ** noteOffset)
  where
    -- Pentatonic scale indices mapped over an irrational expansion (phi / pi mix)
    phi = 1.61803398875
    piVal = 3.14159265359
    index = floor (fromIntegral n * phi + sin (fromIntegral n * piVal)) `mod` 12
    pentatonicMap = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26]
    noteOffset = fromIntegral (pentatonicMap !! index)

-- Encodes string representation into a valid self-rendering quine format
renderQuine :: [String] -> String
renderQuine t = unlines t ++ "\nmain :: IO ()\nmain = putStr $ renderQuine " ++ show t

main :: IO ()
main = putStr $ renderQuine template