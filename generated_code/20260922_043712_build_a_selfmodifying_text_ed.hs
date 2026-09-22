-- A self-modifying text editor in Haskell that strips vowels 
-- when system CPU usage exceeds 80%, forcing a consonantal dialect.

import System.IO
import Control.Concurrent
import Control.Monad
import Data.Char (toLower)
import System.Directory (doesFileExist)

-- Check if a character is a vowel
isVowel :: Char -> Bool
isVowel c = toLower c `elem` "aeiou"

-- Strip all vowels from a string
stripVowels :: String -> String
stripVowels = filter (not . isVowel)

-- Simulate or read system CPU load from /proc/loadavg (Linux) or fallback
getCPUUsage :: IO Double
getCPUUsage = do
    exists <- doesFileExist "/proc/loadavg"
    if exists
        then do
            content <- readFile "/proc/loadavg"
            case words content of
                (loadStr:_) -> case reads loadStr of
                    [(val, "")] -> return (val * 30.0) -- Scaling factor for demo
                    _ -> return 10.0
                _ -> return 10.0
        else return 15.0 -- Default safe load on non-Linux platforms

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    putStrLn "=== Consonantal Text Editor Initialized ==="
    putStrLn "Monitoring system CPU. If load > 80%, vowels vanish!"
    
    -- Initial text buffer
    let initialBuffer = "Hello world, welcome to functional programming in Haskell!"
    editorLoop initialBuffer

editorLoop :: String -> IO ()
editorLoop buffer = do
    cpu <- getCPUUsage
    
    -- Self-modification trigger: CPU > 80%
    let activeBuffer = if cpu > 80.0 
                        then stripVowels buffer 
                        else buffer
    
    putStrLn $ "[CPU: " ++ show (round cpu :: Int) "%] Buffer: " ++ activeBuffer
    
    threadDelay 1000000 -- Wait 1 second before next check
    editorLoop activeBuffer