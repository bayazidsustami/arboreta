import System.IO
import Data.Char (ord)

-- Represents a single watercolor brushstroke instruction
data Stroke = Stroke {
    sX :: Double,
    sY :: Double,
    sRx :: Double,
    sRy :: Double,
    sColor :: (Int, Int, Int),
    sOpacity :: Double
} deriving Show

-- Adaptive state for the self-modifying compression encoder
data State = State {
    stSeed :: Int,
    stColorShift :: Int,
    stPosX :: Double,
    stPosY :: Double
}

-- Encodes plain text into a sequence of brushstrokes via self-modifying state transitions
encodeText :: String -> [Stroke]
encodeText txt = fst $ foldl step ([], State 42 0 400 300) txt
  where
    step (strokes, st) char =
        let cVal = ord char
            -- Self-modifying feedback loop updating generation parameters
            newSeed = (stSeed st * 33 + cVal) `mod` 100003
            dx = fromIntegral (cVal `mod` 100) - 50
            dy = fromIntegral ((cVal `div` 7) `mod` 100) - 50
            nx = max 50 (min 750 (stPosX st + dx))
            ny = max 50 (min 550 (stPosY st + dy))
            
            -- Derive watercolor color components from character properties and history
            r = (cVal * 19 + stColorShift st) `mod` 256
            g = (cVal * 37 + stSeed st) `mod` 256
            b = (cVal * 53) `mod` 256
            
            op = 0.1 + 0.3 * (fromIntegral (cVal `mod` 10) / 10.0)
            radX = 30 + fromIntegral (cVal `mod` 50)
            radY = 20 + fromIntegral ((cVal * 3) `mod` 40)
            
            newSt = State newSeed ((stColorShift st + cVal) `mod` 256) nx ny
            newStroke = Stroke nx ny radX radY (r, g, b) op
        in (strokes ++ [newStroke], newSt)

-- Renders the brushstroke sequence into an SVG abstract watercolor painting
toSVG :: [Stroke] -> String
toSVG strokes = 
    "<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" width=\"800\" height=\"600\" viewBox=\"0 0 800 600\">\n" ++
    "<style>ellipse { mix-blend-mode: multiply; filter: blur(4px); }</style>\n" ++
    "<rect width=\"100%\" height=\"100%\" fill=\"#fcfaf2\"/>\n" ++
    concatMap strokeToSvg strokes ++
    "</svg>"
  where
    strokeToSvg (Stroke px py rx ry (r,g,b) op) =
        let colStr = "rgb(" ++ show r ++ "," ++ show g ++ "," ++ show b ++ ")"
        in "<ellipse cx=\"" ++ show px ++ "\" cy=\"" ++ show py ++ 
           "\" rx=\"" ++ show rx ++ "\" ry=\"" ++ show ry ++ 
           "\" fill=\"" ++ colStr ++ "\" fill-opacity=\"" ++ show op ++ 
           "\" />\n"

main :: IO ()
main = do
    let message = "Self-modifying compression transforms plain text into fluid washes of abstract digital watercolor."
    let strokes = encodeText message
    writeFile "painting.svg" (toSVG strokes)
    putStrLn "Successfully compressed text into watercolor instructions and rendered painting.svg"