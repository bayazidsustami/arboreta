function love.load()
    -- settings
    width, height = 800, 600
    love.window.setMode(width, height, {resizable=true})
    -- toroidal grid
    gridSize = 64
    cellSize = 10
    grid = {}
    for y = 1, gridSize do
        grid[y] = {}
        for x = 1, gridSize do
            grid[y][x] = 0
        end
    end
    -- audio stream (placeholder sine wave)
    sampleRate = 44100
    bufferSize = 1024
    stream = love.sound.newQueueableSource(sampleRate, 16, 1, 4096)
    phase = 0
    -- map bands to rules (simple Wolfram 1‑dim automata)
    bandCount = 8
    rules = {}
    for i = 1, bandCount do
        rules[i] = math.random(0, 255)  -- 8‑bit rule number
    end
    camAngleX, camAngleY = 0, 0
    camDist = 500
    mouseDown = false
    love.keyboard.setKeyRepeat(true)
end

-- generate a short buffer and push to the audio queue
local function pushAudio()
    local data = love.sound.newSoundData(bufferSize, sampleRate, 16, 1)
    for i = 0, bufferSize-1 do
        local t = (i + phase) / sampleRate
        -- simple audio: sum of sines, frequencies 220‑880 Hz
        local sample = 0
        for f = 1, bandCount do
            sample = sample + 0.1 * math.sin(2*math.pi*t*(220 + (f-1)*80))
        end
        data:setSample(i, sample)
    end
    phase = (phase + bufferSize) % sampleRate
    stream:queue(data)
    if not stream:isPlaying() then stream:play() end
end

-- extract a fake spectrum (real FFT would be needed for a true implementation)
local function getSpectrum()
    local spectrum = {}
    for i = 1, bandCount do
        -- map current amplitude of each sine to [0,1]
        local t = love.timer.getTime()
        spectrum[i] = 0.5 + 0.5*math.sin(t + i)
    end
    return spectrum
end

-- apply cellular automaton rule for each band
local function stepCA()
    local newGrid = {}
    for y = 1, gridSize do
        newGrid[y] = {}
        for x = 1, gridSize do
            local sum = 0
            for dy = -1,1 do
                for dx = -1,1 do
                    if not (dx==0 and dy==0) then
                        local nx = ((x+dx-1) % gridSize) + 1
                        local ny = ((y+dy-1) % gridSize) + 1
                        sum = sum + grid[ny][nx]
                    end
                end
            end
            -- pick band based on position
            local band = ((x+y) % bandCount) + 1
            local rule = rules[band]
            -- use sum (0‑8) as index into rule bits
            local bit = (rule >> sum) & 1
            newGrid[y][x] = bit
        end
    end
    grid = newGrid
end

function love.update(dt)
    pushAudio()
    stepCA()
    -- subtle influence: modulate playback speed by average grid activity
    local active = 0
    for y = 1, gridSize do
        for x = 1, gridSize do
            active = active + grid[y][x]
        end
    end
    local activity = active / (gridSize*gridSize)
    stream:setPitch(1 + 0.2*(activity-0.5))
    stream:setVolume(0.5 + 0.5*activity)
    -- camera control
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        camAngleX = camAngleX + (mx - width/2)*0.001
        camAngleY = camAngleY + (my - height/2)*0.001
        love.mouse.setPosition(width/2, height/2)
    end
    camDist = camDist + love.keyboard.isDown('up') and -dt*200 or 0
    camDist = camDist + love.keyboard.isDown('down') and dt*200 or 0
    camDist = math.max(200, math.min(1000, camDist))
end

function love.draw()
    love.graphics.setBackgroundColor(0.1,0.1,0.12)
    love.graphics.translate(width/2, height/2)
    love.graphics.scale(1, -1) -- Y up
    love.graphics.rotate(camAngleX)
    love.graphics.rotate(camAngleY)
    love.graphics.translate(0, 0, -camDist)

    for y = 1, gridSize do
        for x = 1, gridSize do
            local v = grid[y][x]
            if v==1 then
                local hue = ((x+y) % bandCount) / bandCount
                local r,g,b = love.math.colorFromHSV(hue*360,0.8,0.9)
                love.graphics.setColor(r,g,b,0.9)
                local px = (x - gridSize/2) * cellSize
                local py = (y - gridSize/2) * cellSize
                love.graphics.push()
                love.graphics.translate(px, py, 0)
                love.graphics.box('fill', -cellSize/2, -cellSize/2, cellSize, cellSize, cellSize/2)
                love.graphics.pop()
            end
        end
    end
end

function love.keypressed(k)
    if k=='escape' then love.event.quit() end
    if k=='space' then
        -- randomize rules
        for i=1,bandCount do rules[i]=math.random(0,255) end
    end
end