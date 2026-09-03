import Data.Char (isAlpha)
import System.IO (hSetEncoding, stdout, utf8)

-- | Represents an RGB color palette generated from a stanza
type Color = (Int, Int, Int)
type Palette = [Color]

-- | Count vowels to approximate syllable count for a word
countSyllables :: String -> Int
countSyllables word = max 1 . length . filter (`elem` "aeiouyAEIOUY") $ word

-- | Extract the structural cadence (syllables per line) from poetic text
extractCadence :: String -> [[Int]]
extractCadence text = 
  map (map countSyllables . words . filter (\c -> isAlpha c || c == ' ')) 
  . filter (not . null) 
  $ lines text

-- | Map a stanza's syllable cadence to a harmonized color palette
cadenceToPalette :: [Int] -> Palette
cadenceToPalette cadence =
  let totalSyllables = sum cadence
      baseHue = (totalSyllables * 37) `mod` 360
      len = length cadence
  in [ hsvToRgb ((baseHue + i * (360 `div` max 1 len)) `mod` 360) 0.85 0.95 
     | (i, s) <- zip [0..] cadence 
     ]

-- | Convert HSV values to RGB color tuple
hsvToRgb :: Int -> Float -> Float -> Color
hsvToRgb h s v =
  let c = v * s
      x = c * (1 - abs (fromIntegral (h `div` 60 `mod` 2) - 1))
      m = v - c
      (r', g', b')
        | h < 60    = (c, x, 0)
        | h < 120   = (x, c, 0)
        | h < 180   = (0, c, x)
        | h < 240   = (0, x, c)
        | h < 300   = (x, 0, c)
        | otherwise = (c, 0, x)
  in (round ((r' + m) * 255), round ((g' + m) * 255), round ((b' + m) * 255))

-- | Render a character using ANSI 24-bit background colors
renderPixel :: Color -> String
renderPixel (r, g, b) = "\ESC[48;2;" ++ show r ++ ";" ++ show g ++ ";" ++ show b ++ "m  \ESC[0m"

-- | Generate an algorithmic tapestry frame using wave interference of palettes
renderFrame :: [Palette] -> Int -> String
renderFrame palettes t = unlines
  [ concat [ renderPixel (samplePoint x y t palettes) | x <- [0..59] ]
  | y <- [0..23]
  ]

-- | Sample a color at spatial coordinates (x, y) at time t
samplePoint :: Int -> Int -> Int -> [Palette] -> Color
samplePoint x y t palettes =
  let numPalettes = max 1 (length palettes)
      pIndex = (x + y + t) `mod` numPalettes
      palette = palettes !! pIndex
      colorIdx = abs (round (sin (fromIntegral (x * y + t) * 0.1) * fromIntegral (length palette - 1))) `mod` length palette
      (r, g, b) = palette !! colorIdx
      -- Modulate color brightness by a cyclic spatial algorithm
      wave = (sin (fromIntegral x * 0.15 + fromIntegral t * 0.1) + cos (fromIntegral y * 0.15 + fromIntegral t * 0.1)) * 0.2 + 0.8
  in (min 255 (round (fromIntegral r * wave)), 
      min 255 (round (fromIntegral g * wave)), 
      min 255 (round (fromIntegral b * wave)))

-- | Execute the tapestry loop continuously in terminal
runTapestry :: [Palette] -> Int -> IO ()
runTapestry palettes t = do
  putStr "\ESC[H" -- Move cursor to top-left
  putStr (renderFrame palettes t)
  -- Simple frame delay using dummy evaluation loop
  let _ = sum [1..10000000 :: Int]
  runTapestry palettes (t + 1)

main :: IO ()
main = do
  hSetEncoding stdout utf8
  
  -- Sample poetic text input
  let poem = unlines
        [ "O Rose thou art sick"
        , "The invisible worm"
        , "That flies in the night"
        , "In the howling storm"
        , ""
        , "Has found out thy bed"
        , "Of crimson joy"
        , "And his dark secret love"
        , "Does thy life destroy"
        ]

  -- Parse cadence and compile to color palettes per stanza
  let stanzas = filter (not . null) $ extractCadence poem
      palettes = map cadenceToPalette stanzas

  putStr "\ESC[2J\ESC[?25l" -- Clear screen and hide cursor
  runTapestry palettes 0