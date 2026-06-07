-- fractal_music_vis.lua
-- Love2D script that loads a MIDI or WAV file, extracts a simple melodic contour,
-- and drives a real‑time fractal terrain.  Perfect fifths trigger hidden symbols.
-- The resulting animation can be saved as a GIF using love.filesystem.

local music            = nil          -- audio source
local notes            = {}           -- extracted notes {pitch, time, dur}
local playbackStart    = 0
local terrainScale     = 200          -- vertical scale for height
local erosionSpeed    = 0.5           -- base erosion rate
local symbols          = {}           -- Easter‑egg symbols to draw
local captureFrames    = false        -- toggle recording
local frames           = {}           -- captured frames

-- --------------------------------------------------------------------
-- Simple mock note extraction (replace with real MIDI parsing if desired)
-- --------------------------------------------------------------------
local function mockExtractNotes()
    -- Generate a rising C major scale as demo data
    local basePitch = 60  -- MIDI note number for middle C
    for i = 0, 15 do
        local pitch = basePitch + i % 7
        local time  = i * 0.5
        local dur   = 0.4 + 0.1 * (i % 3)
        table.insert(notes, {pitch = pitch, time = time, dur = dur})
    end
end

-- --------------------------------------------------------------------
-- Utility: map MIDI pitch (0‑127) to terrain height and color
-- --------------------------------------------------------------------
local function pitchToHeight(pitch)
    return (pitch - 60) * 2   -- centre C at height 0
end

local function pitchToColor(pitch)
    local hue = (pitch % 12) / 12
    local r, g, b = love.math.colorFromHSV(hue * 360, 0.6, 1)
    return r, g, b
end

-- --------------------------------------------------------------------
-- Detect perfect fifth intervals and schedule symbols
-- --------------------------------------------------------------------
local function detectFifths()
    for i = 2, #notes do
        local interval = math.abs(notes[i].pitch - notes[i-1].pitch)
        if interval == 7 then  -- perfect fifth in semitones
            table.insert(symbols, {
                time = notes[i].time,
                x = math.random(0, love.graphics.getWidth()),
                y = love.graphics.getHeight() / 2,
                alpha = 0
            })
        end
    end
end

-- --------------------------------------------------------------------
-- Fractal terrain generator (simple midpoint displacement)
-- --------------------------------------------------------------------
local function generateFractal(width, points, roughness)
    local heights = {}
    heights[1] = 0
    heights[width] = 0
    local segment = width - 1
    while segment > 1 do
        for i = 1, width - segment, segment do
            local mid = i + segment / 2
            local avg = (heights[i] + heights[i + segment]) / 2
            local disp = (math.random() - 0.5) * roughness * segment
            heights[mid] = avg + disp
        end
        segment = segment / 2
        roughness = roughness * 0.7
    end
    return heights
end

-- --------------------------------------------------------------------
-- Love2D callbacks
-- --------------------------------------------------------------------
function love.load()
    love.window.setMode(800, 600, {resizable = false})
    music = love.audio.newSource("demo.wav", "stream") -- placeholder file
    mockExtractNotes()
    detectFifths()
    terrain = generateFractal(love.graphics.getWidth(), 513, 1.0)
    playbackStart = love.timer.getTime()
    music:play()
end

function love.update(dt)
    local now = love.timer.getTime() - playbackStart
    -- Erode/grow terrain based on currently sounding notes
    for _, n in ipairs(notes) do
        if now >= n.time and now <= n.time + n.dur then
            local idx = math.floor((n.time / notes[#notes].time) * #terrain) + 1
            terrain[idx] = terrain[idx] + (n.dur * erosionSpeed * dt)
        end
    end

    -- Fade in Easter‑egg symbols
    for _, s in ipairs(symbols) do
        if now >= s.time then
            s.alpha = math.min(s.alpha + dt, 1)
        end
    end

    -- Capture frame if recording
    if captureFrames then
        local screenshot = love.graphics.newScreenshot()
        table.insert(frames, screenshot)
    end
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.translate(0, h/2)
    love.graphics.scale(1, -1)  -- y up

    -- Draw terrain
    for i = 2, #terrain do
        local x1 = (i-2) / (#terrain-1) * w
        local x2 = (i-1) / (#terrain-1) * w
        local y1 = terrain[i-1] * terrainScale
        local y2 = terrain[i]   * terrainScale
        local pitch = notes[math.min(i, #notes)].pitch
        love.graphics.setColor(pitchToColor(pitch))
        love.graphics.line(x1, y1, x2, y2)
    end

    -- Draw symbols
    for _, s in ipairs(symbols) do
        love.graphics.setColor(1, 1, 0, s.alpha)
        love.graphics.circle("fill", s.x, -s.y, 15)
    end

    -- UI
    love.graphics.origin()
    love.graphics.setColor(1,1,1)
    love.graphics.print("Press R to toggle recording frames", 10, 10)
    love.graphics.print("Frames captured: "..#frames, 10, 30)
end

function love.keypressed(key)
    if key == "r" then
        captureFrames = not captureFrames
        if not captureFrames and #frames > 0 then
            -- Save as animated GIF (requires love2d's gif encoder library)
            local gif = require("gifEncoder")  -- placeholder, assumes library present
            gif.save("output.gif", frames, 30)
            frames = {}
        end
    end
end