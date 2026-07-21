-- Generative Dying Galaxy Simulation
-- Driven by Lua GC Memory Allocation Jitter and Fragmentation Patterns

local math_sin, math_cos, math_sqrt, math_random = math.sin, math.cos, math.sqrt, math.random
local math_floor, math_max = math.floor, math.max
local clock = os.clock

-- Console Display Parameters
local WIDTH, HEIGHT = 70, 26
local CENTER_X, CENTER_Y = WIDTH / 2, HEIGHT / 2

local function clear()
    io.write("\27[2J\27[H")
end

local function sleep(n)
    local t0 = clock()
    while clock() - t0 < n do end
end

-- Memory Allocator Probe: Induces fragmentation & measures execution timing jitter
local memory_pool = {}
local function probe_allocator()
    local t0 = clock()
    
    -- Pseudo-random allocation and freeing to induce heap holes & GC churn
    for i = 1, 60 do
        local key = math_random(1, 250)
        if memory_pool[key] then
            memory_pool[key] = nil -- Free chunk
        else
            memory_pool[key] = { string.rep("★", math_random(5, 50)), math_random() }
        end
    end
    
    local t1 = clock()
    local jitter = (t1 - t0) * 1000000 -- Allocator timing noise in microseconds
    local kb_used = collectgarbage("count")
    local fragmentation = (kb_used % 40) / 40.0 -- Normalized heap fragmentation metric
    
    return jitter, fragmentation, kb_used
end

-- Initialize Galaxy Stars
local NUM_STARS = 100
local stars = {}

for i = 1, NUM_STARS do
    local radius = math_random() * 18 + 2
    stars[i] = {
        r = radius,
        theta = math_random() * math.pi * 2,
        speed = 0.6 / math_sqrt(radius), -- Keplerian orbital velocity baseline
        energy = math_random() * 100 + 50,
        symbol = "*"
    }
end

-- Main Render Loop
local frame = 0
local max_frames = 120

while frame < max_frames do
    frame = frame + 1
    
    -- Harvest system memory telemetry
    local jitter, frag, mem_kb = probe_allocator()
    
    -- High jitter triggers Cosmic Ray Bursts
    local cosmic_burst = jitter > 12
    
    -- Prepare Frame Grid
    local grid = {}
    for y = 1, HEIGHT do
        grid[y] = {}
        for x = 1, WIDTH do
            grid[y][x] = " "
        end
    end

    -- Supermassive Black Hole core
    grid[math_floor(CENTER_Y)][math_floor(CENTER_X)] = "@"

    -- Simulate Stars
    for i = 1, NUM_STARS do
        local st = stars[i]
        
        -- Decay star energy over time, accelerated by memory fragmentation
        st.energy = st.energy - (0.2 + frag * 0.4)
        
        if st.energy > 0 then
            -- Orbital perturbation driven by allocation timing jitter
            local perturbation = 1.0 + (jitter * 0.015)
            st.theta = st.theta + (st.speed * perturbation) / (st.r * 0.2)
            
            -- Stellar Nursery Formation: low fragmentation allows gravitational collapse
            if frag < 0.25 and math_random() < 0.08 then
                st.r = math_max(1.5, st.r - 0.15) -- condensation into nursery
                st.symbol = "o"
            else
                st.r = st.r + 0.015 -- galaxy expansion/dissipation
                st.symbol = st.energy < 30 and "." or "*"
            end

            -- Convert polar orbit to Cartesian screen coordinates (aspect-ratio corrected)
            local screen_x = math_floor(CENTER_X + st.r * math_cos(st.theta) * 1.8)
            local screen_y = math_floor(CENTER_Y + st.r * math_sin(st.theta))

            if screen_x >= 1 and screen_x <= WIDTH and screen_y >= 1 and screen_y <= HEIGHT then
                grid[screen_y][screen_x] = cosmic_burst and "!" or st.symbol
            end
        end
    end

    -- Display Frame
    clear()
    local buffer = {}
    table.insert(buffer, string.format("--- DYING GALAXY SIMULATION --- [Frame %d/%d]", frame, max_frames))
    table.insert(buffer, string.format("Alloc Jitter: %.2f us | Fragmentation Index: %.2f | RAM: %.1f KB", jitter, frag, mem_kb))
    table.insert(buffer, cosmic_burst and "STATUS: *** COSMIC RAY BURST DETECTED ***" or "STATUS: Gravitational Decay Active")
    table.insert(buffer, string.rep("=", WIDTH))

    for y = 1, HEIGHT do
        table.insert(buffer, table.concat(grid[y]))
    end

    io.write(table.concat(buffer, "\n") .. "\n")
    sleep(0.05)
end

io.write("\nSimulation complete. Galaxy heat death reached.\n")