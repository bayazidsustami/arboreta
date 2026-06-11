import System.Environment (getArgs)
import System.IO (readFile)
import Data.Char (isAlpha, toLower)
import Data.List (group, sort, sortOn, maximumBy)
import Data.Ord (comparing)
import qualified Data.Map.Strict as M
import Graphics.Gloss
import Graphics.Gloss.Data.ViewPort (ViewPort)
import Graphics.Gloss.Interface.IO.Simulate (simulateIO)

-- Simple sentiment dictionary (very naive)
sentiment :: M.Map String Double
sentiment = M.fromList [("love",0.9),("joy",0.8),("happy",0.7),("sad",-0.7),("pain",-0.8),("death",-0.9)]

-- Analyze a line: count syllables (approx), find last word for rhyme, compute sentiment
analyzeLine :: String -> (Int,String,Double)
analyzeLine l = (syllables, rhyme, emot)
 where
   words' = filter (not . null) $ words $ map toLower l
   lastWord = if null words' then "" else last words'
   rhyme = take 3 $ reverse $ takeWhile (/= '\'') $ reverse lastWord ++ "   "
   syllables = length $ filter (`elem` "aeiouy") $ concat words'
   emot = sum [ M.findWithDefault 0 w sentiment | w <- words' ] / max 1 (fromIntegral $ length words')

-- Aggregate poem data
data PoemInfo = PoemInfo {
    meter   :: [Int],          -- syllable count per line
    rhymes  :: [String],       -- rhyme key per line
    emotions :: [Double]       -- sentiment per line
  }

extractInfo :: String -> PoemInfo
extractInfo txt = PoemInfo ms rs es
 where
   lines' = filter (not . null) $ lines txt
   analyses = map analyzeLine lines'
   ms = map (\(s,_,_) -> s) analyses
   rs = map (\(_,r,_) -> r) analyses
   es = map (\(_,_,e) -> e) analyses

-- Particle definition
data Particle = Particle {
    pos   :: (Float,Float,Float),
    vel   :: (Float,Float,Float),
    col   :: Color,
    age   :: Float
  }

-- Create particles from poem info
initParticles :: PoemInfo -> [Particle]
initParticles (PoemInfo ms rs es) = zipWith3 mkParticle ms rs es
 where
   mkParticle syl rhyme emot = Particle {
        pos = (0,0,0),
        vel = (fromIntegral syl * 0.5, fromIntegral (length rhyme) * 0.3, emot * 2),
        col = blend 0.5 blue (if emot>0 then makeColor 1 0 0 1 else makeColor 0 0 1 1),
        age = 0
     }

-- Update a particle each frame (gravity + damping)
updateParticle :: Float -> Particle -> Particle
updateParticle dt p = p { pos = (x+dx*dt, y+dy*dt, z+dz*dt)
                        , vel = (dx*0.99, dy*0.99-9.8*dt*0.05, dz*0.99)
                        , age = age p + dt }
 where
   (x,y,z) = pos p
   (dx,dy,dz) = vel p

-- Convert particle to a drawable sphere
particlePicture :: Particle -> Picture
particlePicture p = translate x y $ color (col p) $ circleSolid (2 + age p*0.5)
 where
   (x,y,_) = pos p

-- Main simulation loop
main :: IO ()
main = do
   args <- getArgs
   txt  <- case args of
             [f] -> readFile f
             _   -> putStrLn "Usage: poem3d <file>" >> readFile "poem.txt"
   let info = extractInfo txt
   let particles = initParticles info
   simulateIO
     (InWindow "Poem Sculpture" (800,600) (100,100))
     black
     60
     particles
     (\ps -> return $ pictures $ map particlePicture ps)
     (\view dt ps -> return $ map (updateParticle dt) ps)