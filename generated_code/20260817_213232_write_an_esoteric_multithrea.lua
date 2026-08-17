-- Memory Constellation & Deadlock Event Horizon Simulation
-- Uses Lua pseudo-threading via coroutines and lightweight OS-level memory sampling
-- to project memory addresses into dynamic ASCII star constellations.
-- Deadlocked coroutines cause local gravitational collapse into event horizons ('@').

local math, io, os, string = math, io, os, string
math.randomseed(os.time())

-- Screen dimensions
local WIDTH, HEIGHT = 70, 22
local STAR_CHARS = {".", "*", "+", "o", "O", "#"}

-- Global state
local stars = {}
local threads = {}
local memory_pool = {}

-- Utility: Clear screen using ANSI escape sequences
local function clear_screen()
    io.write("\27[2J\27[1;1H")
end

-- Map a memory memory address value to 2D ASCII screen coordinates
local function map_to_canvas(addr, salt)
    local x = (addr * 13 + salt * 7) % WIDTH + 1
    local y = (addr * 17 + salt * 3) % HEIGHT + 1
    return math.floor(x), math.floor(y)
end

-- Esoteric Thread worker: Allocates memory and dynamically generates stars
local function star_worker(id, lock_resource)
    local local_store = {}
    local counter = 0
    while true do
        counter = counter + 1
        -- Allocate changing structures to shift live memory pointers
        local_store[counter % 50] = { data = string.rep("0", (counter % 10) * 100) }
        
        -- Acquire memory address of live table as an esoteric seed
        local ptr_str = tostring(local_store[counter % 50])
        local ptr_val = tonumber(ptr_str:match("0x(%x+)") or ptr_str:match("(%d+)") or "12345", 16) or counter

        local x, y = map_to_canvas(ptr_val, id)
        table.insert(stars, {x = x, y = y, intensity = (counter % #STAR_CHARS) + 1, thread_id = id})

        -- Artificial Deadlock Simulation: Thread 1 & 2 acquire resource locks in reverse order
        if counter > 30 then
            if id == 1 and lock_resource.held_by == 2 then
                -- Deadlocked: Infinite wait without yielding
                lock_resource.deadlocked_1 = true
                while true do end 
            elseif id == 2 and lock_resource.held_by == 1 then
                -- Deadlocked: Infinite wait without yielding
                lock_resource.deadlocked_2 = true
                while true do end 
            end
            lock_resource.held_by = id
        end

        coroutine.yield()
    end
end

-- Initialize threads and shared lock object
local shared_lock = { held_by = 0 }
for i = 1, 4 do
    threads[i] = {
        co = coroutine.create(star_worker),
        id = i,
        status = "ALIVE"
    }
end

-- Main Render Loop
for frame = 1, 100 do
    stars = {}
    local deadlocks = {}

    -- Step active coroutines
    for _, t in ipairs(threads) do
        if coroutine.status(t.co) ~= "dead" then
            -- Resume coroutine execution
            local ok, err = coroutine.resume(t.co, t.id, shared_lock)
            if not ok then
                t.status = "DEADLOCKED"
            end
        end
    end

    -- Detect deadlocks from lock state flags
    if shared_lock.deadlocked_1 and shared_lock.deadlocked_2 then
        table.insert(deadlocks, {x = math.floor(WIDTH / 3), y = math.floor(HEIGHT / 2), radius = frame % 5 + 2})
        table.insert(deadlocks, {x = math.floor(2 * WIDTH / 3), y = math.floor(HEIGHT / 2), radius = frame % 5 + 2})
    end

    -- Construct ASCII Canvas Buffer
    local canvas = {}
    for y = 1, HEIGHT do
        canvas[y] = {}
        for x = 1, WIDTH do
            canvas[y][x] = " "
        end
    end

    -- Render Stars (Active memory addresses)
    for _, s in ipairs(stars) do
        if s.x >= 1 and s.x <= WIDTH and s.y >= 1 and s.y <= HEIGHT then
            canvas[s.y][s.x] = STAR_CHARS[s.intensity]
        end
    end

    -- Render Collapsing Black Holes (Deadlocks)
    for _, hole in ipairs(deadlocks) do
        for dy = -hole.radius, hole.radius do
            for dx = -hole.radius * 2, hole.radius * 2 do
                local nx, ny = hole.x + dx, hole.y + dy
                if nx >= 1 and nx <= WIDTH and ny >= 1 and ny <= HEIGHT then
                    local dist = math.sqrt((dx/2)^2 + dy^2)
                    if dist <= hole.radius / 2 then
                        canvas[ny][nx] = "@" -- Singular Event Horizon
                    elseif dist <= hole.radius then
                        canvas[ny][nx] = "O" -- Gravitational Lens Edge
                    end
                end
            end
        end
    end

    -- Output Rendered Frame
    clear_screen()
    io.write("=== LIVE MEMORY CONSTELLATION MAP (FRAME " .. frame .. ") ===\n")
    for y = 1, HEIGHT do
        io.write(table.concat(canvas[y]) .. "\n")
    end
    
    if #deadlocks > 0 then
        io.write("\27[31m[CRITICAL WARNING] DEADLOCK DETECTED: EVENT HORIZON COLLAPSING MEMORY SPACES!\27[0m\n")
    else
        io.write("[INFO] Threads active. Translating heap memory addresses to stars...\n")
    end

    -- Platform independent delay
    local start_time = os.clock()
    while os.clock() - start_time < 0.08 do end
end