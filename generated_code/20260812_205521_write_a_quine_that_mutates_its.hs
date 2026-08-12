import Data.Time.Clock
import Data.Time.Clock.POSIX
import Data.Char
import Control.Exception
import Text.Read (readMaybe)

-- Haskell Quine: Mutates source into an ASCII constellation when millisecond is prime.
-- Stars ('*') represent active network packets read from local interface stats.
main :: IO ()
main = do
  t <- getCurrentTime
  let ms = floor (utcTimeToPOSIXSeconds t * 1000) `mod` 1000
  let isP n = n > 1 && null [x | x <- [2 .. floor (sqrt (fromIntegral n :: Double))], n `mod` x == 0]
  pkts <- catch (do
    c <- readFile "/proc/net/dev"
    let p = sum [v | line <- lines c, let ws = words line, length ws > 10, Just v <- [readMaybe (ws !! 2)]]
    return (p `mod` 35 + 5)) (\(_ :: SomeException) -> return 12)
  let src = q ++ show q
  if isP ms
    then putStrLn (mutToStars pkts src)
    else putStr src

mutToStars :: Int -> String -> String
mutToStars p str = zipWith f [0..] str
  where f i c
          | c == '\n' = '\n'
          | isAlphaNum c && (i `mod` max 1 (length str `div` p) == 0) = '*'
          | otherwise = ' '

q = "import Data.Time.Clock\nimport Data.Time.Clock.POSIX\nimport Data.Char\nimport Control.Exception\nimport Text.Read (readMaybe)\n\n-- Haskell Quine: Mutates source into an ASCII constellation when millisecond is prime.\n-- Stars ('*') represent active network packets read from local interface stats.\nmain :: IO ()\nmain = do\n  t <- getCurrentTime\n  let ms = floor (utcTimeToPOSIXSeconds t * 1000) `mod` 1000\n  let isP n = n > 1 && null [x | x <- [2 .. floor (sqrt (fromIntegral n :: Double))], n `mod` x == 0]\n  pkts <- catch (do\n    c <- readFile \"/proc/net/dev\"\n    let p = sum [v | line <- lines c, let ws = words line, length ws > 10, Just v <- [readMaybe (ws !! 2)]]\n    return (p `mod` 35 + 5)) (\\(_ :: SomeException) -> return 12)\n  let src = q ++ show q\n  if isP ms\n    then putStrLn (mutToStars pkts src)\n    else putStr src\n\nmutToStars :: Int -> String -> String\nmutToStars p str = zipWith f [0..] str\n  where f i c\n          | c == '\\n' = '\\n'\n          | isAlphaNum c && (i `mod` max 1 (length str `div` p) == 0) = '*'\n          | otherwise = ' '\n\nq = "