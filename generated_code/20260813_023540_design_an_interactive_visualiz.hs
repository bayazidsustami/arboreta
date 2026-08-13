-- Real-Time Dynamic 3D Heap Memory Mountain & Garbage Collection Visualizer
-- Runs an isometric 3D engine monitoring runtime heap allocation and GC activity.
-- Active allocations raise landscape peaks; Garbage Collection triggers simulated earthquakes.
-- Compile with: ghc -O2 -rtsopts -with-rtsopts="-T" Visualizer.hs

{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import Graphics.Gloss
import Graphics.Gloss.Interface.IO.Game
import GHC.Stats
import System.Mem (performGC)
import Control.Exception (catch, SomeException)
import Data.Word (Word64)

-- Grid resolution for 3D mountain terrain
gridSize :: Int
gridSize = 24

gridSpacing :: Float
gridSpacing = 18.0

-- World state tracking mountain geometry, allocated payload, and RTS metrics
data World = World
  { terrainHeights :: [[Float]]
  , heapTrash      :: [[Int]]     -- Retained heap payload driving active memory allocations
  , lastAlloc      :: Word64
  , lastGCs        :: Word64
  , quake          :: Float       -- Earthquake shockwave intensity [0.0 - 1.0]
  , animTime       :: Float
  , rotAngle       :: Float
  }

initialWorld :: World
initialWorld = World
  { terrainHeights = replicate gridSize (replicate gridSize 0.0)
  , heapTrash      = []
  , lastAlloc      = 0
  , lastGCs        = 0
  , quake          = 0.0
  , animTime       = 0.0
  , rotAngle       = 0.0
  }

-- Fetch real-time RTS statistics safely (with fallback if RTS options are disabled)
fetchStats :: IO (Maybe RTSStats)
fetchStats = (Just <$> getRTSStats) `catch` \(_ :: SomeException) -> return Nothing

-- Project 3D coordinate (x, y, z) into 2D isometric screen space with dynamic camera rotation
project3D :: Float -> Float -> Float -> Float -> (Float, Float)
project3D angle x y z =
  let rad  = angle
      rx   = x * cos rad - y * sin rad
      ry   = x * sin rad + y * cos rad
      isoX = (rx - ry) * cos (pi / 6)
      isoY = (rx + ry) * sin (pi / 6) + z
  in (isoX, isoY)

-- Render terrain grid mesh as dynamic 3D mountain landscape with height color gradients & seismic rumble
drawWorld :: World -> IO Picture
drawWorld w = do
  let heights = terrainHeights w
      q       = quake w
      t       = animTime w
      ang     = rotAngle w
      halfG   = fromIntegral gridSize / 2.0

  -- Calculate wireframe vertices with earthquake displacement logic
  let getPoint i j =
        let h     = (heights !! i) !! j
            shake = if q > 0.02 then sin (fromIntegral (i * 7 + j * 13) + t * 40.0) * q * 14.0 else 0.0
            x     = (fromIntegral i - halfG) * gridSpacing
            y     = (fromIntegral j - halfG) * gridSpacing
            z     = h + shake
        in project3D ang x y z

  -- Build wireframe mesh connection lines across the mountain surface
  let lineSegments = do
        i <- [0 .. gridSize - 1]
        j <- [0 .. gridSize - 1]
        let p0    = getPoint i j
        let right = [Line [p0, getPoint (i + 1) j] | i + 1 < gridSize]
        let down  = [Line [p0, getPoint i (j + 1)] | j + 1 < gridSize]
        right ++ down

  -- Seismic HUD overlay & Dynamic terrain color shift (Emerald/Cyan to Crimson during GC Earthquakes)
  let baseColor
        | q > 0.2   = mixColors q (1.0 - q) red (makeColor 0.1 0.8 0.5 1.0)
        | otherwise = makeColor 0.2 0.75 0.95 0.85

  let hudText = Pictures
        [ Translate (-380) 270 $ Scale 0.15 0.15 $ Color white $ Text "3D HEAP MEMORY MOUNTAIN VISUALIZER"
        , Translate (-380) 245 $ Scale 0.12 0.12 $ Color (greyN 0.7) $ Text "Allocations raise mountain peaks | Garbage Collection causes earthquakes"
        , Translate (-380) 220 $ Scale 0.12 0.12 $ Color (if q > 0.2 then red else yellow) $
            Text $ "Seismic Activity (GC Quake): " ++ show (round (q * 100) :: Int) ++ "%"
        , Translate (-380) (-270) $ Scale 0.1 0.1 $ Color (greyN 0.5) $
            Text "Controls: [SPACE] Trigger Garbage Collection | [LEFT/RIGHT] Rotate Camera"
        ]

  return $ Pictures
    [ Translate 0 (-40) $ Color baseColor $ Pictures lineSegments
    , hudText
    ]

-- Handle user interactions (manual GC triggers and manual view camera rotation)
handleEvent :: Event -> World -> IO World
handleEvent (EventKey (Char ' ') Down _ _) w = do
  performGC
  return w { quake = 1.0, heapTrash = [] }
handleEvent (EventKey (SpecialKey KeyLeft) Down _ _) w =
  return w { rotAngle = rotAngle w - 0.15 }
handleEvent (EventKey (SpecialKey KeyRight) Down _ _) w =
  return w { rotAngle = rotAngle w + 0.15 }
handleEvent _ w = return w

-- Frame update loop: churns heap, queries RTS memory stats, and updates terrain mechanics
stepWorld :: Float -> World -> IO World
stepWorld dt w = do
  mstats <- fetchStats
  
  -- Active Heap Churn: Continuously allocate nested data structures to simulate memory growth
  let newPayload   = replicate 400 [1 .. 800]
  let updatedTrash = newPayload : heapTrash w

  (allocs, gcsCount) <- case mstats of
    Just s  -> return (allocated_bytes s, gcs s)
    Nothing -> return (lastAlloc w + 45000, lastGCs w)

  let allocDiff   = if lastAlloc w == 0 then 0 else allocs - lastAlloc w
  let gcOccurred  = gcsCount > lastGCs w && lastGCs w /= 0

  -- Earthquake activation & decay physics
  let newQuake = if gcOccurred then 1.0 else max 0.0 (quake w - dt * 1.6)

  -- Calculate mountain peak deformation based on dynamic allocation rate
  let allocFactor = fromIntegral allocDiff / 8000.0
  let t           = animTime w + dt
  
  let newHeights =
        [ [ let distFromCenter = sqrt (fromIntegral ((i - 12) ^ (2 :: Int) + (j - 12) ^ (2 :: Int)))
                radialWeight   = max 0.0 (1.0 - distFromCenter / 12.0)
                pulse          = sin (t * 2.5 + distFromCenter * 0.4) * 12.0
                currentH       = (terrainHeights w !! i) !! j
                targetH        = radialWeight * (allocFactor * 18.0 + pulse)
            in if gcOccurred
               then currentH * 0.25 -- GC Earthquakes collapse mountain peaks back to lowlands
               else currentH * 0.90 + targetH * 0.10
          | j <- [0 .. gridSize - 1] ]
        | i <- [0 .. gridSize - 1] ]

  return w
    { terrainHeights = newHeights
    , heapTrash      = if length updatedTrash > 50 then drop 20 updatedTrash else updatedTrash
    , lastAlloc      = allocs
    , lastGCs        = gcsCount
    , quake          = newQuake
    , animTime       = t
    , rotAngle       = rotAngle w + dt * 0.08 -- Gentle auto-rotation
    }

main :: IO ()
main = playIO
  (InWindow "Haskell Real-Time Heap Mountain Visualizer" (900, 700) (100, 100))
  black
  30
  initialWorld
  drawWorld
  handleEvent
  stepWorld