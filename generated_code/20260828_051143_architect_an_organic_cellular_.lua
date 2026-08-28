local os = os
local math = math

-- Terminal setup and utility helpers
local function clear_screen()
    io.write("\27[2J\27[H")
end

local function get_memory_usage()
    local usage = collectgarbage("count") -- Returns memory in KB
    -- Introduce mild pseudo-random jitter tied to system clock to ensure dynamic visual evolution
    local jitter = (math.sin(os.clock() * 3.5) + 1) * 128
    return usage + jitter
end

-- Musical Pitch Scale Mapping (Pentatonic / Ambient Modal Frequency Ratios mapped to ASCII density)
local pitches = {
    { symbol = " ", freq = 0.0,  name = "Rest" },
    { symbol = ".", freq = 130.81, name = "C3" },
    { symbol = ":", freq = 146.83, name = "D3" },
    { symbol = "~", freq = 164.81, name = "E3" },
    { symbol = "*", freq = 196.00, name = "G3" },
    { symbol = "o", freq = 220.00, name = "A3" },
    { symbol = "=", freq = 261.63, name = "C4" },
    { symbol = "#", freq = 293.66, name = "D4" },
    { symbol = "%", freq = 329.63, name = "E4" },
    { symbol = "@", freq = 392.00, name = "G4" },
}

local WIDTH = 64
local HEIGHT = 24

-- Create 2D grid
local function create_grid(w, h, fill_val)
    local g = {}
    for y = 1, h do
        g[y] = {}
        for x = 1, w do
            g[y][x] = fill_val or 1
        end
    end
    return g
end

local grid = create_grid(WIDTH, HEIGHT, 1)

-- Seed initial organic landscape peaks
math.randomseed(os.time())
for x = 1, WIDTH do
    local depth = math.floor((math.sin(x * 0.15) + 1) * 0.5 * (HEIGHT * 0.6)) + 5
    for y = HEIGHT - depth, HEIGHT do
        grid[y][x] = math.random(2, #pitches)
    end
end

-- Organic Cellular Automaton step with memory-influenced rules
local function step_automaton(current_grid, memory_kb)
    local next_grid = create_grid(WIDTH, HEIGHT, 1)
    
    -- Memory pressure influences birth/decay thresholds and pitch modulation
    local mem_factor = (memory_kb % 1000) / 1000
    local pitch_shift = math.floor(mem_factor * (#pitches - 1))

    for y = 1, HEIGHT do
        for x = 1, WIDTH do
            -- Sum neighbor pitch indices
            local total_pitch = 0
            local count = 0
            for dy = -1, 1 do
                for dx = -1, 1 do
                    if not (dx == 0 and dy == 0) then
                        local nx, ny = x + dx, y + dy
                        if nx >= 1 and nx <= WIDTH and ny >= 1 and ny <= HEIGHT then
                            total_pitch = total_pitch + current_grid[ny][nx]
                            count = count + 1
                        end
                    end
                end
            end

            local avg_pitch = total_pitch / count
            local current = current_grid[y][x]

            -- Transition rules based on pitch harmony and system memory resonance
            if current == 1 then
                -- Spontaneous organic growth modulated by memory pulse
                if avg_pitch > 1.8 and math.random() < (0.05 + mem_factor * 0.1) then
                    next_grid[y][x] = (math.floor(avg_pitch) + pitch_shift) % (#pitches - 1) + 2
                else
                    next_grid[y][x] = 1
                end
            else
                -- Harmonic evolution/decay
                if avg_pitch < 1.5 then
                    next_grid[y][x] = math.max(1, current - 1) -- Decay
                elseif math.abs(avg_pitch - current) <= 1.5 then
                    next_grid[y][x] = math.min(#pitches, current + 1) -- Resonate higher
                else
                    next_grid[y][x] = current -- Stability
                end
            end
        end
    end

    return next_grid
end

-- Render frame to console
local function render(g, memory_kb)
    local buffer = {}
    table.insert(buffer, string.format("=== ORGANIC PITCH LANDSCAPE | RAM: %.2f KB ===\n", memory_kb))
    
    for y = 1, HEIGHT do
        local line = {}
        for x = 1, WIDTH do
            local pitch_idx = g[y][x]
            table.insert(line, pitches[pitch_idx].symbol)
        end
        table.insert(buffer, table.concat(line) .. "\n")
    end
    
    io.write(table.concat(buffer))
end

-- Main Real-Time Simulation Loop
local function run()
    clear_screen()
    local cycles = 0
    while cycles < 200 do -- Limit iterations for safe autonomous execution
        local mem = get_memory_usage()
        grid = step_automaton(grid, mem)
        
        io.write("\27[H") -- Reset cursor to top-left
        render(grid, mem)
        
        -- Sleep execution slightly for smooth animation pacing
        local start = os.clock()
        while os.clock() - start < 0.08 do end
        cycles = cycles + 1
    end
end

run()