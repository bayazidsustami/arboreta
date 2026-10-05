-- Generative Graphics Engine: The Garden of Forgotten Libraries
-- Pure Lua implementation with ANSI terminal rendering and dynamic CPU thermal coupling.

-- Function to read CPU temperature (Linux /sys filesystem or fallback simulation)
local function get_cpu_temp()
    local f = io.open("/sys/class/thermal/thermal_zone0/temp", "r")
    if f then
        local content = f:read("*all")
        f:close()
        local temp = tonumber(content)
        if temp then return temp / 1000.0 end
    end
    -- Fallback: simulate fluctuating thermal load based on time
    return 45.0 + math.sin(os.time() * 0.7) * 18.0
end

-- Forgotten libraries dataset representing digital artifacts
local libraries = {
    {name = "left-pad.js", age = 12, crystals = {}, color = "\27[31m"},
    {name = "mootools.js", age = 16, crystals = {}, color = "\27[33m"},
    {name = "flash-runtime", age = 9, crystals = {}, color = "\27[35m"},
    {name = "activex-ctrl", age = 24, crystals = {}, color = "\27[36m"},
}

-- Initialize geometric crystal nodes for each library
math.randomseed(os.time())
for _, lib in ipairs(libraries) do
    for i = 1, 4 do
        table.insert(lib.crystals, {
            size = 1.0,
            max_size = math.random(4, 8),
            purity = math.random()
        })
    end
end

-- Clear screen and hide terminal cursor
io.write("\27[2J\27[?25l")

-- Main generative rendering loop (runs 40 frames for demonstration)
for frame = 1, 40 do
    local temp = get_cpu_temp()
    -- Growth rate accelerates non-linearly with higher CPU temperatures
    local growth_rate = math.max(0.05, (temp / 45.0) * 0.4)

    -- Move cursor to top-left
    io.write("\27[H")
    io.write(string.format("\27[1;36m=== GARDEN OF FORGOTTEN LIBRARIES === [CPU Temp: %.1f°C] ===\27[0m\n\n", temp))

    for _, lib in ipairs(libraries) do
        io.write(string.format("\27[1mArtifact: %-15s (Age: %2d yrs)\27[0m\n  Bloom: ", lib.name, lib.age))
        
        for _, c in ipairs(lib.crystals) do
            -- Grow crystals based on thermal energy
            if c.size < c.max_size then
                c.size = c.size + growth_rate
            end
            
            -- Render geometric crystal structure using ASCII/ANSI glyphs
            local facets = {".", "o", "◆", "█", "▓"}
            local f_idx = math.min(#facets, math.floor(c.size))
            io.write(lib.color .. string.rep(facets[f_idx], math.floor(c.size)) .. "\27[0m ")
        end
        io.write("\n\n")
    end

    io.write("\27[2m[Thermal feedback active: High temps accelerate crystal brittleness]\27[0m\n")
    io.flush()

    -- Frame pacing delay (~250ms)
    local start = os.clock()
    while os.clock() - start < 0.25 do end
end

-- Restore terminal cursor
io.write("\27[?25h\n")