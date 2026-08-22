import Data.Bits (xor, (.&.))
import Data.Char (chr)
import System.IO (hSetBuffering, stdout, BufferMode(NoBuffering))
import Control.Concurrent (threadDelay)

-- Represents target CPU registers
data Reg = R0 | R1 | R2 | R3 deriving (Show, Enum, Bounded)

-- Intermediate Assembly Instructions compiled from audio frequencies
data Instr 
  = Push Reg 
  | Pop Reg 
  | Add Reg Reg 
  | XOR Reg Reg 
  | Nop

-- Represents a Virtual Machine state (Register Bank, Stack Memory)
data VM = VM 
  { regs  :: [Int]
  , stack :: [Int]
  }

initVM :: VM
initVM = VM [0, 0, 0, 0] []

-- Compiler: Maps raw audio frequencies (Hz) to targeted assembly instructions
compilePitch :: Double -> Instr
compilePitch freq
  | freq < 100.0  = Nop
  | freq < 300.0  = Push R0
  | freq < 600.0  = Push R1
  | freq < 900.0  = Add R0 R1
  | freq < 1200.0 = XOR R0 R1
  | otherwise     = Pop R0

-- VM Executer: Mutates internal memory state based on compiled instruction
stepVM :: Instr -> VM -> VM
stepVM (Push r) (VM rs st)     = VM rs ((rs !! fromEnum r + 42) : st)
stepVM (Pop _)  (VM rs (_:st)) = VM rs st
stepVM (Pop _)  vm             = vm
stepVM (Add r1 r2) (VM rs st)  = 
  let val = (rs !! fromEnum r1 + rs !! fromEnum r2 + 15) `mod` 256
  in VM (take (fromEnum r1) rs ++ [val] ++ drop (fromEnum r1 + 1) rs) st
stepVM (XOR r1 r2) (VM rs st)  = 
  let val = (rs !! fromEnum r1) `xor` (rs !! fromEnum r2) `xor` 0xFF
  in VM (take (fromEnum r1) rs ++ [val] ++ drop (fromEnum r1 + 1) rs) st
stepVM Nop vm                   = vm

-- Visualizer: Renders stack memory state as ANSI 24-bit color heatmap cells
renderHeatmap :: [Int] -> String
renderHeatmap st = "\ESC[H" ++ concatMap toRGB (take 64 (st ++ repeat 0))
  where
    toRGB val = 
      let r = (val * 7) `mod` 256
          g = (val * 3) `mod` 256
          b = (255 - val) `mod` 256
      in "\ESC[48;2;" ++ show r ++ ";" ++ show g ++ ";" ++ show b ++ "m  \ESC[0m"

-- Simulated Ambient Audio Stream generating shifting frequency waves
ambientAudioStream :: [Double]
ambientAudioStream = [ 440.0 + 400.0 * sin (t / 5.0) + 200.0 * cos (t / 2.0) | t <- [0.0, 0.1 ..] ]

-- Pipeline execution: Streams audio -> Compiles -> Executes -> Heatmap Rendering
main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStr "\ESC[2J\ESC[?25l" -- Clear screen and hide cursor
  loop initVM ambientAudioStream
  where
    loop vm (freq:freqs) = do
      let instr = compilePitch freq
      let nextVM = stepVM instr vm
      putStr (renderHeatmap (stack nextVM))
      threadDelay 30000 -- Real-time frame rendering delay (~33fps)
      loop nextVM freqs
    loop _ [] = return ()