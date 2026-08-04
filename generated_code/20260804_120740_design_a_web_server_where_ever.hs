{-# LANGUAGE OverloadedStrings #-}
-- | Generative Stained Glass Ecosystem HTTP Server in Haskell.
-- Every HTTP request alters virtual organism DNA (hues, radii, frequencies).
-- Server state renders as dynamic SVG with embedded Web Audio interactive synth chords.

import Control.Concurrent (forkIO)
import Data.IORef
import Data.Time.Clock (getCurrentTime, diffUTCTime)
import Network.Socket
import Network.Socket.ByteString (recv, sendAll)
import qualified Data.ByteString.Char8 as BS
import Text.Printf (printf)

-- Organism representing virtual DNA within our ecosystem
data Organism = Organism
  { dnaHue      :: Double   -- Visual color hue (0-360)
  , dnaRadius   :: Double   -- Size in SVG stained glass window
  , dnaSides    :: Int      -- Geometric symmetry sides
  , dnaHarmonic :: Double   -- Audio chord frequency (Hz)
  } deriving (Show)

type Ecosystem = [Organism]

-- Initial primal ecosystem DNA
initialEcosystem :: Ecosystem
initialEcosystem =
  [ Organism 210.0 140.0 6 220.0  -- Root A3
  , Organism 45.0  110.0 5 277.18 -- C#4
  , Organism 340.0 80.0  8 329.63 -- E4
  , Organism 160.0 50.0  12 440.0 -- A4
  ]

-- Mutate ecosystem state deterministically based on request path and latency
mutateEcosystem :: String -> Double -> Ecosystem -> Ecosystem
mutateEcosystem path latency eco =
  let pathFactor = fromIntegral (length path) * 7.0
      latFactor  = latency * 100.0
      mutate i org = org
        { dnaHue      = fmod (dnaHue org + pathFactor + latFactor + fromIntegral (i * 15)) 360.0
        , dnaRadius   = max 30.0 (min 280.0 (dnaRadius org + sin (latFactor + fromIntegral i) * 20.0))
        , dnaHarmonic = max 110.0 (min 880.0 (dnaHarmonic org + (latFactor - 10.0)))
        }
  in zipWith mutate [1..] eco

fmod :: Double -> Double -> Double
fmod a b = a - b * fromIntegral (floor (a / b) :: Int)

-- Render live internal server state to generative SVG with interactive audio
renderStainedGlassSVG :: Ecosystem -> Double -> String
renderStainedGlassSVG eco latency =
  let width = 800 :: Int
      height = 800 :: Int
      cx = width `div` 2
      cy = height `div` 2
      
      -- Generate geometric stained-glass polygon for each organism
      renderOrg i org =
        let angleStep = 2 * pi / fromIntegral (dnaSides org)
            pts = [ ( fromIntegral cx + dnaRadius org * cos (a + fromIntegral i * 0.4)
                    , fromIntegral cy + dnaRadius org * sin (a + fromIntegral i * 0.4)
                    )
                  | k <- [0 .. dnaSides org - 1]
                  , let a = fromIntegral k * angleStep
                  ]
            ptsStr = unwords [printf "%.1f,%.1f" x y | (x, y) <- pts]
            fillColor = printf "hsla(%.1f, 80%%, 50%%, 0.45)" (dnaHue org) :: String
            strokeColor = printf "hsla(%.1f, 95%%, 85%%, 0.85)" (dnaHue org + 40.0) :: String
        in printf "<polygon points='%s' fill='%s' stroke='%s' stroke-width='3' style='mix-blend-mode: screen;' />"
                  ptsStr fillColor strokeColor

      polygons = unlines $ zipWith renderOrg [0..] eco
      frequencies = show [dnaHarmonic org | org <- eco]
      
  in printf "<?xml version='1.0' encoding='UTF-8'?>\n\
     \<svg xmlns='[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)' viewBox='0 0 %d %d' style='background:#04040a; cursor:pointer;'>\n\
     \<style>\n\
     \  polygon { transform-origin: %dpx %dpx; transition: all 0.6s cubic-bezier(0.4, 0, 0.2, 1); }\n\
     \  polygon:hover { stroke-width: 7px; opacity: 0.9; }\n\
     \  text { font-family: monospace; fill: #70a0ff; font-size: 13px; }\n\
     \</style>\n\
     \<g>\n\
     \%s\n\
     \</g>\n\
     \<text x='25' y='40'>Evolving Ecosystem Server State</text>\n\
     \<text x='25' y='60'>Measured Latency: %.3f ms | Organism Count: %d</text>\n\
     \<text x='25' y='%d'>[Click Window to Synthesize Latency Harmonic Chord]</text>\n\
     \<script><![CDATA[\n\
     \  const freqs = %s;\n\
     \  document.addEventListener('click', () => {\n\
     \    const ctx = new (window.AudioContext || window.webkitAudioContext)();\n\
     \    freqs.forEach(f => {\n\
     \      const osc = ctx.createOscillator();\n\
     \      const gain = ctx.createGain();\n\
     \      osc.type = 'triangle';\n\
     \      osc.frequency.setValueAtTime(f, ctx.currentTime);\n\
     \      gain.gain.setValueAtTime(0.12, ctx.currentTime);\n\
     \      gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 3.0);\n\
     \      osc.connect(gain);\n\
     \      gain.connect(ctx.destination);\n\
     \      osc.start();\n\
     \      osc.stop(ctx.currentTime + 3.0);\n\
     \    });\n\
     \  });\n\
     \]]></script>\n\
     \</svg>"
     width height cx cy polygons latency (length eco) (height - 30) frequencies

-- Main socket server listening for incoming HTTP requests
main :: IO ()
main = do
  state <- newIORef initialEcosystem
  let port = "8080"
  putStrLn $ "Generative Stained Glass Server active on http://localhost:" ++ port
  
  addr <- resolve port
  sock <- socket (addrFamily addr) (addrSocketType addr) (addrProtocol addr)
  setSocketOption sock ReuseAddr 1
  bind sock (addrAddress addr)
  listen sock 15
  
  serverLoop sock state

resolve :: String -> IO AddrInfo
resolve p = do
  let hints = defaultHints { addrFlags = [AI_PASSIVE], addrSocketType = Stream }
  head <$> getAddrInfo (Just hints) Nothing (Just p)

serverLoop :: Socket -> IORef Ecosystem -> IO ()
serverLoop sock state = do
  (conn, _) <- accept sock
  _ <- forkIO $ handleClient conn state
  serverLoop sock state

handleClient :: Socket -> IORef Ecosystem -> IO ()
handleClient conn state = do
  t0 <- getCurrentTime
  msg <- recv conn 2048
  let reqStr = BS.unpack msg
  let reqPath = case words reqStr of
        (_:p:_) -> p
        _       -> "/"
        
  t1 <- getCurrentTime
  let latency = realToFrac (diffUTCTime t1 t0) * 1000.0 :: Double
  
  -- Mutate DNA stored in IORef based on request & network timing
  newEco <- atomicModifyIORef' state (\eco ->
    let mutated = mutateEcosystem reqPath latency eco
    in (mutated, mutated))
    
  let svgContent = renderStainedGlassSVG newEco latency
  let httpResponse = "HTTP/1.1 200 OK\r\n\
                     \Content-Type: image/svg+xml\r\n\
                     \Content-Length: " ++ show (length svgContent) ++ "\r\n\
                     \Connection: close\r\n\r\n" ++ svgContent
                     
  sendAll conn (BS.pack httpResponse)
  close conn