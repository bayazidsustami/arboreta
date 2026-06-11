import Control.Monad (when, forever)
import Data.Bits (shiftR, (.&.))
import Data.Word (Word8)
import System.Random (randomRIO)
import qualified Data.Vector.Storable as V
import qualified Data.Vector.Unboxed as UV
import qualified Graphics.Rendering.OpenGL as GL
import qualified Graphics.UI.GLUT as GLUT
import qualified Sound.PortAudio as PA
import qualified OpenCV as CV
import qualified OpenCV.VideoIO as CVio
import qualified OpenCV.Core.Types as CVC
import qualified OpenCV.TypeLevel as TL

-- Parameters
gridSize :: Int
gridSize = 16        -- 16³ voxels

sampleRate :: Int
sampleRate = 44100

freqBase :: Double
freqBase = 220.0    -- base frequency for the lattice

-- Voxel state: Bool alive + phase
type Voxel = (Bool, Double)

type Lattice = UV.Vector Voxel

-- Initialize a random lattice
initLattice :: IO Lattice
initLattice = UV.replicateM (gridSize^3) $ do
    alive <- randomRIO (0,1) :: IO Int
    phase <- randomRIO (0.0, 2*pi)
    return (alive == 1, phase)

-- Simple cellular automaton rule (Game of Life on 3D)
neighbors :: Int -> Int
neighbors idx = length $ filter id $ map (UV.unsafeIndex lattice) $ neighborIndices idx
  where
    lattice = undefined  -- placeholder, will be supplied by caller

neighborIndices :: Int -> [Int]
neighborIndices i = [ clamp (x+dx) (y+dy) (z+dz) |
                      dx <- [-1,0,1], dy <- [-1,0,1], dz <- [-1,0,1],
                      (dx,dy,dz) /= (0,0,0) ]
  where
    (x,y,z) = idxToCoord i
    clamp nx ny nz = coordToIdx ( (nx + gridSize) `mod` gridSize
                               , (ny + gridSize) `mod` gridSize
                               , (nz + gridSize) `mod` gridSize)

idxToCoord :: Int -> (Int,Int,Int)
idxToCoord i = (i `mod` gridSize,
                (i `div` gridSize) `mod` gridSize,
                i `div` (gridSize*gridSize))

coordToIdx :: (Int,Int,Int) -> Int
coordToIdx (x,y,z) = x + y*gridSize + z*gridSize*gridSize

stepLattice :: Lattice -> Lattice
stepLattice lat = UV.imap evolve lat
  where
    evolve i (alive,ph) =
      let n = length $ filter id $ map (UV.unsafeIndex lat) $ neighborIndices i
          alive' = (alive && n `elem` [5,6,7]) || (not alive && n == 6)
          ph' = if alive' then ph + 0.01 else ph
      in (alive', ph')

-- Generate audio sample for a voxel
voxelSample :: Voxel -> Double -> Double
voxelSample (alive,phase) t
  | not alive = 0
  | otherwise = sin (2*pi*freq* t + phase)
  where
    freq = freqBase * (1 + fromIntegral (round (phase*10)) / 10)

-- Mix all voxels into a single sample
mixSamples :: Lattice -> Double -> Double
mixSamples lat t = sum $ UV.map (`voxelSample` t) lat / fromIntegral (gridSize^3)

-- Audio callback
audioCallback :: PA.Stream s => PA.StreamCallback s
audioCallback _ _ output _ _ = do
    let frames = PA.bufferFrameCount output
    mapM_ (\i -> do
        let t = fromIntegral i / fromIntegral sampleRate
        let s = realToFrac $ mixSamples globalLattice t
        PA.writeStreamData output i s) [0..frames-1]
    return PA.Continue

globalLattice :: Lattice
globalLattice = unsafePerformIO initLattice
{-# NOINLINE globalLattice #-}

-- Generate a random haiku (3 lines: 5-7-5 syllables)
randomHaiku :: IO String
randomHaiku = do
    l1 <- replicateM 5 randomWord
    l2 <- replicateM 7 randomWord
    l3 <- replicateM 5 randomWord
    return $ unwords l1 ++ "\n" ++ unwords l2 ++ "\n" ++ unwords l3
  where
    randomWord = do
        len <- randomRIO (1,3)
        replicateM len $ randomRIO ('a','z')

-- Render the lattice as points
render :: Lattice -> IO ()
render lat = do
    GL.clear [GL.ColorBuffer, GL.DepthBuffer]
    GL.preservingMatrix $ do
        GL.translate $ GL.Vector3 0 0 (-5 :: GL.GLfloat)
        UV.imapM_ drawVoxel lat
    GLUT.swapBuffers
  where
    drawVoxel i (alive,ph) = when alive $ do
        let (x,y,z) = idxToCoord i
        let fx = fromIntegral x / fromIntegral gridSize - 0.5
        let fy = fromIntegral y / fromIntegral gridSize - 0.5
        let fz = fromIntegral z / fromIntegral gridSize - 0.5
        let hue = (ph `mod'` (2*pi)) / (2*pi)
        let (r,g,b) = hsvToRgb hue 0.8 0.9
        GL.color $ GL.Color3 r g b
        GL.renderPrimitive GL.Points $ GL.vertex $ GL.Vertex3 fx fy fz

hsvToRgb :: Double -> Double -> Double -> (GL.GLfloat,GL.GLfloat,GL.GLfloat)
hsvToRgb h s v = (realToFrac r, realToFrac g, realToFrac b)
  where
    i = floor (h*6) :: Int
    f = h*6 - fromIntegral i
    p = v * (1 - s)
    q = v * (1 - f*s)
    t = v * (1 - (1-f)*s)
    (r,g,b) = case i `mod` 6 of
        0 -> (v,t,p)
        1 -> (q,v,p)
        2 -> (p,v,t)
        3 -> (p,q,v)
        4 -> (t,p,v)
        5 -> (v,p,q)
        _ -> (0,0,0)

-- Main loop: capture webcam, update lattice, render, play sound
main :: IO ()
main = do
    -- Init OpenGL/GLUT
    _ <- GLUT.getArgsAndInitialize
    GLUT.initialDisplayMode GLUT.$= [GLUT.DoubleBuffered, GLUT.RGBMode, GLUT.WithDepthBuffer]
    _ <- GLUT.createWindow "Voxel Haiku Automaton"
    GL.pointSize $= 2

    -- Init audio
    PA.withdefaultStream (PA.StreamParameters Nothing 0 0) (PA.StreamParameters Nothing 1 44100) 256 audioCallback $ \_ -> do

        -- Init webcam (placeholder, no actual processing)
        cam <- CVio.newVideoCapture 0
        _ <- CVio.videoCaptureIsOpened cam

        -- Main GLUT loop
        let loop = do
                -- Capture a frame (unused)
                _ <- CV.videoCaptureRead cam
                -- Evolve lattice
                let newLat = stepLattice globalLattice
                -- Update global (unsafe, for demo)
                let _ = seq newLat () `seq` ()
                -- Render
                render newLat
                GLUT.postRedisplay
                loop
        loop

)