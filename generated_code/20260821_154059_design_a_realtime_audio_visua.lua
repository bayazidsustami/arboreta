local -- Check environment
if type(window) == "nil" or type(js) == "nil" then
    -- Polyfill/mock for non-browser/CLI Lua environments to render instructions
    print("================================================================================")
    print("CPU-Fractal Ambient Visualizer (Lua)")
    print("================================================================================")
    print("This self-contained script targets WebAssembly/Fengari Lua environments.")
    print("To run in a web browser, execute via Fengari/Lua.vm.js attached to a Canvas.")
    print("================================================================================")
end

-- Web API / JS Bindings via Fengari or global interop
local js = js or {}
local window = window or js.global or {}
local document = window.document

-- Configuration Parameters
local CONFIG = {
    canvasWidth = 800,
    canvasHeight = 600,
    maxDepth = 7,
    baseBranchLength = 110,
    branchScale = 0.72,
    baseSpreadAngle = math.rad(25),
    baseFrequency = 138.59, -- C#3 microtonal root
    chordNotes = {1.0, 1.05946, 1.18921, 1.33484, 1.49831, 1.68179, 1.88775} -- Just/Microtonal ratios
}

-- Application State
local state = {
    cpuUsage = 0.1,
    targetCpu = 0.1,
    time = 0,
    audioCtx = nil,
    masterGain = nil,
    oscillators = {},
    gains = {},
    isAudioStarted = false
}

-- Pseudo CPU Load Generator (Simulates fluctuating real-time CPU telemetry)
local function sampleCpuUsage(t)
    local noise1 = math.sin(t * 0.8) * 0.3
    local noise2 = math.cos(t * 2.3) * 0.15
    local noise3 = math.sin(t * 5.1) * 0.05
    local raw = 0.35 + noise1 + noise2 + noise3
    return math.max(0.05, math.min(0.95, raw))
end

