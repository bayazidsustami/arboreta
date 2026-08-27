import Control.Concurrent (threadDelay)
import Control.Monad (forM_, when, replicateM)
import Data.Char (isDigit)
import Data.List (isPrefixOf)
import System.Exit (exitSuccess)
import System.IO (hSetEcho, hSetBuffering, hSetBinaryMode, stdin, stdout, BufferMode(..))
import System.Random (randomRIO)

-- Data Structures
data CommitType = NormalCommit | BugFixCommit | MergeConflictCommit deriving (Eq, Show)

data Commit = Commit
  { commitHash :: String
  , commitMsg  :: String
  , commitType :: CommitType
  } deriving Show

data Bullet = Bullet
  { bX :: Double
  , bY :: Double
  , bVX :: Double
  , bVY :: Double
  , bChar :: Char
  }

data Boss = Boss
  { bossX :: Double
  , bossY :: Double
  , bossHP :: Int
  , bossMaxHP :: Int
  , bossName :: String
  }

data GameState = GameState
  { playerX :: Double
  , playerY :: Double
  , playerHP :: Int
  , score :: Int
  , bullets :: [Bullet]
  , currentBoss :: Maybe Boss
  , remainingCommits :: [Commit]
  , frameCount :: Int
  }

-- Screen Dimensions
screenWidth, screenHeight :: Int
screenWidth = 60
screenHeight = 25

-- Parsing Mock Git Log into Dynamic Game Events
parseCommit :: String -> Commit
parseCommit msg
  | "fix" `isPrefixOf` msg || "bug" `isPrefixOf` msg = Commit "a1b2c3d" msg BugFixCommit
  | "merge" `isPrefixOf` msg || "conflict" `isPrefixOf` msg = Commit "f9e8d7c" msg MergeConflictCommit
  | otherwise = Commit "0000000" msg NormalCommit

mockGitLog :: [Commit]
mockGitLog = map parseCommit
  [ "initial commit"
  , "add core feature architecture"
  , "fix null pointer exception in parser"
  , "refactor rendering pipeline"
  , "merge branch feature/async-io with conflicts"
  , "fix memory leak in event loop"
  , "update documentation"
  , "merge main into release"
  ]

-- Terminal Utilities
clearScreen :: IO ()
clearScreen = putStr "\ESC[2J\ESC[1;1H"

hideCursor :: IO ()
hideCursor = putStr "\ESC[?25l"

showCursor :: IO ()
showCursor = putStr "\ESC[?25h"

-- Initialization
initGame :: [Commit] -> GameState
initGame commits = GameState
  { playerX = fromIntegral screenWidth / 2
  , playerY = fromIntegral screenHeight - 3
  , playerHP = 100
  , score = 0
  , bullets = []
  , currentBoss = Nothing
  , remainingCommits = commits
  , frameCount = 0
  }

-- Spawning Mechanics derived from Git History
processGitQueue :: GameState -> IO GameState
processGitQueue gs = case (currentBoss gs, remainingCommits gs) of
  (Nothing, c:cs) -> triggerCommitEvent c (gs { remainingCommits = cs })
  _ -> return gs

triggerCommitEvent :: Commit -> GameState -> IO GameState
triggerCommitEvent commit gs = case commitType commit of
  BugFixCommit -> do
    let newBoss = Boss
          { bossX = fromIntegral screenWidth / 2
          , bossY = 4
          , bossHP = 50
          , bossMaxHP = 50
          , bossName = "BUG FIX: " ++ commitMsg commit
          }
    return gs { currentBoss = Just newBoss }
  
  MergeConflictCommit -> do
    -- Trigger screen-clearing wave of technical debt bullets
    debtBullets <- replicateM 40 $ do
      rx <- randomRIO (1, fromIntegral screenWidth - 2)
      rvx <- randomRIO (-0.5, 0.5)
      rvy <- randomRIO (0.5, 1.2)
      return $ Bullet rx 1 rvx rvy '!'
    return gs { bullets = bullets gs ++ debtBullets, score = score gs + 50 }

  NormalCommit -> do
    -- Spawn minor debt bullets
    nb <- replicateM 5 $ do
      rx <- randomRIO (2, fromIntegral screenWidth - 3)
      return $ Bullet rx 1 0 0.8 '*'
    return gs { bullets = bullets gs ++ nb, score = score gs + 10 }

