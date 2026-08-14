-- | Interactive Digital Ecosystem in Haskell
-- | Autonomous organisms navigate a canvas composed of live system process tables,
-- | feeding on low-priority threads and mutating their visual geometry on context switches.

import Control.Concurrent (threadDelay)
import Control.Exception (catch, SomeException)
import Control.Monad (forM_)
import System.IO (hSetBuffering, hSetEcho, stdin, stdout, BufferMode(..), hReady)
import System.Process (readProcess)
import System.Random (randomRIO)

-- | Organism shapes representing visual geometry
data Shape = Dot | Triangle | Diamond | Star | Vortex | Rune
  deriving (Show, Enum, Bounded, Eq)

-- | Autonomous entity roaming the process canvas
data Organism = Organism
  { orgId     :: Int
  , orgX      :: Int
  , orgY      :: Int
  , orgEnergy :: Int
  , orgShape  :: Shape
  , orgColor  :: Int -- ANSI color code (31-36)
  } deriving (Show)

-- | Process cell in the system canvas
data ProcessInfo = ProcessInfo
  { procPid  :: String
  , procName :: String
  , procPri  :: Int -- Priority / Nice value (higher = lower priority)
  } deriving (Show)

-- | World state
data World = World
  { organisms    :: [Organism]
  , processGrid  :: [[Maybe ProcessInfo]]
  , width        :: Int
  , height       :: Int
  , contextCount :: Int
  , stepCounter  :: Int
  }

-- | Visual representation of organism shapes
shapeGlyph :: Shape -> String
shapeGlyph Dot      = "."
shapeGlyph Triangle = "^"
shapeGlyph Diamond  = "<>"
shapeGlyph Star     = "*"
shapeGlyph Vortex   = "@"
shapeGlyph Rune     = "#"

-- | Read live process table from OS
fetchProcesses :: IO [ProcessInfo]
fetchProcesses = do
  raw <- readProcess "ps" ["-ax", "-o", "pid,ni,comm"] "" `catch` fallback
  let linesOfPs = drop 1 (lines raw)
  return $ map parseLine linesOfPs
  where
    fallback :: SomeException -> IO String
    fallback _ = return "1 0 init\n2 10 background_worker\n3 19 low_priority_daemon"
    
    parseLine l = case words l of
      (pid:ni:comm) -> ProcessInfo pid (take 8 (unwords comm)) (readDef 0 ni)
      _             -> ProcessInfo "0" "idle" 0

    readDef d s = case reads s of
      [(v, "")] -> v
      _         -> d

-- | Map process list into a 2D canvas grid
buildGrid :: Int -> Int -> [ProcessInfo] -> [[Maybe ProcessInfo]]
buildGrid w h procs =
  let totalCells = w * h
      extended   = take totalCells (cycle (map Just procs ++ replicate 5 Nothing))
  in chunk w extended
  where
    chunk _ [] = []
    chunk n xs = take n xs : chunk n (drop n xs)

-- | Spawn a new organism with random geometry
spawnOrganism :: Int -> Int -> Int -> IO Organism
spawnOrganism i w h = do
  rx <- randomRIO (0, w - 1)
  ry <- randomRIO (0, h - 1)
  s  <- randomRIO (0, fromEnum (maxBound :: Shape))
  c  <- randomRIO (31, 36)
  return $ Organism i rx ry 50 (toEnum s) c

-- | Detect shift/change in process table context
detectContextSwitches :: [ProcessInfo] -> Int -> Int
detectContextSwitches procs prevCount =
  let currentCount = length procs
      diff = abs (currentCount - prevCount)
  in if diff == 0 then 1 else diff

-- | Mutate visual geometry on context switch
mutateOrganism :: Organism -> IO Organism
mutateOrganism org = do
  newS <- randomRIO (0, fromEnum (maxBound :: Shape))
  newC <- randomRIO (31, 36)
  return $ org { orgShape = toEnum newS, orgColor = newC }

-- | Movement and feeding logic
updateOrganism :: World -> Organism -> IO (Organism, World)
updateOrganism w org = do
  dx <- randomRIO (-1, 1)
  dy <- randomRIO (-1, 1)
  let nx = (orgX org + dx) `mod` width w
      ny = (orgY org + dy) `mod` height w
      grid = processGrid w
      cell = (grid !! ny) !! nx
  
  case cell of
    Just p | procPri p > 0 -> do
      -- Feed on low-priority thread (high nice value yields more energy)
      let energyGained = procPri p * 5
          updatedOrg   = org { orgX = nx, orgY = ny, orgEnergy = orgEnergy org + energyGained }
          updatedRow   = take nx (grid !! ny) ++ [Nothing] ++ drop (nx + 1) (grid !! ny)
          updatedGrid  = take ny grid ++ [updatedRow] ++ drop (ny + 1) grid
      return (updatedOrg, w { processGrid = updatedGrid })
    _ -> do
      -- Move and consume metabolic energy
      let updatedOrg = org { orgX = nx, orgY = ny, orgEnergy = max 0 (orgEnergy org - 1) }
      return (updatedOrg, w)

