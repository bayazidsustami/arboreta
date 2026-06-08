love = require("love")

-- Configuration
local PALETTE_SIZE = 5          -- number of dominant colors
local NOTE_SCALE = {"C4","D4","E4","G4","A4"} -- custom harmonic lattice
local SAMPLE_RATE = 44100
local BUFFER_SIZE = 1024

-- Global state
local video          -- webcam video source
local canvas         -- drawing canvas for mandala
local audioData      -- raw audio buffer
local audioSource    -- streaming audio source
local frameCount = 0

-- Utility: simple k-means for dominant colors (very lightweight)
local function getDominantColors(imageData, k)
    local w, h = imageData:getDimensions()
    local samples = {}
    for i = 1, 5000 do
        local x = math.random(0, w - 1)
        local y = math.random(0, h - 1)
        local r, g, b, a = imageData:getPixel(x, y)
        if a > 0 then
            table.insert(samples, {r, g, b})
        end
    end

    -- initialise centroids randomly
    local centroids = {}
    for i = 1, k do
        centroids[i] = samples[math.random(#samples)]
    end

    for iter = 1, 5 do
        local clusters = {}
        for i = 1, k do clusters[i] = {} end

        -- assign samples
        for _, s in ipairs(samples) do
            local best, bestDist = 1, 1e9
            for i, c in ipairs(centroids) do
                local d = (s[1]-c[1])^2+(s[2]-c[2])^2+(s[3]-c[3])^2
                if d < bestDist then best, bestDist = i, d end
            end
            table.insert(clusters[best], s)
        end

        -- recompute centroids
        for i, cluster in ipairs(clusters) do
            if #cluster > 0 then
                local sum = {0,0,0}
                for _, s in ipairs(cluster) do
                    sum[1]=sum[1]+s[1]; sum[2]=sum[2]+s[2]; sum[3]=sum[3]+s[3]
                end
                centroids[i] = {sum[1]/#cluster, sum[2]/#cluster, sum[3]/#cluster}
            end
        end
    end

    return centroids
end

-- Map a color to a note index
local function colorToNoteIdx(color)
    local intensity = (color[1]+color[2]+color[3])/3
    return math.floor(intensity * (#NOTE_SCALE-1) / 255) + 1
end

-- Generate a short sine wave for a given frequency
local function generateSine(freq, length)
    local samples = math.floor(SAMPLE_RATE * length)
    local data = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
    for i = 0, samples-1 do
        local t = i / SAMPLE_RATE
        local amp = math.sin(2*math.pi*freq*t)
        data:setSample(i, amp)
    end
    return data
end

-- Create streaming audio source
local function initAudio()
    audioData = love.sound.newSoundData(BUFFER_SIZE, SAMPLE_RATE, 16, 1)
    audioSource = love.audio.newSource(audioData, "stream")
    audioSource:setVolume(0.5)
    audioSource:play()
end

-- Update audio buffer with notes derived from colors
local function feedAudio(colors)
    for i = 0, BUFFER_SIZE-1 do
        local noteIdx = colorToNoteIdx(colors[(i % #colors)+1])
        local freq = 440 * 2^((noteIdx-1)/12) -- simple equal‑tempered mapping
        local t = i / SAMPLE_RATE
        local sample = math.sin(2*math.pi*freq*t) * 0.3
        audioData:setSample(i, sample)
    end
    audioSource:queue(audioData)
end

-- Draw a mandala segment based on spectral energy (mocked with random)
local function drawMandalaSegment(cx, cy, radius, angle, color, opacity)
    local points = {}
    local segments = 8
    for i = 0, segments do
        local a = angle + (i/segments)*2*math.pi
        local r = radius * (0.7 + 0.3*math.random())
        table.insert(points, cx + r*math.cos(a))
        table.insert(points, cy + r*math.sin(a))
    end
    love.graphics.setColor(color[1]/255, color[2]/255, color[3]/255, opacity)
    love.graphics.polygon("fill", points)
end

function love.load()
    love.window.setMode(800,600,{resizable=false})
    canvas = love.graphics.newCanvas(800,600)
    video = love.video.newVideoCapture()
    initAudio()
end

function love.update(dt)
    frameCount = frameCount + 1
    if video:isPlaying() then
        local frame = video:getFrame()
        if frame then
            local imgData = frame:newImageData()
            local palette = getDominantColors(imgData, PALETTE_SIZE)
            feedAudio(palette)

            -- render mandala
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0,0,0,0)

            local cx, cy = 400,300
            local baseRadius = 50 + 30*math.sin(frameCount*0.05)
            for i, col in ipairs(palette) do
                local angle = i * (2*math.pi / #palette) + frameCount*0.01
                local opacity = 0.5 + 0.5*math.sin(frameCount*0.03 + i)
                drawMandalaSegment(cx, cy, baseRadius+i*20, angle, col, opacity)
            end

            love.graphics.setCanvas()
        end
    end
end

function love.draw()
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(canvas)
    if video:isPlaying() then
        love.graphics.setColor(1,1,1,0.3)
        love.graphics.draw(video, 10, 10, 0, 0.2, 0.2)
    end
end

function love.keypressed(k)
    if k == "escape" then love.event.quit() end
    if k == "space" then
        if video:isPlaying() then video:pause() else video:play() end
    end
end