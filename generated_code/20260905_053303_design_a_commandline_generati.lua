local ffi = require("ffi")

-- Foreign Function Interface bindings for system memory check (POSIX / Linux)
ffi.cdef[[
    struct sysinfo {
        long uptime;
        unsigned long loads[3];
        unsigned long totalram;
        unsigned long freeram;
        unsigned long sharedram;
        unsigned long bufferram;
        unsigned long totalswap;
        unsigned long freeswap;
        unsigned short procs;
        unsigned short pad;
        unsigned long totalhigh;
        unsigned long freehigh;
        unsigned int mem_unit;
        char _f[2080];
    };
    int sysinfo(struct sysinfo *info);
    int usleep(unsigned int usec);
]]

-- Fallback/Default memory usage reader
local function get_ram_usage()
    local ok, info = pcall(function()
        local s = ffi.new("struct sysinfo")
        if ffi.C.sysinfo(s) == 0 then
            local total = tonumber(s.totalram)
            local free = tonumber(s.freeram) + tonumber(s.bufferram)
            return (total - free) / total
        end
    end)
    if ok and info then return info end

    -- Portable fallback via /proc/meminfo or cross-platform estimation
    local f = io.open("/proc/meminfo", "r")
    if f then
        local total, free, buffers, cached = 0, 0, 0, 0
        for line in f:lines() do
            local k, v = line:match("(%w+):%s+(%d+)")
            if k == "MemTotal" then total = tonumber(v)
            elseif k == "MemFree" then free = tonumber(v)
            elseif k == "Buffers" then buffers = tonumber(v)
            elseif k == "Cached" then cached = tonumber(v) end
        end
        f:close()
        if total > 0 then
            return (total - (free + buffers + cached)) / total
        end
    end
    
    -- Sine wave dynamic modulation if system metrics are unavailable
    return 0.5 + 0.4 * math.sin(os.time() * 0.8)
end

-- Screen setup & ASCII palette
local W, H = 80, 40
local grid = {}
local palette = { " ", ".", ":", "-", "=", "+", "*", "#", "%", "@" }

-- Barnsley Fern IFS Affine Transformation Matrices
local transforms = {
    {  0.00,  0.00,  0.00,  0.16, 0.00, 0.00, 0.01 }, -- Stem
    {  0.85,  0.04, -0.04,  0.85, 0.00, 1.60, 0.85 }, -- Successively smaller leaflets
    {  0.20, -0.26,  0.23,  0.22, 0.00, 1.60, 0.07 }, -- Largest left leaflet
    { -0.15,  0.28,  0.26,  0.24, 0.00, 0.44, 0.07 }  -- Largest right leaflet
}

local function clear_buffer()
    for y = 1, H do
        grid[y] = grid[y] or {}
        for x = 1, W do grid[y][x] = 0 end
    end
end

local function draw_frame(ram_ratio, growth_step)
    clear_buffer()

    -- Map RAM usage [0, 1] to total iterations (foliage density)
    local max_points = math.floor(2000 + ram_ratio * 25000)
    -- Cap growth to animate fern unraveling over time
    local points = math.min(max_points, math.floor(growth_step * 1500))

    local x, y = 0, 0

    for i = 1, points do
        local r = math.random()
        local t
        if r < transforms[1][7] then t = transforms[1]
        elseif r < transforms[1][7] + transforms[2][7] then t = transforms[2]
        elseif r < transforms[1][7] + transforms[2][7] + transforms[3][7] then t = transforms[3]
        else t = transforms[4] end

        local nx = t[1] * x + t[2] * y + t[5]
        local ny = t[3] * x + t[4] * y + t[6]
        x, y = nx, ny

        -- Map fern coordinates [-2.182 <= x <= 2.655, 0 <= y <= 9.958] to CLI grid
        local gx = math.floor((x + 2.5) / 5.2 * (W - 1)) + 1
        local gy = H - math.floor(y / 10.2 * (H - 1))

        if gx >= 1 and gx <= W and gy >= 1 and gy <= H then
            grid[gy][gx] = grid[gy][gx] + 1
        end
    end

    -- Render buffer to terminal using ANSI color & density mapping
    local out = { "\27[H\27[2J" } -- Clear screen & reset cursor
    table.insert(out, string.format(" === ASCII Fern Growth Engine === RAM Load: %d%% | Density Points: %d\n", math.floor(ram_ratio * 100), points))

    for gy = 1, H do
        local line = {}
        for gx = 1, W do
            local val = grid[gy][gx]
            if val == 0 then
                table.insert(line, " ")
            else
                local char_idx = math.min(#palette, val + 1)
                local char = palette[char_idx]
                -- Dynamic ANSI green grading based on foliage intensity
                local color = (val > 6) and "\27[1;32m" or (val > 2 and "\27[0;32m" or "\27[2;32m")
                table.insert(line, color .. char .. "\27[0m")
            end
        end
        table.insert(out, table.concat(line) .. "\n")
    end

    io.write(table.concat(out))
    io.flush()
end

-- Main Loop
math.randomseed(os.time())
local growth_step = 1

while true do
    local ram = get_ram_usage()
    draw_frame(ram, growth_step)
    growth_step = growth_step + 1
    
    -- ~30 FPS sleep via FFI or os.execute fallback
    pcall(function() ffi.C.usleep(33000) end)
end