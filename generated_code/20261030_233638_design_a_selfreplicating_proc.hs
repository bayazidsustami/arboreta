-- A self-replicating procedural shader of forgotten syntax errors
-- Triggered when CPU temperature crosses 70°C.
module Main where

import System.Environment (getArgs)
import System.IO (readFile, writeFile, hFlush, stdout)
import Control.Monad (forM_)
import System.IO.Error (catchIOError)

-- Read CPU temperature (Linux sysfs path, fallback to 72.0°C for safety/demo if unavailable)
getCPUTemp :: IO Double
getCPUTemp = do
  content <- catchIOError (readFile "/sys/class/thermal/thermal_zone0/temp") (\_ -> return "72000")
  let tempMillis = read (head (lines content ++ ["72000"])) :: Double
  return (tempMillis / 1000.0)

-- Lexicon of forgotten/dreaded syntax errors
syntaxErrors :: [String]
syntaxErrors = 
  [ "parse error (possibly incorrect indentation)"
  , "Occurs check: cannot construct infinite type"
  , "Not in scope: 'return' or 'pure'"
  , "Could not deduce (Num [Char])"
  , "Mismatched bracket: ) instead of }"
  , "Ambiguous type variable 'a'"
  , "Non-existent constructor: 'Justification'"
  ]

-- Procedural shader generating swirling constellations via trigonometric fields
renderShader :: Int -> Int -> Double -> String
renderShader width height t = unlines [concat [pixel x y t | x <- [0..width-1]] | y <- [0..height-1]]
  where
    pixel x y time = 
      let fx = fromIntegral x / 3.0
          fy = fromIntegral y / 1.5
          v  = sin (fx * 0.15 + time) + cos (fy * 0.15 - time) + sin ((fx + fy) * 0.08)
          idx = abs (floor (v * 4.0 + fromIntegral (x * y))) `mod` length syntaxErrors
      in if abs v > 1.1 then "[" ++ take 2 (syntaxErrors !! idx) ++ "]" else "     "

main :: IO ()
main = do
  args <- getArgs
  temp <- getCPUTemp
  putStrLn $ "Current CPU Temperature: " ++ show temp ++ "°C"
  
  if temp > 70.0
    then do
      putStrLn "WARNING: CPU > 70°C! Unleashing syntax error constellation shader & self-replication..."
      
      -- Self-replication: read source and append thermal mutation signature
      case args of
        (src:_) -> do
          srcCode <- readFile src
          let mutatedCode = srcCode ++ "\n-- Replicated under thermal stress at " ++ show temp ++ "C\n"
          writeFile ("replicated_" ++ src) mutatedCode
          putStrLn $ "Successfully spawned copy: replicated_" ++ src
        _ -> putStrLn "Tip: Pass source filename as argument to execute full self-replication."

      -- Execute procedural shader animation loop
      forM_ [0..15] $ \frame -> do
        putStr "\ESC[2J\ESC[H" -- Clear screen terminal escape
        putStrLn $ "=== THERMAL SHADER ACTIVE [Frame " ++ show frame ++ "/15] ==="
        putStr (renderShader 25 12 (fromIntegral frame * 0.4))
        hFlush stdout
    else
      putStrLn "CPU temperature nominal (<70°C). Shader remains dormant."