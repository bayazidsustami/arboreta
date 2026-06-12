import Graphics.Gloss
import Graphics.Gloss.Interface.IO.Game
import System.Random
import Data.Char (isAlpha, toLower)
import qualified Data.Map.Strict as M
import Data.List (group, sort)
import Control.Monad (forM_)
import Data.Maybe (fromMaybe)

-- | A seed representing a word.
data Seed = Seed
  { sPos   :: Point          -- ^ position (x,y)
  , sVel   :: (Float,Float)  -- ^ velocity
  , sWord  :: String         -- ^ original word
  , sColor :: Color          -- ^ display colour (sentiment)
  , sSize  :: Float          -- ^ radius (POS + frequency)
  }

type World = [Seed]

-- dummy sentiment: happy words (contain 'a','e','i','o','u') are warm colours
sentimentColor :: String -> Color
sentimentColor w = case any (`elem` "aeiou") (map toLower w) of
  True  -> makeColorI 255 180  50 255   -- orange
  False -> makeColorI  50 120 255 255   -- blue

-- dummy POS: words starting with a capital are nouns (bigger)
posSize :: String -> Float
posSize w = if not (null w) && head w `elem` ['A'..'Z']
               then 30 else 15

-- frequency factor: more common words are larger
freqSize :: M.Map String Int -> String -> Float
freqSize freq w = 5 * fromIntegral (fromMaybe 1 (M.lookup (map toLower w) freq))

-- create seeds from text
makeSeeds :: String -> IO World
makeSeeds txt = do
  let ws = filter (not . null) $ words txt
      freq = M.fromListWith (+) [(map toLower w,1) | w <- ws]
  gen <- newStdGen
  let positions = take (length ws) $ randomRs ((-300,300),(-200,200)) gen
  return [ Seed
            { sPos   = p
            , sVel   = (0,0)
            , sWord  = w
            , sColor = sentimentColor w
            , sSize  = posSize w + freqSize freq w
            }
         | (w,p) <- zip ws positions ]

-- update world each time step
updateWorld :: Float -> World -> IO World
updateWorld dt seeds = return $ map (moveSeed dt) seeds

moveSeed :: Float -> Seed -> Seed
moveSeed dt s = s { sPos = (x+vx*dt, y+vy*dt) }
  where
    (x,y) = sPos s
    (vx,vy) = sVel s

-- handle mouse drag as wind
handleEvent :: Event -> World -> IO World
handleEvent (EventMotion (mx,my)) seeds = return $ map (applyWind (mx,my)) seeds
handleEvent _ seeds = return seeds

applyWind :: Point -> Seed -> Seed
applyWind (mx,my) s = s { sVel = (vx+dx, vy+dy) }
  where
    (x,y) = sPos s
    (vx,vy) = sVel s
    dx = (mx - x) * 0.001
    dy = (my - y) * 0.001

-- draw the world
drawWorld :: World -> IO Picture
drawWorld seeds = return $ Pictures $ map drawSeed seeds

drawSeed :: Seed -> Picture
drawSeed s = Translate x y $ Color (sColor s) $ Pictures
  [ ThickCircle (sSize s) (sSize s + 2)
  , Translate (-txtW/2) (-8) $ Scale 0.1 0.1 $ Color black $ Text (sWord s)
  ]
  where
    (x,y) = sPos s
    txtW = fromIntegral (length (sWord s)) * 10

-- generate new poetic sentence by shuffling words each frame
reencode :: World -> IO World
reencode seeds = do
  let ws = map sWord seeds
  gen <- newStdGen
  let shuffled = shuffle gen ws
  return $ zipWith (\s w -> s { sWord = w }) seeds shuffled

shuffle :: StdGen -> [a] -> [a]
shuffle gen xs = map snd $ sortOn fst $ zip (randoms gen :: [Int]) xs

main :: IO ()
main = do
  putStrLn "Enter text (end with Ctrl+D):"
  txt <- getContents
  initSeeds <- makeSeeds txt
  playIO
    (InWindow "Voronoi Poetry" (800,600) (100,100))
    black
    60
    initSeeds
    drawWorld
    handleEvent
    (\dt w -> updateWorld dt w >>= reencode)