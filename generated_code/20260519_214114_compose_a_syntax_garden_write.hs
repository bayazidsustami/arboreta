import System.Environment (getArgs)
import Data.Char (isAlpha, toLower)
import Data.List (foldl')
import qualified Data.Map.Strict as M

-- Very tiny POS dictionary
posDict :: M.Map String String
posDict = M.fromList $
    [ ("the","DET"), ("a","DET"), ("an","DET")
    , ("and","CONJ"), ("or","CONJ"), ("but","CONJ")
    , ("red","ADJ"), ("green","ADJ"), ("blue","ADJ")
    , ("bright","ADJ"), ("dark","ADJ")
    , ("love","NOUN"), ("life","NOUN"), ("time","NOUN")
    , ("tree","NOUN"), ("river","NOUN"), ("mountain","NOUN")
    , ("run","VERB"), ("grow","VERB"), ("shine","VERB")
    , ("whisper","VERB"), ("sing","VERB")
    ]

-- naive tokeniser
tokenise :: String -> [String]
tokenise = words . map (\c -> if isAlpha c then toLower c else ' ')

-- tag each token, default to "NOUN"
tag :: String -> String
tag w = M.findWithDefault "NOUN" w posDict

type Point = (Double, Double)

-- branch drawing parameters
data Style = Style { hue :: Double, depth :: Int }

-- simple colour from hue (0‑360) as HSL → SVG rgb
hslToRgb :: Double -> (Int,Int,Int)
hslToRgb h = let s = 0.7; l = 0.5
                 c = (1 - abs (2*l - 1)) * s
                 h' = h/60
                 x = c * (1 - abs (mod' h' 2 - 1))
                 (r1,g1,b1) | h' < 1 = (c,x,0)
                            | h' < 2 = (x,c,0)
                            | h' < 3 = (0,c,x)
                            | h' < 4 = (0,x,c)
                            | h' < 5 = (x,0,c)
                            | otherwise = (c,0,x)
                 m = l - c/2
                 to255 v = round ((v + m) * 255)
              in (to255 r1, to255 g1, to255 b1)

-- convert colour to hex string
rgbHex :: (Int,Int,Int) -> String
rgbHex (r,g,b) = "#" ++ pad (showHex r) ++ pad (showHex g) ++ pad (showHex b)
  where
    pad s = replicate (2 - length s) '0' ++ s
    showHex = (`showIntAtBase` intToDigit) 16

-- recursive SVG branch generator
branch :: Point -> Double -> Double -> Style -> [String]
branch (x,y) len ang style
  | depth style <= 0 = []
  | otherwise =
      let (x',y') = (x + len * cos ang, y + len * sin ang)
          (r,g,b) = hslToRgb (hue style)
          line = "<line x1=\"" ++ show x ++ "\" y1=\"" ++ show y ++
                 "\" x2=\"" ++ show x' ++ "\" y2=\"" ++ show y' ++
                 "\" stroke=\"" ++ rgbHex (r,g,b) ++ "\" stroke-width=\"1\"/>"
          newDepth = depth style - 1
          -- branch splits based on next tokens (simulated)
          left  = branch (x',y') (len*0.7) (ang - 0.4) style{depth=newDepth}
          right = branch (x',y') (len*0.7) (ang + 0.4) style{depth=newDepth}
       in line : left ++ right

-- map POS to style changes
styleFromPOS :: String -> Style -> Style
styleFromPOS "ADJ" s  = s{ hue = (hue s + 60) `mod'` 360 }
styleFromPOS "VERB" s = s{ depth = depth s + 1 }
styleFromPOS _ s      = s

-- walk tokens, building up SVG
buildSVG :: [String] -> [String]
buildSVG tokens = go tokens (150,300) 80  (-pi/2) (Style 0 5) []
  where
    go [] _ _ _ _ acc = acc
    go (t:ts) pt len ang sty acc =
        let pos = tag t
            sty' = styleFromPOS pos sty
            segs = branch pt len ang sty'
            newPt = let (x,y) = pt
                        (x',y') = (x + len * cos ang, y + len * sin ang)
                    in (x',y')
        in go ts newPt (len*0.95) (ang+0.05) sty' (acc ++ segs)

-- wrap SVG content
svgHeader :: String
svgHeader = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"300\" height=\"600\">"

svgFooter :: String
svgFooter = "</svg>"

main :: IO ()
main = do
    args <- getArgs
    txt <- case args of
             []     -> getContents
             (f:_)  -> readFile f
    let tokens = tokenise txt
        body   = buildSVG tokens
    putStrLn $ unlines $ [svgHeader] ++ body ++ [svgFooter]