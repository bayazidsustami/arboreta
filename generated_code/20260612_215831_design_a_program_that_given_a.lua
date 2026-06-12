-- mandala_music.lua
-- LÖVE2D script: extracts dominant colors from video frames,
-- maps them to chords, plays them, and draws a kaleidoscopic mandala.

local video               -- video source (replace with webcam stream if available)
local palette = {}        -- current dominant colors
local chord = {}          -- current chord frequencies
local synthSources = {}   -- audio sources for chord notes
local time = 0
local mandala = {}        -- geometry of mandala particles
local particleCount = 200
local k = 5                -- number of colors / notes per chord

-- Simple color quantization (reduce to k dominant colors)
local function extractPalette(imageData)
    local hist = {}
    local w, h = imageData:getDimensions()
    for i = 0, w * h - 1 do
        local r, g, b, a = imageData:getPixel(i % w, math.floor(i / w))
        if a > 0 then
            local key = string.format("%d_%d_%d", math.floor(r*255), math.floor(g*255), math.floor(b*255))
            hist[key] = (hist[key] or 0) + 1
        end
    end
    -- pick top-k entries
    local sorted = {}
    for kcol, cnt in pairs(hist) do sorted[#sorted+1] = {kcol, cnt} end
    table.sort(sorted, function(a,b) return a[2] > b[2] end)
    local result = {}
    for i = 1, math.min(k, #sorted) do
        local r,g,b = sorted[i][1]:match("(%d+)_(%d+)_(%d+)")
        result[i] = {r/255, g/255, b/255}
    end
    return result
end

-- Map a color to a MIDI note (0‑127) then to frequency
local function colorToFreq(col)
    local hue = math.atan2(math.sqrt(3)*(col[2]-col[3]), 2*col[1]-col[2]-col[3]) / (2*math.pi)
    if hue < 0 then hue = hue + 1 end
    local midi = 48 + math.floor(hue * 24)   -- map to a two‑octave range starting at C2
    return 440 * (2 ^ ((midi-69)/12))
end

-- Build a chord (triad) from palette frequencies
local function buildChord(pal)
    local freqs = {}
    for i, col in ipairs(pal) do
        freqs[i] = colorToFreq(col)
    end
    return freqs
end

-- Generate a simple sine wave source for a given frequency
local function createSineSource(freq)
    local sampleRate = 44100
    local length = 0.5         -- seconds
    local samples = sampleRate * length
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)
    for i = 0, samples-1 do
        local t = i / sampleRate
        local amplitude = 0.2
        local s = amplitude * math.sin(2*math.pi*freq*t)
        soundData:setSample(i, s)
    end
    return love.audio.newSource(soundData)
end

-- Initialize mandala particles
local function initMandala()
    mandala = {}
    for i = 1, particleCount do
        local angle = (i/particleCount) * 2*math.pi
        mandala[i] = {
            r = 0,
            angle = angle,
            speed = 30 + math.random()*20,
            hue = i / particleCount,
        }
    end
end

function love.load()
    love.window.setTitle("Live Color‑Music Mandala")
    love.window.setMode(800, 600, {resizable=true, highdpi=true})
    video = love.graphics.newVideo("sample.mp4")   -- replace with webcam stream if possible
    video:setLooping(true)
    video:play()
    initMandala()
    love.graphics.setBackgroundColor(0,0,0)
end

function love.update(dt)
    time = time + dt
    video:update()
    local frame = video:getFrames()
    if frame then
        local imageData = frame:getData()
        palette = extractPalette(imageData)
        chord = buildChord(palette)
        -- recreate audio sources
        for _, src in ipairs(synthSources) do src:stop() end
        synthSources = {}
        for _, freq in ipairs(chord) do
            local src = createSineSource(freq)
            src:setVolume(0.4)
            src:play()
            table.insert(synthSources, src)
        end
    end

    -- update mandala particles
    local cx, cy = love.graphics.getWidth()/2, love.graphics.getHeight()/2
    for _, p in ipairs(mandala) do
        p.r = p.r + p.speed * dt
    end
end

function love.draw()
    local cx, cy = love.graphics.getWidth()/2, love.graphics.getHeight()/2
    local maxR = math.min(cx, cy) * 0.9

    -- draw mandala layers
    for i = 1, #mandala do
        local p = mandala[i]
        local radius = (p.r % 1) * maxR
        local x = cx + radius * math.cos(p.angle + time)
        local y = cy + radius * math.sin(p.angle + time)
        local col = palette[(i-1) % #palette + 1] or {1,1,1}
        love.graphics.setColor(col[1], col[2], col[3], 0.6)
        love.graphics.circle("fill", x, y, 8)
    end

    -- overlay current palette squares
    for i, col in ipairs(palette) do
        love.graphics.setColor(col[1], col[2], col[3])
        love.graphics.rectangle("fill", 10 + (i-1)*30, love.graphics.getHeight()-40, 20, 20)
    end
end

function love.quit()
    for _, src in ipairs(synthSources) do src:stop() end
end