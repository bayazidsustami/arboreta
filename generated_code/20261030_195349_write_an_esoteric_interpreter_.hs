-- A musical-interval esoteric interpreter and fractal tree generator in Haskell.
-- Instructions: Musical intervals and chords mutate the growth parameters of a living fractal tree.

module Main where

-- Musical tokens representing microphone inputs
data Interval 
  = Unison | MinorSecond | MajorSecond | MinorThird | MajorThird
  | PerfectFourth | Tritone | PerfectFifth | MinorSixth | MajorSixth
  | MinorSeventh | MajorSeventh | Octave
  deriving (Show, Eq, Enum)

-- The state of our living fractal tree
data TreeState = TreeState
  { angle      :: Double   -- Branching angle
  , lengthMul  :: Double   -- Length multiplier per recursion
  , depth      :: Int      -- Max recursion depth
  , branchChar :: Char     -- Character used for rendering
  } deriving (Show)

initialState :: TreeState
initialState = TreeState 25.0 0.7 5 '*'

-- Interpret a musical interval to modify tree parameters
applyInterval :: Interval -> TreeState -> TreeState
applyInterval Unison t       = t { depth = min 8 (depth t + 1) }
applyInterval MajorThird t   = t { angle = angle t + 5.0 }
applyInterval MinorThird t   = t { angle = angle t - 5.0 }
applyInterval PerfectFifth t = t { lengthMul = min 0.9 (lengthMul t + 0.05) }
applyInterval Octave t       = t { depth = max 1 (depth t - 1) }
applyInterval _ t            = t

-- Interpret a sequence of musical inputs (simulating microphone stream)
interpret :: [Interval] -> TreeState -> TreeState
interpret [] st     = st
interpret (x:xs) st = interpret xs (applyInterval x st)

-- Procedural generation of a fractal tree representation
renderTree :: TreeState -> [String]
renderTree st = 
  [ "--- Living Fractal Tree Evolution ---"
  , "Current Angle: " ++ show (angle st) ++ "°"
  , "Recursion Depth: " ++ show (depth st)
  , "Length Multiplier: " ++ show (lengthMul st)
  , ""
  , simulateBranches (depth st) (branchChar st)
  ]

simulateBranches :: Int -> Char -> String
simulateBranches d c = unlines [ replicate i c | i <- [1..d*2] ]

main :: IO ()
main = do
  putStrLn "Initializing Esoteric Musical Interpreter..."
  putStrLn "Capturing microphone stream and parsing intervals..."
  
  -- Simulated musical performance captured from the mic:
  let performance = [MajorThird, MajorThird, PerfectFifth, MajorThird, Octave, Unison]
  
  let finalState = interpret performance initialState
  mapM_ putStrLn (renderTree finalState)
  putStrLn "Fractal tree evolution state finalized."