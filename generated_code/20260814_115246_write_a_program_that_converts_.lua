-- Polyphonic Code Fugue & Spectrogram Art Generator
-- Converts this Lua script's source code into a 3-voice audio fugue.
-- Character frequencies dictate harmonic intervals; audio spectrogram reveals code text.

local sample_rate = 44100
local col_dur = 0.016 -- seconds per font column (16ms)
local col_samples = math.floor(sample_rate * col_dur)

-- 1. Self-reading code extraction
local src_info = debug.getinfo(1, "S").source
local file_path = src_info:sub(1, 1) == "@" and src_info:sub(2) or (arg and arg[0])
local code_file = io.open(file_path or "", "r")
local code = code_file and code_file:read("*a") or "local fugue = true"
if code_file then code_file:close() end

-- 2. Character frequency analysis to dictate musical harmony
local char_counts = {}
for i = 1, #code do
    local c = code:sub(i, i)
    char_counts[c] = (char_counts[c] or 0) + 1
end

local sorted_counts = {}
for c, count in pairs(char_counts) do
    table.insert(sorted_counts, {char = c, count = count})
end
table.sort(sorted_counts, function(a, b) return a.count > b.count end)

-- Harmonic ratios derived from the top character frequencies
local f1 = sorted_counts[1] and sorted_counts[1].count or 100
local f2 = sorted_counts[2] and sorted_counts[2].count or 75
local f3 = sorted_counts[3] and sorted_counts[3].count or 50

local ratio_answer = 1.0 + (f2 / f1) -- Harmonic ratio for Voice 2 (Answer)
local ratio_bass   = 0.5 + (f3 / f1) * 0.25 -- Harmonic ratio for Voice 3 (Bass)

-- 3. Compact 3x5 ASCII Font representation (3 columns per char, 5 bits per col)
local glyphs = {
    A={30,5,30}, B={31,21,10}, C={14,17,17}, D={31,17,14}, E={31,21,17},
    F={31,5,1},  G={14,17,29}, H={31,4,31},  I={17,31,17}, J={16,17,15},
    K={31,4,27}, L={31,16,16}, M={31,2,31},  N={31,6,31},  O={14,17,14},
    P={31,5,2},  Q={14,19,30}, R={31,5,26},  S={18,21,9},  T={1,31,1},
    U={15,16,15},V={7,24,7},   W={31,16,31}, X={27,4,27},  Y={3,28,3}, Z={19,21,25},
    ["0"]={14,17,14},["1"]={18,31,16},["2"]={23,21,29},["3"]={21,21,31},["4"]={7,4,31},
    ["5"]={29,21,23},["6"]={31,21,23},["7"]={1,29,3},  ["8"]={31,21,31},["9"]={29,21,31},
    [" "]={0,0,0},   ["="]={10,10,10},["+"]={4,14,4},  ["-"]={4,4,4},   ["*"]={21,14,21},
    ["/"]={16,8,2},  ["("]={0,14,17}, [")"]={17,14,0}, ["["]={0,31,17}, ["]"]={17,31,0},
    ["{"]={4,14,17}, ["}"]={17,14,4}, ["<"]={4,10,17}, [">"]={17,10,4}, ["."]={0,16,0},
    [","]={0,16,8},  [":"]={0,10,0},  [";"]={0,18,8},  ['"']={3,0,3},   ["'"]={1,2,0},
    ["_"]={16,16,16},["#"]={10,31,10},["%"]={19,4,25}, ["&"]={26,21,18},["!"]={0,23,0},
    ["\n"]={0,0,0},  ["\r"]={0,0,0},  ["\t"]={0,0,0}
}

local function get_glyph(c)
    local u = c:upper()
    return glyphs[u] or glyphs[c] or {31, 17, 31} -- Default frame for unknown chars
end

-- Convert code into bitmap column stream
local code_cols = {}
for i = 1, #code do
    local g = get_glyph(code:sub(i, i))
    table.insert(code_cols, g[1])
    table.insert(code_cols, g[2])
    table.insert(code_cols, g[3])
    table.insert(code_cols, 0) -- Character spacing
end
local total_cols = #code_cols

-- 4. Fugal Voice Setup (Subject, Answer, Bass)
local voices = {
    { base = 1200, step = 120, delay = 0,                            amp = 0.25 }, -- Subject
    { base = 1200 * ratio_answer, step = 120 * ratio_answer, delay = math.floor(total_cols * 0.12), amp = 0.20 }, -- Answer
    { base = 1200 * ratio_bass,   step = 120 * ratio_bass,   delay = math.floor(total_cols * 0.25), amp = 0.30 }  -- Bass
}

local max_end_col = 0
for _, v in ipairs(voices) do
    local end_col = v.delay + total_cols
    if end_col > max_end_col then max_end_col = end_col end
end

local total_samples = max_end_col * col_samples
local buffer = {}
for i = 1, total_samples do buffer[i] = 0 end

-- 5. Synthesize Polyphonic Fugue & Rasterize Spectrogram Text
for _, v in ipairs(voices) do
    local phase = {0, 0, 0, 0, 0}
    for col_idx = 1, total_cols do
        local mask = code_cols[col_idx]
        local sample_offset = (v.delay + col_idx - 1) * col_samples
        
        for s = 0, col_samples - 1 do
            local t_col = s / col_samples
            local env = math.sin(math.pi * t_col) -- Smooth organ-like envelope
            local sample_val = 0
            
            for r = 0, 4 do
                local bit = math.floor(mask / (2^r)) % 2
                local freq = v.base + (4 - r) * v.step -- Row 0 at top frequency
                phase[r + 1] = phase[r + 1] + (2 * math.pi * freq / sample_rate)
                if bit == 1 then
                    sample_val = sample_val + math.sin(phase[r + 1])
                end
            end
            
            local idx = sample_offset + s + 1
            buffer[idx] = buffer[idx] + sample_val * env * v.amp
        end
    end
end

-- 6. Output Uncompressed 16-bit PCM WAV File
local wav_name = "fugue_spectrogram.wav"
local wav = io.open(wav_name, "wb")
if wav then
    local data_size = total_samples * 2
    wav:write("RIFF")
    wav:write(string.pack("<I4", ") #chunk * + 1, 16)) 16, 1]="string.pack("<i2"," 2, 32767)) 36 buffer[i])) chunk="{}" chunk[#chunk data_size)) do for i="1," if local math.floor(val math.min(1.0, sample_rate sample_rate, total_samples val="math.max(-1.0," wav:write("WAVEfmt wav:write("data") wav:write(string.pack("<I4", wav:write(string.pack("<I4I2I2I4I4I2I2",>= 4096 then
            wav:write(table.concat(chunk))
            chunk = {}
        end
    end
    if #chunk > 0 then wav:write(table.concat(chunk)) end
    wav:close()
    print("Fugue generated: " .. wav_name)
end