module Main where

import System.IO
import System.Directory (doesFileExist)
import Data.Time.Clock.POSIX (getPOSIXTime)
import Text.Printf (printf)

-- Simple Linear Congruential Generator for pure Haskell pseudo-randomness
type Seed = Int

nextSeed :: Seed -> Seed
nextSeed s = (s * 1103515245 + 12345) `mod` 2147483647

randomFloat :: Seed -> (Float, Seed)
randomFloat s = 
    let s' = nextSeed s
        val = fromIntegral (s' `mod` 10000) / 10000.0
    in (val, s')

-- Read CPU temperature (Linux thermal zone with fallback to simulated thermal wave)
getCPUTemp :: IO Float
getCPUTemp = do
    let path = "/sys/class/thermal/thermal_zone0/temp"
    exists <- doesFileExist path
    if exists
        then do
            content <- readFile path
            case reads (head (lines content)) of
                [(val, _)] -> return (fromIntegral (val :: Int) / 1000.0)
                _          -> fallbackTemp
        else fallbackTemp

fallbackTemp :: IO Float
fallbackTemp = do
    t <- fmap realToFrac getPOSIXTime
    -- Smoothly oscillate thermal output for demonstration
    return $ 55.0 + 25.0 * sin (t / 4.0)

-- Medieval jewel-tone color representation
data Color = Color Int Int Int

-- Map CPU thermal output to medieval stained glass color palettes
tempToColor :: Float -> Float -> Color
tempToColor temp seedVal =
    if temp > 70.0
    -- Fiery Ruby and Amber (High thermal output)
    then Color (190 + round (65 * seedVal)) (20 + round (40 * seedVal)) (20 + round (30 * seedVal))
    else if temp > 50.0
    -- Rich Emerald and Gold (Moderate thermal output)
    then Color (30 + round (40 * seedVal)) (140 + round (90 * seedVal)) (40 + round (50 * seedVal))
    else
    -- Deep Sapphire and Amethyst (Cool operation)
    then Color (20 + round (40 * seedVal)) (30 + round (50 * seedVal)) (175 + round (80 * seedVal))

main :: IO ()
main = do
    temp <- getCPUTemp
    putStrLn $ "Translating CPU Thermal Output (" ++ printf "%.1f" temp ++ " °C) into Stained Glass..."
    
    let width = 900
        height = 700
        numPanes = 60
        initialSeed = round (temp * 1000)
        
        -- SVG Canvas Header
        svgHeader = printf "<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" width=\"%d\" height=\"%d\" style=\"background:#0b0b0f\">\n" width height
        svgFooter = "</svg>"
        
        -- Gothic window stone frame / lead border
        frame = printf "<rect x=\"15\" y=\"15\" width=\"%d\" height=\"%d\" fill=\"none\" stroke=\"#151518\" stroke-width=\"22\" rx=\"35\" />\n" (width - 30) (height - 30)
        
        -- Generate procedural mosaic facets influenced by thermal seed
        (panes, _) = foldl (\(acc, s) i -> 
            let (x1, s1) = randomFloat s
                (y1, s2) = randomFloat s1
                (x2, s3) = randomFloat s2
                (y3, s4) = randomFloat s3
                (x4, s5) = randomFloat s4
                (cVal, s6) = randomFloat s5
                Color r g b = tempToColor temp cVal
                px1 = round (x1 * fromIntegral width)
                py1 = round (y1 * fromIntegral height)
                px2 = round (x2 * fromIntegral width)
                py2 = round (y3 * fromIntegral height)
                px3 = round (x4 * fromIntegral width)
                py4 = round (y1 * fromIntegral height)
                paneStr = printf "<polygon points=\"%d,%d %d,%d %d,%d\" fill=\"rgb(%d,%d,%d)\" fill-opacity=\"0.82\" stroke=\"#07070a\" stroke-width=\"5\" />\n" px1 py1 px2 py2 px3 py4 r g b
            in (acc ++ [paneStr], s6)
            ) ([], initialSeed) [1..numPanes]
            
        svgContent = svgHeader +++ frame +++ concat panes +++ svgFooter
        where
          (+++) = (++)
            
    writeFile "cpu_stained_glass.svg" svgContent
    putStrLn "Masterpiece generated successfully: cpu_stained_glass.svg"