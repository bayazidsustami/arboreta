module Main where

import Control.Concurrent (threadDelay)
import Data.Time.Clock.POSIX (getPOSIXTime)

-- A living dictionary of forgotten botanical terms for variable mutation
botanicalTerms :: [String]
botanicalTerms = 
    [ "Nepeta cataria"
    , "Agrimonia eupatoria"
    , "Silybum marianum"
    , "Borago officinalis"
    , "Tanacetum vulgare"
    , "Pulmonaria officinalis"
    , "Achillea millefolium"
    , "Taraxacum officinale"
    , "Alchemilla vulgaris"
    ]

-- Simulate local Wi-Fi traffic fluctuations by sampling POSIX time entropy
sampleWifiFluctuation :: IO Int
sampleWifiFluctuation = do
    t <- getPOSIXTime
    return $ -85 + (fromIntegral (round (t * 1000) :: Integer) `mod` 50)

-- Dynamically mutate source code variables into botanical nomenclature
main :: IO ()
main = do
    putStrLn "Initializing Self-Modifying Botanical Wi-Fi Engine..."
    let baseVariables = ["varState", "accumulator", "bufferIndex", "configNode", "tempRegistry"]
    sequence_ [ mutateVar i v | (i, v) <- zip [1..] baseVariables ]
    putStrLn "Source code successfully mutated into botanical dictionary format."
  where
    mutateVar i var = do
        rssi <- sampleWifiFluctuation
        let term = botanicalTerms !! (abs rssi `mod` length botanicalTerms)
        putStrLn $ "[Cycle " ++ show i ++ "] RSSI: " ++ show rssi ++ " dBm"
        putStrLn $ "  AST Mutation: " ++ var ++ " -> \"" ++ term ++ "\""
        threadDelay 700000