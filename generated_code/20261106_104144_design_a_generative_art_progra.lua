-- Prime-harmonic ASCII Mandala generator driven by simulated GPS & atmospheric pressure
local math_sin, math_cos, math_floor, math_abs, math_sqrt, math_atan2 = math.sin, math.cos, math.floor, math.abs, math.sqrt, math.atan2

-- Sacred prime sequence governing the geometric harmonics
local primes = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29}

-- Simulate real-time atmospheric pressure and GPS coordinates
local function get_environmental_state()
    local t = os.time()
    local lat = 37.7749 + math_sin(t * 0.01) * 0.1
    local lon = -122.4194 + math_cos(t * 0.01) * 0.1
    local pressure = 1013.25 + math_sin(t * 0.05) * 15.0 + math_cos(t * 0.03) * 8.0
    return lat, lon, pressure
end

-- Recursive bytecode poetry layer using prime arithmetic
local function generate_mandala_layer(depth, max_depth, x, y, p_val, angle)
    if depth > max_depth then return 0 end
    local prime = primes[(depth % #primes) + 1]
    local harmonics = math_sin(x * prime * 0.1 + angle) * math_cos(y * (prime / 2) * 0.1 - angle)
    return (harmonics * p_val / 1000) + (1 / prime) * generate_mandala_layer(depth + 1, max_depth, x, y, p_val, angle * 1.618)
end

-- Render loop generating the evolving ASCII mandala
local width, height = 61, 31
local chars = " .:-=+*#%@"

local function run()
    for frame = 1, 40 do
        local lat, lon, pressure = get_environmental_state()
        local t = frame * 0.2
        
        -- Clear terminal and print telemetry
        io.write("\27[2J\27[H")
        io.write(string.format("GPS: [%.4f, %.4f] | Pressure: %.2f hPa | Frame: %d/40\n", lat, lon, pressure, frame))
        io.write(string.rep("=", width) .. "\n")
        
        local cx, cy = width / 2, height / 2
        for y = 0, height - 1 do
            local line = {}
            for x = 0, width - 1 do
                local nx = (x - cx) / (cx * 0.8)
                local ny = (y - cy) / (cy * 0.8)
                local r = math_sqrt(nx*nx + ny*ny)
                local theta = math_atan2(ny, nx)
                
                if r > 1.0 then
                    table.insert(line, " ")
                else
                    local val = generate_mandala_layer(1, 5, nx * 4, ny * 4, pressure, t + theta * 3)
                    local idx = math_floor(math_abs(val) * #chars) % #chars + 1
                    table.insert(line, chars:sub(idx, idx))
                end
            end
            io.write(table.concat(line) .. "\n")
        end
        io.flush()
        
        -- Portable sleep simulation
        local start = os.time()
        repeat until os.time() > start
    end
end

run()