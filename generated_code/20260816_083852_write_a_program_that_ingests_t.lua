-- Bytecode-Driven Infinite Fractal Canvas
-- Ingests its own compiled function bytecode and translates every byte into
-- an algorithmic rule set to mutate an infinite self-drawing fractal in real time.

-- 1. Bytecode Ingestion: Dump function bytecode into a raw byte stream
local function source_dna(a, b, c)
    local x = (a or 1.5) * math.sin(b or 0.7) + math.cos(c or 0.3)
    local y = function(t) return math.exp(-t) * math.tan(x) end
    return x, y
end

local bytecode = string.dump(source_dna)
local bytes = { string.byte(bytecode, 1, #bytecode) }

-- 2. Algorithmic Rule Set Translation: Map each byte to dynamic fractal parameters
local rules = {}
for i, b in ipairs(bytes) do
    rules[i] = {
        weight = b / 255,
        freq   = 0.05 + (b % 17) * 0.02,
        phase  = (b % 31) / 31 * math.pi * 2,
        mode   = b % 5,
        cr     = ((b % 19) - 9) / 10,
        ci     = (math.floor(b / 19) % 19 - 9) / 10
    }
end

-- Terminal Canvas Setup
local W, H = 55, 30
io.write("\27[2J\27[?25l") -- Clear screen and hide cursor

-- Cross-platform frame timer helper
local function sleep(sec)
    local t0 = os.clock()
    while os.clock() - t0 < sec do end
end

-- 3. Real-Time Infinite Canvas Mutation Loop
local time = 0
local num_rules = #rules

while true do
    -- Dynamic view trajectory through infinite fractal space
    local zoom = 1.2 + math.sin(time * 0.15) * 0.6
    local cx   = math.cos(time * 0.08) * 0.6
    local cy   = math.sin(time * 0.05) * 0.6
    local rot  = time * 0.03
    local cos_r, sin_r = math.cos(rot), math.sin(rot)

    local buffer = { "\27[H" }

    for y = 0, H - 1 do
        for x = 0, W - 1 do
            -- Map screen coordinates into complex coordinate space
            local nx = (x / (W - 1) - 0.5) * 2.5 * zoom
            local ny = (y / (H - 1) - 0.5) * 2.0 * zoom

            -- Rotate and translate viewport
            local zr = nx * cos_r - ny * sin_r + cx
            local zi = nx * sin_r + ny * cos_r + cy

            local iter = 0
            local max_iter = 20
            local escaped = false
            local active_rule = rules[1]

            -- Mutate orbit trajectory sequentially through the bytecode rule set
            for k = 1, max_iter do
                local r = rules[(k - 1) % num_rules + 1]
                local wave = r.weight * math.sin(time * r.freq + r.phase)

                local zr2, zi2 = zr * zr, zi * zi
                if zr2 + zi2 > 4.0 then
                    escaped = true
                    iter = k
                    active_rule = r
                    break
                end

                local cr = r.cr + wave
                local ci = r.ci + wave

                -- Apply bytecode opcode transformations
                if r.mode == 0 then
                    zr, zi = zr2 - zi2 + cr, 2 * zr * zi + ci
                elseif r.mode == 1 then
                    zr, zi = zr2 - zi2 + cr, math.abs(2 * zr * zi) + ci
                elseif r.mode == 2 then
                    local tr, ti = zr2 - zi2 + cr, 2 * zr * zi + ci
                    zr = tr * math.cos(wave) - ti * math.sin(wave)
                    zi = tr * math.sin(wave) + ti * math.cos(wave)
                elseif r.mode == 3 then
                    zr, zi = zr2 - zi2 + cr, -2 * zr * zi + ci
                else
                    zr = zr2 - zi2 + cr + math.sin(zi * 1.5) * 0.1
                    zi = 2 * zr * zi + ci + math.cos(zr * 1.5) * 0.1
                end
            end

            -- 4. Color Rendering: Synthesize byte parameters & orbit state into 24-bit ANSI colors
            if not escaped then
                buffer[#buffer + 1] = "\27[48;2;0;0;0m  "
            else
                local norm = iter / max_iter
                local hue = (norm * 360 + time * 30 + active_rule.weight * 180) % 360
                local rad = hue * (math.pi / 180)

                local red   = math.floor(127.5 * (1 + math.sin(rad)))
                local green = math.floor(127.5 * (1 + math.sin(rad + 2.094)))
                local blue  = math.floor(127.5 * (1 + math.sin(rad + 4.188)))

                buffer[#buffer + 1] = string.format("\27[48;2;%d;%d;%dm  ", red, green, blue)
            end
        end
        buffer[#buffer + 1] = "\27[0m\n"
    end

    -- Render frame buffer atomically to terminal
    io.write(table.concat(buffer))
    io.flush()

    time = time + 0.05
    sleep(0.03)
end