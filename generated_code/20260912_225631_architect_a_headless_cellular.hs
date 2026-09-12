import Control.Concurrent (threadDelay)
import Control.Monad (forM_, when)
import Data.Array.IO (IOUArray, newArray, readArray, writeArray)
import Data.Bits (xor, (.&.), (.|.))
import Data.Char (chr, ord)
import Data.IORef (IORef, newIORef, readIORef, modifyIORef')
import System.Random (randomRIO)

-- Sector state: Active File (Char + TTL), Fossil (structural energy), or Empty
data Sector = File Char Int | Fossil Int | Empty

-- Disk size and decay rates
diskSize :: Int
diskSize = 64

maxTTL :: Int
maxTTL = 15

-- Map Sector to a visual character representation
render :: Sector -> Char
render (File c _)  = c
render (Fossil e)  | e > 10    = '█'
                   | e > 5     = '▓'
                   | e > 2     = '▒'
                   | otherwise = '░'
render Empty       = '.'

-- Quantum/Cellular rule for disk sector evolution
evolveSector :: Sector -> Sector -> Sector -> Sector
evolveSector left center right = case center of
  File c ttl ->
    if ttl > 0 
      then File c (ttl - 1) 
      else Fossil (maxTTL / 2) -- Decays into a fossil upon death
  
  Fossil e ->
    if e > 0 
      then Fossil (e - 1) 
      else Empty
  
  Empty ->
    -- Empty space self-organizes fossils based on neighboring activity/energy
    case (left, right) of
      (File _ _, _)          -> Fossil 4
      (_, File _ _)          -> Fossil 4
      (Fossil e1, Fossil e2) -> if e1 + e2 > 8 then Fossil 6 else Empty
      _                      -> Empty

-- Step the entire disk forward using double-buffering
stepDisk :: IOUArray Int Sector -> IOUArray Int Sector -> IO ()
stepDisk current next = do
  forM_ [0 .. diskSize - 1] $ \i -> do
    let lIdx = (i - 1 + diskSize) `mod` diskSize
    let rIdx = (i + 1) `mod` diskSize
    left   <- readArray current lIdx
    center <- readArray current i
    right  <- readArray current rIdx
    writeArray next i (evolveSector left center right)
    
  forM_ [0 .. diskSize - 1] $ \i -> do
    val <- readArray next i
    writeArray current i val

-- Write a file payload starting at a target index
writeFileDisk :: IOUArray Int Sector -> Int -> String -> IO ()
writeFileDisk disk startIdx str = do
  forM_ (zip [0..] str) $ \(offset, c) -> do
    let idx = (startIdx + offset) `mod` diskSize
    writeArray disk idx (File c maxTTL)

-- Read/Refresh a file: reading restores full TTL to intact file sectors
readFileDisk :: IOUArray Int Sector -> Int -> Int -> IO String
readFileDisk disk startIdx len = do
  forM [0 .. len - 1] $ \offset -> do
    let idx = (startIdx + offset) `mod` diskSize
    sec <- readArray disk idx
    case sec of
      File c _ -> do
        writeArray disk idx (File c maxTTL) -- Refresh TTL on access
        return c
      Fossil _ -> return '?' -- Corrupted / fossilized byte
      Empty    -> return ' '

-- Print the disk state to terminal
printDisk :: IOUArray Int Sector -> Int -> IO ()
printDisk disk tick = do
  chars <- forM [0 .. diskSize - 1] (fmap render . readArray disk)
  putStrLn $ "[" ++ show tick ++ "]  " ++ chars

main :: IO ()
main = do
  disk <- newArray (0, diskSize - 1) Empty
  temp <- newArray (0, diskSize - 1) Empty
  
  putStrLn "=== Organic Cellular FS Simulation ==="
  putStrLn "Legend: [A-Z] Active Files | [█▓▒░] Self-Organizing Fossils | [.] Empty Sector\n"
  
  -- Seed initial files on disk
  writeFileDisk disk 5  "SYSTEM_CORE"
  writeFileDisk disk 35 "EPHEMERAL_LOG"
  
  forM_ [1 .. 45] $ \tick -> do
    printDisk disk tick
    
    -- Keep "SYSTEM_CORE" alive by reading (refreshing) it every 4 ticks
    when (tick `mod` 4 == 0) $ do
      _ <- readFileDisk disk 5 11
      return ()
      
    -- Write a short-lived transient file at tick 20
    when (tick == 20) $ do
      writeFileDisk disk 22 "TEMP"
      
    stepDisk disk temp
    threadDelay 150000 -- 150ms delay per tick