-- Initialize Web Audio Synthesis Pipeline
local function initAudio()
    if state.isAudioStarted then return end
    
    local AudioContext = window.AudioContext or window.webkitAudioContext
    if not AudioContext then return end
    
    state.audioCtx = AudioContext.new()
    state.masterGain = state.audioCtx:createGain()
    state.masterGain.gain.value = 0.15
    state.masterGain:connect(state.audioCtx.destination)

    -- Create additive synth bank corresponding to tree branch depth levels
    for i = 1, CONFIG.maxDepth do
        local osc = state.audioCtx:createOscillator()
        local gain = state.audioCtx:createGain()
        
        osc.type = (i % 2 == 0) and "sine" or "triangle"
        local ratio = CONFIG.chordNotes[((i - 1) % #CONFIG.chordNotes) + 1]
        osc.frequency.value = CONFIG.baseFrequency * ratio * (1 + (i * 0.02))
        
        gain.gain.value = 0.0
        osc:connect(gain)
        gain:connect(state.masterGain)
        osc:start()
        
        table.insert(state.oscillators, osc)
        table.insert(state.gains, gain)
    end
    
    state.isAudioStarted = true
end

-- Update Microtonal Audio Parameters based on CPU activity and tree dynamics
local function updateAudio(cpu, time)
    if not state.isAudioStarted then return end
    
    local currentTime = state.audioCtx.currentTime
    for i = 1, #state.gains do
        local depthFactor = i / CONFIG.maxDepth
        local targetGain = (math.sin(time * 1.5 + i) * 0.5 + 0.5) * (0.05 + cpu * 0.2) * (1 - depthFactor * 0.5)
        
        -- Microtonal pitch modulation based on CPU load turbulence
        local detuneAmount = math.sin(time * 0.5 + i) * (cpu * 35)
        
        state.gains[i].gain:setTargetAtTime(targetGain, currentTime, 0.1)
        state.oscillators[i].detune:setTargetAtTime(detuneAmount, currentTime, 0.1)
    end
end

-- Recursive Fractal Tree Renderer
local function drawBranch(ctx, len, depth, cpu, time)
    if depth == 0 then return end

    -- Dynamic Branch Styling linked to CPU Metrics
    local lineWidth = depth * (1.2 + cpu * 1.5)
    local hue = (180 + (depth * 25) + (cpu * 120) + (time * 10)) % 360
    local lightness = 40 + (depth * 5) + (cpu * 20)
    
    ctx.lineWidth = lineWidth
    ctx.strokeStyle = string.format("hsl(%d, 80%%, %d%%)", hue, lightness)
    ctx.lineCap = "round"

    -- Render Branch Line
    ctx:beginPath()
    ctx:moveTo(0, 0)
    ctx:lineTo(0, -len)
    ctx:stroke()

    -- Translate coordinate space to top of branch
    ctx:save()
    ctx:translate(0, -len)

    -- Dynamic Angle Perturbations driven by CPU stream
    local angleVariation = math.sin(time * 2 + depth) * (cpu * 0.15)
    local spread = CONFIG.baseSpreadAngle + (cpu * 0.35) + angleVariation
    local nextLen = len * (CONFIG.branchScale + (math.cos(time + depth) * 0.02))

    -- Left Branch
    ctx:save()
    ctx:rotate(-spread)
    drawBranch(ctx, nextLen, depth - 1, cpu, time)
    ctx:restore()

    -- Right Branch
    ctx:save()
    ctx:rotate(spread)
    drawBranch(ctx, nextLen, depth - 1, cpu, time)
    ctx:restore()

    ctx:restore()
end

-- Main Graphics Engine / Animation Loop
local function setupEngine()
    if not document or not document.createElement then return end
    
    local canvas = document:createElement("canvas")
    canvas.width = CONFIG.canvasWidth
    canvas.height = CONFIG.canvasHeight
    document.body:appendChild(canvas)
    
    local ctx = canvas:getContext("2d")
    
    -- Interaction: Start audio context on user interaction
    local function handleInteraction()
        initAudio()
        if state.audioCtx and state.audioCtx.state == "suspended" then
            state.audioCtx:resume()
        end
    end
    
    canvas:addEventListener("click", handleInteraction)
    window:addEventListener("keydown", handleInteraction)

    -- Main Animation Loop
    local function renderFrame()
        state.time = state.time + 0.016
        
        -- Sample CPU metric stream and interpolate smooth state
        state.targetCpu = sampleCpuUsage(state.time)
        state.cpuUsage = state.cpuUsage + (state.targetCpu - state.cpuUsage) * 0.05

        -- Clear Canvas with procedural trailing glow effect
        ctx.fillStyle = "rgba(10, 12, 18, 0.25)"
        ctx.fillRect(0, 0, canvas.width, canvas.height)

        -- Draw Root Origin
        ctx:save()
        ctx:translate(canvas.width / 2, canvas.height - 40)
        
        -- Trigger recursive fractal tree draw
        drawBranch(ctx, CONFIG.baseBranchLength * (0.8 + state.cpuUsage * 0.4), CONFIG.maxDepth, state.cpuUsage, state.time)
        ctx:restore()

        -- Render On-screen Telemetry HUD
        ctx.fillStyle = "rgba(255, 255, 255, 0.7)"
        ctx.font = "12px monospace"
        ctx:fillText(string.format("SYSTEM CPU LOAD: %.1f%%", state.cpuUsage * 100), 20, 30)
        ctx:fillText(string.format("AMBIENT AUDIO: %s", state.isAudioStarted and "ACTIVE" or "CLICK CANVAS TO START"), 20, 48)

        -- Update Web Audio Synthesis Parameters
        updateAudio(state.cpuUsage, state.time)

        -- Schedule next frame
        window:requestAnimationFrame(renderFrame)
    end

    -- Kick off animation loop
    renderFrame()
end

-- Execute Script Setup
setupEngine()