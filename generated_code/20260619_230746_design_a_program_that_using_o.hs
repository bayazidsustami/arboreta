#!/usr/bin/env stack
{- stack
   script
   --resolver lts-22.27
   --package base
   --package vector
   --package stm
   --package async
   --package bytestring
   --package streamly
   --package streamly-core
   --package streamly-fd
   --package streamly-process
   --package streamly-unicode
   --package ansi-terminal
   --package fft
   --package random
-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RecordWildCards #-}

import qualified Data.Vector.Storable as VS
import qualified Data.Vector as V
import Data.Complex
import Data.Word (Word8)
import System.Console.ANSI
import System.IO
import Control.Concurrent (threadDelay)
import Control.Monad (forever, when)
import System.Random (randomRIO)
import Numeric.FFT (fft)

-- Parameters
frameSize :: Int
frameSize = 1024      -- samples per FFT frame

sampleRate :: Double
sampleRate = 44100.0  -- Hz

numBands :: Int
numBands = 16         -- number of frequency bands to display

-- L‑system definition
type Symbol = Char
type Rule = Symbol -> String

axiom :: String
axiom = "F"

rule :: Rule
rule 'F' = "F+F−F"
rule  c  = [c]

-- Generate n iterations of the L‑system
lsys :: Int -> String
lsys n = iterate (concatMap rule) axiom !! n

-- Map a band magnitude to a colour (using 6‑bit 256‑color palette)
magToColor :: Double -> Color
magToColor m = case floor (m * 5) of
    0 -> Blue
    1 -> Cyan
    2 -> Green
    3 -> Yellow
    4 -> Red
    _ -> Magenta

-- Choose a Unicode block element based on the magnitude
magToGlyph :: Double -> String
magToGlyph m
    | m < 0.2 = "▁"
    | m < 0.4 = "▂"
    | m < 0.6 = "▃"
    | m < 0.8 = "▄"
    | otherwise = "█"

-- Compute spectral centroid (used to seed L‑system depth)
centroid :: VS.Vector Double -> Double
centroid mags =
    let freqs = VS.generate (VS.length mags) (\i -> fromIntegral i * sampleRate / fromIntegral frameSize)
        weighted = VS.sum $ VS.zipWith (*) mags freqs
        total = VS.sum mags + 1e-9
    in weighted / total

-- Produce one visual line from FFT magnitudes
renderLine :: VS.Vector Double -> IO ()
renderLine mags = do
    let bandSize = VS.length mags `div` numBands
        bands = [ VS.slice (i*bandSize) bandSize mags | i <- [0..numBands-1] ]
        magsNorm = map (\v -> VS.maximum v) bands
        maxMag = maximum magsNorm + 1e-9
        norms = map (/maxMag) magsNorm
        cent = centroid mags
        depth = min 5 (max 1 (floor (cent / (sampleRate/2) * 6)))
        lsysStr = take (depth*2) (lsys depth)
        glyphs = map magToGlyph norms
        colors = map (magToColor . (**0.5)) norms
    hideCursor
    setCursorPosition 0 0
    mapM_ (\(c,g) -> do
            setSGR [SetColor Foreground Vivid c]
            putStr g) (zip colors (cycle glyphs))
    putStrLn ""
    setSGR [Reset]
    showCursor

-- Dummy audio source: generate random samples
genAudioChunk :: IO (VS.Vector Double)
genAudioChunk = VS.generateM frameSize (\_ -> randomRIO (-1.0,1.0))

main :: IO ()
main = do
    hSetBuffering stdout NoBuffering
    clearScreen
    forever $ do
        chunk <- genAudioChunk
        let fftResult = fft (VS.map (:+ 0) chunk)
            mags = VS.map magnitude fftResult
        renderLine mags
        threadDelay 50000   -- ~20 FPS