-- Git Commit History Labyrinth Generator
-- Parses current git repo's main branch commits and proceduralizes a printable ASCII maze
-- where the only true path from Start (S) to Exit (E) traces the commit history sequence.

import System.Process (readProcess)
import qualified Data.Set as Set
import Data.Word (Word32)
import Data.List (zip5)

type Pos = (Int, Int)
type RNG = Word32

-- Linear Congruential Generator for zero-dependency deterministic pseudo-randomness
nextRNG :: RNG -> (Int, RNG)
nextRNG seed =
  let nextSeed = seed * 1103515245 + 12345
      val = fromIntegral ((nextSeed `div` 65536) `mod` 32768)
  in (val, nextSeed)

-- Fisher-Yates shuffle variant driven by custom PRNG
shuffle :: RNG -> [a] -> ([a], RNG)
shuffle rng [] = ([], rng)
shuffle rng xs = go rng (length xs) xs []
  where
    go r 0 _ acc = (acc, r)
    go r n rest acc =
      let (val, r') = nextRNG r
          idx = val `mod` n
          (left, picked : right) = splitAt idx rest
      in go r' (n - 1) (left ++ right) (picked : acc)

-- Grid cardinal direction vectors
dirs :: [Pos]
dirs = [(0, -1), (1, 0), (0, 1), (-1, 0)]

-- Step 1: Layout the main branch commit sequence as a self-avoiding path on a 2D grid
layoutCommitPath :: RNG -> Int -> Pos -> Set.Set Pos -> [Pos] -> ([Pos], Set.Set Pos, RNG)
layoutCommitPath rng 0 pos visited path = (reverse (pos : path), Set.insert pos visited, rng)
layoutCommitPath rng remaining pos visited path =
  let (shuffledDirs, rng') = shuffle rng dirs
      candidates = [ (x + dx, y + dy) | (dx, dy) <- shuffledDirs, let (x, y) = pos, Set.notMember (x + dx, y + dy) visited ]
  in case candidates of
       (nextPos : _) -> layoutCommitPath rng' (remaining - 1) nextPos (Set.insert pos visited) (pos : path)
       []            -> (reverse (pos : path), Set.insert pos visited, rng')

-- Step 2: Depth-First Search maze expansion to add false branches and dead-ends
carveDeadEnds :: RNG -> Pos -> Set.Set (Pos, Pos) -> Set.Set Pos -> (Set.Set (Pos, Pos), Set.Set Pos)
carveDeadEnds rng startPos initialPassages initialVisited = go rng initialPassages initialVisited [startPos]
  where
    go r passages visited [] = (passages, visited)
    go r passages visited (curr : stack) =
      let (shuffledDirs, r') = shuffle r dirs
          neighbors = [ (x + dx, y + dy) | (dx, dy) <- shuffledDirs, let (x, y) = curr, abs (x) <= 12, abs (y) <= 12 ]
          unvisited = filter (`Set.notMember` visited) neighbors
      in case unvisited of
           (nxt : _) ->
             let passages' = Set.insert (curr, nxt) $ Set.insert (nxt, curr) passages
                 visited'  = Set.insert nxt visited
             in go r' passages' visited' (nxt : curr : stack)
           [] -> go r' passages visited stack

main :: IO ()
main = do
  -- Parse the Git history (first-parent chain represents the main branch topology)
  gitLogRaw <- readProcess "git" ["log", "--first-parent", "--format=%h %s", "-n", "20"] ""
  let commits = reverse $ lines gitLogRaw
  let totalCommits = length commits

  if totalCommits == 0
    then putStrLn "Error: Not a git repository or no commits found."
    else do
      let initialSeed = 20260813 :: Word32
      let startPos = (0, 0)

      -- Generate main branch solution trail
      let (mainPath, visitedMain, rng1) = layoutCommitPath initialSeed (totalCommits - 1) startPos (Set.singleton startPos) []
      let mainPassages = Set.fromList [ p | (a, b) <- zip mainPath (tail mainPath), p <- [(a, b), (b, a)] ]

      -- Populate the maze with decoys around the commit path
      let (allPassages, allVisited) = carveDeadEnds rng1 startPos mainPassages visitedMain

      -- Grid boundaries calculation
      let coords = Set.toList allVisited
      let xs = map fst coords
      let ys = map snd coords
      let (minX, maxX) = (minimum xs, maximum xs)
      let (minY, maxY) = (minimum ys, maximum ys)

      -- Render Git commit legend
      putStrLn "=========================================================================="
      putStrLn "                    GIT COMMIT HISTORY LABYRINTH                          "
      putStrLn "=========================================================================="
      putStrLn "Solve the maze from [S] (Root) to [E] (HEAD) to trace main branch history:\n"
      mapM_ (\(idx, commit) -> putStrLn $ "  Step " ++ show idx ++ ": " ++ commit) (zip [(1::Int)..] commits)
      putStrLn "\nLegend: S = Root Commit, E = HEAD, █ = Wall, Space = Passage\n"

      -- Render ASCII Maze
      let hasPassage p1 p2 = Set.member (p1, p2) allPassages
      let renderCell pos
            | pos == head mainPath = "S"
            | pos == last mainPath = "E"
            | otherwise            = " "

      mapM_ (\y -> do
        -- Draw horizontal cell borders / walls
        putStrLn $ concat [ if hasPassage (x, y) (x, y - 1) then "█ " else "██" | x <- [minX..maxX] ] ++ "█"
        -- Draw cell content and vertical walls
        putStrLn $ concat [ "█" ++ renderCell (x, y) ++ if hasPassage (x, y) (x + 1, y) then " " else "█" | x <- [minX..maxX] ]
        ) [minY..maxY]
      putStrLn $ replicate ((maxX - minX + 1) * 2 + 1) '█'