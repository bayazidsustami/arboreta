-- | High-Dimensional Emotional Text Compression Engine
-- Encodes text as a trajectory through an 8-D emotional vector space (Plutchik's Wheel:
-- Joy, Sadness, Anger, Fear, Trust, Disgust, Surprise, Anticipation).
-- Decompresses payload by traversing the shortest topological geodesic path
-- across word nodes in the emotional manifold.

import Data.Char (toLower, isAlphaNum)
import Data.List (minimumBy, intercalate)
import Data.Ord (comparing)
import Numeric (showFFloat)

-- | 8-Dimensional Emotional Vector representing basic emotional coordinates.
type EmotionVec = (Double, Double, Double, Double, Double, Double, Double, Double)

-- | Word entry on the emotional manifold.
data WordNode = WordNode
  { wordText   :: String
  , wordVector :: EmotionVec
  } deriving (Show, Eq)

-- | Compressed payload containing emotional waypoints and target path length.
data CompressedPayload = CompressedPayload
  { waypoints  :: [EmotionVec]
  , wordCount  :: Int
  } deriving (Show)

-- -----------------------------------------------------------------------------
-- Vector Operations & Manifold Geometry
-- -----------------------------------------------------------------------------

zeroVec :: EmotionVec
zeroVec = (0,0,0,0,0,0,0,0)

addVec :: EmotionVec -> EmotionVec -> EmotionVec
addVec (a1,b1,c1,d1,e1,f1,g1,h1) (a2,b2,c2,d2,e2,f2,g2,h2) =
  (a1+a2, b1+b2, c1+c2, d1+d2, e1+e2, f1+f2, g1+g2, h1+h2)

scaleVec :: Double -> EmotionVec -> EmotionVec
scaleVec s (a,b,c,d,e,f,g,h) =
  (s*a, s*b, s*c, s*d, s*e, s*f, s*g, s*h)

-- Euclidean distance on the emotional manifold.
distVec :: EmotionVec -> EmotionVec -> Double
distVec (a1,b1,c1,d1,e1,f1,g1,h1) (a2,b2,c2,d2,e2,f2,g2,h2) =
  sqrt $ (a1-a2)^2 + (b1-b2)^2 + (c1-c2)^2 + (d1-d2)^2 +
         (e1-e2)^2 + (f1-f2)^2 + (g1-g2)^2 + (h1-h2)^2

-- Linear interpolation along a geodesic segment.
lerpVec :: EmotionVec -> EmotionVec -> Double -> EmotionVec
lerpVec v1 v2 t = addVec (scaleVec (1.0 - t) v1) (scaleVec t v2)

-- -----------------------------------------------------------------------------
-- Lexicon & Deterministic Emotional Projection
-- -----------------------------------------------------------------------------

-- Core lexicon mapping anchor words into 8-D emotional space.
-- Dimensions: (Joy, Sadness, Anger, Fear, Trust, Disgust, Surprise, Anticipation)
lexicon :: [WordNode]
lexicon =
  [ WordNode "joyful"      (0.9, 0.0, 0.0, 0.0, 0.7, 0.0, 0.4, 0.6)
  , WordNode "ecstatic"    (1.0, 0.0, 0.1, 0.0, 0.6, 0.0, 0.7, 0.8)
  , WordNode "serene"      (0.7, 0.0, 0.0, 0.0, 0.8, 0.0, 0.1, 0.3)
  , WordNode "melancholy"  (0.0, 0.8, 0.1, 0.2, 0.1, 0.2, 0.0, 0.1)
  , WordNode "despair"     (0.0, 1.0, 0.3, 0.7, 0.0, 0.4, 0.0, 0.0)
  , WordNode "gloomy"      (0.0, 0.6, 0.2, 0.3, 0.2, 0.3, 0.0, 0.1)
  , WordNode "furious"     (0.0, 0.1, 1.0, 0.2, 0.0, 0.6, 0.3, 0.4)
  , WordNode "enraged"     (0.0, 0.2, 0.9, 0.3, 0.0, 0.5, 0.2, 0.5)
  , WordNode "terrified"   (0.0, 0.3, 0.1, 1.0, 0.0, 0.2, 0.6, 0.3)
  , WordNode "anxious"     (0.0, 0.2, 0.2, 0.8, 0.2, 0.1, 0.3, 0.7)
  , WordNode "hopeful"     (0.6, 0.0, 0.0, 0.1, 0.8, 0.0, 0.3, 0.9)
  , WordNode "peaceful"    (0.8, 0.0, 0.0, 0.0, 0.9, 0.0, 0.0, 0.2)
  , WordNode "loathsome"   (0.0, 0.3, 0.5, 0.2, 0.0, 1.0, 0.1, 0.0)
  , WordNode "astonished"  (0.4, 0.0, 0.0, 0.2, 0.3, 0.0, 1.0, 0.5)
  , WordNode "eager"       (0.6, 0.0, 0.0, 0.0, 0.5, 0.0, 0.4, 1.0)
  , WordNode "the"         (0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1)
  , WordNode "shadow"      (0.0, 0.5, 0.2, 0.6, 0.1, 0.2, 0.1, 0.2)
  , WordNode "light"       (0.8, 0.0, 0.0, 0.0, 0.6, 0.0, 0.3, 0.5)
  , WordNode "soul"        (0.5, 0.3, 0.0, 0.1, 0.7, 0.0, 0.2, 0.3)
  , WordNode "journey"     (0.4, 0.1, 0.0, 0.2, 0.5, 0.0, 0.3, 0.8)
  , WordNode "silence"     (0.2, 0.4, 0.0, 0.3, 0.4, 0.1, 0.1, 0.1)
  , WordNode "storm"       (0.0, 0.2, 0.8, 0.6, 0.0, 0.3, 0.5, 0.4)
  ]

