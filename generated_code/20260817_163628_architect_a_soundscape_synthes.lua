-- process_soundscape.lua
-- Soundscape synthesizer converting call stack topology & memory into microtonal ambient audio.

local math_sin, math_exp, math_pi = math.sin, math.exp, math.pi

-- 1. Simulated Process State (Call Stack Topology & Memory Allocations)
local function sample_process_state()
    local stack_frames = {
        { id = 1, func = "main",           depth = 1, mem_bytes = 4096,  ptrs = {0x7fff51, 0x7fff58} },
        { id = 2, func = "event_loop",     depth = 2, mem_bytes = 16384, ptrs = {0x7fff60, 0x7fff80, 0x800100} },
        { id = 3, func = "render_scene",   depth = 3, mem_bytes = 65536, ptrs = {0x800200, 0x800f00} },
        { id = 4, func = "ray_march",      depth = 4, mem_bytes = 8192,  ptrs = {0x801000} },
        { id = 5, func = "evaluate_sdf",   depth = 5, mem_bytes = 1024,  ptrs = {0x801050, 0x8010a0} },
    }
    return stack_frames
end

-- 2. Microtonal Scale & Synthesis Utilities
-- Uses 19-Tone Equal Temperament (19-TET) for microtonal harmony
local BASE_FREQ = 110.0 -- A2 base frequency in Hz
local TET_19 = 2^(1/19)

local function frame_to_frequency(frame)
    local note_index = (frame.depth * 3 + #frame.ptrs * 2 + (frame.mem_bytes % 19)) % 19
    return BASE_FREQ * (TET_19 ^ note_index)
end

-- Generates a single PCM audio sample (Sine with exponential decay envelope)
local function synthesize_voice(freq, time, mem_bytes)
    local decay = 1.0 / (0.2 + (mem_bytes / 65536.0) * 1.5)
    local envelope = math_exp(-decay * (time % 2.0))
    local harmonic1 = math_sin(2 * math_pi * freq * time)
    local harmonic2 = 0.3 * math_sin(2 * math_pi * (freq * 1.5) * time) -- Perfect 5th overtone
    return (harmonic1 + harmonic2) * envelope
end

-- 3. Soundscape Audio Stream Synthesizer
local function generate_soundscape(duration_sec, sample_rate)
    sample_rate = sample_rate or 44100
    local total_samples = duration_sec * sample_rate
    local audio_buffer = {}
    
    local stack = sample_process_state()
    
    for i = 1, total_samples do
        local t = i / sample_rate
        local mixed_sample = 0.0
        
        -- Topology Mapping: Each frame in the stack acts as an active oscillator voice
        for _, frame in ipairs(stack) do
            local freq = frame_to_frequency(frame)
            local voice_signal = synthesize_voice(freq, t, frame.mem_bytes)
            -- Pan/amplitude weight based on stack depth
            local weight = 1.0 / frame.depth
            mixed_sample = mixed_sample + voice_signal * weight
        end
        
        -- Master gain normalization and soft clipping
        mixed_sample = math.max(-1.0, math.min(1.0, mixed_sample * 0.3))
        audio_buffer[i] = mixed_sample
    end
    
    return audio_buffer
end

-- 4. WAV File Exporter for self-contained, real audio playback/output
local function export_wav(filename, buffer, sample_rate)
    sample_rate = sample_rate or 44100
    local file = io.open(filename, "wb")
    if not file then return end

    local num_samples = #buffer
    local bytes_per_sample = 2
    local data_size = num_samples * bytes_per_sample

    -- Helper to write integers as little-endian bytes
    local function write_int(val, bytes)
        for i = 1, bytes do
            file:write(string.char(val % 256))
            val = math.floor(val / 256)
        end
    end

    -- Write RIFF Header
    file:write("RIFF")
    write_int(36 + data_size, 4)
    file:write("WAVE")
    file:write("fmt ")
    write_int(16, 4)              -- Subchunk1Size
    write_int(1, 2)               -- PCM format
    write_int(1, 2)               -- Mono channel
    write_int(sample_rate, 4)     -- Sample Rate
    write_int(sample_rate * 2, 4) -- Byte Rate
    write_int(2, 2)               -- Block Align
    write_int(16, 2)              -- Bits Per Sample
    file:write("data")
    write_int(data_size, 4)

    -- Write Audio Data (16-bit signed PCM)
    for i = 1, num_samples do
        local pcm_val = math.floor(buffer[i] * 32767)
        if pcm_val < 0 then pcm_val = pcm_val + 65536 end
        write_int(pcm_val, 2)
    end

    file:close()
end

-- Execution
local duration = 3 -- 3 seconds ambient soundscape
local sample_rate = 44100
local audio_data = generate_soundscape(duration, sample_rate)
export_wav("stack_soundscape.wav", audio_data, sample_rate)
print("Process soundscape successfully generated: stack_soundscape.wav (" .. #audio_data .. " samples)")