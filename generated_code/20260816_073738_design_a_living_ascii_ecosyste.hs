import Control.Concurrent (threadDelay)
import Control.Monad (forM, forM_)
import Data.Bits (xor)
import System.IO (hFlush, stdout)
import System.Random (randomRIO)

-- ASCII Representation of Ecosystem Components
-- Source Code Constructs: '(', ')', ';', '=', '+', '{', '}', '$'
-- Bugs (Invasive Species): '🐛', '👾', '🦠'
-- Dead / Collected Memory: '.'

type Ecosystem = [[Char]]

height :: Int
height = 12

width :: Int
width = 40

-- Initial source code block template
initialGrid :: Ecosystem
initialGrid =
  [ "function main() {                      ",
    "  let energy = 100 + initial;           ",
    "  if (gc_run == true) {                 ",
    "    sweep_memory();                     ",
    "    reclaim_unused_pointers();          ",
    "  }                                     ",
    "  return process_data(energy);          ",
    "}                                       ",
    "// Allocation pool initialization      ",
    "let buffer = new Array(1024);           ",
    "free_list = [0xDEAD, 0xBEEF];           ",
    "/* Ecosystem execution payload */       "
  ]

-- Seed a few invasive bugs into the ecosystem
seedBugs :: Ecosystem -> IO Ecosystem
seedBugs grid = do
  grid' <- injectBug '👾' 2 5 grid
  grid'' <- injectBug '🐛' 5 12 grid'
  injectBug '🦠' 9 20 grid''
  where
    injectBug bug r c g = return $ setCell r c bug g

getCell :: Int -> Int -> Ecosystem -> Char
getCell r c g = (g !! r) !! c

setCell :: Int -> Int -> Char -> Ecosystem -> Ecosystem
setCell r c val g =
  take r g ++ [take c (g !! r) ++ [val] ++ drop (c + 1) (g !! r)] ++ drop (r + 1) g

isBug :: Char -> Bool
isBug ch = ch `elem` ['🐛', '👾', '🦠']

isSourceCode :: Char -> Bool
isSourceCode ch = not (isBug ch) && ch /= '.' && ch /= ' '

-- Garbage collection attempt: sweeps non-essential code and unattached bytes
runGarbageCollector :: Ecosystem -> Ecosystem
runGarbageCollector = map (map sweep)
  where
    sweep ch
      | isBug ch = ch -- Bugs resist direct sweeping by mutating surrounding memory
      | ch `elem` [';', '=', '+', '{', '}', '(', ')', '$'] = '.' -- Structural code swept
      | otherwise = ch

-- Mutate surrounding source code bytes to disguise or feed the bug
mutateByte :: Char -> IO Char
mutateByte ch
  | ch == ' ' || ch == '.' = return ' '
  | otherwise = do
      r <- randomRIO (0, 3 :: Int)
      let ops = ['$', '=', '+', '(', '}', '🦠', '👾', ';']
      return $ ops !! r

-- Advance one generation of the ecosystem
stepEcosystem :: Ecosystem -> IO Ecosystem
stepEcosystem g = do
  -- First perform a GC cycle
  let postGC = runGarbageCollector g
  
  -- Next, bugs react to survival pressure by spreading and mutating adjacent source code
  newG <- forM [0 .. height - 1] $ \r ->
    forM [0 .. width - 1] $ \c -> do
      let current = getCell r c postGC
      if isBug current
        then mutateOrReplicate r c postGC
        else return current

  -- Flatten row updates into cohesive grid
  return $ buildNextGrid newG postGC

mutateOrReplicate :: Int -> Int -> Ecosystem -> IO Char
mutateOrReplicate r c g = do
  action <- randomRIO (0, 10 :: Int)
  if action > 7
    then mutateByte (getCell r c g)
    else return (getCell r c g)

buildNextGrid :: [[Char]] -> Ecosystem -> Ecosystem
buildNextGrid mutated current =
  [ [ resolveCell r c | c <- [0 .. width - 1] ]
  | r <- [0 .. height - 1]
  ]
  where
    resolveCell r c =
      let cell = getCell r c current
          adjBugs = countAdjacentBugs r c current
      in if isSourceCode cell && adjBugs > 0
           then mutateCodeChar cell adjBugs
           else if cell == '.' && adjBugs >= 2
                  then '🐛' -- Invasive species spawns in reclaimed memory
                  else cell

    countAdjacentBugs r c g =
      length [ () | dr <- [-1..1], dc <- [-1..1], (dr, dc) /= (0,0),
                    let nr = r + dr, let nc = c + dc,
                    nr >= 0, nr < height, nc >= 0, nc < width,
                    isBug (getCell nr nc g) ]

    mutateCodeChar ch count =
      let code = fromEnum ch
          mutatedCode = toEnum ((code + count * 13) `mod` 94 + 32)
      in if count > 2 then '👾' else mutatedCode

-- Render the simulation in terminal using ANSI control sequences
render :: Int -> Ecosystem -> IO ()
render gen grid = do
  putStr "\ESC[2J\ESC[H" -- Clear screen & reset cursor
  putStrLn $ "=== ASCII ECOSYSTEM: GARBAGE COLLECTION VS INVASIVE BUGS ==="
  putStrLn $ "Generation: " ++ show gen ++ " | Adaptive Mutation Active\n"
  mapM_ putStrLn grid
  putStrLn "\nStatus: Bugs actively hijacking AST & memory pointers."
  hFlush stdout

loop :: Int -> Ecosystem -> IO ()
loop gen grid = do
  render gen grid
  threadDelay 250000 -- Pause 250ms per tick
  nextGrid <- stepEcosystem grid
  loop (gen + 1) nextGrid

main :: IO ()
main = do
  initialEcosystem <- seedBugs initialGrid
  loop 1 initialEcosystem