function love.load()
    love.window.setTitle("Generative Mandala Synthesizer")
    love.graphics.setBackgroundColor(0, 0, 0)

    -- parameters
    width, height = love.graphics.getDimensions()
    center = {x = width / 2, y = height / 2}
    petalCount = 12
    radius = math.min(width, height) * 0.35

    -- simple audio synthesis using Love2D's Source with generated PCM
    sampleRate = 44100
    bufferSize = 2048
    phase = 0
    freq = 220
    volume = 0.2
    source = love.audio.newSource(love.sound.newSoundData(bufferSize, sampleRate, 16, 1), "stream")
    source:setVolume(volume)
    source:setLooping(true)
    source:play()

    -- dummy webcam data (replace with actual capture if available)
    webcam = {
        dominantColor = {r = 1, g = 1, b = 1},
        motionVector = {x = 0, y = 0}
    }

    -- gesture state
    gesture = {
        rotate = 0,
        zoom = 1
    }
end

-- generate a sine wave chunk for audio
local function fillAudioChunk(soundData)
    local samples = soundData:getSampleCount()
    local step = (2 * math.pi * freq) / sampleRate
    for i = 0, samples - 1 do
        local s = math.sin(phase + i * step) * volume
        soundData:setSample(i, s)
    end
    phase = (phase + samples * step) % (2 * math.pi)
end

function love.update(dt)
    -- simulate webcam color extraction (random walk)
    local c = webcam.dominantColor
    c.r = math.max(0, math.min(1, c.r + (math.random() - 0.5) * 0.01))
    c.g = math.max(0, math.min(1, c.g + (math.random() - 0.5) * 0.01))
    c.b = math.max(0, math.min(1, c.b + (math.random() - 0.5) * 0.01))

    -- simulate motion vector (random small jitter)
    webcam.motionVector.x = (math.random() - 0.5) * 2
    webcam.motionVector.y = (math.random() - 0.5) * 2

    -- map motion to audio frequency and volume
    freq = 220 + webcam.motionVector.x * 200
    volume = 0.1 + (webcam.motionVector.y + 1) * 0.2
    source:setVolume(volume)

    -- feed audio buffer
    local data = love.sound.newSoundData(bufferSize, sampleRate, 16, 1)
    fillAudioChunk(data)
    source:queue(data)

    -- simple hand‑gesture simulation using mouse
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        gesture.rotate = (mx - width / 2) / width * math.pi * 2
        gesture.zoom = 0.5 + (my / height)
    end
end

function drawPetal(angle, scale, hue)
    local petalLength = radius * 0.6 * scale
    local petalWidth  = radius * 0.2 * scale

    love.graphics.push()
    love.graphics.rotate(angle)
    love.graphics.translate(0, -radius * 0.3)

    local r, g, b = hsvToRgb(hue, 0.8, 1)
    love.graphics.setColor(r, g, b, 0.7)

    love.graphics.beginShape()
    love.graphics.moveTo(0, 0)
    love.graphics.quadricBezierTo(petalWidth, -petalLength / 2, 0, -petalLength)
    love.graphics.quadricBezierTo(-petalWidth, -petalLength / 2, 0, 0)
    love.graphics.fill()
    love.graphics.pop()
end

function love.draw()
    love.graphics.translate(center.x, center.y)
    love.graphics.scale(gesture.zoom)

    for i = 1, petalCount do
        local baseAngle = (i - 1) * (2 * math.pi / petalCount) + gesture.rotate
        local hue = (i / petalCount + webcam.dominantColor.r) % 1
        local scale = 0.8 + webcam.motionVector.y * 0.3
        drawPetal(baseAngle, scale, hue)
    end
end

-- utility: convert HSV to RGB (0‑1 range)
function hsvToRgb(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else return v, p, q end
end

-- polyfill for love.graphics.quadricBezierTo (LÖVE 11+ lacks it)
if not love.graphics.quadricBezierTo then
    function love.graphics.quadricBezierTo(cx, cy, x, y)
        local steps = 20
        local ox, oy = love.graphics.getPoint()
        for i = 1, steps do
            local t = i / steps
            local u = 1 - t
            local bx = u*u*ox + 2*u*t*cx + t*t*x
            local by = u*u*oy + 2*u*t*cy + t*t*y
            love.graphics.line(ox, oy, bx, by)
            ox, oy = bx, by
        end
    end
end