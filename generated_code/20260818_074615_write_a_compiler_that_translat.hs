import Data.Char (toLower)
import Data.List (isPrefixOf)
import System.Environment (getArgs)
import System.IO (readFile)
import Text.Printf (printf)

-- Representing sentiment analysis metrics derived from journal paragraphs
data Sentiment = Sentiment
  { positivity :: Double,
    intensity  :: Double,
    isGlitch   :: Bool
  } deriving (Show)

-- Represents a point in 2D space
type Point = (Double, Double)

-- Lexicon dictionaries for sentiment analysis
positiveWords, negativeWords, intenseWords :: [String]
positiveWords = ["happy", "joy", "love", "peace", "bright", "hope", "serene", "calm", "light", "delight"]
negativeWords = ["sad", "pain", "dark", "fear", "gloom", "anger", "rage", "sorrow", "loss", "grief"]
intenseWords  = ["very", "extremely", "overwhelming", "deeply", "burst", "wild", "intense", "furious", "blazing"]

-- Parse a journal entry into sentiment blocks per paragraph
parseParagraph :: String -> Sentiment
parseParagraph text
  | "ERROR:" `isPrefixOf` text = Sentiment 0.0 1.0 True
  | null ws                    = Sentiment 0.5 0.2 False
  | otherwise                  = Sentiment normPos normInt False
  where
    ws = words $ map toLower text
    posCount = length $ filter (`elem` positiveWords) ws
    negCount = length $ filter (`elem` negativeWords) ws
    intCount = length $ filter (`elem` intenseWords) ws
    
    totalSentimentWords = posCount + negCount
    posRatio = if totalSentimentWords == 0 
               then 0.5 
               else fromIntegral posCount / fromIntegral totalSentimentWords
               
    normPos = max 0.0 (min 1.0 posRatio)
    normInt = max 0.1 (min 1.0 (fromIntegral (intCount + 1) / 5.0))

-- Linear interpolation between two RGB colors
lerpColor :: (Double, Double, Double) -> (Double, Double, Double) -> Double -> (Double, Double, Double)
lerpColor (r1, g1, b1) (r2, g2, b2) t =
  ( r1 + t * (r2 - r1),
    g1 + t * (g2 - g1),
    b1 + t * (b2 - b1)
  )

-- Map sentiment to dynamic HSL/RGB colors
sentimentToColor :: Sentiment -> Double -> String
sentimentToColor (Sentiment pos intens glitch) depthRatio
  | glitch =
      -- Volcanic magma/glitch palette (bright oranges, reds, obsidian)
      let (r, g, b) = lerpColor (255, 40, 0) (30, 5, 5) depthRatio
      in printf "rgb(%d,%d,%d)" (round r :: Int) (round g :: Int) (round b :: Int)
  | otherwise =
      -- Smooth palette: cool blue/purple (negative) to bright warm gold/teal (positive)
      let cool = (20, 40, 100)
          warm = (255, 180, 50)
          baseColor = lerpColor cool warm pos
          fadedColor = lerpColor baseColor (15, 15, 25) (depthRatio * (1.1 - intens))
          (r, g, b) = fadedColor
      in printf "rgb(%d,%d,%d)" (round r :: Int) (round g :: Int) (round b :: Int)

