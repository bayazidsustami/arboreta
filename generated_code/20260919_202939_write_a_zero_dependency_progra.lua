-- VerseLang: An esoteric poetry-to-MIDI & self-referential Julia fractal engine in pure Lua
local self_src = [[
local function parse_poetry(text)
    for line in text:gmatch("[^\r\n]+") do
        local freqs = {}
        for i = 1, #line do
            local midi = 60 + (line:byte(i) % 24)
            table.insert(freqs, string.format("%.1fHz", 440 * (2^((midi - 69) / 12))))
        end
    end
end
]]

local poem = [[
  Silent shadows fall,
  Dancing notes on silver strings,
  Echoes of the dawn.
]]

-- Compiles ASCII poetry into valid MIDI frequencies
local function parse_poetry(text)
    print("--- COMPILING POETRY TO MIDI FREQUENCIES ---")
    for line in text:gmatch("[^\r\n]+") do
        if line:match("%S") then
            local freqs = {}
            for i = 1, #line do
                local byte = line:byte(i)
                local midi_note = 60 + (byte % 24)
                local freq = 440 * (2 ^ ((midi_note - 69) / 12))
                table.insert(freqs, string.format("%.1fHz", freq))
            end
            print(string.format("Verse: '%s'\n -> Frequencies: [%s]\n", line:match("^%s*(.-)%s*$"), table.concat(freqs, ", ")))
        end
    end
end

-- Renders a dynamic ASCII Julia fractal using the source code as its palette
local function render_julia(frame)
    local w, h = 50, 16
    local c_re = -0.7 + math.sin(frame * 0.15) * 0.08
    local c_im = 0.27015 + math.cos(frame * 0.1) * 0.08
    
    print("\033[H\033[2J")
    print("=== DYNAMIC SOURCE-CODE JULIA FRACTAL (Frame " .. frame .. ") ===")
    
    local src_len = #self_src
    for y = 0, h - 1 do
        local line = {}
        for x = 0, w - 1 do
            local z_re = 1.5 * (x - w / 2) / (0.4 * w)
            local z_im = (y - h / 2) / (0.4 * h)
            local n = 0
            local max_iter = 20
            while n < max_iter and (z_re * z_re + z_im * z_im) <= 4 do
                local t_re = z_re * z_re - z_im * z_im + c_re
                z_im = 2 * z_re * z_im + c_im
                z_re = t_re
                n = n + 1
            end
            if n == max_iter then
                table.insert(line, " ")
            else
                local char_idx = (n * 3) % src_len + 1
                table.insert(line, self_src:sub(char_idx, char_idx))
            end
        end
        print(table.concat(line))
    end
end

parse_poetry(poem)
print("Rendering live source-code fractal...")
for f = 1, 15 do
    render_julia(f)
    os.execute("sleep 0.12")
end