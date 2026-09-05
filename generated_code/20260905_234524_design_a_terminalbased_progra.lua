local posix = pcall(require, "posix")
local socket = require("socket")

-- Configuration
local WIDTH = 60
local HEIGHT = 20
local UPDATE_INTERVAL = 0.1

-- ASCII shade characters from low to high elevation
local TERRAIN_CHARS = { " ", ".", ":", "-", "=", "+", "*", "#", "%", "@" }
local VOLCANO_CHARS = { "^", "!", "A", "W", "M", "#" }

-- Helper to sleep in seconds
local function sleep(sec)
    socket.sleep(sec)
end

-- Clear terminal screen and hide cursor
local function init_screen()
    io.write("\27[2J")    -- Clear screen
    io.write("\27[?25l") -- Hide cursor
    io.flush()
end

-- Restore terminal cursor
local function restore_screen()
    io.write("\27[?25h") -- Show cursor
    io.write("\27[0m")    -- Reset colors
    io.flush()
end

-- Read CPU frequencies (MHz) and thermal states
-- Reads /proc/cpuinfo or /sys/devices/system/cpu/
local function get_cpu_metrics()
    local freqs = {}
    local max_freq = 1.0
    
    -- Attempt reading Linux sysfs for CPU frequencies
    local core_id = 0
    while true do
        local f = io.open("/sys/devices/system/cpu/cpu" .. core_id .. "/cpufreq/scaling_cur_freq", "r")
        if not f then break end
        local val = tonumber(f:read("*all")) or 0
        f:close()
        
        local f_max = io.open("/sys/devices/system/cpu/cpu" .. core_id .. "/cpufreq/scaling_max_freq", "r")
        local max_val = f_max and tonumber(f_max:read("*all")) or 3000000
        if f_max then f_max:close() end

        table.insert(freqs, {
            freq = val,
            max = max_val,
            ratio = val / (max_val > 0 and max_val or 1)
        })
        core_id = core_id + 1
    end

    -- Fallback mock data if sysfs is unavailable
    if #freqs == 0 then
        local t = os.time() + socket.gettime()
        for i = 1, 4 do
            local ratio = 0.5 + 0.4 * math.sin(t * 2 + i) + (math.random() > 0.85 and 0.4 or 0)
            if ratio > 1.0 then ratio = 1.0 end
            table.insert(freqs, {
                freq = math.floor(ratio * 3500000),
                max = 3500000,
                ratio = ratio
            })
        end
    end

    return freqs
end

-- Simplex/Perlin-style 2D Noise Generator for continuous topographical terrain
local function noise2d(x, y, seed)
    local X = math.floor(x) % 256
    local Y = math.floor(y) % 256
    local fx = x - math.floor(x)
    local fy = y - math.floor(y)
    
    -- Smoothstep interpolation
    local u = fx * fx * (3 - 2 * fx)
    local v = fy * fy * (3 - 2 * fy)

    local hash = function(i, j)
        return math.sin(i * 12.9898 + j * 78.233 + seed) * 43758.5453 % 1
    end

    local g00 = hash(X, Y)
    local g10 = hash(X + 1, Y)
    local g01 = hash(X, Y + 1)
    local g11 = hash(X + 1, Y + 1)

    local nx0 = g00 + u * (g10 - g00)
    local nx1 = g01 + u * (g11 - g01)
    return nx0 + v * (nx1 - nx0)
end

-- Particle system for volcanic eruptions (thermal throttling)
local Eruptions = {}

local function trigger_eruption(x, y)
    table.insert(Eruptions, {
        x = x,
        y = y,
        intensity = 1.0,
        particles = {}
    })
end

locallocal ffi = require("ffi")

ffi.cdef[[
    int usleep(unsigned int usec);
    int rand(void);
]]

-- System Configuration & Helpers
local TERRAIN_WIDTH = 60
local TERRAIN_HEIGHT = 20
local NUM_CORES = 4

-- ASCII Density scale for height mapping
local CHARS = { " ", ".", ":", "-", "=", "+", "*", "#", "%", "@" }

-- Store core state: {freq = 0..1, temp = 0..100, x = 0, y = 0}
local cores = {}
for i = 1, NUM_CORES do
    cores[i] = {
        x = (i / (NUM_CORES + 1)) * TERRAIN_WIDTH,
        y = TERRAIN_HEIGHT / 2 + (i % 2 == 0 and 2 or -2),
        freq = 0.5,
        temp = 40.0,
        throttling = false
    }
end

-- Terminal Controls
local function clear_screen()
    io.write("\27[2J\27[H")
end

local function hide_cursor()
    io.write("\27[?25l")
end

local function show_cursor()
    io.write("\27[?25h")
end

