-- Acoustic Oceanography Simulator in Haskell
-- Real-time system memory usage dictates fluid density, perturbing sound velocity,
-- refracting ASCII sonar waves, and echoing poetic fragments through an abyss of organisms.

import Control.Concurrent (threadDelay)
import Control.Monad (forM_, when)
import Data.Char (isDigit)
import Data.List (isPrefixOf)
import System.Directory (doesFileExist)
import System.IO (BufferMode (..), hSetBuffering, hSetEcho, stdout)
import System.Random (randomRIO)

-- Poetic fragments echoed by marine organisms upon sonar impact
poeticFragments :: [String]
poeticFragments =
  [ "echoes of forgotten light...",
    "the pressure hums in quiet minor...",
    "drifting through bioluminescent silence...",
    "abyssal resonance calling back...",
    "density folds the sound back into night...",
    "membrane vibrations in the deep blue...",
    "phosphorescent memories in suspension..."
  ]

-- Visual representations of deep-sea entities
organismGlyphs :: [String]
organismGlyphs = ["<><", "}(((°>", "<:::X~~", "o0O°", "*:.°", "~~{O}~~", "<===#"]

data Organism = Organism
  { orgX :: Int,
    orgY :: Int,
    orgGlyph :: String,
    orgDepth :: Double
  }

data SonarPulse = SonarPulse
  { pulseX :: Double,
    pulseY :: Double,
    pulseVx :: Double,
    pulseVy :: Double,
    pulseChar :: Char,
    pulseLife :: Int
  }

data SimulationState = SimulationState
  { organisms :: [Organism],
    pulses :: [SonarPulse],
    echoes :: [(Int, Int, String, Int)], -- (x, y, text, ttl)
    timeStep :: Int
  }

-- Fetch real-time system memory usage ratio (0.0 to 1.0)
getMemoryDensity :: IO Double
getMemoryDensity = do
  exists <- doesFileExist "/proc/meminfo"
  if exists
    then do
      contents <- readFile "/proc/meminfo"
      let ls = lines contents
          extractVal key = case filter (isPrefixOf key) ls of
            (line : _) -> case filter isDigit line of
              "" -> 1.0
              ds -> read ds :: Double
            [] -> 1.0
          tot = extractVal "MemTotal:"
          free = extractVal "MemAvailable:"
      pure $! if tot > 0 then 1.0 - (free / tot) else 0.5
    else pure 0.45

-- Initialize ocean ecosystem
initEcosystem :: IO [Organism]
initEcosystem = sequence [spawnOrg | _ <- [1 .. 12]]
  where
    spawnOrg = do
      x <- randomRIO (5, 70)
      y <- randomRIO (4, 18)
      idx <- randomRIO (0, length organismGlyphs - 1)
      pure $ Organism x y (organismGlyphs !! idx) (fromIntegral y / 20.0)

-- Spawn a sonar pulse from top ocean boundary
spawnSonar :: IO SonarPulse
spawnSonar = do
  x <- randomRIO (10, 70)
  vx <- randomRIO (-0.5, 0.5)
  pure $ SonarPulse (fromIntegral (x :: Int)) 2.0 vx 1.0 ')' 30

-- ANSI Terminal Helpers
clearScreen :: IO ()
clearScreen = putStr "\ESC[2J\ESC[H\ESC[?25l"

moveCursor :: Int -> Int -> IO ()
moveCursor x y = putStr $ "\ESC[" ++ show y ++ ";" ++ show x ++ "H"

setColor :: String -> IO ()
setColor code = putStr $ "\ESC[" ++ code ++ "m"

resetColor :: IO ()
resetColor = putStr "\ESC[0m"

-- Render top banner and diagnostics
renderUI :: Double -> Double -> IO ()
renderUI memRatio density = do
  moveCursor 1 1
  setColor "36;1"
  putStr "=== ACOUSTIC OCEANOGRAPHY SIMULATOR [Haskell] ==="
  moveCursor 1 2
  setColor "33"
  let memPct = floor (memRatio * 100) :: Int
  putStr $ "Fluid Density: " ++ show density ++ " g/cm^3 | Sys Mem Usage: " ++ show memPct ++ "%"
  resetColor