-- Update Game Engine
updateGame :: GameState -> GameState
updateGame gs = 
  let 
    -- Move player bullets / Enemy bullets
    movedBullets = [ b { bX = bX b + bVX b, bY = bY b + bVY b } 
                   | b <- bullets gs
                   , bY b > 0 && bY b < fromIntegral screenHeight
                   , bX b > 0 && bX b < fromIntegral screenWidth 
                   ]

    -- Boss bullet generation
    (bossBullets, updatedBoss) = case currentBoss gs of
      Just b -> 
        let bx = bossX b + sin (fromIntegral (frameCount gs) / 5.0) * 1.5
            b' = b { bossX = max 2 (min (fromIntegral screenWidth - 3) bx) }
            pattern = [ Bullet (bossX b') (bossY b') (cos angle * 0.7) (sin angle * 0.7) 'o'
                      | i <- [0..7]
                      , let angle = (fromIntegral i * pi / 4) + (fromIntegral (frameCount gs) / 10.0)
                      ]
        in (if frameCount gs `mod` 4 == 0 then pattern else [], Just b')
      Nothing -> ([], Nothing)

    -- Bullet collisions with player
    hitPlayer b = abs (bX b - playerX gs) < 1.5 && abs (bY b - playerY gs) < 1.0
    hits = filter hitPlayer movedBullets
    newHP = max 0 (playerHP gs - length hits * 5)
    survivingBullets = filter (not . hitPlayer) movedBullets

  in gs
    { playerHP = newHP
    , bullets = survivingBullets ++ bossBullets
    , currentBoss = updatedBoss
    , frameCount = frameCount gs + 1
    }

-- Rendering Screen
render :: GameState -> IO ()
render gs = do
  clearScreen
  let pX = round (playerX gs) :: Int
      pY = round (playerY gs) :: Int
      
      -- Render Frame Matrix
      buffer = [ [ getCharAt x y | x <- [0..screenWidth-1] ] | y <- [0..screenHeight-1] ]
      
      getCharAt x y
        | x == 0 || x == screenWidth - 1 || y == 0 || y == screenHeight - 1 = '#'
        | x == pX && y == pY = 'A' -- Player ship
        | Just b <- currentBoss gs, round (bossX b) == x && round (bossY b) == y = 'W' -- Boss
        | any (\b -> round (bX b) == x && round (bY b) == y) (bullets gs) = 
            case filter (\b -> round (bX b) == x && round (bY b) == y) (bullets gs) of
              (b:_) -> bChar b
              [] -> '.'
        | otherwise = ' '

  putStrLn $ unlines buffer
  putStrLn $ " [GIT BULLET-HELL] | HP: " ++ show (playerHP gs) ++ "% | Score: " ++ show (score gs)
  case currentBoss gs of
    Just b -> putStrLn $ " BOSS: " ++ bossName b ++ " [" ++ show (bossHP b) ++ "/" ++ show (bossMaxHP b) ++ "]"
    Nothing -> putStrLn " Status: Compiling Commit History..."

-- Main Game Loop
gameLoop :: GameState -> IO ()
gameLoop gs = do
  render gs
  when (playerHP gs <= 0) $ do
    putStrLn "\n [BUILD FAILED] Technical Debt Overwhelmed the Repository!"
    showCursor
    exitSuccess

  threadDelay 50000 -- ~20 FPS frame rate
  gs' <- processGitQueue gs
  let nextState = updateGame gs'
  gameLoop nextState

main :: IO ()
main = do
  hSetBuffering stdin NoBuffering
  hSetBuffering stdout (BlockBuffering Nothing)
  hideCursor
  putStrLn "Compiling repository commits into dynamic battle..."
  threadDelay 1000000
  gameLoop (initGame mockGitLog)
  showCursor