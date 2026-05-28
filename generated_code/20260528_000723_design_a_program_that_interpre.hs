import Graphics.Gloss
import Graphics.Gloss.Interface.IO.Game
import System.IO
import Control.Concurrent
import Control.Concurrent.STM
import Data.Char (isSpace)
import Data.List (foldl')
import qualified Data.Text as T

-- | State of the program
data World = World
  { poemLines   :: TVar [String]   -- lines of the poem, updated live
  , iter        :: Int             -- current L‑system iteration
  , angle       :: Float           -- turning angle
  , stepLength  :: Float           -- length of forward step
  }

-- | Convert a line of words to an RGB color.
lineToColor :: String -> Color
lineToColor line = makeColorI r g b 255
  where
    lens = map length . words $ line
    r = if length lens > 0 then lens !! 0 `mod` 256 else 0
    g = if length lens > 1 then lens !! 1 `mod` 256 else 0
    b = if length lens > 2 then lens !! 2 `mod` 256 else 0

-- | Simple deterministic L‑system: F → F+F--F+F
lsys :: String -> String
lsys = concatMap replace
  where replace 'F' = "F+F--F+F"
        replace c   = [c]

-- | Expand the axiom n times.
expand :: Int -> String -> String
expand n ax = iterate lsys ax !! n

-- | Turtle graphics: interpret the expanded string.
drawTurtle :: Float -> Float -> String -> Picture
drawTurtle step ang = snd . foldl' stepFunc ((0,0), Blank)
  where
    stepFunc ((x,y), pic) sym = case sym of
      'F' -> let nx = x + step * cos a
                 ny = y + step * sin a
                 line = Color white $ Line [(x,y),(nx,ny)]
              in ((nx,ny), Pictures [pic,line])
      '+' -> ((x,y), pic) -- turn right handled by angle accumulator
      '-' -> ((x,y), pic) -- turn left handled by angle accumulator
      _   -> ((x,y), pic)
      where a = currentAngle
    -- angle accumulator is thread‑local; we simulate by folding with state
    -- but for brevity we keep angle constant (no turns) – a full turtle would need a richer state.
    currentAngle = 0  -- placeholder: actual turning omitted for simplicity

-- | Render the whole world each frame.
render :: World -> IO Picture
render w = do
  linesNow <- readTVarIO (poemLines w)
  let baseColor = case linesNow of
                    (l:_) -> lineToColor l
                    []    -> white
      axiom = "F"
      system = expand (iter w) axiom
      fractal = Color baseColor $ drawTurtle (stepLength w) (angle w) system
      poemPic = translate (-300) 200 $ scale 0.15 0.15 $ Color baseColor $ Text (unlines linesNow)
  return $ Pictures [fractal, poemPic]

-- | Update world each tick: increase iteration slowly.
update :: Float -> World -> IO World
update _ w = return w { iter = iter w + 1 }

-- | No event handling (the poem is edited via stdin thread).
handleEvent :: Event -> World -> IO World
handleEvent _ w = return w

-- | Background thread that reads stdin line‑by‑line and updates the poem.
poemInputThread :: TVar [String] -> IO ()
poemInputThread var = forever $ do
  eof <- hIsEOF stdin
  if eof then threadDelay 100000 else do
    line <- getLine
    atomically $ modifyTVar' var (\ls -> ls ++ [line])

main :: IO ()
main = do
  hSetBuffering stdin LineBuffering
  poemVar <- newTVarIO []
  _ <- forkIO $ poemInputThread poemVar
  let initWorld = World { poemLines = poemVar
                        , iter = 0
                        , angle = 60
                        , stepLength = 5
                        }
  playIO (InWindow "Poem L‑system" (800,600) (100,100))
         black
         30
         initWorld
         render
         handleEvent
         update