-- Main simulation step
updateStep :: SimulationState -> Double -> IO SimulationState
updateStep state density = do
  -- Update organisms (slight drift)
  newOrgs <- mapM driftOrg (organisms state)

  -- Random pulse generation
  spawnChance <- randomRIO (1 :: Int, 5)
  newPulseList <-
    if spawnChance == 1
      then do
        p <- spawnSonar
        pure (p : pulses state)
      else pure (pulses state)

  -- Update sonar pulses based on fluid density refraction
  let (updatedPulses, newEchoes) = foldr (stepPulse density (organisms state)) ([], echoes state) newPulseList

  -- Decay old echoes
  let activeEchoes = [(x, y, txt, ttl - 1) | (x, y, txt, ttl) <- newEchoes, ttl > 0]

  pure $ SimulationState newOrgs updatedPulses activeEchoes (timeStep state + 1)
  where
    driftOrg org = do
      dx <- randomRIO (-1, 1)
      let nx = max 4 (min 72 (orgX org + dx))
      pure $ org {orgX = nx}

-- Physics: pulse movement, refraction by density gradient, and collision detection
stepPulse :: Double -> [Organism] -> SonarPulse -> ([SonarPulse], [(Int, Int, String, Int)]) -> ([SonarPulse], [(Int, Int, String, Int)])
stepPulse density orgs pulse (accP, accE) =
  let -- Refraction alters vertical speed proportional to fluid density
      refractedVy = pulseVy pulse * (1.0 + (density - 0.5) * 0.3)
      nx = pulseX pulse + pulseVx pulse
      ny = pulseY pulse + refractedVy
      nl = pulseLife pulse - 1
      ix = floor nx
      iy = floor ny
      -- Check collision with organisms
      hitOrg = filter (\o -> abs (orgX o - ix) <= 2 && orgY o == iy) orgs
   in if nl <= 0 || ix < 2 || ix > 75 || iy < 3 || iy > 20
        then (accP, accE)
        else case hitOrg of
          (o : _) ->
            let fragmentIdx = (ix + iy) `mod` length poeticFragments
                echo = (orgX o, orgY o - 1, poeticFragments !! fragmentIdx, 8)
             in (accP, echo : accE)
          [] ->
            let np = pulse {pulseX = nx, pulseY = ny, pulseVy = refractedVy, pulseLife = nl}
             in (np : accP, accE)

-- Display rendered layer to terminal
renderScene :: SimulationState -> IO ()
renderScene state = do
  -- Clear oceanic grid area
  forM_ [3 .. 21] $ \y -> do
    moveCursor 1 y
    putStr $ replicate 78 ' '

  -- Render water depth gradient background lines
  forM_ [4, 8, 12, 16, 20] $ \y -> do
    moveCursor 2 y
    setColor "34;2"
    putStr $ replicate 76 '~'

  -- Render Organisms
  forM_ (organisms state) $ \o -> do
    moveCursor (orgX o) (orgY o)
    setColor "32;1"
    putStr (orgGlyph o)

  -- Render Sonar Pulses
  forM_ (pulses state) $ \p -> do
    moveCursor (floor (pulseX p)) (floor (pulseY p))
    setColor "36;1"
    putChar (pulseChar p)

  -- Render Poetic Echoes
  forM_ (echoes state) $ \(x, y, txt, _) -> do
    moveCursor (max 2 (min 50 x)) (max 3 y)
    setColor "35;1"
    putStr $ "* " ++ txt

  resetColor

-- Recursive simulation loop
simLoop :: SimulationState -> IO ()
simLoop state = do
  memRatio <- getMemoryDensity
  -- Density dynamic scale: Base 1.00 + memory impact
  let fluidDensity = 1.00 + (memRatio * 0.45)
  renderUI memRatio fluidDensity
  renderScene state
  hSetBuffering stdout NoBuffering
  threadDelay 120000 -- Frame speed constraint (~8 FPS)
  nextState <- updateStep state fluidDensity
  simLoop nextState

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  hSetEcho stdin False
  clearScreen
  initialOrgs <- initEcosystem
  let initialState = SimulationState initialOrgs [] [] 0
  simLoop initialState