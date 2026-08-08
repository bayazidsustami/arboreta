import Data.Array
import Data.Bits
import Data.ByteString qualified as BS
import Data.Char (chr, ord)
import Data.Complex
import Data.Word
import System.Environment (getArgs)
import System.IO

-- | World Bounds & Render Size
width, height :: Int
width = 80
height = 24

-- | A point in the Complex plane representing world coordinates
type Point = Complex Double

-- | Coastal Erosion & Fractal Parameters
data State = State
  { center :: Point,
    zoom :: Double,
    erosionSteps :: Int,
    erosionFactor :: Double,
    byteOffset :: Int,
    payload :: BS.ByteString
  }

-- | Default initial state
initialState :: BS.ByteString -> State
initialState bs =
  State
    { center = (-0.5) :+ 0.0,
      zoom = 1.0,
      erosionSteps = 100,
      erosionFactor = 0.05,
      byteOffset = 0,
      payload = bs
    }

-- | Compute Mandelbrot / Julia Hybrid Coastline height at point c
-- Uses payload bytes to dynamically modulate coastal shape (Binary Map Driver)
coastlineHeight :: State -> Point -> (Int, Double)
coastlineHeight st c = go 0 (0 :+ 0)
  where
    maxItr = erosionSteps st
    bytes = payload st
    bLen = BS.length bytes
    
    -- Pick erosion byte corresponding to local coordinate dynamics
    getByte idx =
      if bLen == 0
        then 0
        else fromIntegral (BS.index bytes ((idx + byteOffset st) `mod` bLen))

    go itr z
      | itr >= maxItr = (maxItr, magnitude z)
      | magnitude z > 4.0 = (itr, magnitude z)
      | otherwise =
          let b = getByte itr
              -- Coastal erosion perturbation based on file payload
              perturbation = (fromIntegral (b .&. 0x0F) / 16.0) * erosionFactor st
              -- Smooth nonlinear coastline fractal function z_{n+1} = z_n^2 + c + e
              z' = z * z + c + (perturbation :+ perturbation)
           in go (itr + 1) z'

-- | Map height iteration count to ASCII terrain glyphs
renderGlyph :: State -> Point -> Char
renderGlyph st c =
  let (itr, mag) = coastlineHeight st c
      maxItr = erosionSteps st
   in if itr == maxItr
        then ' ' -- Deep ocean
        else
          let norm = fromIntegral itr / fromIntegral maxItr
              shading = ".~=+#*%@#"
              idx = floor (norm * fromIntegral (length shading - 1))
           in shading !! idx

-- | Render current viewport as string frame
renderFrame :: State -> String
renderFrame st = unlines [ [ charAt x y | x <- [0 .. width - 1] ] | y <- [0 .. height - 1] ]
  where
    aspect = fromIntegral width / fromIntegral (height * 2)
    scale = 2.0 / (zoom st)
    
    charAt x y =
      let re = realPart (center st) + (fromIntegral x / fromIntegral width - 0.5) * scale * aspect
          im = imagPart (center st) + (fromIntegral y / fromIntegral height - 0.5) * scale
       in renderGlyph st (re :+ im)

-- | Read a single byte from file payload at current navigation viewport
readAtPointer :: State -> Word8
readAtPointer st =
  if BS.null (payload st)
    then 0
    else BS.index (payload st) (byteOffset st `mod` BS.length (payload st))

-- | Modify binary data via coastal alteration (Erosion / Tectonic edit)
modifyByte :: State -> (Word8 -> Word8) -> State
modifyByte st f =
  if BS.null (payload st)
    then st
    else
      let len = BS.length (payload st)
          idx = byteOffset st `mod` len
          (headBS, tailBS) = BS.splitAt idx (payload st)
          oldVal = BS.head tailBS
          newVal = f oldVal
          updated = BS.concat [headBS, BS.singleton newVal, BS.tail tailBS]
       in st {payload = updated}

-- | Clear terminal ANSI escape
clearScreen :: IO ()
clearScreen = putStr "\ESC[2J\ESC[H"

-- | Print interactive interface stats
printHUD :: State -> IO ()
printHUD st = do
  let currByte = readAtPointer st
  putStrLn $ "=== FRACTAL FILE SYSTEM COASTLINE DRIVER ==="
  putStrLn $ "Center: " ++ show (center st) ++ " | Zoom: " ++ show (zoom st)
  putStrLn $ "Erosion Steps: " ++ show (erosionSteps st) ++ " | Erosion Factor: " ++ show (erosionFactor st)
  putStrLn $ "Byte Offset: " ++ show (byteOffset st) ++ " | Current Byte: 0x" ++ showHex currByte "" ++ " ('" ++ sanitize (chr $ fromIntegral currByte) ++ "')"
  putStrLn $ "Controls: [WASD] Pan | [+-] Zoom | [JK] Erosion Depth | [UO] Erosion Intensity | [N/P] Byte Shift | [E] Alter Coastline Data | [Q] Quit"
  where
    sanitize c = if c >= ' ' && c <= '~' then c else '.'
    showHex w = show -- Simple display for byte value

-- | Main Interactive Loop
interactiveLoop :: State -> IO ()
interactiveLoop st = do
  clearScreen
  putStr (renderFrame st)
  printHUD st
  hFlush stdout
  cmd <- getChar
  case cmd of
    'q' -> putStrLn "\nExiting Fractal FS Driver."
    'w' -> interactiveLoop st {center = center st + (0 :+ (-0.2 / zoom st))}
    's' -> interactiveLoop st {center = center st + (0 :+ (0.2 / zoom st))}
    'a' -> interactiveLoop st {center = center st + ((-0.2 / zoom st) :+ 0)}
    'd' -> interactiveLoop st {center = center st + ((0.2 / zoom st) :+ 0)}
    '+' -> interactiveLoop st {zoom = zoom st * 1.5}
    '=' -> interactiveLoop st {zoom = zoom st * 1.5}
    '-' -> interactiveLoop st {zoom = max 0.1 (zoom st / 1.5)}
    'k' -> interactiveLoop st {erosionSteps = max 10 (erosionSteps st + 15)}
    'j' -> interactiveLoop st {erosionSteps = max 10 (erosionSteps st - 15)}
    'o' -> interactiveLoop st {erosionFactor = erosionFactor st * 1.25}
    'u' -> interactiveLoop st {erosionFactor = erosionFactor st / 1.25}
    'n' -> interactiveLoop st {byteOffset = byteOffset st + 1}
    'p' -> interactiveLoop st {byteOffset = max 0 (byteOffset st - 1)}
    'e' -> do
      -- Real-time alteration: modify byte at current offset
      let newSt = modifyByte st (\b -> b `xor` 0xFF)
      interactiveLoop newSt
    _ -> interactiveLoop st

-- | Entry point: Optionally pass file to navigate & alter fractal coastline
main :: IO ()
main = do
  hSetBuffering stdin NoBuffering
  hSetEcho stdin False
  args <- getArgs
  bytes <- case args of
    (fileName : _) -> BS.readFile fileName
    [] -> return $ BS.pack [fromIntegral (ord c) | c <- "FRACTAL_FILE_SYSTEM_BINARY_DATA_INITIAL_COASTLINE_DRIVER_2026"]
  interactiveLoop (initialState bytes)