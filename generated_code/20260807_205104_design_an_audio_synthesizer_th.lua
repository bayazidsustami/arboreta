-- Microtonal Ambient Synthesizer
-- Translates x86 machine code into audio waveforms modulated by CPU core thermal state.

-- 1. Read System CPU Core Temperatures (Linux sysfs with fallback)
local function get_cpu_temperatures()
    local temps = {}
    local p = io.popen("ls /sys/class/thermal/thermal_zone*/temp 2>/dev/null")
    if p then
        for path in p:lines() do
            local f = io.open(path, "r")
            if f then
                local t = tonumber(f:read("*all") or "")
                if t then table.insert(temps, t > 1000 and (t / 1000) or t) end
                f:close()
            end
        end
        p:close()
    end
    -- Fallback synthetic core heat distribution if hardware sensors are inaccessible
    if #temps == 0 then
        temps = {42.5, 48.1, 45.3, 51.0, 44.2, 49.8, 46.0, 53.2}
    end
    return temps
end

-- 2. Microtonal Tuning & x86 Opcode Parsing
-- Generates frequencies based on 19-TET (19 Tone Equal Temperament) microtonal scale
local function opcode_to_frequency(byte, base_freq, tet_divisions)
    tet_divisions = tet_divisions or 19
    local octave = math.floor(byte / 32)
    local step = byte % tet_divisions
    return base_freq * (2 ^ (octave + step / tet_divisions))
end

-- Raw x86 Assembly Machine Bytes (Sample function kernel loop)
local x86_bytecode = {
    0x31, 0xC0,             -- xor eax, eax
    0x89, 0xC1,             -- mov ecx, eax
    0x40,                   -- inc eax
    0x83, 0xF8, 0x10,       -- cmp eax, 16
    0x75, 0xF9,             -- jne back
    0xC3,                   -- ret
    0x0F, 0x1F, 0x44, 0x00, -- nop
    0x8D, 0x4C, 0x24, 0x04  -- lea ecx, [esp+4]
}

-- 3. Soundscape Synthesis Engine
local SAMPLE_RATE = 44100
local DURATION = 8 -- Seconds of ambient soundscape
local NUM_SAMPLES = SAMPLE_RATE * DURATION

local temps = get_cpu_temperatures()
local pcm_data = {}

-- Fundamental pitch base per core (governed by core heat distribution)
local num_cores = #temps
local base_freqs = {}
for i, temp in ipairs(temps) do
    base_freqs[i] = 55.0 * (temp / 37.5)
end

for s = 0, NUM_SAMPLES - 1 do
    local t = s / SAMPLE_RATE
    local sample_val = 0

    -- Each x86 opcode byte creates a microtonal layer modulated by a CPU core's heat
    for idx, byte in ipairs(x86_bytecode) do
        local core_idx = ((idx - 1) % num_cores) + 1
        local heat_factor = temps[core_idx] / 50.0
        
        -- Microtonal base frequency mapping
        local freq = opcode_to_frequency(byte, base_freqs[core_idx], 19)
        
        -- FM synthesis modulation governed by x86 opcode byte and CPU thermal variance
        local mod_freq = freq * (0.5 + (byte % 7) * 0.1)
        local mod_depth = (byte % 13) * heat_factor * 4.0
        local modulation = math.sin(2 * math.pi * mod_freq * t) * mod_depth
        
        -- Slow ambient phase drift and LFO panning dynamics
        local lfo = math.sin(2 * math.pi * (0.04 + (core_idx * 0.015)) * t)
        local wave = math.sin(2 * math.pi * (freq + modulation) * t + lfo)
        
        sample_val = sample_val + (wave * (0.06 / #x86_bytecode) * heat_factor)
    end

    -- Soft clipping master limiter
    sample_val = math.max(-0.95, math.min(0.95, sample_val))
    
    -- Convert float sample to 16-bit PCM integer
    local pcm_16 = math.floor(sample_val * 32767)
    table.insert(pcm_data, pcm_16)
end

-- 4. WAV File Exporter
local function write_wav(filename, samples, sample_rate)
    local f = assert(io.open(filename, "wb"))
    local num_channels = 1
    local bits_per_sample = 16
    local byte_rate = sample_rate * num_channels * (bits_per_sample / 8)
    local block_align = num_channels * (bits_per_sample / 8)
    local data_size = #samples * (bits_per_sample / 8)

    local function write_int(val, bytes)
        for i = 1, bytes do
            f:write(string.char(val % 256))
            val = math.floor(val / 256)
        end
    end

    f:write("RIFF")
    write_int(36 + data_size, 4)
    f:write("WAVE")
    f:write("fmt ")
    write_int(16, 4)             -- Subchunk1Size
    write_int(1, 2)              -- PCM Format
    write_int(num_channels, 2)   -- Channels
    write_int(sample_rate, 4)    -- Sample Rate
    write_int(byte_rate, 4)      -- Byte Rate
    write_int(block_align, 2)    -- Block Align
    write_int(bits_per_sample, 2)-- Bits Per Sample
    f:write("data")
    write_int(data_size, 4)
    
    for _, sample in ipairs(samples) do
        if sample < 0 then sample = sample + 65536 end
        write_int(sample, 2)
    end
    
    f:close()
end

write_wav("x86_thermal_ambient.wav", pcm_data, SAMPLE_RATE)
print("Microtonal ambient soundscape generated: x86_thermal_ambient.wav")