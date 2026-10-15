-- Gravitational N-Body Source Code Compiler & Simulator
-- Translates source code into a gravitational system where syntax errors
-- manifest as supermassive black holes that devour neighboring functions.

import Data.List (intercalate)
import Text.Printf (printf)

data Body = Body
  { name     :: String
  , mass     :: Double
  , posX     :: Double
  , posY     :: Double
  , velX     :: Double
  , velY     :: Double
  , isBH     :: Bool
  , devoured :: Bool
  } deriving (Show)

type Vec = (Double, Double)

-- Compile source code into a universe of bodies
compile :: String -> [Body]
compile src = 
  let rawLines = filter (not . null) (lines src)
  in zipWith parseLine [0..] rawLines

parseLine :: Int -> String -> Body
parseLine i line = 
  let angle = (fromIntegral i * 2 * pi) / 8.0
      radius = 12.0
      x = radius * cos angle
      y = radius * sin angle
      -- Syntax error heuristic: contains "ERROR" or unbalanced braces
      hasError = "ERROR" `elem` words line || countChar '{' line /= countChar '}' line
      m = if hasError then 2000.0 else 1.0
      vMag = if hasError then 0.0 else sqrt (2000.0 / radius)
      vx = if hasError then 0.0 else -vMag * sin angle
      vy = if hasError then 0.0 else vMag * cos angle
  in Body { name = "Func_" ++ show i ++ "_" ++ take 4 (filter (/= ' ') line)
          , mass = m
          , posX = x
          , posY = y
          , velX = vx
          , velY = vy
          , isBH = hasError
          , devoured = False
          }

countChar :: Char -> String -> Int
countChar c = length . filter (== c)

gConst :: Double
gConst = 1.0

-- Simulate one time step using Euler integration and gravitational attraction
step :: Double -> [Body] -> [Body]
step dt bodies = 
  let updatedBodies = map (applyForces dt bodies) bodies
  in checkCollisions updatedBodies

applyForces :: Double -> [Body] -> Body -> Body
applyForces dt allBodies b
  | devoured b = b
  | otherwise = 
      let (fx, fy) = foldr (accForce b) (0.0, 0.0) allBodies
          ax = fx / mass b
          ay = fy / mass b
          nvx = velX b + ax * dt
          nvy = velY b + ay * dt
          npx = posX b + nvx * dt
          npy = posY b + nvy * dt
      in b { posX = npx, posY = npy, velX = nvx, velY = nvy }

accForce :: Body -> Body -> Vec -> Vec
accForce b1 b2 (accX, accY)
  | name b1 == name b2 || devoured b2 = (accX, accY)
  | otherwise =
      let dx = posX b2 - posX b1
          dy = posY b2 - posY b1
          distSq = dx*dx + dy*dy + 0.5 -- softening factor
          dist = sqrt distSq
          f = (gConst * mass b1 * mass b2) / distSq
          fx = f * (dx / dist)
          fy = f * (dy / dist)
      in (accX + fx, accY + fy)

checkCollisions :: [Body] -> [Body]
checkCollisions bodies =
  let bhs = filter (\b -> isBH b && not (devoured b)) bodies
  in map (devourCheck bhs) bodies

devourCheck :: [Body] -> Body -> Body
devourCheck bhs b
  | isBH b || devoured b = b
  | otherwise = 
      case filter (isClose b) bhs of
        (bh:_) -> b { devoured = True, mass = 0.0 }
        []     -> b

isClose :: Body -> Body -> Bool
isClose b1 b2 =
  let dx = posX b1 - posX b2
      dy = posY b1 - posY b2
      distSq = dx*dx + dy*dy
  in distSq < 3.0 -- Event horizon threshold

simulate :: Int -> Double -> [Body] -> [[Body]]
simulate 0 _ bodies = [bodies]
simulate n dt bodies = bodies : simulate (n - 1) dt (step dt bodies)

main :: IO ()
main = do
  let sourceCode = unlines
        [ "main() { return 0; }"
        , "calculate() { return x + y; }"
        , "corruptFunc() { ERROR missing semicolon }"
        , "render() { drawScreen(); }"
        , "logger() { printMsg(); }"
        , "parser() { tokenStream(); }"
        ]
  
  let universe = compile sourceCode
  putStrLn "=== COMPILE STATUS: SUCCESS (Generating Gravitational Topology) ==="
  mapM_ printBodyInfo universe
  
  let frames = simulate 4 0.2 universe
  putStrLn "\n=== SIMULATION EXECUTION ==="
  mapM_ (\(stepNum, frame) -> do
    putStrLn $ "\n--- Tick " ++ show stepNum ++ " ---"
    mapM_ printBodyInfo frame
    ) (zip [0..] frames)

printBodyInfo :: Body -> IO ()
printBodyInfo b = 
  if devoured b
    then putStrLn $ "  [DEVOURRED] Function " ++ name b ++ " was consumed by a syntax black hole!"
    else putStrLn $ printf "  %-20s | Type: %-10s | Pos: (%6.2f, %6.2f) | Mass: %.1f" 
             (name b) 
             (if isBH b then "BLACK HOLE" else "Function") 
             (posX b) 
             (posY b) 
             (mass b)