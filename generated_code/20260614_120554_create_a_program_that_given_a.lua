--[[ 
Lua script (Love2D) that:
1. Loads a PDF file (via external tool 'pdftotext' and 'pdf2svg' assumed installed).
2. Extracts plain text, creates a simple musical motif per character.
3. Generates a SVG outline for each character (mocked as simple rectangles).
4. Animates the outlines morphing into the characters while playing tones.
5. All assets are generated on the fly, no external assets required.
--]]

local pdfPath = "sample.pdf"          -- change to your PDF file
local tmpText = "tmp_text.txt"
local tmpSvg  = "tmp_glyph.svg"

local font = nil
local glyphs = {}        -- {char=..., x=..., y=..., shape=...}
local music = {}         -- {char=..., sound=Source}
local timer = 0
local animationDuration = 3    -- seconds per glyph

-- Utility: run shell command and capture output
local function exec(cmd)
    local f = io.popen(cmd)
    local res = f:read("*a")
    f:close()
    return res
end

-- 1. Extract text from PDF
local function extractText()
    exec(string.format('pdftotext -layout "%s" "%s"', pdfPath, tmpText))
    local f = io.open(tmpText, "r")
    local txt = f:read("*a")
    f:close()
    return txt:gsub("\r\n", "\n")
end

-- 2. Create a very simple SVG outline for each glyph (placeholder)
local function createSvgOutline(char)
    -- Real implementation would call a vectorizer; we use a rectangle.
    local size = 64
    local svg = string.format(
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">'..
        '<rect width="%d" height="%d" fill="none" stroke="black" stroke-width="2"/></svg>',
        size, size, size, size)
    local f = io.open(tmpSvg, "w")
    f:write(svg)
    f:close()
    return love.graphics.newImage(tmpSvg)   -- Love can load SVG via Image if supported
end

-- 3. Map each character to a tone (C major scale)
local baseFreq = 261.63  -- C4
local scale = {0,2,4,5,7,9,11,12} -- semitone offsets
local function charToFreq(c)
    local code = string.byte(c)
    local idx = ((code - 32) % #scale) + 1
    local semitone = scale[idx]
    return baseFreq * (2 ^ (semitone/12))
end

-- 4. Generate SoundData for a sine wave tone
local function makeTone(freq, dur)
    dur = dur or 0.5
    local sampleRate = 44100
    local samples = math.floor(sampleRate * dur)
    local sound = love.sound.newSoundData(samples, sampleRate, 16, 1)
    for i=0,samples-1 do
        local t = i / sampleRate
        local amp = math.sin(2*math.pi*freq*t) * (1 - t/dur)  -- fade out
        sound:setSample(i, amp)
    end
    return love.audio.newSource(sound)
end

function love.load()
    love.window.setTitle("PDF Glyph → Music Visualizer")
    love.graphics.setBackgroundColor(0.1,0.1,0.1)
    font = love.graphics.newFont(48)

    local txt = extractText()
    local x, y = 50, 100
    local spacing = 60

    for c in txt:gmatch(".") do
        if c == "\n" then
            y = y + spacing
            x = 50
        else
            local img = createSvgOutline(c)   -- placeholder rectangle
            local src = makeTone(charToFreq(c))
            table.insert(glyphs, {char=c, x=x, y=y, img=img, progress=0})
            table.insert(music, {char=c, src=src, played=false})
            x = x + spacing
        end
    end
end

function love.update(dt)
    timer = timer + dt
    -- start playing sounds as glyphs appear
    for i,g in ipairs(glyphs) do
        local m = music[i]
        if not m.played and timer > (i-1)*0.3 then
            m.src:play()
            m.played = true
        end
        -- animate progress 0..1 over animationDuration
        g.progress = math.min(1, (timer - (i-1)*0.3)/animationDuration)
    end
end

function love.draw()
    love.graphics.setColor(1,1,1)
    for i,g in ipairs(glyphs) do
        local p = g.progress
        -- draw morphing rectangle to character
        local sx = 1 - p
        local sy = 1 - p
        love.graphics.draw(g.img, g.x, g.y, 0, sx, sy, g.img:getWidth()/2, g.img:getHeight()/2)
        if p > 0.5 then
            love.graphics.setFont(font)
            love.graphics.print(g.char, g.x - 20, g.y - 30, 0, p, p)
        end
    end
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
end