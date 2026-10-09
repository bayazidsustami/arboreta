module Main where

import Control.Concurrent (threadDelay)
import System.CPUTime (getCPUTime)

-- A cellular automaton that evolves a string representation of its own logic
-- and weaves procedural folk tales based on atmospheric pressure fluctuations.

type State = [Int]

initialState :: State
initialState = [0,1,1,0,1,0,0,1,1,1,0,0,1,0,1,1,0,0,1,1,0,1,0,1,1,0,1,1,0,0,1,0]

-- Elementary Cellular Automaton rule 110 variant for self-rewriting logic
stepCA :: State -> State
stepCA xs = zipWith3 rule (last xs : xs) xs (tail xs ++ [head xs])
  where
    rule 1 1 1 = 0
    rule 1 1 0 = 1
    rule 1 0 1 = 1
    rule 1 0 0 = 0
    rule 0 1 1 = 1
    rule 0 1 0 = 1
    rule 0 0 1 = 1
    rule 0 0 0 = 0
    rule _ _ _ = 0

renderTale :: Integer -> State -> String
renderTale pressure state =
    let visual = map (\b -> if b == 1 then '#' else '.') state
        mood | pressure `mod` 2 == 0 = "The barometer falls: A tale of the deep sea weavers."
             | otherwise             = "The barometer rises: A legend of the mountain wind."
    in mood ++ " [" ++ visual ++ "]"

main :: IO ()
main = do
    putStrLn "Weaving procedural folk tales from atmospheric rhythms..."
    let loop st count = do
            time <- getCPUTime
            let pressure = time `mod` 50 + 995 -- Simulated pressure in hPa
            putStrLn (renderTale pressure st)
            threadDelay 250000
            if count > 0 
               then loop (stepCA st) (count - 1)
               else putStrLn "The source code settles into its final myth."
    loop initialState 20