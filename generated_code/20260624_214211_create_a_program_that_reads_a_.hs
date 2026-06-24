import System.IO
import System.Random
import Control.Concurrent (threadDelay, forkIO)
import Control.Monad (forever, when)
import Data.Char (isAlphaNum)
import Data.List (nub)
import qualified Data.Map.Strict as M
import System.Console.ANSI

-- Simple mock of Twitter hashtag stream
mockHashtags :: IO String
mockHashtags = do
    tags <- sequence $ replicate 3 randomTag
    return $ unwords tags
  where
    randomTag = do
        n <- randomRIO (3,8)
        txt <- sequence $ replicate n (randomRIO ('a','z'))
        return ('#':txt)

-- Very naive sentiment: random polarity between -1 and 1
randomSentiment :: IO Double
randomSentiment = randomRIO (-1.0,1.0)

-- L‑system state
type Symbol = Char
type Word   = [Symbol]

data LSys = LSys { axiom   :: Word
                 , rules   :: M.Map Symbol (Double -> Word)  -- rule depends on sentiment
                 , angle   :: Double                         -- base turning angle
                 }

-- Example rules: F -> F[+F]F[-F]F, altered by sentiment (grow faster for positive)
exampleRules :: M.Map Symbol (Double -> Word)
exampleRules = M.fromList
    [ ('F', \s -> if s > 0 then "F[+F]F[-F]F" else "F[+F]F")
    , ('X', \_ -> "F+[[X]-X]-F[-FX]+X")
    ]

baseLSys :: LSys
baseLSys = LSys { axiom = "FX"
                , rules = exampleRules
                , angle = 25.0
                }

-- Produce next generation given sentiment
iterateLSys :: LSys -> Double -> Word
iterateLSys lsys sentiment = concatMap expand (axiom lsys)
  where
    expand sym = case M.lookup sym (rules lsys) of
                    Just f  -> f sentiment
                    Nothing -> [sym]

-- Turtle graphics in 3D projected to 2D ASCII
type Vec3 = (Double,Double,Double)
type Vec2 = (Int,Int)

data Turtle = Turtle { pos   :: Vec3
                     , heading :: Vec3
                     , stack :: [(Vec3,Vec3)]
                     }

identityTurtle :: Turtle
identityTurtle = Turtle (0,0,0) (0,0,1) []

rotate :: Vec3 -> Double -> Vec3
rotate (x,y,z) a = (x',y',z')
  where
    rad = a * pi / 180
    (x',y',z') = ( x* cos rad - z* sin rad
                , y
                , x* sin rad + z* cos rad)

step :: Turtle -> Double -> Turtle
step t d = t { pos = (x+dx*d, y+dy*d, z+dz*d) }
  where (x,y,z) = pos t
        (dx,dy,dz) = heading t

push :: Turtle -> Turtle
push t = t { stack = (pos t, heading t) : stack t }

pop :: Turtle -> Turtle
pop t = case stack t of
          []          -> t
          (p,h):rest -> t { pos = p, heading = h, stack = rest }

-- Render a word to a buffer of chars
type Buffer = M.Map (Int,Int) Char

render :: Word -> Double -> Buffer
render w ang = go w identityTurtle M.empty
  where
    go [] _ buf = buf
    go (c:cs) tr buf = case c of
        'F' -> let tr' = step tr 1
                   (x,y,_) = pos tr'
                   ix = round x + 40
                   iy = round y + 12
                   buf' = M.insert (ix,iy) '*' buf
               in go cs tr' buf'
        '+' -> go cs tr{heading = rotate (heading tr)   ang} buf
        '-' -> go cs tr{heading = rotate (heading tr) (-ang)} buf
        '[' -> go cs (push tr) buf
        ']' -> go cs (pop tr)  buf
        _   -> go cs tr buf

display :: Buffer -> IO ()
display buf = do
    clearScreen
    setCursorPosition 0 0
    mapM_ printLine [0..24]
  where
    printLine y = do
        let line = [ M.findWithDefault ' ' (x,y) buf | x <- [0..79] ]
        putStrLn line

-- Mock sound: just print a note description
playTone :: Double -> IO ()
playTone curvature = putStrLn $ "Tone: pitch " ++ show (100 + curvature*200) ++ "Hz"

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    let loop cache = do
            tagLine <- mockHashtags
            let tags = nub $ filter (not . null) $ map (takeWhile isAlphaNum . drop 1) $ words tagLine
            mapM_ (\tag -> do
                sentiment <- randomSentiment
                let lsys = baseLSys { angle = baseLSys.angle + sentiment*10 }
                let word = iterateLSys lsys sentiment
                let buf  = render word (lsys.angle)
                display buf
                let curvature = abs sentiment * 30   -- crude curvature proxy
                playTone curvature
                threadDelay 500000) tags
            loop cache
    loop M.empty