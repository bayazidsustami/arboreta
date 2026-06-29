--[[ 
    Love2D script: real‑time webcam color → notes → watercolor brush strokes.
    Requires: Love2D 11.x, LuaJIT, and a webcam binding exposing getWebcamFrame()
    (e.g., via luajit-opencv or a custom C module). The script is self‑contained;
    replace getWebcamFrame() with your actual webcam capture function.
--]]

local paletteSize = 5                -- number of dominant colors to extract
local scale = { "C4", "D4", "E4", "G4", "A4" } -- custom harmonic scale
local noteDur = 0.2                  -- seconds per note
local brushSize = 30
local brushAlpha = 0.2

local lastNoteTime = 0
local notes = {}
local brushStrokes = {}

-- placeholder webcam capture – must return a Love ImageData object
local function getWebcamFrame()
    -- replace this stub with actual webcam capture code
    -- Example using OpenCV+LuaJIT:
    --   local img = webcam:read()
    --   return love.image.newImageData(img.width, img.height, img.data)
    return love.graphics.newImage("placeholder.jpg"):newImageData()
end

-- simple k‑means for dominant colors (very lightweight)
local function extractPalette(imgData, k)
    local w, h = imgData:getWidth(), imgData:getHeight()
    local samples = {}
    for i = 1, 1000 do
        local x = math.random(0, w-1)
        local y = math.random(0, h-1)
        local r, g, b = imgData:getPixel(x, y)
        table.insert(samples, {r,g,b})
    end

    local centroids = {}
    for i = 1, k do
        centroids[i] = samples[math.random(#samples)]
    end

    for iter = 1, 5 do
        local clusters = {}
        for i = 1, k do clusters[i] = {} end

        for _,c in ipairs(samples) do
            local best, bestDist = 1, 1e9
            for i,cent in ipairs(centroids) do
                local d = (c[1]-cent[1])^2+(c[2]-cent[2])^2+(c[3]-cent[3])^2
                if d<bestDist then best,i = i,d end
            end
            table.insert(clusters[best], c)
        end

        for i,cl in ipairs(clusters) do
            if #cl>0 then
                local sum={0,0,0}
                for _,c in ipairs(cl) do
                    sum[1]=sum[1]+c[1]; sum[2]=sum[2]+c[2]; sum[3]=sum[3]+c[3]
                end
                centroids[i] = {sum[1]/#cl, sum[2]/#cl, sum[3]/#cl}
            end
        end
    end

    local palette = {}
    for _,c in ipairs(centroids) do
        table.insert(palette, {r=c[1], g=c[2], b=c[3]})
    end
    return palette
end

-- map a color to a note index (simple nearest‑hue mapping)
local function colorToNoteIdx(color)
    local hue = math.atan2(math.sqrt(3)*(color.g - color.b), 2*color.r - color.g - color.b)
    hue = (hue/(2*math.pi) + 1) % 1        -- 0..1
    return 1 + math.floor(hue * #scale + 0.5) % #scale + 1
end

-- generate a short sine tone for a given note name
local function generateTone(note, duration)
    local freqs = {C4=261.63,D4=293.66,E4=329.63,G4=392.00,A4=440.00}
    local freq = freqs[note] or 440
    local sampleRate = 44100
    local samples = duration * sampleRate
    local data = love.sound.newSoundData(samples, sampleRate, 16, 1)
    for i=0,samples-1 do
        local t = i / sampleRate
        local amp = math.sin(2*math.pi*freq*t)
        data:setSample(i, amp)
    end
    return love.audio.newSource(data)
end

function love.load()
    love.window.setMode(800,600, {highdpi=true})
    brushCanvas = love.graphics.newCanvas(800,600)
    love.graphics.setCanvas(brushCanvas)
    love.graphics.clear()
    love.graphics.setCanvas()
end

function love.update(dt)
    local frame = getWebcamFrame()
    local palette = extractPalette(frame, paletteSize)

    -- create notes from palette
    notes = {}
    for _,col in ipairs(palette) do
        local idx = colorToNoteIdx(col)
        notes[#notes+1] = {note=scale[idx], color=col}
    end

    -- play notes rhythmically
    if love.timer.getTime() - lastNoteTime > noteDur then
        for _,n in ipairs(notes) do
            local src = generateTone(n.note, noteDur)
            src:setVolume(0.4)
            src:play()
        end
        lastNoteTime = love.timer.getTime()
    end

    -- brush stroke generation driven by amplitude (simulated)
    local amplitude = math.random() * 0.5 + 0.5
    for _,n in ipairs(notes) do
        local angle = math.random()*2*math.pi
        local len = amplitude * 100
        local x = math.random(0,800)
        local y = math.random(0,600)
        local dx = math.cos(angle)*len
        local dy = math.sin(angle)*len
        table.insert(brushStrokes, {
            x=x, y=y, dx=dx, dy=dy,
            col=n.color,
            life=1.5
        })
    end

    -- update and fade brush strokes
    for i=#brushStrokes,1,-1 do
        local s = brushStrokes[i]
        s.x = s.x + s.dx * dt
        s.y = s.y + s.dy * dt
        s.life = s.life - dt
        if s.life <= 0 then table.remove(brushStrokes,i) end
    end
end

function love.draw()
    love.graphics.setCanvas(brushCanvas)
    for _,s in ipairs(brushStrokes) do
        local a = s.life / 1.5 * brushAlpha
        love.graphics.setColor(s.col.r, s.col.g, s.col.b, a)
        love.graphics.circle("fill", s.x, s.y, brushSize * (s.life/1.5))
    end
    love.graphics.setCanvas()
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(brushCanvas,0,0)
end