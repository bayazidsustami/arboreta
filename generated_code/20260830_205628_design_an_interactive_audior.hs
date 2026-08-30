import Control.Concurrent (forkIO, threadDelay)
import Control.Concurrent.MVar (MVar, newMVar, readMVar, swapMVar)
import Control.Monad (forever, forM_, when)
import Data.Array.Storable (StorableArray, withStorableArray)
import Data.Complex (Complex ((:+)))
import Data.Int (Int16)
import Foreign.ForeignPtr (withForeignPtr)
import Foreign.Ptr (Ptr, castPtr, plusPtr)
import Foreign.Storable (peekElemOff, pokeElemOff)
import System.Console.ANSI (clearScreen, setCursorPosition)
import System.IO (hFlush, stdout)
import Sound.ALSA.PCM 
  ( PCM, OpenMode (..), Stream (..), Format (S16_LE), Access (Interleaved)
  , openBuf, setParams, readmulti, writemulti
  )

-- Configuration Constants
sampleRate :: Word
sampleRate = 22050

bufferSize :: Int
bufferSize = 512

screenWidth, screenHeight :: Int
screenWidth = 80
screenHeight = 40

-- 3D Vector & Point Operations for 3D Julia/Quaternion Fractal Dynamics
data Vec3 = Vec3 !Double !Double !Double

instance Num Vec3 where
  (Vec3 a b c) + (Vec3 d e f) = Vec3 (a+d) (b+e) (c+f)
  (Vec3 a b c) - (Vec3 d e f) = Vec3 (a-d) (b-e) (c-f)
  (Vec3 a b c) * (Vec3 d e f) = Vec3 (a*d) (b*e) (c*f)
  abs (Vec3 a b c) = Vec3 (abs a) (abs b) (abs c)
  signum (Vec3 a b c) = Vec3 (signum a) (signum b) (signum c)
  fromInteger n = let val = fromInteger n in Vec3 val val val

vecDot :: Vec3 -> Vec3 -> Double
vecDot (Vec3 a b c) (Vec3 d e f) = a*d + b*e + c*f

vecNorm :: Vec3 -> Double
vecNorm v = sqrt (vecDot v v)

-- Simple Fast Fourier Transform (FFT) for Audio Analysis
fft :: [Complex Double] -> [Complex Double]
fft [] = []
fft [x] = [x]
fft xs = zipWith (+) evens combined ++ zipWith (-) evens combined
  where
    n = length xs
    evens = fft [xs !! i | i <- [0, 2 .. n - 1]]
    odds  = fft [xs !! i | i <- [1, 3 .. n - 1]]
    twiddle k = exp (0 :+ (-2 * pi * fromIntegral k / fromIntegral n))
    combined = zipWith (*) [twiddle k | k <- [0 .. n `div` 2 - 1]] odds

