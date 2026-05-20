import System.IO
import System.Random (mkStdGen, randomRs)
import Control.Concurrent (threadDelay)
import Data.List (foldl')
import Data.Char (isSpace)

-- Simple sonnet (Shakespeare Sonnet 18)
sonnet :: String
sonnet = unlines
  [ "Shall I compare thee to a summer's day?"
  , "Thou art more lovely and more temperate."
  , "Rough winds do shake the darling buds of May,"
  , "And summer's lease hath all too short a date."
  , "Sometime too hot the eye of heaven shines,"
  , "And often is his gold complexion dimmed;"
  , "And every fair from fair sometime declines,"
  , "By chance or nature's changing course untrimmed."
  , "But thy eternal summer shall not fade"
  , "Nor lose possession of that fair thou owest;"
  , "Nor shall Death brag thou wander'st in his shade,"
  , "When in eternal lines to time thou growest."
  , "So long as men can breathe or eyes can see,"
  , "So long lives this, and this gives life to thee." ]

-- Very naive stress detector: every second syllable is stressed.
-- We approximate syllables by vowels groups per word.
syllables :: String -> [String]
syllables = filter (not . null) . words . map (\c -> if c `elem` "aeiouyAEIOUY" then c else ' ')

stressPattern :: [String] -> [Bool] -- True = stressed
stressPattern ws = zipWith (\i _ -> even i) [0..] ws

-- Generate a simple mandala frame based on a seed integer.
mandala :: Int -> [String]
mandala seed = [ [ charAt x y | x <- [-r..r] ] | y <- [-r..r] ]
  where
    r = 12
    rnd = take ((2*r+1)*(2*r+1)) $ randomRs (0,7) (mkStdGen seed) :: [Int]
    charMap n = " .·*◦✶✸✹" !! n
    charAt x y = charMap $ rnd !! ((y+r)*(2*r+1) + (x+r))

-- Render mandala to terminal
render :: [String] -> IO ()
render rows = do
    clearScreen
    mapM_ putStrLn rows

clearScreen :: IO ()
clearScreen = putStr "\ESC[2J\ESC[H"

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    let wordsList = concatMap (syllables . filter (/= ',')) (lines sonnet)
        stresses = stressPattern wordsList
    loop 0 stresses
  where
    loop :: Int -> [Bool] -> IO ()
    loop _ [] = return ()
    loop seed (s:ss) = do
        when s $ do
            let frame = mandala seed
            render frame
            threadDelay 300000  -- 0.3 sec per stressed syllable
        loop (seed+1) ss

when :: Bool -> IO () -> IO ()
when True act = act
when False _   = return ()