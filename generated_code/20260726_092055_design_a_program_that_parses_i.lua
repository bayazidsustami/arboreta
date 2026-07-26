-- Real-time Memory Heap 3D Terrain & Seismic Visualizer in Pure Lua
-- Standard Lua 5.1+ compatible, outputs ANSI 3D wireframe graphics directly to terminal

local math, io, os, string = math, io, os, string
local collectgarbage, setmetatable = collectgarbage, setmetatable

-- Terminal viewport dimensions
local WIDTH, HEIGHT = 80, 36
local RAD = math.pi / 180

-- ANSI Escape Helpers
local function hide_cursor() io.write("\27[?25l") end
local function show_cursor() io.write("\27[?25h") end
local function clear_screen() io.write("\27[2J\27[H") end

-- State for tracking heap allocations and garbage collection cycles
local heap_tracker = {
    allocations = {},
    last_count = collectgarbage("count"),
    seismic_intensity = 0,
    gc_triggered = false
}

-- GC Sentinel object that fires its __gc metamethod when collected
local function create_gc_sentinel()
    local sentinel
    if newproxy then
        sentinel = newproxy(true)
        getmetatable(sentinel).__gc = function()
            heap_tracker.gc_triggered = true
            create_gc_sentinel()
        end
    else
        sentinel = setmetatable({}, {
            __gc = function()
                heap_tracker.gc_triggered = true
                create_gc_sentinel()
            end
        })
    end
end
create_gc_sentinel()

-- Dynamically allocate and deallocate Lua heap data to simulate workload
local function churn_memory()
    if math.random() < 0.75 then
        local chunk = {}
        for i = 1, math.random(50, 200) do
            chunk[i] = string.rep("0123456789ABCDEF", math.random(5, 20))
        end
        table.insert(heap_tracker.allocations, chunk)
    end
    -- Trigger sudden drop in allocations to induce garbage collection
    if #heap_tracker.allocations > 35 or math.random() < 0.04 then
        heap_tracker.allocations = {}
        collectgarbage("collect")
    end
end

-- Standard 3D perspective projection onto 2D terminal coordinates
local function project(x, y, z, angle_x, angle_y)
    -- Rotate Y axis
    local ry = angle_y * RAD
    local cy, sy = math.cos(ry), math.sin(ry)
    local x1 = x * cy + z * sy
    local z1 = -x * sy + z * cy

    -- Rotate X axis
    local rx = angle_x * RAD
    local cx, sx = math.cos(rx), math.sin(rx)
    local y2 = y * cx - z1 * sx
    local z2 = y * sx + z1 * cx

    -- Project 3D -> 2D
    local distance = 32
    local depth = z2 + distance
    if depth <= 0.1 then depth = 0.1 end

    local screen_x = math.floor(WIDTH / 2 + (x1 * 38) / depth)
    local screen_y = math.floor(HEIGHT / 2 + (y2 * 18) / depth)
    return screen_x, screen_y, depth
end

-- Frame rate delay helper
local function sleep(seconds)
    local start = os.clock()
    while os.clock() - start < seconds do end
end

-- Cleanup terminal state on exit
local function cleanup()
    show_cursor()
    io.write("\27[0m\27[2J\27[H")
end

-- Main Render Loop
local function run()
    hide_cursor()
    clear_screen()

    local frame = 0
    local angle_y = 0
    local angle_x = 32
    local chars = { " ", ".", ":", "-", "=", "+", "*", "#", "%", "@" }

    while frame < 400 do
        frame = frame + 1
        churn_memory()

        local current_mem = collectgarbage("count")
        local mem_delta = current_mem - heap_tracker.last_count
        heap_tracker.last_count = current_mem

        -- Detect GC cycle (via sentinel hook or large memory decrease)
        if heap_tracker.gc_triggered or mem_delta < -30 then
            heap_tracker.seismic_intensity = 18.0
            heap_tracker.gc_triggered = false
        end

        -- Decay seismic shockwave intensity
        heap_tracker.seismic_intensity = heap_tracker.seismic_intensity * 0.82
        if heap_tracker.seismic_intensity < 0.05 then
            heap_tracker.seismic_intensity = 0
        end

        -- Initialize double buffer and z-buffer
        local buffer, zbuffer = {}, {}
        for y = 1, HEIGHT do
            buffer[y], zbuffer[y] = {}, {}
            for x = 1, WIDTH do
                buffer[y][x] = " "
                zbuffer[y][x] = 99999
            end
        end

        -- Render dynamic terrain generated from heap state
        local grid_size = 13
        angle_y = (angle_y + 1.8) % 360

        for gx = -grid_size, grid_size do
            for gy = -grid_size, grid_size do
                local dist = math.sqrt(gx * gx + gy * gy)
                local base_height = math.sin(dist * 0.4 - frame * 0.12) * 1.2
                local heap_ridge = math.sin(gx * 0.35 + current_mem * 0.008) * math.cos(gy * 0.35) * 2.8

                -- Seismic displacement calculation
                local quake = 0
                if heap_tracker.seismic_intensity > 0.1 then
                    quake = (math.random() - 0.5) * heap_tracker.seismic_intensity
                end

                local world_x = gx * 1.15
                local world_y = base_height + heap_ridge + quake
                local world_z = gy * 1.15

                local sx, sy, sz = project(world_x, world_y, world_z, angle_x, angle_y)

                if sx >= 1 and sx <= WIDTH and sy >= 1 and sy <= HEIGHT then
                    if sz < zbuffer[sy][sx] then
                        zbuffer[sy][sx] = sz
                        local char_idx = math.floor(math.max(1, math.min(#chars, (world_y + 5) * 1.1)))
                        buffer[sy][sx] = chars[char_idx] or "#"
                    end
                end
            end
        end

        -- Draw to terminal
        io.write("\27[H")
        local is_quake = heap_tracker.seismic_intensity > 1.0
        local header_color = is_quake and "31;1" or "36"

        io.write(string.format("\27[%sm=== LUA HEAP TERRAIN | Heap: %.2f KB | Seismic Quake: %.1f ===\27[0m\n",
            header_color, current_mem, heap_tracker.seismic_intensity))

        for y = 1, HEIGHT - 2 do
            local row = {}
            for x = 1, WIDTH do
                table.insert(row, buffer[y][x])
            end
            if is_quake then
                io.write("\27[31;1m" .. table.concat(row) .. "\27[0m\n")
            else
                io.write("\27[32m" .. table.concat(row) .. "\27[0m\n")
            end
        end

        if is_quake then
            io.write("\27[41;30;1m [CATASTROPHIC GARBAGE COLLECTION EVENT DETECTED] \27[0m\r")
        else
            io.write("\27[K\r")
        end

        io.flush()
        sleep(0.04)
    end

    cleanup()
end

pcall(run)
cleanup()