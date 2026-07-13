import System.IO
import System.Environment (getArgs)
import System.Console.ANSI
import Control.Concurrent (threadDelay)
import Data.List (foldl')
import Data.Maybe (fromMaybe)
import qualified Data.Vector as V
import qualified Codec.Midi as Midi

-- Parameters
width, height :: Int
width  = 80   -- terminal columns
height = 24   -- terminal rows

frameDelay :: Int
frameDelay = 50000   -- 20 FPS

-- Cellular automaton state: a grid of Bool
type Grid = V.Vector (V.Vector Bool)

-- Initialise empty grid
emptyGrid :: Grid
emptyGrid = V.replicate height (V.replicate width False)

-- Convert a MIDI note event to a column index (pitch class) and intensity
noteToPos :: Midi.Message -> Maybe (Int,Int)
noteToPos (Midi.NoteOn _ pitch vel) = Just (fromIntegral pitch `mod` width, fromIntegral vel)
noteToPos (Midi.NoteOff _ pitch _) = Just (fromIntegral pitch `mod` width, 0)
noteToPos _ = Nothing

-- Build a time‑ordered list of note‑on/off events per tick
type TickEvents = [(Int,[(Int,Int)])]   -- (tick, [(col,vel)])

collectEvents :: Midi.Midi -> TickEvents
collectEvents midi =
    let tracks = Midi.tracks midi
        flat   = concat $ zipWith (\t evs -> map (\e -> (t+Midi.tick e, Midi.message e)) evs) (repeat 0) tracks
        addEvt m (tick,msg) = case noteToPos msg of
            Just (c,v) -> V.modify (\v' -> V.modify v' (\i -> V.modify (v' V.! i) (\j -> V.modify (v' V.! i) (\_ -> True))) c) m
            Nothing    -> m
        grouped = foldl' (\acc (t,msg) -> case noteToPos msg of
                    Just (c,v) -> let (pre,rest) = span ((<t).fst) acc
                                      rest' = case rest of
                                                [] -> [(t,[(c,v)])]
                                                ((_,es):rs) -> (t,(c,v):es):rs
                                  in pre ++ rest'
                    Nothing -> acc) [] flat
    in grouped

-- Generate next CA row using a rule number (0‑255)
nextRow :: Int -> V.Vector Bool -> V.Vector Bool
nextRow rule prev = V.generate width $ \i ->
    let left  = prev V.! ((i-1) `mod` width)
        self  = prev V.! i
        right = prev V.! ((i+1) `mod` width)
        idx   = (if left then 4 else 0) + (if self then 2 else 0) + (if right then 1 else 0)
    in testBit rule idx

-- Update grid with new row at the bottom, shift up
stepGrid :: Int -> Grid -> Grid
stepGrid rule g =
    let top   = V.head g
        newR  = nextRow rule top
    in V.tail g V.++ V.singleton newR

-- Render grid to terminal
render :: Grid -> IO ()
render g = do
    clearScreen
    setCursorPosition 0 0
    V.mapM_ (putStrLn . V.toList . V.map (\b -> if b then '#' else ' ')) g
    hFlush stdout

-- Main loop: advance CA, reacting to MIDI ticks
main :: IO ()
main = do
    args <- getArgs
    file <- case args of
        (f:_) -> return f
        []    -> error "Usage: midiCA <file.mid>"
    midi <- Midi.importFile file >>= \case
        Left err -> error err
        Right m -> return m
    let events = collectEvents midi
        totalTicks = if null events then 0 else fst (last events)
    -- initial state
    let loop _ _ [] = return ()
        loop tick rule g evs@((et,_):rest)
            | tick >= et = do
                let rule' = (rule + 1) `mod` 256  -- simple rule change on any event
                loop tick rule' g rest
            | otherwise = do
                render g
                threadDelay frameDelay
                let g' = stepGrid rule g
                loop (tick+1) rule g' evs
    loop 0 30 emptyGrid events