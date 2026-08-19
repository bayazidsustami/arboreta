import Data.Char (isAlpha, isPunctuation, toLower)
import Data.List (foldl')                                                                                                                    
import System.Environment (getArgs)                                                                                                        

-- Abstract Syntax Tree / Bytecode Instructions                                                                                              
data Instruction                                                                                                                             
  = Push Int     -- Driven by high syllable density                                                                                          
  | Add          -- Exclamation mark (!)                                                                                                     
  | Sub          -- Dash / Hyphen (-)                                                                                                        
  | Mul          -- Question mark (?)                                                                                                        
  | PrintChar    -- Period (.)                                                                                                               
  | Duplicate    -- Comma (,)                                                                                                                
  | MemoryStore  -- Semicolon (;)                                                                                                            
  | MemoryLoad   -- Colon (:)                                                                                                                
  | Newline      -- Line breaks                                                                                                              
  deriving (Show, Eq)                                                                                                                        

type Stack = [Int]                                                                                                                           
type Memory = [Int] -- Simple fixed-size memory array                                                                                        

-- Syllable estimator based on vowel group counting                                                                                          
countSyllables :: String -> Int                                                                                                              
countSyllables word = max 1 (length . filter id $ zipWith isVowelStart (False : map isVowel clean) (map isVowel clean))                      
  where                                                                                                                                      
    clean = filter isAlpha (map toLower word)                                                                                                
    isVowel c = c `elem` "aeiouy"                                                                                                             
    isVowelStart prev current = current && not prev                                                                                          

-- Compile a line of prose into instructions                                                                                                 
compileLine :: String -> [Instruction]                                                                                                       
compileLine line = wordsInstructions ++ punctInstructions ++ [Newline]                                                                      
  where                                                                                                                                      
    ws = words line                                                                                                                          
    totalSyllables = sum (map countSyllables ws)                                                                                             
    wordsInstructions = [Push totalSyllables | totalSyllables > 0]                                                                           
    
    punctInstructions = concatMap mapPunct line                                                                                              
    mapPunct '!' = [Add]                                                                                                                     
    mapPunct '-' = [Sub]                                                                                                                     
    mapPunct '?' = [Mul]                                                                                                                     
    mapPunct '.' = [PrintChar]                                                                                                               
    mapPunct ',' = [Duplicate]                                                                                                               
    mapPunct ';' = [MemoryStore]                                                                                                             
    mapPunct ':' = [MemoryLoad]                                                                                                              
    mapPunct _   = []                                                                                                                       

-- Virtuoso Compiler: Translates raw prose string to Bytecode                                                                                
compile :: String -> [Instruction]                                                                                                           
compile = concatMap compileLine . lines                                                                                                      

-- Virtual Machine / Bytecode Interpreter                                                                                                   
runVM :: [Instruction] -> Stack -> Memory -> IO ()                                                                                           
runVM [] _ _ = putStrLn ""                                                                                                                   
runVM (instr:is) stack mem = case instr of                                                                                                   
  Push n -> runVM is (n : stack) mem                                                                                                         
  Add -> case stack of                                                                                                                       
    (a : b : rest) -> runVM is ((b + a) : rest) mem                                                                                          
    _              -> runVM is stack mem                                                                                                     
  Sub -> case stack of                                                                                                                       
    (a : b : rest) -> runVM is ((b - a) : rest) mem                                                                                          
    _              -> runVM is stack mem                                                                                                     
  Mul -> case stack of                                                                                                                       
    (a : b : rest) -> runVM is ((b * a) : rest) mem                                                                                          
    _              -> runVM is stack mem                                                                                                     
  PrintChar -> case stack of                                                                                                                 
    (a : rest) -> putChar (toEnum (a `mod` 128)) >> runVM is rest mem                                                                        
    []         -> runVM is stack mem                                                                                                         
  Duplicate -> case stack of                                                                                                                 
    (a : rest) -> runVM is (a : a : rest) mem                                                                                                
    []         -> runVM is stack mem                                                                                                         
  MemoryStore -> case stack of                                                                                                               
    (val : addr : rest) -> runVM is rest (updateMem addr val mem)                                                                            
    _                   -> runVM is stack mem                                                                                                
  MemoryLoad -> case stack of                                                                                                                
    (addr : rest) -> runVM is (readMem addr mem : rest) mem                                                                                  
    []            -> runVM is stack mem                                                                                                      
  Newline -> putChar '\n' >> runVM is stack mem                                                                                              
  where                                                                                                                                      
    updateMem idx val m = take idx m ++ [val] ++ drop (idx + 1) m                                                                            
    readMem idx m       = if idx >= 0 && idx < length m then m !! idx else 0                                                                 

-- Example Prose: Compiles to "Hello World!" style bytecode execution                                                                        
sampleProse :: String                                                                                                                        
sampleProse = unlines                                                                                                                        
  [ "An extraordinary, beautiful illumination shining upon the realm!"                                                                       
  , "Gentle soft murmurings, delicate whispers."                                                                                             
  , "Are there mysterious, wonderful secrets hidden deeply within?"                                                                          
  ]                                                                                                                                          

main :: IO ()                                                                                                                                
main = do                                                                                                                                    
  args <- getArgs                                                                                                                            
  input <- if null args then return sampleProse else readFile (head args)                                                                    
  let bytecode = compile input                                                                                                               
  putStrLn "=== Emotional Cadence Bytecode compiled ==="                                                                                     
  mapM_ print bytecode                                                                                                                       
  putStrLn "\n=== Execution Output ==="                                                                                                      
  runVM bytecode [] (replicate 256 0)