-- LiveTickerKaleido.lua
-- LOVE2D script that simulates a stock ticker, maps price changes to micro‑tonal notes,
-- and draws a self‑modifying kaleidoscopic pattern driven by the data.

function love.load()
    love.window.setTitle("Ticker Kaleidoscope")
    love.window.setMode(800, 600, {resizable=false})
    math.randomseed(os.time())

    -- Simulation parameters
    price = 100.0                -- starting price
    lastPrice = price
    volatility = 0.0
    tickInterval = 0.2           -- seconds between ticks
    tickTimer = 0

    -- Micro‑tonal scale (13‑EDO within an octave)
    scale = {}
    for i=0,12 do
        scale[i+1] = 440 * 2^((i/13))  -- A4 = 440 Hz as base
    end

    -- Audio buffer for generated notes
    notes = {}
    noteDuration = 0.4           -- seconds
    sampleRate = 44100

    -- Kaleidoscope parameters
    polys = {}
    polyCount = 6                -- number of polygons per frame
    maxVertices = 8
    time = 0
end

-- Generate a PCM sound for a given frequency
local function generateTone(freq)
    local length = math.floor(noteDuration * sampleRate)
    local data = love.sound.newSoundData(length, sampleRate, 16, 1)
    for i=0,length-1 do
        local t = i / sampleRate
        local amp = math.exp(-3*t)               -- simple envelope
        local sample = amp * math.sin(2*math.pi*freq*t)
        data:setSample(i, sample)
    end
    local source = love.audio.newSource(data)
    source:setVolume(0.3)
    return source
end

-- Create a new polygon driven by current financial metrics
local function createPolygon()
    local verts = {}
    local vCount = math.random(3, maxVertices)
    local radius = 30 + volatility*200
    for i=1,vCount do
        local angle = (i-1)/vCount * 2*math.pi
        local r = radius * (0.5 + math.random())
        table.insert(verts, r*math.cos(angle))
        table.insert(verts, r*math.sin(angle))
    end
    local hue = (price/200) % 1
    return {
        verts = verts,
        hue = hue,
        rot = math.random()*2*math.pi,
        rotSpeed = (math.random()*2-1)*0.5,
        scale = 0.5 + volatility,
        pos = {x = love.graphics.getWidth()/2, y = love.graphics.getHeight()/2},
        age = 0
    }
end

function love.update(dt)
    time = time + dt
    tickTimer = tickTimer + dt
    if tickTimer >= tickInterval then
        tickTimer = tickTimer - tickInterval
        -- Simulate price change
        lastPrice = price
        price = price + (math.random()*2-1) * 0.5   -- small random walk
        volatility = math.abs(price - lastPrice) / price
        -- Map change magnitude to scale degree
        local delta = price - lastPrice
        local idx = 1 + math.floor(((delta+0.5)/1)*12)  -- map -0.5..+0.5 to 1..13
        idx = math.max(1, math.min(#scale, idx))
        local freq = scale[idx]
        -- Play note
        local src = generateTone(freq)
        src:play()
        table.insert(notes, src)

        -- Add a new polygon
        table.insert(polys, createPolygon())
        if #polys > 30 then table.remove(polys,1) end
    end

    -- Update polygons
    for i=#polys,1,-1 do
        local p = polys[i]
        p.age = p.age + dt
        p.rot = p.rot + p.rotSpeed * dt
        p.scale = p.scale * (1 - dt*0.1)
        if p.age > 5 then table.remove(polys,i) end
    end

    -- Clean finished audio sources
    for i=#notes,1,-1 do
        if not notes[i]:isPlaying() then table.remove(notes,i) end
    end
end

-- Convert hue to RGB
local function hsv(h, s, v)
    local i = math.floor(h*6)
    local f = h*6 - i
    local p = v*(1-s)
    local q = v*(1-f*s)
    local t = v*(1-(1-f)*s)
    i = i % 6
    if i==0 then return v,t,p
    elseif i==1 then return q,v,p
    elseif i==2 then return p,v,t
    elseif i==3 then return p,q,v
    elseif i==4 then return t,p,v
    else return v,p,q end
end

function love.draw()
    love.graphics.setBlendMode("alpha")
    local cx, cy = love.graphics.getWidth()/2, love.graphics.getHeight()/2

    for _,p in ipairs(polys) do
        local r,g,b = hsv(p.hue, 0.8, 1)
        love.graphics.setColor(r,g,b, 0.6)
        love.graphics.push()
        love.graphics.translate(cx, cy)
        love.graphics.rotate(p.rot)
        love.graphics.scale(p.scale, p.scale)
        love.graphics.polygon("fill", p.verts)
        love.graphics.pop()
    end

    -- HUD
    love.graphics.setColor(1,1,1)
    love.graphics.print(string.format("Price: %.2f  Volatility: %.3f", price, volatility), 10, 10)
end