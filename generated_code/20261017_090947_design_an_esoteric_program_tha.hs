-- Weather-Driven Cellular Automata SVG Tapestry Generator
-- Run with: runhaskell tapestry.hs

import System.Process (readProcess)
import System.IO (writeFile)
import Data.Char (ord)
import Data.List (intercalate)
import Control.Exception (catch, SomeException)

main :: IO ()
main = do
    putStrLn "Consulting the skies for local weather..."
    weather <- fetchWeather
    let seed = sum (map ord weather)
    putStrLn $ "Weather signature acquired: " ++ weather ++ " (Seed: " ++ show seed ++ ")"
    
    -- Generate Cellular Automata grid using Rule 110
    let width = 80
    let height = 60
    let initialRow = initRow width seed
    let caGrid = take height (iterate (stepCA 110) initialRow)
    
    -- Generate SVG Tapestry
    let svgContent = generateSVG caGrid weather
    let filename = "mythical_creature_tapestry.svg"
    writeFile filename svgContent
    putStrLn $ "Tapestry woven successfully into " ++ filename

fetchWeather :: IO String
fetchWeather = catch (readProcess "curl" ["-s", "wttr.in/?format=%t+%C"] "")
                     (\e -> return "+15°C Clear (Fallback)")

initRow :: Int -> Int -> [Bool]
initRow w seed = [ (i == w `div` 2) || (i `mod` (max 1 (seed `mod` 7)) == 0) | i <- [0..w-1] ]

stepCA :: Int -> [Bool] -> [Bool]
stepCA rule row = zipWith3 applyRule (False : row) row (tail row ++ [False])
  where
    applyRule l c r = 
        let idx = (if l then 4 else 0) + (if c then 2 else 0) + (if r then 1 else 0)
        in (rule `div` (2 ^ idx)) `mod` 2 == 1

generateSVG :: [[Bool]] -> String -> String
generateSVG grid weather = unlines
    [ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    , "<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" viewBox=\"0 0 800 600\" width=\"100%\" height=\"100%\">"
    , "<defs>"
    , "<linearGradient id=\"bg\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"100%\">"
    , "<stop offset=\"0%\" stop-color=\"#0f0c29\"/>"
    , "<stop offset=\"50%\" stop-color=\"#302b63\"/>"
    , "<stop offset=\"100%\" stop-color=\"#24243e\"/>"
    , "</linearGradient>"
    , "<filter id=\"glow\">"
    , "<feGaussianBlur stdDeviation=\"2\" result=\"coloredBlur\"/>"
    , "<feMerge>"
    , "<feMergeNode in=\"coloredBlur\"/>"
    , "<feMergeNode in=\"SourceGraphic\"/>"
    , "</feMerge>"
    , "</filter>"
    , "</defs>"
    , "<rect width=\"100%\" height=\"100%\" fill=\"url(#bg)\"/>"
    -- Mythical creature watermark silhouette (Celestial Dragon)
    , "<g transform=\"translate(150, 80) scale(0.6)\" opacity=\"0.15\" fill=\"#ffffff\">"
    , "<path d=\"M200,300 Q300,100 500,150 Q700,200 800,100 Q750,300 600,350 Q500,400 400,350 Q300,400 200,300 Z\" />"
    , "</g>"
    -- CA Tapestry Pixels
    , "<g transform=\"translate(100, 60)\" filter=\"url(#glow)\">"
    , svgPixels grid
    , "</g>"
    -- Weather Signature Label
    , "<text x=\"400\" y=\"570\" text-anchor=\"middle\" fill=\"#a0c4ff\" font-family=\"monospace\" font-size=\"14\" opacity=\"0.8\">"
    , "Weather Animus: " ++ escapeXML weather
    , "</text>"
    , "</svg>"
    ]

svgPixels :: [[Bool]] -> String
svgPixels grid = unlines [ renderRow y row | (y, row) <- zip [0..] grid ]
  where
    cellSize = 7.5
    renderRow y row = concat [ renderCell x y b | (x, b) <- zip [0..] row ]
    renderCell x y True = 
        let color = if (x + y) `mod` 3 == 0 then "#ff007f" else (if (x * y) `odd` then "#00f0ff" else "#7000ff")
        in "<rect x=\"" ++ show (fromIntegral x * cellSize) ++ "\" y=\"" ++ show (fromIntegral y * cellSize) ++ "\" width=\"" ++ show cellSize ++ "\" height=\"" ++ show cellSize ++ "\" fill=\"" ++ color ++ "\" rx=\"1\"/>"
    renderCell _ _ False = ""

escapeXML :: String -> String
escapeXML = concatMap escape
  where
    escape '<'  = "&lt;"
    escape '>'  = "&gt;"
    escape '&'  = "&amp;"
    escape '\"' = "&quot;"
    escape '\'' = "&apos;"
    escape c    = [c]