-- Generate fractal SVG trees/volcanic pillars recursively
renderFractal :: Point -> Double -> Double -> Int -> Int -> Sentiment -> [String]
renderFractal (x, y) angle length currentDepth maxDepth sent =
  let x2 = x + length * cos angle
      y2 = y - length * sin angle
      depthRatio = fromIntegral currentDepth / fromIntegral maxDepth
      colorStr = sentimentToColor sent depthRatio
      strokeWidth = max 1.0 ((fromIntegral (maxDepth - currentDepth) + 1.0) * (intensity sent + 0.5))
      
      -- Volcanic terrain glitch distortion applied on syntax errors
      (fx2, fy2) = if isGlitch sent
                   then (x2 + sin (fromIntegral currentDepth * 12.34) * 25.0, 
                         y2 + cos (fromIntegral currentDepth * 56.78) * 20.0)
                   else (x2, y2)

      lineSvg = printf "<line x1=\"%.2f\" y1=\"%.2f\" x2=\"%.2f\" y2=\"%.2f\" stroke=\"%s\" stroke-width=\"%.2f\" stroke-linecap=\"round\" opacity=\"0.85\" />"
                       x y fx2 fy2 colorStr
  in if currentDepth >= maxDepth
     then [lineSvg]
     else
       let angleSpread = if isGlitch sent then 0.85 else 0.45 + (positivity sent * 0.3)
           scaleFactor = if isGlitch sent then 0.75 else 0.72
           leftBranch  = renderFractal (fx2, fy2) (angle + angleSpread) (length * scaleFactor) (currentDepth + 1) maxDepth sent
           rightBranch = renderFractal (fx2, fy2) (angle - angleSpread) (length * scaleFactor) (currentDepth + 1) maxDepth sent
           midBranch   = if isGlitch sent 
                         then renderFractal (fx2, fy2) angle (length * 0.5) (currentDepth + 1) maxDepth sent 
                         else []
       in lineSvg : (leftBranch ++ rightBranch ++ midBranch)

-- Split raw text into non-empty paragraphs
splitParagraphs :: String -> [String]
splitParagraphs content = filter (not . null) $ linesByParagraph (lines content) []
  where
    linesByParagraph [] acc = [unwords (reverse acc) | not (null acc)]
    linesByParagraph (l:ls) acc
      | null (words l) = unwords (reverse acc) : linesByParagraph ls []
      | otherwise      = linesByParagraph ls (l:acc)

-- Translate journal text into an infinite fractal SVG landscape
compileToSVG :: String -> String
compileToSVG content =
  let paragraphs = splitParagraphs content
      sentiments = map parseParagraph paragraphs
      width = 1600.0
      height = 900.0
      numTrees = length sentiments
      spacing = width / fromIntegral (max 1 (numTrees + 1))
      
      -- Generate recursive landscapes from sentiment nodes
      fractalSVG = concat $ zipWith (\idx sent ->
                     let originX = spacing * fromIntegral (idx + 1)
                         originY = height - 50.0
                         trunkLength = 120.0 * (0.8 + intensity sent)
                         depth = if isGlitch sent then 8 else 9
                     in renderFractal (originX, originY) (pi / 2) trunkLength 0 depth sent
                   ) [0..] sentiments
                   
      header = printf "<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" viewBox=\"0 0 %.0f %.0f\" style=\"background-color: #0a0a10;\">" width height
      defs = "<defs><filter id=\"glow\"><feGaussianBlur stdDeviation=\"3\" result=\"coloredBlur\"/><feMerge><feMergeNode in=\"coloredBlur\"/><feMergeNode in=\"SourceGraphic\"/></feMerge></filter></defs>"
      ground = printf "<rect x=\"0\" y=\"%.0f\" width=\"%.0f\" height=\"100\" fill=\"#050508\" />" (height - 50.0) width
      footer = "</svg>"
  in unlines ([header, defs, ground, "<g filter=\"url(#glow)\">"] ++ fractalSVG ++ ["</g>", footer])

-- Default fallback journal input
sampleJournal :: String
sampleJournal = unlines
  [ "I woke up feeling extremely bright and full of peace. The light streamed through the window with warm delight and endless hope.",
    "ERROR: SYNTAX_ERR_UNBALANCED_EMOTION - Volcanic tremor detected in sub-routine core. Memory heap overflowed with unhandled rage.",
    "A dark gloomy cloud settled over my chest later today. Cold fear and sorrow whispered through the dark loss."
  ]

main :: IO ()
main = do
  args <- getArgs
  content <- case args of
    [filePath] -> readFile filePath
    _          -> return sampleJournal
  putStrLn $ compileToSVG content