-- | Render process canvas and organisms to ANSI terminal
render :: World -> IO ()
render w = do
  putStr "\ESC[H" -- Move cursor home
  putStrLn "\ESC[1;32m=== AUTONOMOUS DIGITAL ECOSYSTEM (LIVE PROCESS CANVAS) ===\ESC[0m"
  putStrLn $ "Context Switches: " ++ show (contextCount w) ++ " | Active Organisms: " ++ show (length (organisms w))
  putStrLn $ "+" ++ replicate (width w) '-' ++ "+"
  
  let grid = processGrid w
  forM_ [0 .. height w - 1] $ \y -> do
    putStr "|"
    forM_ [0 .. width w - 1] $ \x -> do
      let mbOrg  = filter (\o -> orgX o == x && orgY o == y) (organisms w)
          mbCell = (grid !! y) !! x
      case mbOrg of
        (o:_) -> putStr $ "\ESC[" ++ show (orgColor o) ++ "m" ++ shapeGlyph (orgShape o) ++ "\ESC[0m"
        []    -> case mbCell of
                   Just p | procPri p > 5 -> putStr "\ESC[33m~\ESC[0m" -- Low-priority thread food source
                          | otherwise     -> putStr "\ESC[90m.\ESC[0m" -- Core system thread
                   Nothing                -> putStr " "
    putStrLn "|"
  putStrLn $ "+" ++ replicate (width w) '-' ++ "+"
  putStrLn "Controls: [A] Spawn Organism | [Q] Quit"

-- | Entry point and interactive main loop
main :: IO ()
main = do
  hSetBuffering stdin NoBuffering
  hSetBuffering stdout NoBuffering
  hSetEcho stdin False
  putStr "\ESC[2J" -- Clear terminal
  
  let wWidth  = 60
      wHeight = 20
  
  procs <- fetchProcesses
  let grid = buildGrid wWidth wHeight procs
  
  initialOrgs <- mapM (\i -> spawnOrganism i wWidth wHeight) [1..6]
  let initialWorld = World initialOrgs grid wWidth wHeight 0 0
  
  loop initialWorld
  where
    loop w = do
      render w
      threadDelay 150000 -- Frame rate control
      
      -- Check non-blocking user input
      hasKey <- hReady stdin
      inputChar <- if hasKey then Just <$> getChar else return Nothing
      
      case inputChar of
        Just 'q' -> putStrLn "\ESC[2J\ESC[H\ESC[1;31mSimulation Terminated.\ESC[0m"
        _ -> do
          -- Query live process table state periodically
          newProcs <- if stepCounter w `mod` 25 == 0 then fetchProcesses else return []
          let cs = if null newProcs 
                   then contextCount w 
                   else contextCount w + detectContextSwitches newProcs (length (processGrid w) * width w)
              csOccurred = cs /= contextCount w
          
          -- Mutate organism visual geometry whenever a context switch occurs
          mutatedOrgs <- if csOccurred
                            then mapM mutateOrganism (organisms w)
                            else return (organisms w)
          
          -- Update movement and feeding
          (nextOrgs, nextWorld) <- foldMAccum w mutatedOrgs
          
          -- Handle organism spawning interaction
          spawnedOrgs <- case inputChar of
            Just 'a' -> do
              o <- spawnOrganism (length nextOrgs + 1) (width w) (height w)
              return (o : nextOrgs)
            _ -> return nextOrgs
          
          -- Remove depleted organisms and sync process table
          let livingOrgs = filter (\o -> orgEnergy o > 0) spawnedOrgs
              refreshedGrid = if null newProcs then processGrid nextWorld else buildGrid (width w) (height w) newProcs
          
          loop nextWorld
            { organisms = livingOrgs
            , processGrid = refreshedGrid
            , contextCount = cs
            , stepCounter = stepCounter w + 1
            }

    foldMAccum env [] = return ([], env)
    foldMAccum env (o:os) = do
      (o', env') <- updateOrganism env o
      (os', env'') <- foldMAccum env' os
      return (o':os', env'')