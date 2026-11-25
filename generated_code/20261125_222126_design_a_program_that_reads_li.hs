{-# LANGUAGE RecordWildCards #-}

-- Live Buoy Wind-to-Chalk Blackboard
-- Reads buoy telemetry lines ("<windSpeed_knots> <windDeg> <pressure_hPa>" or CSV)
-- from stdin (or runs an interactive simulated buoy stream with --demo / piped input).
-- Each wind shift adds a chalk vector stroke on a virtual blackboard;
-- a stroke remains visible only while barometric pressure keeps falling relative to
-- when that stroke was drawn (or while pressure trends downward).

module Main where

import Control.Concurrent (threadDelay)
import Control.Monad (forM_, when)
import Data.Char (isSpace)
import Data.List (intercalate)
import System.Environment (getArgs)
import System.IO (BufferMode (..), hIsEOF, hSetBuffering, stdin, stdout)
import Text.Read (readMaybe)

data Telemetry = Telemetry
  { windSpeed :: !Double   -- knots
  , windDir   :: !Double   -- meteorological degrees (0 = N, 90 = E, 180 = S, 270 = W)
  , pressure  :: !Double   -- hPa
  } deriving (Show, Eq)

data ChalkStroke = ChalkStroke
  { strokeId       :: !Int
  , originX        :: !Double
  , originY        :: !Double
  , deltaX         :: !Double
  , deltaY         :: !Double
  , birthPressure  :: !Double
  , lastPressure   :: !Double
  , chalkIntensity :: !Int     -- 1..3 chalk dust thickness
  } deriving (Show, Eq)

data Blackboard = Blackboard
  { canvasWidth  :: !Int
  , canvasHeight :: !Int
  , penX         :: !Double
  , penY         :: !Double
  , prevDir      :: !(Maybe Double)
  , prevPress    :: !(Maybe Double)
  , nextId       :: !Int
  , strokes      :: ![ChalkStroke]
  } deriving (Show, Eq)

emptyBoard :: Int -> Int -> Blackboard
emptyBoard w h =
  Blackboard
    { canvasWidth = w
    , canvasHeight = h
    , penX = fromIntegral w / 2.0
    , penY = fromIntegral h / 2.0
    , prevDir = Nothing
    , prevPress = Nothing
    , nextId = 1
    , strokes = []
    }

-- Parse flexible telemetry lines: "14.2 215 1008.4" or "14.2,215,1008.4"
parseTelemetry :: String -> Maybe Telemetry
parseTelemetry raw =
  let cleaned = map (\c -> if c == ',' || c == ';' then ' ' else c) (trim raw)
      parts   = filter (not . null) (words cleaned)
  in case parts of
       (sStr : dStr : pStr : _) -> do
         ws <- readMaybe sStr
         wd <- readMaybe dStr
         pr <- readMaybe pStr
         if isNaN ws || isNaN wd || isNaN pr
           then Nothing
           else Just (Telemetry ws (normalizeDeg wd) pr)
       _ -> Nothing

trim :: String -> String
trim = f . f
  where f = reverse . dropWhile isSpace

normalizeDeg :: Double -> Double
normalizeDeg d =
  let m = d `mod'` 360.0
  in if m < 0 then m + 360.0 else m

mod' :: Double -> Double -> Double
mod' a b = a - fromIntegral (floor (a / b) :: Int) * b

-- Convert meteorological wind direction + speed into blackboard displacement.
-- Wind *from* direction `deg` blows *toward* `deg + 180`.
windVector :: Double -> Double -> (Double, Double)
windVector speed deg =
  let towardRad = ((deg + 180.0) `mod'` 360.0) * (pi / 180.0)
      mag       = min 9.0 (max 1.5 (speed * 0.28))
      dx        = sin towardRad * mag
      dy        = -cos towardRad * mag * 0.65 -- aspect compensation for terminal cells
  in (dx, dy)

wrapCoord :: Double -> Double -> Double
wrapCoord maxVal x
  | x < 0      = x + maxVal
  | x >= maxVal = x - maxVal
  | otherwise   = x

-- Advance the blackboard with one live telemetry sample.
-- Key rule: A stroke stays visible only as long as barometric pressure keeps falling.
-- If pressure rises (or stops falling for existing strokes), strokes whose pressure
-- is no longer falling fade/erase; when pressure drops, strokes remain chalked.
stepBoard :: Telemetry -> Blackboard -> Blackboard
stepBoard Telemetry{..} Blackboard{..} =
  let (dx, dy)     = windVector windSpeed windDir
      wF           = fromIntegral canvasWidth
      hF           = fromIntegral canvasHeight
      nx           = wrapCoord wF (penX + dx)
      ny           = wrapCoord hF (penY + dy)
      shifted      = case prevDir of
                       Nothing -> True
                       Just pd -> angularDiff pd windDir >= 8.0
      intensity    = if windSpeed >= 22 then 3 else if windSpeed >= 10 then 2 else 1
      newStroke    =
        ChalkStroke
          { strokeId = nextId
          , originX = penX
          , originY = penY
          , deltaX = dx
          , deltaY = dy
          , birthPressure = pressure
          , lastPressure = pressure
          , chalkIntensity = intensity
          }
      -- Update existing strokes: keep only those where pressure has continued falling
      -- relative to the previous reading (with a tiny epsilon for floating point noise).
      fallingNow   = case prevPress of
                       Nothing -> True
                       Just pp -> pressure < pp - 0.005
      surviving    =
        [ st { lastPressure = pressure }
        | st <- strokes
        , fallingNow && pressure <= birthPressure + 0.01
        ]
      allStrokes   =
        if shifted || null strokes
          then surviving ++ [newStroke]
          else surviving
      -- Keep blackboard readable by capping very old strokes if pressure falls endlessly
      bounded      = drop (max 0 (length allStrokes - 48)) allStrokes
  in Blackboard
       { canvasWidth = canvasWidth
       , canvasHeight = canvasHeight
       , penX = nx
       , penY = ny
       , prevDir = Just windDir
       , prevPress = Just pressure
       , nextId = if shifted || null strokes then nextId + 1 else nextId
       , strokes = bounded
       }

angularDiff :: Double -> Double -> Double
angularDiff a b =
  let raw = abs (normalizeDeg a - normalizeDeg b)
  in if raw > 180.0 then 360.0 - raw else raw

-- Rasterize chalk strokes onto an ASCII blackboard grid.
renderBoard :: Telemetry -> Blackboard -> String
renderBoard Telemetry{..} Blackboard{..} =
  let blankRow = replicate canvasWidth ' '
      baseGrid = replicate canvasHeight blankRow
      grid1    = foldl (plotStroke canvasWidth canvasHeight) baseGrid strokes
      px       = clampInt 0 (canvasWidth - 1) (round penX)
      py       = clampInt 0 (canvasHeight - 1) (round penY)
      grid2    = setCell grid1 px py '@'
      topBar   = "+" ++ replicate canvasWidth '-' ++ "+"
      botBar   = "+" ++ replicate canvasWidth '-' ++ "+"
      trendStr = case prevPress of
                   Nothing -> "INIT"
                   Just pp
                     | pressure < pp - 0.005 -> "FALLING (chalk holds)"
                     | pressure > pp + 0.005 -> "RISING  (chalk erasing!)"
                     | otherwise             -> "STEADY  (chalk fading)"
      status   =
        "BUOY TELEMETRY | Wind: "
          ++ showFixed 1 windSpeed ++ " kt @ "
          ++ showFixed 0 windDir ++ " deg | Baro: "
          ++ showFixed 2 pressure ++ " hPa ["
          ++ trendStr ++ "] | Active Strokes: "
          ++ show (length strokes)
      framed   = map (\row -> "|" ++ row ++ "|") grid2
  in intercalate "\n" ([status, topBar] ++ framed ++ [botBar])

plotStroke :: Int -> Int -> [String] -> ChalkStroke -> [String]
plotStroke w h grid ChalkStroke{..} =
  let steps = max 1 (ceiling (hypot deltaX deltaY * 2.0) :: Int)
      glyph = case chalkIntensity of
                3 -> '#'
                2 -> '='
                _ -> '.'
      pts   =
        [ ( clampInt 0 (w - 1) (round (wrapCoord (fromIntegral w) (originX + deltaX * t)))
          , clampInt 0 (h - 1) (round (wrapCoord (fromIntegral h) (originY + deltaY * t)))
          )
        | i <- [0 .. steps]
        , let t = fromIntegral i / fromIntegral steps
        ]
  in foldl (\g (x, y) -> setCell g x y glyph) grid pts

hypot :: Double -> Double -> Double
hypot x y = sqrt (x * x + y * y)

clampInt :: Int -> Int -> Int -> Int
clampInt lo hi v = max lo (min hi v)

setCell :: [String] -> Int -> Int -> Char -> [String]
setCell rows x y ch =
  [ if rIdx == y
      then take x row ++ [ch] ++ drop (x + 1) row
      else row
  | (rIdx, row) <- zip [0 ..] rows
  ]

showFixed :: Int -> Double -> String
showFixed decimals val =
  let scale :: Double
      scale = fromIntegral ((10 :: Int) ^ decimals)
      scaled :: Integer
      scaled = round (val * scale)
      (q, r) = quotRem (abs scaled) (round scale)
      signStr = if scaled < 0 then "-" else ""
      rStr    = padLeft '0' decimals (show r)
  in if decimals <= 0
       then signStr ++ show q
       else signStr ++ show q ++ "." ++ rStr

padLeft :: Char -> Int -> String -> String
padLeft c n s = replicate (max 0 (n - length s)) c ++ s

-- Built-in live-style buoy telemetry sequence demonstrating falling,
-- steady, and rising barometric pressure with shifting wind vectors.
demoTelemetry :: [Telemetry]
demoTelemetry =
  [ Telemetry 11.0 190.0 1016.40
  , Telemetry 14.5 215.0 1015.10
  , Telemetry 18.0 245.0 1013.65
  , Telemetry 23.5 275.0 1011.80
  , Telemetry 21.0 310.0 1010.20
  , Telemetry 16.5 340.0 1009.40
  , Telemetry 13.0  20.0 1009.40  -- steady: pressure stops falling
  , Telemetry 12.0  45.0 1010.80  -- rising: chalk strokes erase
  , Telemetry 10.5  70.0 1012.60  -- rising: more strokes erase
  , Telemetry 15.0 130.0 1011.10  -- falling again: fresh chalk holds
  , Telemetry 19.5 165.0 1009.30
  ]

runLiveStream :: Blackboard -> IO ()
runLiveStream board = do
  eof <- hIsEOF stdin
  unless eof $ do
    line <- getLine
    case parseTelemetry line of
      Nothing -> runLiveStream board
      Just tel -> do
        let board' = stepBoard tel board
        putStrLn "\ESC[2J\ESC[H"
        putStrLn (renderBoard tel board')
        runLiveStream board'

runDemoStream :: Blackboard -> [Telemetry] -> IO ()
runDemoStream _ [] = pure ()
runDemoStream board (tel : rest) = do
  let board' = stepBoard tel board
  putStrLn "\ESC[2J\ESC[H"
  putStrLn (renderBoard tel board')
  threadDelay 750000
  runDemoStream board' rest

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  hSetBuffering stdin LineBuffering
  args <- getArgs
  let board = emptyBoard 72 20
  if "--demo" `elem` args
    then runDemoStream board demoTelemetry
    else do
      eof <- hIsEOF stdin
      if eof
        then runDemoStream board demoTelemetry
        else runLiveStream board