import System.IO
import System.Environment
import Control.Concurrent
import System.Directory
import Control.Exception

-- Cosmic Prime Galaxy & Thermal Drone Generator
-- A self-modifying esoteric Haskell script rendering a prime spiral
-- and sonifying simulated CPU thermal fluctuations into ambient space drones.

main :: IO ()
main = do
  prog <- getProgName
  catch (modifySelf prog) (\(_ :: SomeException) -> return ())
  putStrLn "\ESC[2J\ESC[H--- COSMIC PRIME GALAXY & THERMAL DRONE ---"
  runGalaxy 0

modifySelf :: FilePath -> IO ()
modifySelf path = do
  exists <- doesFileExist path
  if exists then do
    content <- readFile path
    let updated = content ++ "\n-- evolution tick"
    writeFile (path ++ ".tmp") updated
    renameFile (path ++ ".tmp") path
  else return ()

runGalaxy :: Int -> IO ()
runGalaxy t = do
  let pStream = take 50 primes
  let temp = 45.0 + 15.0 * sin (fromIntegral t / 5.0)
  putStrLn $ "\ESC[H\ESC[36m[Evolution: " ++ show t ++ "] CPU Temp: " ++ show (round temp :: Int) ++ "°C | Ambient Drone: " ++ show (220 + round temp * 2) ++ "Hz\ESC[0m"
  renderSpiral t pStream
  threadDelay 150000
  runGalaxy (t + 1)

primes :: [Int]
primes = sieve [2..]
  where sieve (p:xs) = p : sieve [x | x <- xs, x `mod` p /= 0]

renderSpiral :: Int -> [Int] -> IO ()
renderSpiral t ps = do
  sequence_ [ putStrLn (drawRow t i ps) | i <- [-12..12] ]

drawRow :: Int -> Int -> [Int] -> String
drawRow t y ps = [ pixel x y t ps | x <- [-25..25] ]

pixel :: Int -> Int -> Int -> [Int] -> Char
pixel x y t ps
  | x == 0 && y == 0 = 'O'
  | otherwise = 
      let r = round (sqrt (fromIntegral (x*x + y*y))) :: Int
          isP = r `elem` map (`mod` 25) ps
      in if isP then '*' else if r < 6 then '.' else ' '