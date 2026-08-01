-- Self-Ingesting Binary Topographical Map Generator
-- Reads its own source/binary bytes to procedurally generate a flowing ASCII landscape.

local function get_self_bytes()
    local path = arg and arg[0] or debug.getinfo(1, "S").source:sub(2)
    local f = io.open(path, "rb")
    if not f then f = io.open("/proc/self/exe", "rb") end
    
    local bytes = {}
    if f then
        local content = f:read("*a")
        f:close()
        for i = 1, #content do
            bytes[#bytes + 1] = string.byte(content, i)
        end
    else
        -- Fallback pseudo-binary stream if file stream is inaccessible
        for i = 1, 2048 do
            bytes[#bytes + 1] = (i * 37 + (i * i) % 101) % 256
        end
    end
    return bytes
end

-- Biome visual dictionary mapped by byte values and elevation
local biomes = {
    { name = "Deep Water",  min_b = 0,   max_b = 40,  chars = {"~", "approx", "x"}, ANSI = "\27[34m" },
    { name = "Shallow Sea", min_b = 41,  max_b = 80,  chars = {"~", "-", "="},      ANSI = "\27[36m" },
    { name = "Sand/Beach",  min_b = 81,  max_b = 110, chars = {".", ":", "o"},      ANSI = "\27[33m" },
    { name = "Lush Forest", min_b = 111, max_b = 160, chars = {"*", "^", "T"},      ANSI = "\27[32m" },
    { name = "Highlands",   min_b = 161, max_b = 200, chars = {"n", "m", "A"},      ANSI = "\27[92m" },
    { name = "Mountain",    min_b = 201, max_b = 235, chars = {"M", "A", "^"},      ANSI = "\27[37m" },
    { name = "Snow Peak",   min_b = 236, max_b = 255, chars = {"#", "*", "@"},      ANSI = "\27[97;1m" }
}

local function get_biome(byte_val)
    for _, b in ipairs(biomes) do
        if byte_val >= b.min_b and byte_val <= b.max_b then
            return b
        end
    end
    return biomes[1]
end

-- Smooth interpolation over binary addresses to create topographical contour heightmap
local function sample_height(bytes, x, y, width)
    local idx = (y * width + x) % #bytes + 1
    local byte = bytes[idx]
    local address = idx - 1
    
    -- Address-driven contour harmonics
    local freq1 = math.sin(address * 0.015 + x * 0.1)
    local freq2 = math.cos(address * 0.035 + y * 0.15)
    local noise = (freq1 + freq2 + 2) / 4
    
    local elevation = math.floor((byte / 255) * 0.6 * 100 + noise * 40)
    return math.min(100, math.max(0, elevation)), byte, address
end

-- Render function
local function generate_map()
    local bytes = get_self_bytes()
    local width = 72
    local height = 28
    local reset_color = "\27[0m"

    print("\27[2J\27[H") -- Clear screen
    print(string.format("\27[1;35m=== TOPOGRAPHICAL MAP OF BINARY [%d BYTES INGESTED] ===\27[0m\n", #bytes))

    for y = 0, height - 1 do
        local line = {}
        for x = 0, width - 1 do
            local elev, byte, addr = sample_height(bytes, x, y, width)
            
            -- Memory address contours (marked at specific modulo intervals)
            if (addr % 64 == 0) and elev > 30 then
                table.insert(line, "\27[90m" .. string.format("%X", (addr / 64) % 16) .. reset_color)
            else
                local biome = get_biome(byte)
                local char_idx = (elev % #biome.chars) + 1
                local char = biome.chars[char_idx]
                table.insert(line, biome.ANSI .. char .. reset_color)
            end
        end
        print(table.concat(line))
    end

    print("\n\27[1;30mLegend: [~] Water  [.] Coast  [*] Forest  [A] Highlands  [#] Peaks | Numbers: Memory Contours\27[0m")
end

generate_map()