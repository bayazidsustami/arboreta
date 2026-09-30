import Graphics.Gloss
import Graphics.Gloss.Interface.IO.Interact

-- Represents a weeping willow spawned by a deleted character (typo)
data Willow = Willow 
  { willowX :: Float
  , willowY :: Float
  , willowAge :: Float
  , willowBranches :: Int
  } deriving (Show)

-- The global application state
data World = World
  { willows :: [Willow]
  , cursorX :: Float
  , cursorY :: Float
  } deriving (Show)

initialWorld :: World
initialWorld = World [] 0 0

-- Renders the neon landscape and pulsing willows
renderWorld :: World -> Picture
renderWorld (World ws cx cy) = Pictures (cursor : map renderWillow ws)
  where
    cursor = translate cx cy $ color (makeColor 0 1 0.8 1) (circleSolid 4)
    renderWillow (Willow wx wy age _) = 
      translate wx wy $ color (makeColor 1 0.2 (sin (age * 3)) (max 0 (1 - age/5))) 
      $ Pictures [circle (age * 15), line [(0,0), (0, -40)]]

-- Updates the physics, fading out old willows over time
updateWorld :: Float -> World -> World
updateWorld dt (World ws cx cy) = 
  World [w { willowAge = willowAge w + dt } | w <- ws, willowAge w < 5] cx cy

-- Handles keyboard input: backspace spawns a neon willow
handleEvent :: Event -> World -> World
handleEvent (EventKey (Char '\b') Down _ _) (World ws cx cy) = 
  let newWillow = Willow cx cy 0 5
  in World (newWillow : ws) (max (-380) (cx - 10)) cy
handleEvent (EventKey (Char _) Down _ _) (World ws cx cy) =
  World ws (min 380 (cx + 10)) cy
handleEvent _ w = w

main :: IO ()
main = play 
  (InWindow "Neon Weeping Willows" (800, 600) (100, 100))
  black 
  60 
  initialWorld 
  renderWorld 
  handleEvent 
  updateWorld