-- Read Linux CPU metrics (falls back to simulation if unreadable)
local function sample_cpu_metrics()
    local f_freq = io.open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq", "r")
    local f_temp = io.open("/sys/class/thermal/thermal_zone0/temp", "r")

    for i = 1, NUM_CORES do
        local core = cores[i]
        
        -- Frequency Reading / Simulation
        if f_freq then
            local f = io.open("/sys/devices/system/cpu/cpu" .. (i - 1) .. "/cpufreq/scaling_cur_freq", "r")
            if f then
                local val = tonumber(f:read("*all")) or 2000000
                core.freq = math.min(1.0, math.max(0.1, val / 4000000))
                f:close()
            end
        else
            -- Synthesize dynamic CPU load fluctuations
            core.freq = math.min(1.0, math.max(0.1, core.freq + (ffi.C.rand() % 21 - 10) / 50))
        end

        -- Temperature & Thermal Throttling Logic
        if f_temp and i == 1 then
            local val = tonumber(f_temp:read("*all")) or 45000
            core.temp = val / 1000.0
        else
            -- Synthesize thermal build-up based on frequency intensity
            core.temp = core.temp + (core.freq * 2.5) - 1.2 + (ffi.C.rand() % 10 - 5) / 10
            core.temp = math.min(100.0, math.max(30.0, core.temp))
        end

        core.throttling = core.temp > 78.0
    end

    if f_freq then f_freq:close() end
    if f_temp then f_temp:close() end
end

-- Generate Topographical Height via Multi-Core Radial Gaussian Waves
local function calculate_height(x, y, time)
    local height = 0
    for i = 1, NUM_CORES do
        local core = cores[i]
        local dx = x - core.x
        local dy = y - core.y
        local dist_sq = dx * dx + dy * dy
        
        -- Frequency determines wave amplitude and spread width
        local radius = 8.0 * core.freq + 2.0
        local amp = core.freq * 8.0
        
        -- Ripple wave effect centered on CPU cores
        local wave = math.sin(math.sqrt(dist_sq) - time * 4) * 0.5 + 0.5
        height = height + math.exp(-dist_sq / (radius * radius)) * amp * wave
    end
    return height
end

-- Render Screen
local function render_frame(time)
    local buffer = {}
    
    -- Display Header & Core Telemetry
    table.insert(buffer, "\27[1;1H\27[1;36m=== REAL-TIME CPU THERMAL TERRAIN & VOLCANIC MAP ===\27[0m\n")
    for i = 1, NUM_CORES do
        local c = cores[i]
        local status = c.throttling and "\27[1;31m[ERUPTING - THROTTLED]\27[0m" or "\27[1;32m[STABLE]\27[0m"
        table.insert(buffer, string.format("Core %d | Freq: %4.2f GHz | Temp: %4.1f°C | Status: %s\n", 
            i - 1, c.freq * 4.0, c.temp, status))
    end
    table.insert(buffer, "\n")

    -- Render Terrain Map
    for y = 0, TERRAIN_HEIGHT do
        for x = 0, TERRAIN_WIDTH do
            local h = calculate_height(x, y, time)
            local is_volcano_core = false
            local is_erupting = false

            -- Check if current cell corresponds to a throttled core center
            for i = 1, NUM_CORES do
                local c = cores[i]
                if math.abs(x - c.x) <= 1 and math.abs(y - c.y) <= 1 then
                    if c.throttling then
                        is_erupting = true
                    end
                    if math.floor(x) == math.floor(c.x) and math.floor(y) == math.floor(c.y) then
                        is_volcano_core = true
                    end
                end
            end

            -- Render Eruption Particles or Standard Topography
            if is_erupting then
                if is_volcano_core then
                    table.insert(buffer, "\27[1;31m▲\27[0m") -- Volcano Peak
                else
                    local lava = { "░", "▒", "▓", "*", "█" }
                    local char = lava[(ffi.C.rand() % #lava) + 1]
                    local color = (ffi.C.rand() % 2 == 0) and "\27[1;31m" or "\27[1;33m"
                    table.insert(buffer, color .. char .. "\27[0m")
                end
            else
                -- Map continuous height to ASCII character gradient
                local idx = math.floor(h) + 1
                idx = math.max(1, math.min(#CHARS, idx))
                local char = CHARS[idx]
                
                -- Color depth based on altitude
                if idx > 7 then
                    table.insert(buffer, "\27[1;33m" .. char .. "\27[0m")
                elseif idx > 4 then
                    table.insert(buffer, "\27[0;32m" .. char .. "\27[0m")
                else
                    table.insert(buffer, "\27[0;34m" .. char .. "\27[0m")
                end
            end
        end
        table.insert(buffer, "\n")
    end

    io.write(table.concat(buffer))
    io.flush()
end

-- Main Loop Execution
local function main()
    clear_screen()
    hide_cursor()

    local time = 0.0
    local running = true

    -- Graceful exit trap handling
    os.execute("stty -echo 2>/dev/null")

    while running do
        sample_cpu_metrics()
        render_frame(time)
        
        time = time + 0.15
        ffi.C.usleep(50000) -- Sleep ~50ms (20 FPS)
    end

    show_cursor()
    os.execute("stty echo 2>/dev/null")
end

-- Execute Program
local status, err = pcall(main)
show_cursor()
os.execute("stty echo 2>/dev/null")
if not status and err then
    print("\nProgram stopped: " .. tostring(err))
end