import System.Random (randomRIO)
import Control.Concurrent (forkIO, threadDelay, MVar, newMVar, modifyMVar_, readMVar)
import Control.Monad (forever, when)
import Data.Complex (Complex(..))
import Data.List (transpose)
import Data.Word (Word8)
import Graphics.Gloss
import Graphics.Gloss.Data.Picture
import qualified Data.Vector.Unboxed as V

-- Parameters
windowWidth, windowHeight :: Int
windowWidth  = 800
windowHeight = 600

fftSize :: Int
fftSize = 1024        -- size of the simulated FFT buffer

numAgents :: Int
numAgents = 200       -- number of flocking agents

-- Agent data
data Agent = Agent
  { pos   :: (Float, Float)
  , vel   :: (Float, Float)
  , hue   :: Float       -- colour derived from frequency band
  } deriving Show

type World = ([Agent], V.Vector Float)   -- agents + latest spectrum

-- Initialise agents at random positions with zero velocity
initAgents :: IO [Agent]
initAgents = mapM (\_ -> do
    x <- randomRIO (-fromIntegral windowWidth/2, fromIntegral windowWidth/2)
    y <- randomRIO (-fromIntegral windowHeight/2, fromIntegral windowHeight/2)
    h <- randomRIO (0,360)
    return $ Agent (x,y) (0,0) h) [1..numAgents]

-- Simulate an audio stream by generating random amplitudes
audioThread :: MVar (V.Vector Float) -> IO ()
audioThread mv = forever $ do
    -- generate a pseudo‑FFT magnitude spectrum (0..1)
    spectrum <- V.replicateM fftSize (randomRIO (0.0, 1.0))
    modifyMVar_ mv (const $ return spectrum)
    threadDelay 20000   -- ~50 Hz update rate

-- Simple flocking rules influenced by spectrum:
updateAgents :: V.Vector Float -> [Agent] -> [Agent]
updateAgents spec = map $ \a ->
    let (x,y) = pos a
        (vx,vy) = vel a
        -- map x‑position to a frequency band
        bandIdx = floor $ ((x + fromIntegral windowWidth/2) / fromIntegral windowWidth) * fromIntegral fftSize
        bandVal = if bandIdx >= 0 && bandIdx < fftSize then spec V.! bandIdx else 0
        -- attraction to centre weighted by band amplitude
        (cx,cy) = (0,0)
        ax = (cx - x) * bandVal * 0.01
        ay = (cy - y) * bandVal * 0.01
        -- simple cohesion with neighbours
        neigh = filter (\b -> let (dx,dy) = (fst (pos b) - x, snd (pos b) - y)
                                   d2 = dx*dx + dy*dy
                               in d2 > 0 && d2 < 10000) agents
        (cohX,cohY) = if null neigh then (0,0)
                     else let (sx,sy) = foldr (\b (sx,sy) -> let (px,py) = pos b in (sx+px,sy+py)) (0,0) neigh
                              cnt = fromIntegral (length neigh)
                          in ((sx/cnt - x)*0.001, (sy/cnt - y)*0.001)
        -- update velocity and clamp
        nvx = max (-5) $ min 5 $ vx + ax + cohX
        nvy = max (-5) $ min 5 $ vy + ay + cohY
        -- new position wrap around edges
        nx  = wrap (x + nvx) (-fromIntegral windowWidth/2) (fromIntegral windowWidth/2)
        ny  = wrap (y + nvy) (-fromIntegral windowHeight/2) (fromIntegral windowHeight/2)
        -- colour hue follows band amplitude
        nhue = (hue a + bandVal*10) `mod'` 360
    in Agent (nx,ny) (nvx,nvy) nhue
  where
    agents = []  -- placeholder; actual neighbour list filled later
    wrap v lo hi = if v < lo then hi else if v > hi then lo else v
    mod' a b = a - b * fromIntegral (floor (a / b))

-- Convert an agent to a brushstroke picture.
agentPicture :: Agent -> Picture
agentPicture a =
    let (x,y) = pos a
        col = makeColorI (floor $ 127 * (sin (hue a * pi/180) + 1))
                         (floor $ 127 * (sin ((hue a+120) * pi/180) + 1))
                         (floor $ 127 * (sin ((hue a+240) * pi/180) + 1))
                         180
        -- choose a primitive based on band‑derived hue
        pic | hue a < 120 = ThickCircle 2 8          -- stipple
            | hue a < 240 = Line [(x-4,y-4),(x+4,y+4)] -- hatching
            | otherwise   = Circle 6                 -- wash
    in Color col $ Translate x y pic

-- Gloss drawing function
drawWorld :: World -> Picture
drawWorld (agents,_) = Pictures $ map agentPicture agents

-- Gloss step function (pure, no time‑dependent behaviour)
stepWorld :: Float -> World -> World
stepWorld _ (agents,spec) = (updateAgents spec agents, spec)

main :: IO ()
main = do
    spectrumVar <- newMVar (V.replicate fftSize 0)
    agents0 <- initAgents
    _ <- forkIO $ audioThread spectrumVar
    let initWorld = (agents0, V.replicate fftSize 0)
        -- fetch latest spectrum each frame
        worldStep dt w@(_,_) = do
            spec <- readMVar spectrumVar
            return $ stepWorld dt (fst w, spec)
    playIO (InWindow "Audio‑Flocking Canvas" (windowWidth,windowHeight) (100,100))
           black
           60
           initWorld
           (return . drawWorld)
           (\_ _ w -> return w)            -- no input handling
           worldStep