import Data.Char (ord, chr)
import Data.Bits (xor)
import System.IO (writeFile)
import GHC.Stats (getRTSStats, allocated_bytes, RTSStats)

-- Quine payload: template containing source code structure
s :: String
s = "import Data.Char (ord, chr)\nimport Data.Bits (xor)\nimport System.IO (writeFile)\nimport GHC.Stats (getRTSStats, allocated_bytes, RTSStats)\n\n-- Quine payload: template containing source code structure\ns :: String\ns = %s\n\n-- Microtonal tuning: Maps source byte to frequency in Cents / Hz (24-TET / Just Intonation shift)\nbyteToMicrotone :: Char -> Double\nbyteToMicrotone c = 440.0 * (2.0 ** ((fromIntegral (ord c) - 65.0) / 24.0))\n\n-- Simulates interactive fluid mesh displacement mapped from heap memory allocation\nfluidMeshNode :: Word64 -> Int -> Double\nfluidMeshNode bytes index = sin (fromIntegral bytes * 0.00001 + fromIntegral index * 0.1)\n\n-- Evolving mutation step for self-rewriting cycle\nevolve :: String -> String\nevolve str = zipWith mutate str (cycle [1..7])\n  where mutate c n = if ord c >= 32 && ord c <= 126 then chr (((ord c - 32 + n) `mod` 95) + 32) else c\n\nmain :: IO ()\nmain = do\n    -- Quine self-reconstruction\n    let self = replace \"%s\" (show s) s\n    \n    -- Render dynamic microtonal score from byte sequence\n    let score = map byteToMicrotone self\n    putStrLn $ \"Generated Microtonal Frequencies (Hz, 24-TET): \" ++ show (take 10 score) ++ \"...\"\n\n    -- Map dynamic RTS memory allocation stats into fluid mesh\n    stats <- getRTSStats\n    let mem = allocated_bytes stats\n    let mesh = map (fluidMeshNode mem) [0..15]\n    putStrLn $ \"Fluid Mesh Node Heights: \" ++ show mesh\n\n    -- Self-rewrite code to target file for next evolution cycle\n    let mutatedSelf = replace (show s) (show (evolve s)) self\n    writeFile \"QuineEvolved.hs\" mutatedSelf\n    putStrLn \"Self-rewriting complete: Written to QuineEvolved.hs\"\n\nreplace :: String -> String -> String -> String\nreplace [] _ _ = []\nreplace target sub str@(x:xs)\n    | take (length target) str == target = sub ++ drop (length target) str\n    | otherwise = x : replace target sub xs\n"

-- Microtonal tuning: Maps source byte to frequency in Cents / Hz (24-TET / Just Intonation shift)
byteToMicrotone :: Char -> Double
byteToMicrotone c = 440.0 * (2.0 ** ((fromIntegral (ord c) - 65.0) / 24.0))

-- Simulates interactive fluid mesh displacement mapped from heap memory allocation
fluidMeshNode :: Word64 -> Int -> Double
fluidMeshNode bytes index = sin (fromIntegral bytes * 0.00001 + fromIntegral index * 0.1)

-- Evolving mutation step for self-rewriting cycle
evolve :: String -> String
evolve str = zipWith mutate str (cycle [1..7])
  where mutate c n = if ord c >= 32 && ord c <= 126 then chr (((ord c - 32 + n) `mod` 95) + 32) else c

main :: IO ()
main = do
    -- Quine self-reconstruction
    let self = replace "%s" (show s) s
    
    -- Render dynamic microtonal score from byte sequence
    let score = map byteToMicrotone self
    putStrLn $ "Generated Microtonal Frequencies (Hz, 24-TET): " ++ show (take 10 score) ++ "..."

    -- Map dynamic RTS memory allocation stats into fluid mesh
    stats <- getRTSStats
    let mem = allocated_bytes stats
    let mesh = map (fluidMeshNode mem) [0..15]
    putStrLn $ "Fluid Mesh Node Heights: " ++ show mesh

    -- Self-rewrite code to target file for next evolution cycle
    let mutatedSelf = replace (show s) (show (evolve s)) self
    writeFile "QuineEvolved.hs" mutatedSelf
    putStrLn "Self-rewriting complete: Written to QuineEvolved.hs"

replace :: String -> String -> String -> String
replace [] _ _ = []
replace target sub str@(x:xs)
    | take (length target) str == target = sub ++ drop (length target) str
    | otherwise = x : replace target sub xs