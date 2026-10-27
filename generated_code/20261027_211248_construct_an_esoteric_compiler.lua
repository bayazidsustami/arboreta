-- Esoteric Water-Log to Polyphonic Jellyfish Soundscape Compiler
-- Pure Lua implementation translating municipal water consumption into a cellular automaton of wandering ASCII jellyfish and a live polyphonic frequency stream.

local water_logs = {45, 62, 88, 110, 240, 310, 180, 95, 50, 42, 38, 70}
local width, height = 48, 14
local scale = {130.81, 146.83, 164.81, 196.00, 220.00, 261.63} -- C3 pentatonic scale
local jellyfish = {}

math.randomseed(os.time() or 1)

-- Initialize jellyfish swarm from water consumption spikes
for i, flow in ipairs(water_logs) do
    table.insert(jellyfish, {
        x = math.random(2, width - 1),
        y = math.random(2, height - 1),
        vx = math.random(-1, 1),
        vy = math.random(-1, 1),
        energy = flow,
        base_note = scale[((i - 1) % #scale) + 1]
    })
end

io.write("\27[2J") -- Clear terminal

local function run_compiler()
    for step = 1, 25 do
        local grid = {}
        for y = 1, height do
            grid[y] = {}
            for x = 1, width do
                grid[y][x] = "."
            end
        end

        local polyphony = {}
        for _, j in ipairs(jellyfish) do
            -- Automaton / wandering logic with toroidal wrap
            j.x = j.x + j.vx
            j.y = j.y + j.vy

            if j.x < 1 then j.x = width; j.vx = -j.vx end
            if j.x > width then j.x = 1; j.vx = -j.vx end
            if j.y < 1 then j.y = height; j.vy = -j.vy end
            if j.y > height then j.y = 1; j.vy = -j.vy end

            if math.random() < 0.3 then
                j.vx = math.random(-1, 1)
                j.vy = math.random(-1, 1)
            end

            -- Jellyfish glyph based on water consumption energy
            local glyph = j.energy > 250 and "O" or (j.energy > 120 and "~" or "*")
            grid[math.floor(j.y)][math.floor(j.x)] = glyph

            -- Synthesize polyphonic frequency modulation
            local freq = j.base_note * (1.0 + (j.y / height) * 0.5)
            table.insert(polyphony, string.format("%.1fHz", freq))
        end

        -- Render frame and soundscape state
        io.write("\27[H")
        io.write("=== MUNICIPAL WATER -> POLYPHONIC JELLYFISH COMPILER ===\n")
        io.write(string.format("Clock Cycle: %02d | Active Frequencies: %d voices\n", step, #polyphony))
        io.write("+" .. string.rep("-", width) + "+\n")
        for y = 1, height do
            io.write("|")
            for x = 1, width do
                io.write(grid[y][x])
            end
            io.write("|\n")
        end
        io.write("+" .. string.rep("-", width) + "+\n")
        io.write("Soundscape Stream: " .. table.concat(polyphony, " | ") .. "\n")

        os.execute("sleep 0.12")
    end
end

run_compiler()