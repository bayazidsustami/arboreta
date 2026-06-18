import Codec.Midi
import Graphics.Gloss
import Graphics.Gloss.Data.Picture
import Graphics.Gloss.Interface.IO.Animate
import Data.Array
import Data.List
import System.Directory
import System.FilePath
import Control.Monad
import Data.Word

type Cell = Bool
type Grid = Array (Int,Int) Cell

-- Parameters
windowSize :: Int
windowSize = 600

gridSize :: Int
gridSize = 100

cellSize :: Float
cellSize = fromIntegral windowSize / fromIntegral gridSize

-- Map a MIDI note to a rule: radius = (pitch mod 5)+1, color hue = timbre (instrument)
noteRule :: Message -> (Int, Float)
noteRule (NoteOn chan pitch _) = (1 + fromIntegral (pitch `mod` 5), fromIntegral chan / 16)
noteRule _ = (1,0)

-- Simple cellular automaton: sum of neighbours within radius decides next state
stepGrid :: Int -> Grid -> Grid
stepGrid rad g = array bounds [ ((i,j), next (i,j)) | (i,j) <- range bounds ]
  where
    bounds@((0,0),(n,m)) = bounds g
    next (i,j) = odd $ sum [ if g!(x,y) then 1 else 0
                           | x <- [i-rad..i+rad], y <- [j-rad..j+rad]
                           , inRange bounds (x,y) ]

-- Convert grid to Gloss picture with color based on rule
gridPicture :: Grid -> Float -> Picture
gridPicture g hue = Pictures [ translate x y $ Color (makeColorI r g b 255) $ rectangleSolid cellSize cellSize
                             | ((i,j),True) <- assocs g
                             , let x = fromIntegral i * cellSize - fromIntegral windowSize/2 + cellSize/2
                             , let y = fromIntegral j * cellSize - fromIntegral windowSize/2 + cellSize/2
                             , let (r,g,b) = hsvToRGB hue 0.8 0.9
                             ]

-- HSV to RGB conversion (0-1 range)
hsvToRGB :: Float -> Float -> Float -> (Int,Int,Int)
hsvToRGB h s v = (floor $ r*255, floor $ g*255, floor $ b*255)
  where
    c = v * s
    x = c * (1 - abs ((h*6) `mod'` 2 - 1))
    m = v - c
    (r',g',b') | h < 1/6 = (c,x,0)
               | h < 2/6 = (x,c,0)
               | h < 3/6 = (0,c,x)
               | h < 4/6 = (0,x,c)
               | h < 5/6 = (x,0,c)
               | otherwise = (c,0,x)
    r = r' + m
    g = g' + m
    b = b' + m

-- Main animation
main :: IO ()
main = do
    -- Load MIDI file (replace with your path)
    midi <- importFile "input.mid"
    let notes = [ (t, noteRule msg) | Track ts <- maybe [] (:[]) midi, (t,msg) <- ts, isNoteOn msg ]
        isNoteOn (NoteOn _ _ _) = True
        isNoteOn _ = False
        -- Sort by time
        sorted = sortOn fst notes
        -- Build rule list per time slice (simple approach)
        ruleSeq = map snd sorted

    -- Initial grid (random seed)
    let initGrid = listArray ((0,0),(gridSize-1,gridSize-1))
                    [ (i+j) `mod` 2 == 0 | i <- [0..gridSize-1], j <- [0..gridSize-1] ]

    -- Create a directory for frames
    createDirectoryIfMissing True "frames"

    -- Animate and save frames
    let render t = do
          let idx = floor (t * 30) `mod` length ruleSeq
              (rad, hue) = ruleSeq !! idx
              g' = iterate (stepGrid rad) initGrid !! idx
          -- Save frame
          let img = renderPicture $ gridPicture g' hue
          void $ saveBmpImage ("frames" </> ("frame" ++ pad (idx+1) ++ ".bmp")) img
          return $ gridPicture g' hue

        pad n = let s = show n in replicate (4 - length s) '0' ++ s

    animateIO FullScreen (Color white (rectangleSolid (fromIntegral windowSize) (fromIntegral windowSize)))
        (const $ return $ Color white $ rectangleSolid (fromIntegral windowSize) (fromIntegral windowSize))
        render

-- Helper to convert Gloss picture to BMP (using JuicyPixels)
renderPicture :: Picture -> BitmapData
renderPicture pic = bitmapDataOfPicture pic windowSize windowSize

-- Very thin wrapper (placeholder) – In practice you'd use Gloss's internal functions or JuicyPixels directly.
bitmapDataOfPicture :: Picture -> Int -> Int -> BitmapData
bitmapDataOfPicture _ _ _ = BitmapData (0,0) 0 False -- Placeholder for brevity.