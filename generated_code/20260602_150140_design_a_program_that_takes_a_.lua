--[[ 
   Live‑Webcam → Motion → L‑system → Fractal Tree → Synth Bird (MIDI) → Spectrum → Video Colour
   Closed‑loop stops when source code contains a self‑referential palindrome.
   Requires LÖVE 11.3+ (love2d) and LuaJIT (for simple FFT).
]]--

local ffi = require "ffi"
local bit = require "bit"

-- ==== FFT (simple radix‑2, from public domain) ====
ffi.cdef[[
typedef struct { double re, im; } cplx;
void fft(cplx *buf, int n, int step);
]]
local fft = ffi.load("fft") -- expect compiled fft.so in working dir

-- ==== Simple L‑system ====
local axiom = "F"
local rules = { F = "F[+F]F[-F]F" }
local angle = math.rad(25)

local function generate(lsys, iter)
    local s = lsys
    for i=1,iter do
        s = s:gsub(".", function(ch) return rules[ch] or ch end)
    end
    return s
end

-- ==== Synthetic bird (simple sine burst) ====
local birdSampleRate = 44100
local function birdCall(freq, dur)
    local samples = math.floor(dur * birdSampleRate)
    local data = love.sound.newSoundData(samples, birdSampleRate, 16, 1)
    for i=0,samples-1 do
        local t = i / birdSampleRate
        local env = math.exp(-5*t) -- simple decay
        local val = math.sin(2*math.pi*freq*t) * env
        data:setSample(i, val)
    end
    return love.audio.newSource(data)
end

-- ==== Webcam placeholder (random motion field) ====
local camW, camH = 160,120
local motion = {}
for y=1,camH do motion[y] = {} for x=1,camW do motion[y][x]=0 end end

local function updateMotion()
    for y=1,camH do
        for x=1,camW do
            motion[y][x] = math.random() * 2 - 1 -- fake motion value
        end
    end
end

-- ==== Map motion to L‑system depth ====
local function motionDepth()
    local sum=0
    for y=1,camH do for x=1,camW do sum=sum+math.abs(motion[y][x]) end end
    return math.max(1, math.floor(sum / (camW*camH) * 5))
end

-- ==== Draw fractal tree from L‑system string ====
local function drawTree(str, x, y, len, ang)
    for i=1,#str do
        local ch = str:sub(i,i)
        if ch=="F" then
            local nx = x + len*math.cos(ang)
            local ny = y + len*math.sin(ang)
            love.graphics.line(x,y,nx,ny)
            x, y = nx, ny
        elseif ch=="+" then
            ang = ang + angle
        elseif ch=="-" then
            ang = ang - angle
        elseif ch=="[" then
            love.graphics.push()
            love.graphics.translate(x,y)
            love.graphics.rotate(ang)
            love.graphics.pop()
        end
    end
end

-- ==== Audio analysis (FFT magnitude) ====
local function spectrum(source)
    local data = source:getData()
    local samples = data:getSampleCount()
    local buf = ffi.new("cplx[?]", samples)
    for i=0,samples-1 do
        buf[i].re = data:getSample(i)
        buf[i].im = 0
    end
    fft.fft(buf, samples, 1)
    local mags = {}
    for i=0,samples/2-1 do
        mags[i+1] = math.sqrt(buf[i].re*buf[i].re + buf[i].im*buf[i].im)
    end
    return mags
end

-- ==== Colour feedback from spectrum ====
local function colourFromSpectrum(mags)
    local r = (mags[10] or 0)*255
    local g = (mags[30] or 0)*255
    local b = (mags[60] or 0)*255
    return { r%256/255, g%256/255, b%256/255 }
end

-- ==== Palindrome detection in source history ====
local function isPalindrome(s)
    s = s:gsub("%s+", "")
    return s == s:reverse()
end

local function checkSelfPalindrome()
    local src = love.filesystem.read(love.filesystem.getSourceBaseDirectory().."/main.lua")
    return isPalindrome(src)
end

-- ==== LÖVE callbacks ====
local lsysStr = axiom
local birdSrc = nil
local running = true

function love.load()
    love.window.setMode(800,600)
    love.graphics.setBackgroundColor(0,0,0)
end

function love.update(dt)
    if not running then return end
    updateMotion()
    local depth = motionDepth()
    lsysStr = generate(axiom, depth)

    -- generate a bird call based on average motion intensity
    local avg = 0
    for y=1,camH do for x=1,camW do avg=avg+math.abs(motion[y][x]) end end
    avg = avg/(camW*camH)
    local freq = 400 + avg*800
    birdSrc = birdCall(freq, 0.2)
    birdSrc:play()

    -- stop condition
    if checkSelfPalindrome() then running = false end
end

function love.draw()
    if not running then
        love.graphics.setColor(1,0,0)
        love.graphics.print("Palindrome detected – stopped.", 10,10)
        return
    end

    -- colour feedback
    local mags = spectrum(birdSrc or love.audio.newSource(love.sound.newSoundData(1,44100,16,1)))
    local col = colourFromSpectrum(mags)
    love.graphics.setColor(col)

    love.graphics.push()
    love.graphics.translate(400, 550)
    love.graphics.scale(1,-1)
    drawTree(lsysStr, 0,0,8, -math.pi/2)
    love.graphics.pop()
end

function love.keypressed(k)
    if k=="escape" then love.event.quit() end
end