-- Atmospheric Pressure ASCII Waterfall Instrument
-- A self-contained Haskell script simulating an asynchronous audio-visual 
-- instrument driven by fluctuating atmospheric pressure waves, rendering 
-- cascading constellations of ASCII art to the terminal.

import Control.Concurrent (threadDelay)
import System.IO (hFlush, stdout)

-- Simple Linear Congruential Generator for self-contained pseudo-randomness
type Seed = Int

lcg :: Seed -> (Int, Seed)
lcg s = 
    let s' = (s * 1103515245 + 12345) `mod` 2147483647 
    in (s', s')

-- Simulate local atmospheric pressure fluctuations (in hPa) using harmonic synthesis
atmosphericPressure :: Int -> Double
atmosphericPressure t = 
    1013.25 + 18.5 * sin (fromIntegral t * 0.04) + 7.2 * cos (fromIntegral t * 0.11)

-- Generate an ASCII constellation row modulated by the current pressure state
renderRow :: Int -> Double -> Seed -> (String, Seed)
renderRow width pressure seed = go width seed ""
  where
    symbols = " .:-=+*#%@"
    go 0 s acc = (acc, s)
    go w s acc =
      let (val, s1) = lcg s
          normalized = fromIntegral (val `mod` 1000) / 1000.0
          -- Pressure modulates constellation density and sparkle threshold
          threshold = 0.35 + 0.15 * sin (pressure * 0.02)
          char = if normalized < threshold
                 then symbols !! ((val `div` 1000) `mod` length symbols)
                 else ' '
      in go (w - 1) s1 (char : acc)

main :: IO ()
main = do
    -- Clear screen and hide cursor for smooth waterfall rendering
    putStr "\ESC[2J\ESC[?25l"
    hFlush stdout
    
    let width = 64
        loop t seed = do
            let p = atmosphericPressure t
            let (row, seed') = renderRow width p seed
            -- Calculate synthesized audio frequency response based on pressure delta
            let freq = 220.0 + (p - 1013.25) * 12.5
            
            -- Render telemetry and cascading ASCII constellation line
            putStr $ "\ESC[H\ESC[35m=== ATMOSPHERIC AUDIO-VISUAL STREAM ===\ESC[0m\n"
            putStr $ "Pressure: \ESC[36m" ++ show (round p :: Int) ++ " hPa\ESC[0m | "
            putStr $ "Pitch: \ESC[33m" ++ show (round freq :: Int) ++ " Hz\ESC[0m\n"
            putStrLn $ "┌" ++ replicate width '─' ++ "┐"
            putStrLn $ "│" ++ row ++ "│"
            putStrLn $ "└" ++ replicate width '─' ++ "┘"
            
            hFlush stdout
            threadDelay 80000 -- ~12.5 FPS cascade rate
            
            if t > 300 
               then putStr "\ESC[?25h\n" -- Restore cursor on exit
               else loop (t + 1) seed'

    loop 0 1337