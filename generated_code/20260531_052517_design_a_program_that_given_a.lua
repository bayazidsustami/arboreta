--[[ 
Simple Love2D app that watches a text file, extracts a crude sentiment score,
drives a rotating kaleidoscopic fractal and generates a continuous tone.
Run with: love .
--]]

local filename = "input.txt"
local lastMod = 0
local posWords = {good=true, happy=true, love=true, excellent=true, great=true}
local negWords = {bad=true, sad=true, hate=true, terrible=true, awful=true}

local sentiment = 0        -- current sentiment value [-1,1]
local targetSentiment = 0  -- smoothed target
local smooth = 0.05

local angle = 0
local scale = 1

local palette = {}         -- dynamic color palette

local sampleRate = 44100
local tone = nil
local phase = 0
local freqBase = 220

-- read file and compute sentiment score
local function computeSentiment()
    local info = love.filesystem.getInfo(filename)
    if not info then return 0 end
    if info.modtime == lastMod then return nil end
    lastMod = info.modtime
    local data = love.filesystem.read(filename) or ""
    local pos,neg = 0,0
    for w in data:gmatch("%w+") do
        w = w:lower()
        if posWords[w] then pos = pos + 1
        elseif negWords[w] then neg = neg + 1 end
    end
    if pos+neg==0 then return 0 end
    return (pos-neg)/(pos+neg)  -- range -1..1
end

-- generate a simple palette based on sentiment
local function updatePalette()
    palette = {}
    local hue = (sentiment+1)*0.5   -- 0..1
    for i=1,6 do
        local h = (hue + i*0.1) % 1
        local r,g,b = love.math.colorFromHSV(h*360,0.6,1)
        table.insert(palette,{r,g,b})
    end
end

-- produce a short buffer of a sine wave whose frequency follows sentiment
local function generateTone()
    local len = sampleRate*0.2
    local sound = love.sound.newSoundData(len, sampleRate, 16, 1)
    local freq = freqBase*(1+sentiment)   -- vary 0..2*base
    for i=0,len-1 do
        local t = i / sampleRate
        local s = math.sin(2*math.pi*freq*t)
        sound:setSample(i, s*0.2)
    end
    if tone then tone:stop() end
    tone = love.audio.newSource(sound)
    tone:setLooping(true)
    tone:play()
end

function love.load()
    love.window.setMode(800,600,{resizable=true})
    updatePalette()
    generateTone()
end

function love.update(dt)
    local new = computeSentiment()
    if new then targetSentiment = new end
    sentiment = sentiment + (targetSentiment - sentiment)*smooth

    angle = angle + dt * (0.5 + sentiment)    -- spin speed varies
    scale = 1 + 0.3*sentiment

    updatePalette()
    generateTone()
end

-- draw a simple kaleidoscopic pattern using recursion
local function drawFractal(x,y,s,depth)
    if depth==0 then return end
    love.graphics.push()
    love.graphics.translate(x,y)
    love.graphics.rotate(angle*depth)
    love.graphics.scale(s,s)
    local col = palette[(depth-1)%#palette+1]
    love.graphics.setColor(col)
    love.graphics.rectangle("fill",-50,-50,100,100)
    for i=-1,1,2 do
        drawFractal(60*i,0,s*0.7,depth-1)
    end
    love.graphics.pop()
end

function love.draw()
    local w,h = love.graphics.getDimensions()
    love.graphics.translate(w/2,h/2)
    drawFractal(0,0,scale,4)
    love.graphics.setColor(1,1,1,0.7)
    love.graphics.print(string.format("Sentiment: %.2f",sentiment), -90, -h/2+10)
end

function love.keypressed(k)
    if k=="escape" then love.event.quit() end
end