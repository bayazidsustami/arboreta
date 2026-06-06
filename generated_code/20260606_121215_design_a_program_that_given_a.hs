import System.Environment (getArgs)
import qualified Data.Map.Strict as M
import Data.List (foldl')
import Data.Word (Word8)
import Codec.Midi
import Language.Haskell.Exts (parseFileContents, ParseResult(..), Module(..), ModuleHead(..), Decl(..), Exp(..), Pat(..), SrcSpanInfo)

-- | Assign an instrument (MIDI program number) to each top‑level AST constructor.
instrumentMap :: M.Map String Word8
instrumentMap = M.fromList
  [ ("Module", 0)   -- Acoustic Grand Piano
  , ("ImportDecl", 24) -- Nylon String Guitar
  , ("Decl", 40)    -- Violin
  , ("Exp", 56)     -- Trumpet
  , ("Pat", 72)     -- Clarinet
  ]

-- | Convert a node name and its nesting depth into a MIDI note (0‑127).
noteFromDepth :: Int -> Word8
noteFromDepth d = fromIntegral $ 60 + (d `mod` 12)  -- centre on middle C

-- | Traverse the AST, collecting (time, instrument, note) triples.
collectEvents :: Int -> Int -> Module SrcSpanInfo -> [(AbsTime, Message)]
collectEvents startTicks depth (Module _ _ _ decls) =
  concatMap (collectDecl (startTicks + depth*480) (depth+1)) decls
  where
    collectDecl t d (PatBind _ pat rhs _) =
      let instr = M.findWithDefault 0 "Pat" instrumentMap
          note  = noteFromDepth d
      in [(t,    ProgramChange 0 instr),
          (t,    NoteOn 0 note 100),
          (t+240, NoteOff 0 note 0)] ++
         collectPat (t+240) (d+1) pat ++
         collectRhs (t+240) (d+1) rhs
    collectDecl t d (FunBind _ matches) =
      concatMap (collectMatch t d) matches
    collectDecl _ _ _ = []

    collectMatch t d (Match _ _ pats rhs _) =
      concatMap (collectPat (t+120) (d+1)) pats ++
      collectRhs (t+120) (d+1) rhs
    collectMatch _ _ _ = []

    collectPat t d pat = case pat of
      PVar _ name ->
        let instr = M.findWithDefault 0 "Pat" instrumentMap
            note  = noteFromDepth d
        in [(t, ProgramChange 0 instr),
            (t, NoteOn 0 note 80),
            (t+120, NoteOff 0 note 0)]
      _ -> []

    collectRhs t d rhs = case rhs of
      UnGuardedRhs _ expr -> collectExp t d expr
      GuardedRhss _ ghs -> concatMap (\(GuardedRhs _ _ e) -> collectExp t d e) ghs

    collectExp t d expr = case expr of
      Var _ _ ->
        let instr = M.findWithDefault 0 "Exp" instrumentMap
            note  = noteFromDepth d
        in [(t, ProgramChange 0 instr),
            (t, NoteOn 0 note 70),
            (t+120, NoteOff 0 note 0)]
      App _ e1 e2 -> collectExp t d e1 ++ collectExp (t+60) d e2
      InfixApp _ e1 _ e2 -> collectExp t d e1 ++ collectExp (t+60) d e2
      Lambda _ _ e -> collectExp (t+30) d e
      _ -> []

-- | Main: read source file, parse, generate a simple MIDI file.
main :: IO ()
main = do
  args <- getArgs
  case args of
    [srcPath, outPath] -> do
      src <- readFile srcPath
      case parseFileContents src of
        ParseOk modAST -> do
          let events = collectEvents 0 0 modAST
              track  = map (\(t,m) -> (t,m)) events
              midi = Midi { fileType = Type1
                          , timeDiv  = TicksPerBeat 480
                          , tracks   = [track] }
          exportFile outPath midi
          putStrLn $ "MIDI written to " ++ outPath
        ParseFailed loc msg ->
          putStrLn $ "Parse error at " ++ show loc ++ ": " ++ msg
    _ -> putStrLn "Usage: runhaskell CodeMusic.hs <source.hs> <output.mid>"