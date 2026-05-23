-- main.lua
-- LÖVE2D script: audio‑reactive L‑system fractal with hidden text cipher
-- Press SPACE to start/stop recording the output video (requires ffmpeg installed)

local audioFile = "audio.wav"          -- put a mono WAV file in the same folder
local source = love.audio.newSource(audioFile, "stream")
local sampleRate = 44100
local fftSize = 1024                     -- power of two for FFT
local bins = fftSize / 2
local colors = {}                        -- color per frequency bin
local lsystem = { axiom = "F", rules = { F = "F[+F]F[-F]F" } }
local angle = math.rad(25)               -- base branching angle
local lineLen = 5                        -- base line length
local maxDepth = 5
local hiddenText = "SECRET"
local envelope = {}                      -- amplitude envelope samples
local cipherBits = {}
local frameCount = 0
local recording = false
local ffmpegCmd = nil

-- Precompute colors for frequency bins (rainbow gradient)
for i = 1, bins do
    local t = (i - 1) / (bins - 1)
    local r = math.max(0, math.min(1, 1 - math.abs(t - 0.5) * 2))
    local g = math.max(0, math.min(1, 1 - math.abs(t - 0.75) * 4))
    local b = math.max(0, math.min(1, 1 - math.abs(t - 0.25) * 4))
    colors[i] = {r * 255, g * 255, b * 255}
end

-- Helper: generate L‑system string up to depth
local function generateLSystem(depth)
    local cur = lsystem.axiom
    for d = 1, depth do
        local next = {}
        for i = 1, #cur do
            local sym = cur:sub(i,i)
            local repl = lsystem.rules[sym] or sym
            table.insert(next, repl)
        end
        cur = table.concat(next)
    end
    return cur
end

-- Helper: map dominant frequency to angle/length modifiers
local function modulateFromSpectrum(spectrum)
    local maxAmp = 0
    local maxIdx = 1
    for i = 1, bins do
        if spectrum[i] > maxAmp then
            maxAmp = spectrum[i]
            maxIdx = i
        end
    end
    -- angle changes within +/-15°
    angle = math.rad(25 + (maxIdx / bins - 0.5) * 30)
    -- line length scales with overall energy
    local energy = 0
    for i = 1, bins do energy = energy + spectrum[i] end
    lineLen = 5 + energy * 200
end

-- Helper: draw L‑system using current graphics state
local function drawLSystem(str, x, y, dir)
    local stack = {}
    local posX, posY = x, y
    local heading = dir
    for i = 1, #str do
        local sym = str:sub(i,i)
        if sym == "F" then
            local nx = posX + math.cos(heading) * lineLen
            local ny = posY + math.sin(heading) * lineLen
            -- pick color from frequency bin based on current heading
            local bin = math.floor(((heading % (2*math.pi)) / (2*math.pi)) * bins) + 1
            local c = colors[bin]
            love.graphics.setColor(c[1], c[2], c[3])
            love.graphics.line(posX, posY, nx, ny)
            posX, posY = nx, ny
        elseif sym == "+" then
            heading = heading + angle
        elseif sym == "-" then
            heading = heading - angle
        elseif sym == "[" then
            table.insert(stack, {posX, posY, heading})
        elseif sym == "]" then
            local s = table.remove(stack)
            posX, posY, heading = s[1], s[2], s[3]
        end
    end
end

-- Helper: encode amplitude envelope into bits (simple threshold)
local function encodeEnvelope(sample)
    local thresh = 0.05
    local bit = sample > thresh and 1 or 0
    table.insert(cipherBits, bit)
    if #cipherBits >= #hiddenText * 8 then
        -- stop recording bits after enough for the message
        recording = false
    end
end

-- Convert bits to text (reverse cipher)
local function decodeCipher()
    local bytes = {}
    for i = 1, #cipherBits, 8 do
        local b = 0
        for j = 0,7 do
            b = b + (cipherBits[i+j] or 0) * (2 ^ (7-j))
        end
        table.insert(bytes, string.char(b))
    end
    return table.concat(bytes)
end

function love.load()
    love.window.setMode(800, 600)
    source:setLooping(true)
    source:play()
end

function love.update(dt)
    local spectrum = love.audio.getSpectrum(fftSize)
    modulateFromSpectrum(spectrum)

    -- sample amplitude envelope (simple RMS of recent samples)
    local data = source:getData()
    if data then
        local sum = 0
        for i = 1, #data do
            sum = sum + data[i]^2
        end
        local rms = math.sqrt(sum / #data)
        if recording then encodeEnvelope(rms) end
    end

    if recording and frameCount % 3 == 0 then
        -- capture frame for ffmpeg pipe
        local screenshot = love.graphics.newScreenshot()
        local imgData = screenshot:newImageData()
        imgData:encode("png", "frame.png")
        os.execute(string.format('cat frame.png >> %s', ffmpegCmd))
    end
    frameCount = frameCount + 1
end

function love.draw()
    love.graphics.translate(love.graphics.getWidth()/2, love.graphics.getHeight())
    love.graphics.scale(1, -1)          -- Y up
    local depth = math.min(maxDepth, math.floor(lineLen / 5))
    local instr = generateLSystem(depth)
    drawLSystem(instr, 0, 0, -math.pi/2)
    love.graphics.origin()
    love.graphics.setColor(255,255,255)
    love.graphics.print("Press SPACE to toggle recording", 10, 10)
    if recording then
        love.graphics.print("Recording... " .. #cipherBits .. " bits", 10, 30)
    else
        love.graphics.print("Last decoded: " .. decodeCipher(), 10, 30)
    end
end

function love.keypressed(k)
    if k == "space" then
        recording = not recording
        if recording then
            cipherBits = {}
            -- start ffmpeg pipe (requires ffmpeg in PATH)
            local outFile = "output.mp4"
            os.remove(outFile)
            ffmpegCmd = string.format("ffmpeg -y -f image2pipe -vcodec png -i - -i %s -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest %s", audioFile, outFile)
            io.popen(ffmpegCmd, "w") -- start pipe
        else
            -- finalize ffmpeg
            os.execute("pkill -SIGINT ffmpeg") -- simplistic; in real code manage process handle
        end
    end
end