-- Deterministic projection for unseen words onto the emotional manifold using character hashing.
projectWord :: String -> EmotionVec
projectWord raw
  | null w    = zeroVec
  | otherwise = case lookup w [(wordText n, wordVector n) | n <- lexicon] of
      Just vec -> vec
      Nothing  ->
        let h = foldl (\acc c -> acc * 31 + fromIntegral (fromEnum c)) 7 w :: Double
            val idx = (sin (h * idx) + 1.0) / 2.0
        in (val 1.1, val 2.3, val 3.7, val 4.1, val 5.3, val 6.7, val 7.9, val 8.3)
  where
    w = map toLower . filter isAlphaNum $ raw

-- -----------------------------------------------------------------------------
-- Compression Module
-- -----------------------------------------------------------------------------

-- Downsamples text into a sequence of high-dimensional emotional waypoints.
compress :: Int -> String -> CompressedPayload
compress compressionRatio input =
  let wordsList = words input
      wordVecs  = map projectWord wordsList
      chunks    = chunkBy compressionRatio wordVecs
      avgVecs   = map averageVec chunks
  in CompressedPayload { waypoints = avgVecs, wordCount = length wordsList }
  where
    chunkBy _ [] = []
    chunkBy n xs = take n xs : chunkBy n (drop n xs)

    averageVec [] = zeroVec
    averageVec vs =
      let sumV = foldl addVec zeroVec vs
          len  = fromIntegral (length vs)
      in scaleVec (1.0 / len) sumV

-- -----------------------------------------------------------------------------
-- Topological Geodesic Decompressor
-- -----------------------------------------------------------------------------

-- Finds nearest lexicon word node to a given point in emotional space.
nearestWord :: EmotionVec -> WordNode
nearestWord target = minimumBy (comparing (distVec target . wordVector)) lexicon

-- Synthesizes the shortest topological geodesic path across emotional waypoints.
decompress :: CompressedPayload -> String
decompress (CompressedPayload wps totalWords)
  | null wps   = ""
  | otherwise  =
      let stepsPerSegment = max 1 (totalWords `div` length wps)
          geodesicPath    = concatMap (synthesizeSegment stepsPerSegment) (paired wps)
          -- Append final waypoint node
          finalNode       = nearestWord (last wps)
      in intercalate " " . map wordText $ geodesicPath ++ [finalNode]
  where
    paired [] = []
    paired [_] = []
    paired (x:y:xs) = (x,y) : paired (y:xs)

    -- Interpolate geodesics between emotional waypoints
    synthesizeSegment steps (start, end) =
      [ nearestWord (lerpVec start end (fromIntegral i / fromIntegral steps))
      | i <- [0 .. steps - 1]
      ]

-- -----------------------------------------------------------------------------
-- Execution & Verification
-- -----------------------------------------------------------------------------

formatVec :: EmotionVec -> String
formatVec (a,b,c,d,e,f,g,h) =
  "[" ++ intercalate "," (map (`showFFloat` (Just 2)) [a,b,c,d,e,f,g,h]) ++ "]"

main :: IO ()
main = do
  let originalText = "the joyful light brings serene hope into despair and dark gloom"
      ratio        = 3

  putStrLn "=== High-Dimensional Emotional Text Compression Engine ==="
  putStrLn $ "Original Prose (" ++ show (length (words originalText)) ++ " words):"
  putStrLn $ "  \"" ++ originalText ++ "\"\n"

  -- Compression
  let payload = compress ratio originalText
  putStrLn $ "Compressed Payload (" ++ show (length $ waypoints payload) ++ " Emotional Waypoints):"
  mapM_ (\(i, wp) -> putStrLn $ "  Waypoint " ++ show i ++ ": " ++ formatVec wp) 
        (zip [1..] (waypoints payload))

  -- Decompression via Topological Geodesic Synthesis
  let decompressedText = decompress payload
  putStrLn $ "\nDecompressed Prose (Synthesized Geodesic Path):"
  putStrLn $ "  \"" ++ decompressedText ++ "\"\n"

  -- Compression ratio metrics
  let origBytes = length originalText
      compBytes = length (waypoints payload) * 8 * 8 -- 8 Double coordinates (64-bit)
      compRatio = (1.0 - (fromIntegral compBytes / fromIntegral origBytes)) * 100.0

  putStrLn "=== Metrics ==="
  putStrLn $ "Original Size:   " ++ show origBytes ++ " bytes (raw string)"
  putStrLn $ "Payload Size:    " ++ show compBytes ++ " bytes (raw IEEE-754 vector state)"
  putStrLn $ "Lossy Compression Rate: " ++ showFFloat (Just 1) compRatio "%"