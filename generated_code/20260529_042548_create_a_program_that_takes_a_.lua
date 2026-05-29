--[[ 
Lua script (requires LÖVE2D, OpenCV and a simple audio synthesis library).
It captures webcam frames, extracts dominant colors, maps them to notes,
generates audio, reads a PPG sensor (via serial), and draws a kaleidoscopic
SVG that reacts to the audio spectrum.
--]]

local cv = require "opencv"
local serial = require "serial"          -- simple serial lib for PPG sensor
local synth = require "synth"            -- tiny wavetable synth (placeholder)

local cam = cv.VideoCapture(0)           -- open default webcam
local width, height = 640, 480
cam:set(cv.CAP_PROP_FRAME_WIDTH, width)
cam:set(cv.CAP_PROP_FRAME_HEIGHT, height)

local ser = serial.open("/dev/ttyUSB0", 115200)   -- adjust path to your sensor
local lastPulse = 0
local pulseTimer = 0

-- custom harmonic scale (C major pentatonic)
local scale = {0, 2, 4, 7, 9}   -- semitone offsets from root
local rootFreq = 261.63        -- middle C

-- simple function to map hue (0-360) to a note in the scale
local function hueToFreq(hue)
    local degree = math.floor((hue / 360) * #scale) % #scale + 1
    local semitone = scale[degree]
    return rootFreq * (2 ^ (semitone / 12))
end

-- extract dominant color using k‑means (k=3)
local function dominantColors(img)
    local samples = img:reshape(img:total(), 3):convert(cv.CV_32F)
    local criteria = cv.TermCriteria(cv.TermCriteria_EPS + cv.TermCriteria_MAX_ITER, 10, 1.0)
    local flags = cv.KMEANS_PP_CENTERS
    local compactness, labels, centers = cv.kmeans(samples, 3, nil, criteria, 1, flags)
    return centers -- Nx3 matrix of BGR colors
end

-- convert BGR to HSV hue
local function bgr2hue(bgr)
    local b, g, r = bgr[1], bgr[2], bgr[3]
    local img = cv.Mat({1,1,3}, cv.CV_8U, {b,g,r})
    local hsv = cv.cvtColor(img, cv.COLOR_BGR2HSV)
    return hsv:data()[1] * 2 -- OpenCV hue 0-179 -> 0-360
end

-- create SVG path for a fragment
local function fragmentPath(cx, cy, r, rot, sides)
    local angle = 2*math.pi / sides
    local pts = {}
    for i=0,sides-1 do
        local a = i*angle + rot
        table.insert(pts, string.format("%.2f,%.2f", cx+r*math.cos(a), cy+r*math.sin(a)))
    end
    return "<polygon points='"..table.concat(pts," ").."'/>"
end

-- initialise SVG buffer
local svgHeader = [[<?xml version="1.0" encoding="UTF-8"?><svg xmlns="http://www.w3.org/2000/svg" width="800" height="800">]]
local svgFooter = "</svg>"
local svgContent = {}

-- love2d callbacks
function love.load()
    love.window.setMode(800,800)
    love.graphics.setBackgroundColor(0,0,0)
end

function love.update(dt)
    -- read webcam frame
    local ret, frame = cam:read()
    if not ret then return end

    -- get dominant hues and trigger notes
    local centers = dominantColors(frame)
    for i=1,centers:size(1) do
        local hue = bgr2hue({centers:data()[ (i-1)*3 + 1 ], centers:data()[ (i-1)*3 + 2 ], centers:data()[ (i-1)*3 + 3 ]})
        local freq = hueToFreq(hue)
        synth.playNote(freq, 0.1)   -- short note
    end

    -- read pulse (simple peak detection)
    local line = ser:readline()
    if line then
        local val = tonumber(line)
        if val and val > lastPulse + 30 then   -- naive threshold
            pulseTimer = 0
            lastPulse = val
        end
    end
    pulseTimer = pulseTimer + dt
    local pulsePhase = math.min(pulseTimer, 0.5) / 0.5

    -- audio spectrum (placeholder sine wave analysis)
    local spectrum = synth.getSpectrum()    -- returns table {amplitude, frequency}
    local maxAmp = 0
    for _,bin in ipairs(spectrum) do
        if bin.amplitude > maxAmp then maxAmp = bin.amplitude end
    end

    -- build kaleidoscopic fragments driven by audio and pulse
    svgContent = {}
    local cx, cy = 400, 400
    local radius = 200 * (0.5 + pulsePhase)   -- pulse expands/shrinks
    local sides = 6 + math.floor(maxAmp*10)  -- more sides with louder audio
    local rot = love.timer.getTime()*2        -- continuous rotation

    table.insert(svgContent, fragmentPath(cx, cy, radius, rot, sides))
    -- mirror fragments
    for i=1,5 do
        local angle = i*math.pi/3
        table.insert(svgContent, fragmentPath(
            cx+math.cos(angle)*30, cy+math.sin(angle)*30,
            radius*0.6, rot+angle, sides))
    end
end

function love.draw()
    -- render the generated SVG as Love2D primitives
    love.graphics.translate(400,400)
    love.graphics.rotate(0)
    love.graphics.translate(-400,-400)

    love.graphics.setColor(1,1,1,0.7)
    for _,frag in ipairs(svgContent) do
        -- parse simple polygon points
        local pts = frag:match("points='([^']+)'")
        local points = {}
        for x,y in pts:gmatch("([%d%.%-]+),([%d%.%-]+)") do
            table.insert(points, tonumber(x))
            table.insert(points, tonumber(y))
        end
        love.graphics.polygon("fill", points)
    end
end

function love.quit()
    cam:release()
    ser:close()
end