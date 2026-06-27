{-# LANGUAGE OverloadedStrings #-}
-- The verses shift like sunrise on __DATE__ __TIME__
-- A fleeting poem that changes each compilation, echoing the program's breath.

module Main where

import System.IO (stdin, hGetContents)
import System.Random (randomRIO)
import Data.Time.Clock (getCurrentTime)
import Data.Time.Format (formatTime, defaultTimeLocale)
import Data.Aeson (ToJSON(..), object, (.=), encode)
import qualified Data.ByteString.Lazy as B
import Control.Monad (replicateM)
import Data.Char (isAlpha, toLower)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO

-- | A vertex in the fractal sculpture.
data Vertex = Vertex
  { position :: (Double, Double, Double)   -- ^ 3D coordinates
  , color    :: (Int, Int, Int)            -- ^ RGB color
  , word     :: String                     -- ^ Source word
  } deriving Show

instance ToJSON Vertex where
  toJSON (Vertex (x,y,z) (r,g,b) w) =
    object [ "position" .= [x,y,z]
           , "color"    .= [r,g,b]
           , "word"     .= w ]

-- | Very simple stress detection: uppercase vowels are considered stressed.
stressPattern :: String -> [Bool]
stressPattern = map (`elem` "AEIOU") . filter (`elem` (['a'..'z'] ++ ['A'..'Z']))

-- | Generate a colour based on stress intensity.
stressColor :: Bool -> (Int,Int,Int)
stressColor True  = (255, 100, 100)   -- reddish for stress
stressColor False = (100, 100, 255)   -- bluish otherwise

-- | Produce a list of vertices from words.
makeVertices :: [String] -> IO [Vertex]
makeVertices ws = do
  let base = 0.0
  verts <- zipWithM mkVertex [0..] ws
  return verts
  where
    zipWithM f xs ys = sequence $ zipWith f xs ys
    mkVertex :: Int -> String -> IO Vertex
    mkVertex idx w = do
      let sp = stressPattern w
          stressed = any id sp
          (r,g,b) = stressColor stressed
          angle = fromIntegral idx * 0.618  -- golden angle
          radius = 1.0 + 0.05 * fromIntegral (length w)
          x = radius * cos angle
          y = radius * sin angle
          z = fromIntegral (length (filter isAlpha w)) * 0.1
      return $ Vertex (x,y,z) (r,g,b) w

-- | Main program: read text, build vertices, write JSON.
main :: IO ()
main = do
  txt <- TIO.getContents
  let wordsList = map T.unpack $ T.words txt
  verts <- makeVertices wordsList
  let json = encode verts
  B.writeFile "output.json" json
  putStrLn "Fractal sculpture data written to output.json"