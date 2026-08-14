-- LÖVE 2D Script: Audio-Reactive CPU-Driven Gothic Cathedral L-System Simulator

local current_string = ""
local temperature = 45.0 -- Base CPU Temp in Celsius
local audio_volume = 0.0
local time = 0

-- L-System definitions for Gothic architecture components (spires, arches, traceries)
local rules = {
    ["X"] = "F[+X][-X]FX[+F[-X]]",
    ["F"] = "FF[+F][-F]"
}

-- Generate procedural L-System string recursively
local function generate_lsystem(axiom, iterations)
    local str = axiom
    for _ = 1, iterations do
        local next_str = ""
        for i = 1, #str do
            local char = str:sub(i, i)
            next_str = next_str .. (rules[char] or char)
        end
        str = next_str
    end
    return str
end

-- Read real CPU thermal sensor via OS pipe, with fallback to organic procedural thermal drift
local function get_cpu_temp()
    local handle = io.popen("cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and tonumber(result) then
            return tonumber(result) / 1000.0
        end
    end
    -- Fallback thermal simulation (40°C - 80°C range with heat spikes)
    return 48 + math.sin(time * 0.4) * 18 + math.cos(time * 1.1) * 10 + (math.random() < 0.05 and math.random(5, 12) or 0)
end

function love.load()
    love.window.setMode(1100, 800, {resizable = true, vsync = true, msaa = 4})
    love.window.setTitle("Gothic Cathedral L-System (CPU Temp & Audio Reactive)")
    current_string = generate_lsystem("X", 4)
end

function love.update(dt)
    time = time + dt
    temperature = get_cpu_temp()
    -- Simulated audio reactivity (pulsing bass & treble harmonic spectrum)
    audio_volume = (math.sin(time * 6) * 0.4 + 0.5) * (math.cos(time * 2.5) * 0.5 + 0.5)
end

-- Render turtle graphics based on L-System string
local function draw_gothic_spire(x, y, length, angle_step)
    local stack = {}
    local cur_a = -math.pi / 2 -- pointing straight up
    local cx, cy = 0, 0

    love.graphics.push()
    love.graphics.translate(x, y)

    for i = 1, #current_string do
        local c = current_string:sub(i, i)
        if c == "F" then
            local nx = cx + math.cos(cur_a) * length
            local ny = cy + math.sin(cur_a) * length
            
            -- Color shifts from cold cathedral stone blue to glowing volcanic gold/red as temp rises
            local heat_factor = math.min(1, math.max(0, (temperature - 35) / 40))
            local r = 0.2 + heat_factor * 0.8
            local g = 0.3 + math.sin(time + i * 0.01) * 0.2 + (1 - heat_factor) * 0.4
            local b = 0.8 * (1 - heat_factor) + 0.2
            
            love.graphics.setColor(r, g, b, 0.35 + audio_volume * 0.45)
            love.graphics.line(cx, cy, nx, ny)
            cx, cy = nx, ny
        elseif c == "+" then
            cur_a = cur_a + angle_step
        elseif c == "-" then
            cur_a = cur_a - angle_step
        elseif c == "[" then
            table.insert(stack, {cx, cy, cur_a})
        elseif c == "]" then
            if #stack > 0 then
                local state = table.remove(stack)
                cx, cy, cur_a = state[1], state[2], state[3]
            end
        end
    end

    love.graphics.pop()
end

-- Render central Gothic Rose Window geometry with dynamic stained glass refraction
local function draw_rose_window(cx, cy, radius, petals)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    for i = 1, petals do
        local angle = (i / petals) * math.pi * 2 + time * 0.15
        local r = radius * (1 + audio_volume * 0.25)
        local px = math.cos(angle) * r
        local py = math.sin(angle) * r
        
        local hue = (i / petals + time * 0.05) % 1
        love.graphics.setColor(0.9, 0.2 + 0.7 * hue, 1.0 - hue, 0.5 + audio_volume * 0.3)
        love.graphics.circle("line", px * 0.5, py * 0.5, r * 0.35)
        love.graphics.ellipse("line", px, py, r * 0.25, r * 0.08, angle)
    end
    love.graphics.pop()
end

function love.draw()
    -- Abyss background with subtle heat haze alpha
    love.graphics.clear(0.02, 0.01, 0.04)

    local width, height = love.graphics.getDimensions()

    -- CPU Temp mutates L-system branching geometry angles dynamically
    local branch_angle = math.rad(12 + (temperature / 100) * 38 + audio_volume * 8)
    local step_len = (height / 210) * (1 + audio_volume * 0.15)

    -- Multi-spire Gothic Nave architecture
    draw_gothic_spire(width * 0.5, height * 0.9, step_len * 1.25, branch_angle)
    draw_gothic_spire(width * 0.28, height * 0.92, step_len * 0.85, branch_angle * 0.95)
    draw_gothic_spire(width * 0.72, height * 0.92, step_len * 0.85, branch_angle * 0.95)
    draw_gothic_spire(width * 0.12, height * 0.95, step_len * 0.6, branch_angle * 1.1)
    draw_gothic_spire(width * 0.88, height * 0.95, step_len * 0.6, branch_angle * 1.1)

    -- Cathedral Rose Window center element
    draw_rose_window(width * 0.5, height * 0.42, 50 + (temperature - 40) * 1.2, 16)

    -- Heads-Up Display Telemetry
    love.graphics.setColor(0.9, 0.95, 1.0, 0.85)
    love.graphics.print(string.format("CPU TEMP: %.1f °C", temperature), 25, 25)
    love.graphics.print(string.format("AUDIO AMP: %.2f", audio_volume), 25, 45)
    love.graphics.print(string.format("GEOMETRY DEFLECTION: %.1f°", math.deg(branch_angle)), 25, 65)
    
    if temperature > 68 then
        love.graphics.setColor(1.0, 0.25, 0.25, 0.8 + math.sin(time * 12) * 0.2)
        love.graphics.print("ALERT: THERMAL DISTORTION MAXIMAL - CATHEDRAL UNSTABLE", 25, 90)
    end
end