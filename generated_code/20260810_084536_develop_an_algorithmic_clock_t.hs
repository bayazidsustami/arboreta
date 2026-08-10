import Control.Concurrent (threadDelay)
import Control.Monad (when, forM_)
import Data.Bits (xor)
import Data.Char (chr)
import Data.List (intercalate)
import Data.Time.Clock (getCurrentTime)
import Data.Time.LocalTime (getCurrentTime, getTimeZone, utcToLocalTime, localTimeOfDay, todHour, todMin, todSec)
import System.IO (hFlush, stdout, hSetBuffering, BufferMode(NoBuffering))
import System.Random (mkStdGen, randoms)

-- Reads Linux system metrics via /proc, falling back gracefully on other systems
getSystemMetrics :: IO (Double, Double)
getSystemMetrics = do
  cpu <- readCpu
  mem <- readMem
  pure (cpu, mem)
  where
    readCpu = do
      eContent <- tryReadFile "/proc/stat"
      case eContent of
        Just content -> case lines content of
          (l:_) -> pure $ parseProcStat l
          _     -> fallback
        Nothing -> fallback

    readMem = do
      eContent <- tryReadFile "/proc/meminfo"
      case eContent of
        Just content -> pure $ parseMemInfo content
        Nothing      -> fallback

    fallback = pure (0.35, 0.50)

    tryReadFile path = catch (Just <$> readFile path) (\(_ :: SomeException) -> pure Nothing)

    parseProcStat line =
      let ws = map reads (words line) :: [[(Double, String)]]
          vals = [v | [(v, "")] <- ws]
      in if length vals >= 4
           then let idle = vals !! 3
                    total = sum (take 7 vals)
                in (1.0 - idle / (total + 1e-5))
           else 0.5

    parseMemInfo content =
      let lns = lines content
          findVal key = case filter (isPrefixOf key) lns of
            (x:_) -> case words x of
                       (_:v:_) -> readMaybe v :: Maybe Double
                       _       -> Nothing
            _     -> Nothing
      in case (findVal "MemTotal:", findVal "MemAvailable:") of
        (Just tot, Just avail) -> 1.0 - (avail / tot)
        _                      -> 0.5

-- Non-repeating noise function based on space-time coordinates
labyrinthNoise :: Int -> Int -> Int -> Int -> Double
labyrinthNoise x y z t =
  let h1 = (x * 374761393 + y * 668265263 + z * 362827313 + t * 104729) `xor` 0x5bf03635
      h2 = (h1 ^^^ (h1 `shiftR` 13)) * 1274126177
      h3 = h2 `xor` (h2 `shiftR` 16)
  in fromIntegral (abs h3 `mod` 1000) / 1000.0
  where
    (^^^) = xor
    shiftR = Data.Bits.shiftR

-- Generate wall character based on threshold and local energy
cellChar :: Double -> Double -> Char
cellChar val decay
  | val < 0.2 + decay * 0.1 = ' '
  | val < 0.4               = '░'
  | val < 0.6               = '▒'
  | val < 0.8               = '▓'
  | otherwise               = '█'

-- Maps time and CPU/Memory metrics into ANSI RGB colors
colorCode :: Double -> Double -> Int -> Int -> String
colorCode cpu mem r g =
  let red   = floor (255 * (0.3 + 0.7 * cpu)) :: Int
      green = floor (255 * (0.2 + 0.8 * (fromIntegral r / 80.0))) :: Int
      blue  = floor (255 * (0.4 + 0.6 * mem)) :: Int
  in "\ESC[38;2;" ++ show red ++ ";" ++ show green ++ ";" ++ show blue ++ "m"

import Control.Exception (catch, SomeException)
import Data.List (isPrefixOf)
import Text.Read (readMaybe)

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  putStr "\ESC[2J\ESC[?25l" -- Clear screen and hide cursor

  let width = 70
      height = 22

  let loop frame = do
        now <- getCurrentTime
        tz  <- getTimeZone now
        let local = utcToLocalTime tz now
            tod   = localTimeOfDay local
            h     = todHour tod
            m     = todMin tod
            s     = floor (todSec tod) :: Int

        (cpu, mem) <- getSystemMetrics

        putStr "\ESC[1;1H" -- Move cursor to top-left

        -- Render labyrinth layer
        let timeSeed = h * 3600 + m * 60 + s
        forM_ [0..height-1] $ \y -> do
          let line = concatMap (\x ->
                let n = labyrinthNoise (x + frame) (y + frame) timeSeed frame
                    decay = (sin (fromIntegral (x + y + frame) * 0.1) + 1.0) * 0.5 * cpu
                    ch = cellChar n decay
                    clr = colorCode cpu mem x y
                in clr ++ [ch]
                ) [0..width-1]
          putStrLn (line ++ "\ESC[0m")

        -- Time Overlay Banner
        let timeStr = " 🕒 " ++ showTwo h ++ ":" ++ showTwo m ++ ":" ++ showTwo s
            sysStr  = " | CPU: " ++ show (floor (cpu * 100) :: Int) ++ "% MEM: " ++ show (floor (mem * 100) :: Int) ++ "% "
            banner  = timeStr ++ sysStr
            pad     = (width - length banner) `div` 2
            margin  = replicate (max 0 pad) ' '

        putStrLn $ "\ESC[1;37;44m" ++ margin ++ banner ++ margin ++ "\ESC[0m"

        hFlush stdout
        threadDelay 100000 -- 10 FPS
        loop (frame + 1)

  loop 0

showTwo :: Int -> String
showTwo n = if n < 10 then '0' : show n else show n