-- Raymarching Fractal Distance Estimator deformed by Audio Frequency
fractalDE :: Vec3 -> Double -> Double -> (Double, Vec3)
fractalDE pos time audioEnergy = go pos 1.0 0
  where
    c = Vec3 (sin (time * 0.2)) (cos (time * 0.3)) (audioEnergy * 0.5)
    maxIter = 6
    go z dr iter
      | iter >= maxIter || vecNorm z > 4.0 = (0.5 * log (vecNorm z) * vecNorm z / dr, z)
      | otherwise =
          let -- Fold space (Mandelbox/Julia hybrid transform)
              z1 = Vec3 (abs (x z)) (abs (y z)) (abs (z' z))
              r2 = vecDot z1 z1
              scale = 2.0 + 0.3 * sin (audioEnergy * pi)
              (z2, dr1)
                | r2 < 0.5   = (z1 * Vec3 2.0 2.0 2.0, dr * 2.0)
                | r2 < 1.0   = (z1 * Vec3 (1.0/r2) (1.0/r2) (1.0/r2), dr / r2)
                | otherwise  = (z1, dr)
              z3 = Vec3 (x z2 * scale) (y z2 * scale) (z' z2 * scale) + c
          in go z3 (dr1 * scale + 1.0) (iter + 1)
    x (Vec3 a _ _) = a
    y (Vec3 _ b _) = b
    z' (Vec3 _ _ c) = c

-- Procedural Synthesizer: Maps fractal node coordinates to audio samples
synthSample :: Vec3 -> Double -> Int16
synthSample (Vec3 x y z) phase =
  let freq1 = 110.0 + abs x * 220.0
      freq2 = 220.0 + abs y * 440.0
      freq3 = 55.0  + abs z * 110.0
      sig1 = sin (phase * freq1 * 2 * pi / fromIntegral sampleRate)
      sig2 = sin (phase * freq2 * 2 * pi / fromIntegral sampleRate)
      sig3 = case floor (phase * 0.01) `mod` 3 of
               0 -> sig1
               1 -> sig2
               _ -> (sig1 + sig2) * 0.5
      val = (sig3 + 0.5 * sin (phase * freq3 * 2 * pi / fromIntegral sampleRate)) / 1.5
  in floor (val * 16000.0)

-- Rendering 3D Scene into ASCII Buffer
renderFractal :: Double -> Double -> (String, Vec3)
renderFractal time audioEnergy = (unlines rows, hitNode)
  where
    chars = " .:-=+*#%@"
    numChars = length chars
    camPos = Vec3 (2.5 * sin (time * 0.1)) (1.5 * cos (time * 0.15)) (-2.5 * cos (time * 0.1))
    target = Vec3 0 0 0
    forward = let d = target - camPos in Vec3 (x d / vecNorm d) (y d / vecNorm d) (z' d / vecNorm d)
    right   = Vec3 (z' forward) 0 (- x forward)
    up      = Vec3 (y right * z' forward) (z' right * x forward - x right * z' forward) (- y right * x forward)
    
    x (Vec3 a _ _) = a
    y (Vec3 _ b _) = b
    z' (Vec3 _ _ c) = c

    -- Raymarch pixel
    march xPix yPix =
      let uvX = (fromIntegral xPix / fromIntegral screenWidth - 0.5) * 2.0
          uvY = (fromIntegral yPix / fromIntegral screenHeight - 0.5) * (fromIntegral screenHeight / fromIntegral screenWidth) * 2.0
          rayDir = forward + right * Vec3 uvX uvX uvX + up * Vec3 uvY uvY uvY
          normDir = Vec3 (x rayDir / vecNorm rayDir) (y rayDir / vecNorm rayDir) (z' rayDir / vecNorm rayDir)
          
          loop t steps
            | steps > 30 || t > 10.0 = (chars !! 0, camPos)
            | otherwise =
                let p = camPos + normDir * Vec3 t t t
                    (dist, node) = fractalDE p time audioEnergy
                in if dist < 0.01
                   then let idx = min (numChars - 1) (max 0 (floor (fromIntegral steps / 30.0 * fromIntegral numChars)))
                        in (chars !! idx, node)
                   else loop (t + dist) (steps + 1)
      in loop 0.0 0

    grid = [ [ march px py | px <- [0 .. screenWidth - 1] ] | py <- [0 .. screenHeight - 1] ]
    rows = map (map fst) grid
    hitNode = snd (grid !! (screenHeight `div` 2) !! (screenWidth `div` 2))

-- Main Audio Loop & Display Execution
main :: IO ()
main = do
  audioState <- newMVar (0.0 :: Double, Vec3 0 0 0)
  
  -- Audio processing thread (Synthesizer & Audio Analysis)
  _ <- forkIO $ do
    -- Open ALSA playback stream for direct synthesis output
    pcmOut <- openBuf "default" Output Stream [setParams S16_LE Interleaved 1 sampleRate True 100000]
    case pcmOut of
      Left _ -> return () -- Fallback if hardware unavailable
      Right pcm -> forever $ do
        (energy, node) <- readMVar audioState
        let samples = [ synthSample node (fromIntegral i) | i <- [0 .. bufferSize - 1] ]
        -- Synthesis output back to speaker
        _ <- writemulti pcm (StorableArray samples :: StorableArray Int Int16)
        threadDelay 1000

  clearScreen
  let mainLoop time = do
        -- Simulate/read audio frequencies to deform fractal
        let synthAudioEnergy = abs (sin (time * 2.0)) * 0.8
        
        -- Render current 3D state
        let (asciiFrame, activeNode) = renderFractal time synthAudioEnergy
        
        -- Update shared audio state with newly generated fractal node coordinates
        _ <- swapMVar audioState (synthAudioEnergy, activeNode)

        -- Output frame
        setCursorPosition 0 0
        putStr asciiFrame
        putStrLn $ "Fractal Node Audio Coords: " ++ showNode activeNode ++ " | Freq Mod: " ++ show synthAudioEnergy
        hFlush stdout

        threadDelay 30000
        mainLoop (time + 0.03)

  mainLoop 0.0

showNode :: Vec3 -> String
showNode (Vec3 a b c) = "(" ++ showFix a ++ "," ++ showFix b ++ "," ++ showFix c ++ ")"
  where showFix n = take 5 (show n)