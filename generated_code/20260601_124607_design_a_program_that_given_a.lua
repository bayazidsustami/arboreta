-- Simple real‑time ASCII‑poetry generator from webcam
-- Requires LuaJIT and OpenCV (Lua bindings, e.g. luajit-opencv)

local cv   = require "cv"
require "cv.highgui"
require "cv.imgproc"
require "cv.videoio"

-- tiny Markov model built from a few sonnet lines
local markov = {
  [""] = {"Shall", "When", "O", "And"},
  ["Shall"] = {"I", "we"},
  ["I"] = {"compare", "see"},
  ["compare"] = {"the"},
  ["the"] = {"bright", "soft"},
  ["bright"] = {"sky", "light"},
  ["sky"] = {"to"},
  ["to"] = {"a"},
  ["a"] = {"lovely", "gentle"},
  ["lovely"] = {"dream"},
  ["dream"] = {""},
  ["And"] = {"soft", "deep"},
  ["soft"] = {"whispers", "silence"},
  ["whispers"] = {"of"},
  ["of"] = {"time"},
  ["time"] = {""},
  ["When"] = {"the"},
  ["O"] = {"night"},
  ["night"] = {"falls"},
  ["falls"] = {""}
}

local function next_word(prev)
  local choices = markov[prev] or {}
  if #choices == 0 then return "" end
  return choices[math.random(#choices)]
end

local function generate_line()
  local line = {}
  local word = next_word("")
  while word ~= "" do
    table.insert(line, word)
    word = next_word(word)
  end
  return table.concat(line, " ")
end

-- map a hue value (0‑179) to an ASCII punctuation
local punct = {"", ",", ";", ":", "-", "~", "!"}

local function hue_to_punct(h)
  return punct[1 + math.floor(h / 30) % #punct]
end

-- open default webcam
local cam = cv.VideoCapture{0}
assert(cam:isOpened(), "Cannot open webcam")

cv.namedWindow{"Poetry", cv.WINDOW_AUTOSIZE}

while true do
  local ok, frame = cam:read{}
  if not ok or not frame then break end

  -- resize for speed
  local small = cv.resize{frame, {64,48}}

  -- convert to HSV and compute dominant hue
  local hsv = cv.cvtColor{small, nil, cv.COLOR_BGR2HSV}
  local hue = cv.split{hsv}[1]               -- hue channel
  local hist = cv.calcHist{hue, {1}, nil, {180}, {0,180}}
  local _, maxVal, _, maxLoc = cv.minMaxLoc{hist}
  local dominantHue = maxLoc.y                 -- 0‑179

  -- motion detection (frame differencing)
  if not prevGray then
    prevGray = cv.cvtColor{small, nil, cv.COLOR_BGR2GRAY}
  end
  local gray = cv.cvtColor{small, nil, cv.COLOR_BGR2GRAY}
  local diff = cv.absdiff{gray, prevGray}
  prevGray = gray
  local motionScore = cv.mean{diff}[1] / 255   -- 0‑1

  -- build a line: length from motion, punctuation from hue
  local base = generate_line()
  local length = math.floor(10 + motionScore * 40)  -- 10‑50 chars
  local line = base:sub(1, length)
  line = line .. hue_to_punct(dominantHue)

  -- display as ASCII art (invert colours for visual contrast)
  local ascii = {}
  for i=1,#line do
    local c = line:sub(i,i)
    ascii[i] = c
  end
  local txt = table.concat(ascii, "")

  -- show in OpenCV window
  local img = cv.putText{
    cv.Mat{rows=200, cols=800, type=cv.CV_8UC3, scalar={0,0,0}},
    txt,
    {10,100},
    cv.FONT_HERSHEY_SIMPLEX,
    1.2,
    {255,255,255},
    2,
    cv.LINE_AA
  }
  cv.imshow{"Poetry", img}
  if cv.waitKey{30} >= 0 then break end
end

cam:release()
cv.destroyAllWindows()