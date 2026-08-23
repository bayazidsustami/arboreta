import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.MVar
import Control.Monad (forever, forM_, when)
import Data.Complex
import GHC.Stats
import System.Exit (exitSuccess)
import System.IO (hSetBuffering, BufferMode(NoBuffering), stdout)
import System.Random (randomRIO)

-- Non-Euclidean Poincaré disk transformation for hyperbolic AST spatial rendering
poincareTransform :: Complex Double -> Complex Double
poincareTransform z
  | magnitude z >= 1.0 = z / (realToFrac (magnitude z) + 0.001)
  | otherwise          = z / (1 + sqrt (1 - (magnitude z ** 2)))

-- AST Node representing the evolving organism's organs
data ASTNode 
  = Module String [ASTNode]
  | Function String [ASTNode] Int
  | Expression String Double
  deriving (Show)

-- Represents an organ with non-Euclidean hyperbolic coordinates
data Organ = Organ
  { organName :: String
  , organPos  :: Complex Double
  , organMass :: Double
  , organPulsation :: Double
  } deriving (Show)

-- Mutates AST based on live system memory pressure
mutateAST :: ASTNode -> Double -> IO ASTNode
mutateAST node memRatio = case node of
  Module name children -> do
    newChildren <- mapM (`mutateAST` memRatio) children
    if memRatio > 0.6
      then return $ Module (name ++ "*") newChildren
      else return $ Module name newChildren
  Function name children size -> do
    delta <- randomRIO (-1, 2)
    let newSize = max 1 (size + delta)
    return $ Function name children newSize
  Expression name val -> do
    shift <- randomRIO (-0.1, 0.1)
    return $ Expression name (val + shift * memRatio)

-- Extracts hyperbolic organs from the mutating AST
flattenToOrgans :: ASTNode -> Complex Double -> Double -> [Organ]
flattenToOrgans node parentPos scale = case node of
  Module name children ->
    Organ name parentPos scale 1.0 : concatMap (\(i, c) -> 
      let angle = (fromIntegral i / fromIntegral (length children)) * 2 * pi
          offset = (scale :+ 0) * exp (0 :+ angle)
          pos = poincareTransform (parentPos + offset)
      in flattenToOrgans c pos (scale * 0.5)) (zip [0..] children)
  Function name children sz ->
    Organ name parentPos (fromIntegral sz * scale) 1.2 : concatMap (\(i, c) ->
      let angle = (fromIntegral i / fromIntegral (length children)) * 2 * pi
          offset = ((scale * 0.7) :+ 0) * exp (0 :+ angle)
          pos = poincareTransform (parentPos + offset)
      in flattenToOrgans c pos (scale * 0.4)) (zip [0..] children)
  Expression name val ->
    [Organ name parentPos (val * scale) 0.8]

-- ASCII frame renderer mapping hyperbolic coords to screen grid
renderOrganism :: [Organ] -> Int -> Int -> String
renderOrganism organs width height = 
  let grid = [[ cellAt (x - width `div` 2) (y - height `div` 2) | x <- [0..width]] | y <- [0..height]]
      cellAt x y =
        let rx = fromIntegral x / (fromIntegral width / 2)
            ry = fromIntegral y / (fromIntegral height / 2)
            pt = rx :+ ry
            hit = filter (\o -> magnitude (organPos o - pt) < (0.15 * organMass o)) organs
        in case hit of
             [] -> ' '
             (o:_) -> if organPulsation o > 1.0 then '✹' else '◉'
  in "\ESC[2J\ESC[H--- HYPERBOLIC AST ORGANISM (GC EVOLUTION) ---\n" ++ unlines grid

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  let initialAST = Module "Root" 
        [ Function "gc_alloc" [Expression "heap" 1.2, Expression "stack" 0.8] 3
        , Function "topological_warp" [Expression "metric" 2.1] 5
        , Function "mutate" [Expression "entropy" 0.5] 2
        ]
  astMVar <- newMVar initialAST
  
  -- Background thread tracking RTS telemetry & driving AST mutations
  _ <- forkIO . forever $ do
    stats <- getRTSStats
    let allocated = fromIntegral (allocated_bytes stats) / (1024 * 1024 * 1024)
        gcs = gcs stats
    ast <- takeMVar astMVar
    mutated <- mutateAST ast (min 1.0 (allocated + fromIntegral gcs * 0.05))
    putMVar astMVar mutated
    threadDelay 100000

  -- Primary interaction loop rendering non-Euclidean organism deformation
  let loop frame = do
        ast <- readMVar astMVar
        let organs = flattenToOrgans ast (0.0 :+ 0.0) 0.8
            pulsingOrgans = map (\o -> o { organPulsation = 1.0 + 0.3 * sin (fromIntegral frame * 0.2) }) organs
        putStrLn (renderOrganism pulsingOrgans 60 20)
        threadDelay 150000
        loop (frame + 1)
  
  loop 0