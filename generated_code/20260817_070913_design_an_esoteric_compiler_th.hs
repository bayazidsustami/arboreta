import Data.Word (Word8)
import Data.Bits (testBit)
import System.Environment (getArgs)
import System.IO (readFile')
import Text.Printf (printf)

-- | Represents a grid cell in the maze with 4 walls: (North, East, South, West)
type Walls = (Bool, Bool, Bool, Bool)

-- | Simple 2D Point/Size definition
type Point = (Int, Int)

-- | Translates a single binary byte into an opcode name or dummy instruction
decodeByte :: Word8 -> String
decodeByte b = case b `mod` 8 of
    0 -> "NOP"
    1 -> "MOV"
    2 -> "ADD"
    3 -> "SUB"
    4 -> "XOR"
    5 -> "JMP"
    6 -> "CMP"
    _ -> "RET"

-- | Generates SVG paths for typography and maze walls based on assembly bytes
buildSvg :: [Word8] -> String
buildSvg bytes = unlines
    [ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    , printf "<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" viewBox=\"0 0 %d %d\" width=\"100%%\" height=\"100%%\" style=\"background:#0d0f12;\">" svgWidth svgHeight
    , "  <style>"
    , "    .wall { stroke: #00f0ff; stroke-width: 2; stroke-linecap: round; fill: none; filter: drop-shadow(0 0 2px #00f0ff); }"
    , "    .path { stroke: #ff0055; stroke-width: 4; stroke-linecap: round; stroke-linejoin: round; fill: none; filter: drop-shadow(0 0 4px #ff0055); }"
    , "    .text { font-family: monospace; font-size: 10px; fill: #708090; opacity: 0.6; text-anchor: middle; }"
    , "  </style>"
    , "  <g id=\"maze-grid\">"
    , concatMap renderCell cells
    , "  </g>"
    , "  <g id=\"execution-path\">"
    , printf "    <path class=\"path\" d=\"M %d %d %s\" />" startX startY pathData
    , "  </g>"
    , "</svg>"
    ]
  where
    gridSize = max 4 (ceiling . sqrt . (fromIntegral :: Int -> Double) $ length bytes)
    cellSize = 40
    margin = 40
    svgWidth = gridSize * cellSize + margin * 2
    svgHeight = gridSize * cellSize + margin * 2

    startX = margin + cellSize `div` 2
    startY = margin + cellSize `div` 2

    -- Generate grid cells paired with decoded assembly text and bitwise wall configs
    cells = [ ((x, y), bytes !! idx, decodeByte (bytes !! idx)) 
            | idx <- [0 .. min (gridSize * gridSize - 1) (length bytes - 1)]
            , let x = idx `mod` gridSize
            , let y = idx `div` gridSize
            ]

    renderCell :: (Point, Word8, String) -> String
    renderCell ((x, y), b, op) =
        let px = margin + x * cellSize
            py = margin + y * cellSize
            cx = px + cellSize `div` 2
            cy = py + cellSize `div` 2 + 3
            -- Use bits of byte to drop walls and open paths
            n = not (testBit b 0)
            e = not (testBit b 1)
            s = not (testBit b 2)
            w = not (testBit b 3)
            wN = if n then printf "<line class=\"wall\" x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\"/>" px py (px+cellSize) py else ""
            wE = if e then printf "<line class=\"wall\" x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\"/>" (px+cellSize) py (px+cellSize) (py+cellSize) else ""
            wS = if s then printf "<line class=\"wall\" x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\"/>" px (py+cellSize) (px+cellSize) (py+cellSize) else ""
            wW = if w then printf "<line class=\"wall\" x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\"/>" px py px (py+cellSize) else ""
            txt = printf "<text class=\"text\" x=\"%d\" y=\"%d\">%s</text>" cx cy op
        in unlines [wN, wE, wS, wW, txt]

    -- Tracing the unique assembly path to the center
    pathData = unwords [ printf "L %d %d" (margin + (i `mod` gridSize) * cellSize + cellSize `div` 2)
                                          (margin + (i `div` gridSize) * cellSize + cellSize `div` 2)
                       | i <- [0 .. length cells - 1] ]

main :: IO ()
main = do
    args <- getArgs
    case args of
        [inputFile, outputFile] -> do
            content <- readFile' inputFile
            let bytes = map (fromIntegral . fromEnum) content :: [Word8]
            let dummyBytes = if null bytes then [0x90, 0x8b, 0x01, 0xc3] else bytes
            let svgContent = buildSvg dummyBytes
            writeFile outputFile svgContent
            putStrLn $ "Compiled " ++ inputFile ++ " to typographic SVG maze: " ++ outputFile
        _ -> putStrLn "Usage: esocompiler <input_binary> <output.svg>"