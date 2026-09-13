import System.Random (randomRIO)
import Control.Monad (forM_)
import Data.Complex (Complex((:+)), magnitude)

-- | Represents a quantum-inspired superposition state where coefficients (alpha, beta)
-- dictate the probability of structural stability versus decay upon observation (read).
data QuantumState = State 
  { alpha :: Complex Double  -- Amplitude for stable state |0>
  , beta  :: Complex Double  -- Amplitude for decayed state |1>
  , decay :: Double          -- Accumulated environmental decoherence over time
  } deriving (Show)

-- | An esoteric tree structure whose nodes carry data and a quantum superposition state.
data QuantumFractalTree a 
  = Empty 
  | Node a QuantumState (QuantumFractalTree a) (QuantumFractalTree a)
  deriving (Show)

-- | Initialize a fresh quantum state with equal superposition (|0> + |1>)/sqrt(2).
initQuantumState :: QuantumState
initQuantumState = State (1 / sqrt 2 :+ 0) (1 / sqrt 2 :+ 0) 0.0

-- | Construct a quantum fractal tree of depth n populated with initial values.
buildTree :: Int -> a -> QuantumFractalTree a
buildTree 0 _ = Empty
buildTree depth val = Node val initQuantumState (buildTree (depth - 1) val) (buildTree (depth - 1) val)

-- | Measure a quantum state. Collapses the state and accumulates decay/decoherence.
-- The probability of collapse to decayed state |1> depends on |beta|^2 and current decay.
measureState :: QuantumState -> IO (Bool, QuantumState)
measureState (State a b d) = do
  r <- randomRIO (0.0, 1.0)
  let prob1 = (magnitude b ** 2) + d
  let collapsedToDecay = r < prob1
  -- Evolve amplitudes and increase decay factor for the next observation
  let newDecay = min 1.0 (d + 0.15)
  let newA = a * (0.8 :+ 0.1)
  let newB = b * (1.1 :+ (-0.05))
  return (collapsedToDecay, State newA newB newDecay)

-- | Read operation on the data structure.
-- Reading mutates the tree: reading a node measures its quantum state, transforming it
-- into a visually coherent Mandelbrot/Julia-inspired ASCII fractal character based on state values.
readMutate :: QuantumFractalTree String -> IO (QuantumFractalTree String, String)
readMutate Empty = return (Empty, "")
readMutate (Node val qState left right) = do
  (isDecayed, newQState) <- measureState qState
  
  -- Mutate current node value to a fractal character using complex state coordinates
  let c = alpha newQState
  let mutatedVal = renderFractalChar c (decay newQState) isDecayed
  
  -- Recurse and mutate subtrees
  (left', leftAscii)   <- readMutate left
  (right', rightAscii) <- readMutate right
  
  let currentTreeAscii = renderTreeASCII mutatedVal leftAscii rightAscii
  return (Node mutatedVal newQState left' right', currentTreeAscii)

-- | Maps quantum complex amplitudes to ASCII density characters (Mandelbrot-style escape dynamics).
renderFractalChar :: Complex Double -> Double -> Bool -> String
renderFractalChar (re :+ im) decayFactor isDecayed
  | isDecayed = [decayPalette !! (floor (decayFactor * 5) `mod` length decayPalette)]
  | otherwise = [fractalPalette !! (floor (magnitude (re :+ im) * 8) `mod` length fractalPalette)]
  where
    fractalPalette = " .:-=+*#%@"
    decayPalette   = " ░▒▓█"

-- | Helper to lay out mutated node values into an ASCII fractal tree projection.
renderTreeASCII :: String -> String -> String -> String
renderTreeASCII val leftStr rightStr =
  val ++ "\n├── " ++ indent leftStr ++ "└── " ++ indent rightStr
  where
    indent = unlines . map ("│   " ++) . lines

main :: IO ()
main = do
  putStrLn "=== Initializing Esoteric Quantum Fractal Tree ==="
  let tree = buildTree 3 "Q"
  
  putStrLn "\n--- READ OPERATION 1 (Observation Mutates State) ---"
  (tree1, visual1) <- readMutate tree
  putStrLn visual1

  putStrLn "\n--- READ OPERATION 2 (Further Decay & Fractal Mutation) ---"
  (tree2, visual2) <- readMutate tree1
  putStrLn visual2

  putStrLn "\n--- READ OPERATION 3 (Decoherence Acceleration) ---"
  (_, visual3) <- readMutate tree2
  putStrLn visual3