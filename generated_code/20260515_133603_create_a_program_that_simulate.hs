import System.Random (randomRIO)
import Data.List (sortBy)
import Data.Function (on)
import Text.Printf
import Data.Maybe (catMaybes)

-- We represent file fragments as collections of integers (simulating bits)
data Fragment = 
    Fragment { 
        fragmentId :: Int,           -- Unique identifier for the fragment
        content :: [Int],            -- The actual data bits
        age :: Float,                -- Time since deletion (higher = older)
        entropy :: Float,           -- 0 to 1, how scattered the fragment is
        originalSize :: Int,         -- Original file size
        reconstructProgress :: Float -- 0 to 1, reconstruction progress
    }

-- Memory management processes that hunt fragments
data MemoryHunter = 
    MemoryHunter {
        hunterType :: String,       -- Type of process (GC, defrag, etc.)
        huntingSpeed :: Float,      -- How quickly they hunt
        efficiency :: Float,         -- Success rate at hunting
        targetId :: Maybe Int        -- Current target, if any
    }

-- Creates initial fragments with random properties
initializeFragments :: Int -> Int -> IO [Fragment]
initializeFragments numFragments maxSize = do
    fragmentIds <- mapM (const $ randomRIO (1, 1000000)) [1..numFragments]
    sizes <- mapM (const $ randomRIO (100, maxSize)) [1..numFragments]
    ages <- mapM (const $ randomRIO (0.0, 10.0)) [1..numFragments]
    entropies <- mapM (const $ randomRIO (0.1, 1.0)) [1..numFragments]
    contents <- mapM (\size -> replicateM size (randomRIO (0, 255))) sizes
    
    return $ zipWith5 Fragment fragmentIds contents ages entropies sizes (repeat 0.0)

-- Creates memory management processes
initializeHunters :: Int -> IO [MemoryHunter]
initializeHunters numHunters = do
    let types = ["Garbage Collector", "Defragmenter", "Cache Cleaner", "Wiper"]
    replicateM numHunters $ do
        typeIndex <- randomRIO (0, length types - 1)
        speed <- randomRIO (0.1, 1.0)
        eff <- randomRIO (0.3, 0.9)
        return $ MemoryHunter (types !! typeIndex) speed eff Nothing

-- Attempt to reconstruct a fragment based on its properties
reconstructFragment :: Fragment -> IO Fragment
reconstructFragment fragment = do
    -- Reconstruction becomes harder with higher entropy and age
    let reconstructionFactor = (1.0 - entropy fragment) / (1.0 + age fragment)
    -- More data makes reconstruction easier
    let dataFactor = fromIntegral (length (content fragment)) / fromIntegral (originalSize fragment)
    -- Base increase in reconstruction progress
    let baseIncrease = 0.05 * reconstructionFactor * dataFactor
    
    -- Random element to make simulation more interesting
    randomIncrease <- randomRIO (0.0, 0.03)
    let newProgress = min 1.0 (reconstructProgress fragment + baseIncrease + randomIncrease)
    
    return $ fragment { reconstructProgress = newProgress }

-- Simulate a hunting attempt by memory management processes
huntFragment :: Fragment -> [MemoryHunter] -> IO (Maybe Fragment)
huntFragment fragment hunters = do
    -- Hunters are more likely to target fragments with higher reconstruction progress
    let huntingProbability = (reconstructProgress fragment) * 0.5
    roll1 <- randomRIO (0.0, 1.0)
    
    if huntingProbability < roll1
    then return (Just fragment) -- Hunter missed or didn't target
    else do
        -- Success depends on hunter efficiency and fragment entropy
        let successProbability = averageEfficiency hunters * (1.0 - entropy fragment)
        roll2 <- randomRIO (0.0, 1.0)
        if successProbability < roll2
        then do
            -- Fragment survives but its progress is reduced
            let newProgress = max 0.0 (reconstructProgress fragment - 0.2)
            return $ Just $ fragment { reconstructProgress = newProgress }
        else
            -- Fragment is completely destroyed
            return Nothing -- Indicates destruction
  where
    averageEfficiency [] = 0.0
    averageEfficiency hs = sum (map efficiency hs) / fromIntegral (length hs)

-- Age all fragments and increment their age
ageFragments :: [Fragment] -> [Fragment]
ageFragments fragments = map (\f -> f { age = age f + 0.1 }) fragments

-- Perform one step of the simulation
simulateStep :: [Fragment] -> [MemoryHunter] -> IO ([Fragment], [MemoryHunter])
simulateStep fragments hunters = do
    -- Age all fragments
    let agedFragments = ageFragments fragments
    
    -- Attempt reconstruction for each fragment
    reconstructed <- mapM reconstructFragment agedFragments
    
    -- Hunting phase - filter out destroyed fragments
    huntedResults <- mapM (\f -> huntFragment f hunters) reconstructed
    let newFragments = catMaybes huntedResults
    
    -- Age hunters (they change over time)
    let agedHunters = map (\h -> h { efficiency = efficiency h * 0.999 }) hunters
    
    return (newFragments, agedHunters)

-- Run the simulation for a specified number of steps
runSimulation :: Int -> [Fragment] -> [MemoryHunter] -> IO ()
runSimulation 0 fragments _ = 
    putStrLn $ "Final state: " ++ show (length fragments) ++ " fragments remaining"
runSimulation steps fragments hunters = do
    putStrLn $ "\n--- Step " ++ show (100 - steps + 1) ++ " ---"
    putStrLn $ "Fragments: " ++ show (length fragments)
    printf "Average reconstruction progress: %.2f%%\n" (avgReconstruction fragments)
    
    -- Show some fragment details
    let sorted = sortBy (compare `on` reconstructProgress) (reverse fragments)
    let topN = take 5 sorted
    mapM_ (\f -> printf "  Fragment %d: %.1f%% reconstructed, entropy: %.2f, age: %.1f\n" 
             (fragmentId f) (reconstructProgress f * 100) (entropy f) (age f)) topN
    
    (newFragments, newHunters) <- simulateStep fragments hunters
    runSimulation (steps - 1) newFragments newHunters
  where
    avgReconstruction [] = 0.0
    avgReconstruction fs = sum (map reconstructProgress fs) / fromIntegral (length fs)

-- Show detailed information about fragments
showFragments :: [Fragment] -> String
showFragments fragments = 
    unlines $ map showFragment fragments
  where
    showFragment f = printf "ID: %d, Progress: %.1f%%, Entropy: %.2f, Age: %.1f, Data: %d/%d bits" 
                   (fragmentId f) (reconstructProgress f * 100) (entropy f) (age f) 
                   (length (content f)) (originalSize f)

main :: IO ()
main = do
    putStrLn "Welcome to the Digital Afterlife simulation"
    putStrLn "Deleted file fragments drift in memory, attempting to reconstruct"
    putStrLn "while being hunted by memory management processes.\n"
    
    -- Initialize the simulation
    initialFragments <- initializeFragments 20 1000
    initialHunters <- initializeHunters 5
    
    putStrLn $ "Started with " ++ show (length initialFragments) ++ " fragments"
    putStrLn $ "and " ++ show (length initialHunters) ++ " memory hunters\n"
    
    -- Run the simulation
    runSimulation 100 initialFragments initialHunters