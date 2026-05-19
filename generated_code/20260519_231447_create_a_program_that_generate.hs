import System.Random
import Data.List (nub)
import Control.Monad (replicateM)
import Text.Printf (printf)

-- | A Cell represents a node in the fractal ecosystem.
-- DNA is a list of frequencies (musical notes).
-- The state represents the current biological energy/density.
data Cell = Cell 
    { dna      :: [Double] 
    , energy   :: Double
    , position :: (Int, Int)
    } deriving (Show)

-- | The Ecosystem is a 2D grid of cells.
type Ecosystem = [[Cell]]

-- | Constants derived from the Golden Ratio (phi) and Fibonacci sequence.
phi :: Double
phi = (1 + sqrt 5) / 2

fib :: [Double]
fib = 0 : 1 : zipWith (+) fib (tail fib)

-- | Generates a color based on the Golden Ratio and cell energy.
-- Returns an RGB triplet.
getGoldenColor :: Double -> (Int, Int, Int)
getGoldenColor e = 
    let r = floor $ (sin (e * phi) + 1) * 127
        g = floor $ (sin (e * phi * phi) + 1) * 127
        b = floor $ (sin (e * phi * phi * phi) + 1) * 127
    in (max 0 (min 255 r), max 0 (min 255 g), max 0 (min 255 b))

-- | Calculates the "harmony" of a cell based on its neighbors' DNA.
-- If neighbors share frequencies, energy increases (mitosis).
calculateHarmony :: Cell -> [Cell] -> Double
calculateHarmony parent neighbors =
    let neighborFreqs = concatMap dna neighbors
        parentFreqs   = dna parent
        overlap = sum [1 | f <- parentFreqs, nf <- neighborFreqs, abs (f - nf) < 0.1]
    in fromIntegral overlap / fromIntegral (length parentFreqs + 1)

-- | Evolves a single cell through mitosis or decay.
evolveCell :: Cell -> [Cell] -> IO Cell
evolveCell cell neighbors = do
    let harmony = calculateHarmony cell neighbors
    let newEnergy = (energy cell * 0.9) + (harmony * 0.5)
    
    -- DNA Mutation: Evolve notes using Fibonacci intervals
    mutationIdx <- randomRIO (0, length (dna cell) - 1)
    shift <- randomRIO (-1.0, 1.0)
    let newDNA = zipWith (\i f -> if i == mutationIdx then f * (phi ** (shift/10)) else f) [0..] (dna cell)
    
    -- Mitosis: If energy is high, cell splits (represented by increased energy/complexity)
    let finalEnergy = if newEnergy > 1.5 then 0.8 else newEnergy
    return $ cell { dna = newDNA, energy = finalEnergy }

-- | Initialize a random ecosystem.
initEcosystem :: Int -> Int -> IO Ecosystem
initEcosystem rows cols = replicateM rows $ replicateM cols $ do
    -- DNA consists of frequencies derived from Fibonacci-scaled octaves
    baseFreq <- (\x -> 220 * (2 ** x)) <$> randomRIO (0, 4 :: Double)
    let d = [baseFreq * (phi ** (fromIntegral i / 5)) | i <- [0..3]]
    e <- randomRIO (0.1, 1.0)
    return $ Cell d e (0,0) -- Position handled by grid structure

-- | Get neighbors in a toroidal grid.
getNeighbors :: Int -> Int -> Ecosystem -> [Cell]
getNeighbors r c eco = 
    let rows = length eco
        cols = length (head eco)
        coords = [( (r-1) `mod` rows, c), ((r+1) `mod` rows, c), 
                  (r, (c-1) `mod` cols), (r, (c+1) `mod` cols)]
    in [eco !! ri !! ci | (ri, ci) <- coords]

-- | Step the ecosystem forward.
step :: Ecosystem -> IO Ecosystem
step eco = do
    let rows = length eco
        cols = length (head eco)
    sequence [ sequence [ evolveCell (eco !! r !! c) (getNeighbors r c eco) 
                        | c <- [0..cols-1] ] 
             | r <- [0..rows-1] ]

-- | Renders the ecosystem as an ANSI color terminal visualization.
-- This simulates the "visual symphony".
render :: Ecosystem -> IO ()
render eco = do
    putStr "\ESC[H" -- Reset cursor to top
    mapM_ (\row -> do
        mapM_ (\cell -> do
            let (r, g, b) = getGoldenColor (energy cell)
            -- Print a block of color using ANSI escape codes
            printf "\ESC[48;2;%d;%d;%dm  \ESC[0m" r g b
            ) row
        putStrLn ""
        ) eco
    -- Print the "musical score" of the first cell
    let firstCell = head (head eco)
    printf "\nMusical Pulse (DNA Frequencies): %s\n" (show $ map (printf "%.2f") (dna firstCell) :: String)
    printf "System Harmony Index: %.4f\n" (energy firstCell)

-- | Main loop.
main :: IO ()
main = do
    putStr "\ESC[2J" -- Clear screen
    eco <- initEcosystem 20 40
    let loop e 0 = putStrLn "Evolution Complete."
        loop e n = do
            render e
            nextE <- step e
            loop nextE (n - 1)
    loop eco 100