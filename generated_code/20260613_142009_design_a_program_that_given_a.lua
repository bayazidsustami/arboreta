function love.load()
    -- load a video as a stand‑in for a webcam feed
    video = love.graphics.newVideo("webcam.mp4")
    video:play()

    -- pentatonic scale (C major pentatonic) frequencies
    scale = {261.63, 293.66, 329.63, 392.00, 440.00} -- C D E G A

    -- audio buffer parameters
    sampleRate = 44100
    noteDuration = 0.2          -- seconds per frame
    channels = 1                -- mono

    -- create a source we will replace each frame
    sound = love.audio.newSource(love.sound.newSoundData(1, sampleRate, 16, channels), "static")
    sound:setLooping(false)

    -- shader for a simple fractal (Mandelbrot) whose parameters are driven by audio
    fractalShader = love.graphics.newShader[[
        uniform vec2 resolution;
        uniform float time;
        uniform float amp;
        uniform vec4 spectrum; // low, mid, high, rms

        vec3 palette(float t) {
            return 0.5 + 0.5*cos(6.28318*(t+vec3(0.0,0.33,0.67)));
        }

        vec2 cmul(vec2 a, vec2 b) { return vec2(a.x*b.x-a.y*b.y, a.x*b.y+a.y*b.x); }

        vec4 effect( vec4 color, Image tex, vec2 texcoord, vec2 pixcoord )
        {
            vec2 c = (texcoord - vec2(0.5))*3.0*vec2(resolution.x/resolution.y,1.0);
            c += vec2(sin(time*0.3), cos(time*0.4))*0.2; // slow drift

            // audio‑driven distortion
            c *= 1.0 + spectrum.x*0.3;
            c += vec2(spectrum.y, spectrum.z)*0.2;

            vec2 z = vec2(0.0);
            float i;
            for(i=0.0; i<64.0; i++) {
                if(dot(z,z)>4.0) break;
                z = cmul(z,z) + c;
            }
            float norm = i/64.0;
            vec3 col = palette(norm + amp*0.5);
            return vec4(col,1.0);
        }
    ]]
    fractalShader:send("resolution", {love.graphics.getWidth(), love.graphics.getHeight()})
end

-- compute an average color (as a simple dominant colour proxy)
local function avgColor(imageData)
    local w,h = imageData:getDimensions()
    local r,g,b = 0,0,0
    local cnt = w*h
    for y=0,h-1,4 do        -- sample every 4th row for speed
        for x=0,w-1,4 do
            local pr,pg,pb = imageData:getPixel(x,y)
            r=r+pr; g=g+pg; b=b+pb
        end
    end
    return r/cnt, g/cnt, b/cnt
end

-- map colour components (0‑1) to notes in the pentatonic scale
local function colourToNotes(r,g,b)
    local notes = {}
    local comps = {r,g,b}
    for i,c in ipairs(comps) do
        local idx = math.max(1, math.min(#scale, math.floor(c*#scale)+1))
        table.insert(notes, scale[idx])
    end
    return notes
end

-- generate a short PCM buffer mixing the notes
local function synth(notes)
    local len = math.floor(noteDuration*sampleRate)
    local sd = love.sound.newSoundData(len, sampleRate, 16, channels)
    for i=0,len-1 do
        local t = i/sampleRate
        local sample = 0
        for _,freq in ipairs(notes) do
            sample = sample + math.sin(2*math.pi*freq*t)
        end
        sample = sample / #notes
        sd:setSample(i, sample*0.5) -- keep amplitude safe
    end
    return sd
end

function love.update(dt)
    video:update(dt)

    -- capture current frame
    local frame = video:newImageData()
    local r,g,b = avgColor(frame)

    -- colour -> notes -> sound
    local notes = colourToNotes(r,g,b)
    local sd = synth(notes)
    sound = love.audio.newSource(sd, "static")
    sound:play()

    -- audio analysis for visual shader
    local spectrum = love.audio.getSpectrum(256, false)
    local low = 0; for i=1,64 do low=low+spectrum[i] end low=low/64
    local mid = 0; for i=65,192 do mid=mid+spectrum[i] end mid=mid/128
    local hi  = 0; for i=193,256 do hi=hi+spectrum[i] end hi=hi/64
    local rms = math.sqrt(low*low+mid*mid+hi*hi)

    fractalShader:send("time", love.timer.getTime())
    fractalShader:send("amp", rms)
    fractalShader:send("spectrum", {low,mid,hi,rms})
end

function love.draw()
    love.graphics.setShader(fractalShader)
    love.graphics.rectangle("fill",0,0,love.graphics.getWidth(),love.graphics.getHeight())
    love.graphics.setShader()
    -- overlay the video (optional, semi‑transparent)
    love.graphics.setColor(1,1,1,0.6)
    love.graphics.draw(video,0,0)
    love.graphics.setColor(1,1,1,1)
end