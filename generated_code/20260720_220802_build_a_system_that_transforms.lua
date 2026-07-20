-- CPU Thermal Generative Soundscape Synthesizer
-- Reads CPU core temperatures and synthesizes a polyphonic, ambient WAV audio soundscape.

local SAMPLE_RATE = 22050
local DURATION_SECS = 12
local TOTAL_SAMPLES = SAMPLE_RATE * DURATION_SECS

-- Fetch real CPU temperatures across platforms or simulate dynamic core thermals
local function get_core_temperatures()
    local temps = {}
    -- Query Linux sysfs thermal zones
    local pipe = io.popen("cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null")
    if pipe then
        for line in pipe:lines() do
            local t = tonumber(line)
            if t then
                table.insert(temps, t > 1000 and (t / 1000) or t)
            end
        end
        pipe:close()
    end
    
    -- Fallback/Simulation if hardware thermal nodes are inaccessible
    if #temps == 0 then
        local clock = os.clock()
        for core = 1, 4 do
            local base = 38 + core * 4
            local noise = math.sin(clock * 1.5 + core) * 6 + math.cos(clock * 3.1 + core * 2) * 3
            table.insert(temps, base + noise)
        end
    end
    return temps
end

-- Binary packing helpers for standard 16-bit PCM WAV header generation
local function pack_le16(v)
    v = math.max(-32768, math.min(32767, math.floor(v)))
    if v < 0 then v = v + 65536 end
    return string.char(v % 256, math.floor(v / 256) % 256)
end

local function pack_le32(v)
    v = math.floor(v)
    return string.char(v % 256, math.floor(v / 256) % 256, math.floor(v / 65536) % 256, math.floor(v / 16777216) % 256)
end

local function make_wav_header(data_size)
    return "RIFF" .. pack_le32(36 + data_size) .. "WAVE" ..
           "fmt " .. pack_le32(16) .. pack_le16(1) .. pack_le16(1) ..
           pack_le32(SAMPLE_RATE) .. pack_le32(SAMPLE_RATE * 2) ..
           pack_le16(2) .. pack_le16(16) ..
           "data" .. pack_le32(data_size)
end

-- Render generative soundscape to file
local output_filename = "cpu_thermal_soundscape.wav"
local file = io.open(output_filename, "wb")

if file then
    local data_bytes = TOTAL_SAMPLES * 2
    file:write(make_wav_header(data_bytes))

    local temps = get_core_temperatures()
    local num_cores = #temps

    print(string.format("Generating soundscape from %d CPU core thermal channels...", num_cores))

    for i = 0, TOTAL_SAMPLES - 1 do
        local t = i / SAMPLE_RATE

        -- Periodically re-sample thermals to emulate real-time core fluctuations
        if i % math.floor(SAMPLE_RATE / 4) == 0 then
            temps = get_core_temperatures()
        end

        local master_signal = 0

        for core_id, temp in ipairs(temps) do
            -- Frequency mapped to core temp (Higher temp -> Higher microtonal pitch)
            local base_freq = 65 * math.pow(1.04, temp - 30) * (1 + (core_id - 1) * 0.2)
            
            -- Thermal pulse rhythm (Warmer cores pulse faster)
            local rhythm_rate = (temp / 12) * (0.8 + core_id * 0.3)
            local pulse = math.pow(math.max(0, math.sin(math.pi * t * rhythm_rate)), 3)

            -- Frequency Modulation (FM) synthesis for evolving tonal metallic textures
            local mod_index = (temp % 10) * 3
            local modulator = math.sin(2 * math.pi * (base_freq * 0.5) * t) * mod_index
            local carrier = math.sin(2 * math.pi * (base_freq + modulator) * t)
            
            -- Sub-drone harmonic for ambient weight
            local sub = math.sin(2 * math.pi * (base_freq * 0.5) * t) * 0.5

            master_signal = master_signal + (carrier + sub) * pulse * (0.4 / num_cores)
        end

        -- Soft clipping distortion/saturation to smooth peak dynamics
        local saturated_sample = math.tanh(master_signal) * 28000
        file:write(pack_le16(saturated_sample))
    end

    file:close()
    print("Soundscape successfully written to " .. output_filename)
end