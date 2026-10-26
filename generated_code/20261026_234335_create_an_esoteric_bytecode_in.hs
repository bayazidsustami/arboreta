-- Whispering Bytecode Interpreter & Fractal Bird Simulator in Haskell
import Control.Monad (forever, when)
import Control.Concurrent (threadDelay)
import System.IO (hSetBuffering, stdout, BufferMode(NoBuffering))
import Data.Time.Clock.POSIX (getPOSIXTime)

-- Bytecode Instructions representing the esoteric machine
data Inst = Push Double | Add | Mul | ResJump Int | Draw | BirdUpdate | Nop
  deriving (Show)

-- Interpreter State
data State = State {
    stack :: [Double],
    pc :: Int,
    resonance :: Double,
    birds :: [(Double, Double, Double)] -- x, y, wing phase
} deriving (Show)

-- Simulating acoustic resonance from whispering via dynamic wave functions
sampleAcousticResonance :: IO Double
sampleAcousticResonance = do
    t <- fmap realToFrac getPOSIXTime
    return (sin (t * 3.5) * cos (t * 1.2) + 1.2)

-- Floating-point wrap-around helper
wrap :: Double -> Double -> Double
wrap val limit = val - limit * fromIntegral (floor (val / limit))

-- Execute a single bytecode instruction
step :: Inst -> State -> IO State
step (Push val) s = return s { stack = val : stack s, pc = pc s + 1 }
step Add s = case stack s of
    (y:x:rest) -> return s { stack = (x + y) : rest, pc = pc s + 1 }
    _ -> return s { pc = pc s + 1 }
step Mul s = case stack s of
    (y:x:rest) -> return s { stack = (x * y) : rest, pc = pc s + 1 }
    _ -> return s { pc = pc s + 1 }
step (ResJump target) s = 
    if resonance s > 1.5 
        then return s { pc = target }
        else return s { pc = pc s + 1 }
step Draw s = do
    putStr "\ESC[H\ESC[2J" -- Clear terminal screen using ANSI escape
    putStrLn "=== ACOUSTIC RESONANCE FRACTAL BIRD SIMULATOR ==="
    putStrLn $ "Whisper Resonance Level: " ++ show (resonance s)
    let r = resonance s
    let rows = 14
    let cols = 40
    -- Render dynamic fractal landscape driven by resonance
    mapM_ (\y -> do
        mapM_ (\x -> do
            let cx = (fromIntegral x / fromIntegral cols) * 3.0 - 2.0
            let cy = (fromIntegral y / fromIntegral rows) * 2.0 - 1.0
            let val = sin (cx * cx + cy * cy + r * 2.5) * cos (cx * cy - r)
            putChar $ if val > 0.2 then 'v' else if val > -0.2 then '~' else '.'
          ) [0..cols-1]
        putChar '\n'
      ) [0..rows-1]
    putStrLn "Migrating birds soaring through the acoustic ether..."
    mapM_ (\(bx, by, _) -> do
        let spaces = replicate (floor (wrap bx (fromIntegral cols))) ' '
        putStrLn (spaces ++ "v^v")
      ) (birds s)
    return s { pc = pc s + 1 }
step BirdUpdate s = do
    let newBirds = map (\(x, y, p) -> (wrap (x + 1.0) 40.0, y, p + 0.3)) (birds s)
    return s { birds = newBirds, pc = pc s + 1 }
step Nop s = return s { pc = pc s + 1 }

-- Esoteric bytecode program
program :: [Inst]
program = [
    Push 5.0,
    Push 3.0,
    Add,
    Draw,
    BirdUpdate,
    ResJump 0,
    Push 2.0,
    Mul,
    Draw,
    ResJump 0
  ]

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    putStr "\ESC[?25l" -- Hide terminal cursor
    let initialState = State [] 0 1.0 [(2.0, 2.0, 0.0), (12.0, 4.0, 1.0), (25.0, 6.0, 2.0)]
    let run loopState pcIdx
            | pcIdx >= length program = return ()
            | otherwise = do
                res <- sampleAcousticResonance
                let currState = loopState { resonance = res }
                nextState <- step (program !! pcIdx) currState
                threadDelay 120000 -- Control frame rate (~8.3 FPS)
                run nextState (pc nextState)
    run initialState 0
    putStr "\ESC[?25h" -- Restore terminal cursor