-- love2d script: webcam → palette → notes → fractal driven by music
function love.load()
    love.window.setTitle("Audiovisual Poem")
    love.window.setMode(800, 600)

    -- try to open webcam (requires love 0.10+ with video capture support)
    local devices = love.camera.getDevices and love.camera.getDevices() or {}
    cam = devices[1] and devices[1]:open() or nil

    -- sound data for generated notes
    sampleRate = 44100
    noteLength = 0.2
    notes = {}
    noteIdx = 1
    timer = 0

    -- custom scale (C major pentatonic)
    scale = {261.63, 293.66, 329.63, 392.00, 440.00} -- frequencies

    -- fractal parameters
    zoom = 1
    offsetX, offsetY = 0, 0
    hueShift = 0
end

-- extract dominant colors (simple k‑means with k=3)
local function getPalette(imgData)
    local w, h = imgData:getDimensions()
    local colors = {}
    for i=1,3 do colors[i] = {0,0,0,0} end
    local count = w*h
    for y=0,h-1 do
        for x=0,w-1 do
            local r,g,b,a = imgData:getPixel(x,y)
            local idx = ((r+g+b) % 3) + 1
            colors[idx][1] = colors[idx][1] + r
            colors[idx][2] = colors[idx][2] + g
            colors[idx][3] = colors[idx][3] + b
            colors[idx][4] = colors[idx][4] + 1
        end
    end
    local palette = {}
    for i=1,3 do
        local c = colors[i]
        if c[4] > 0 then
            palette[i] = {c[1]/c[4], c[2]/c[4], c[3]/c[4]}
        end
    end
    return palette
end

-- map a color to a note (by brightness)
local function colorToNote(col)
    local brightness = (col[1]+col[2]+col[3])/3
    local idx = math.floor(brightness*#scale)+1
    return scale[idx]
end

-- generate a sine wave note
local function makeNote(freq)
    local samples = noteLength*sampleRate
    local data = love.sound.newSoundData(samples, sampleRate, 16, 1)
    for i=0,samples-1 do
        local t = i/sampleRate
        local amplitude = math.sin(2*math.pi*freq*t)
        data:setSample(i, amplitude*0.2)
    end
    return love.audio.newSource(data)
end

function love.update(dt)
    timer = timer + dt
    if cam and timer >= noteLength then
        timer = timer - noteLength
        cam:render(function()
            love.graphics.clear()
            love.graphics.draw(cam, 0, 0, 0, 0.2, 0.2)
        end)
        local img = love.graphics.newCanvas(160,120)
        love.graphics.setCanvas(img)
        love.graphics.clear()
        love.graphics.draw(cam, 0,0,0,0.2,0.2)
        love.graphics.setCanvas()
        local data = img:newImageData()
        local palette = getPalette(data)

        -- pick first color, map to note, play it
        if palette[1] then
            local freq = colorToNote(palette[1])
            notes[noteIdx] = makeNote(freq)
            notes[noteIdx]:play()
            noteIdx = noteIdx % 4 + 1
        end

        -- drive fractal params from palette
        if palette[2] then
            zoom = 0.5 + palette[2][1]/255
            hueShift = (hueShift + palette[2][2]/255*0.5) % 1
        end
        if palette[3] then
            offsetX = offsetX + (palette[3][1]-127)/127*dt
            offsetY = offsetY + (palette[3][2]-127)/127*dt
        end
    end
end

-- Mandelbrot rendering
local function drawFractal()
    local w, h = love.graphics.getDimensions()
    local maxIter = 100
    for py=0,h-1,4 do
        for px=0,w-1,4 do
            local x0 = (px/w-0.5)*3.5/zoom + offsetX
            local y0 = (py/h-0.5)*2.0/zoom + offsetY
            local x, y = 0,0
            local iter = 0
            while x*x + y*y <= 4 and iter < maxIter do
                x, y = x*x - y*y + x0, 2*x*y + y0
                iter = iter + 1
            end
            local col = iter==maxIter and 0 or iter/maxIter
            local hue = (col + hueShift) % 1
            local r,g,b = love.graphics.setColor and love.graphics.hsvToRgb(hue,0.8,0.9) or {1,1,1}
            love.graphics.setColor(r,g,b,0.8)
            love.graphics.rectangle("fill", px, py, 4, 4)
        end
    end
end

function love.draw()
    drawFractal()
    if cam then
        love.graphics.setColor(1,1,1,0.6)
        love.graphics.draw(cam, 10,10,0,0.2,0.2)
    end
end

function love.quit()
    if cam then cam:close() end
end