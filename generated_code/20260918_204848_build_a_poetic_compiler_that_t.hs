-- Poetic Heartbreak Compiler in Haskell
-- Translates sorrow into valid Brainfuck bytecode and collapsing star constellations.

import Data.Char (toLower)

-- ASCII constellation representing a collapsing star for stanza breaks
constellation :: String
constellation = unlines
  [ "--- * * . . * * ---"
  , "   \\  |  /      "
  , "  *-- (X) --*   "
  , "   /  |  \\      "
  , "--- * * . . * * ---"
  ]

-- Map characters to poetic Brainfuck instructions
-- Vowels increment the memory cell; spaces shift the pointer; 
-- punctuation emits the current sorrow.
translateChar :: Char -> String
translateChar c
  | c' `elem` "aeiou" = "+"
  | c == ' '          = ">"
  | c == '.'          = "."
  | otherwise         = ""
  where c' = toLower c

-- Compile lines, injecting constellations at empty stanza breaks
compileStanzas :: [String] -> String
compileStanzas [] = ""
compileStanzas (s:ss)
  | all (`elem` " \t\r") s = "\n" ++ constellation ++ "\n"
  | otherwise              = concatMap translateChar s ++ "\n" ++ compileStanzas ss

main :: IO ()
main = do
  content <- getContents
  let stanzas = lines content
  putStrLn "[Brainfuck Heartbreak Bytecode & Constellations]"
  putStr (compileStanzas stanzas)