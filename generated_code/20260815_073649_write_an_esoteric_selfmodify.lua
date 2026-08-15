-- Esoteric Self-Modifying Audio Synthesis Engine for Log-Driven Ambient Soundscapes
-- Converts system logs into self-rewriting DSP code where:
--   - Stack traces dynamically inject harsh FM modulators (harmonic dissonance)
--   - Memory leaks scale feedback decay times (rhythmic/reverb decay modulation)

local math = math
local table = table
local string = string

-- DSL Context & Audio Buffer Settings
local SAMPLE_RATE = 44100
local DURATION_SEC = 6
local TOTAL_SAMPLES = SAMPLE_RATE * DURATION_SEC
local audio_buffer = {}

-- DSL AST State / Self-Modifying Memory Engine
local dsl_ast = {
    root_freq = 110.0, -- Base A2 carrier frequency
    fm_index = 0.0,    -- Driven by stack traces (0 = pure sine, high = harsh dissonance)
    decay_rate = 0.95, -- Driven by memory leaks (slow decay / infinite feedback)
    time_step = 0
}

-- DSL Opcode: Synthesizes a single audio frame from current AST state
local function render_dsl_frame(ast, t)
    -- Carrier wave base
    local carrier = math.sin(2 * math.pi * ast.root_freq * t)
    
    -- Stack trace injection: High FM index introduces violent harmonic sidebands
    local modulator = math.sin(2 * math.pi * (ast.root_freq * 1.618) * t) * ast.fm_index
    local fm_signal = math.sin(2 * math.pi * ast.root_freq * t + modulator)
    
    -- Memory leak injection: Envelope decay rate evolves over time
    local env = math.exp(-ast.decay_rate * (t % 1.0))
    
    -- Mix signals
    return (carrier * 0.4 + fm_signal * 0.6) * env
end

-- Self-Modifying Engine Metatable
-- The DSL rewrites its own AST evaluation rules based on log ingestion
setmetatable(dsl_ast, {
    __call = function(self, log_line)
        -- Self-Modification Rule 1: Stack trace pattern detection
        local trace_depth = select(2, string.gsub(log_line, "at ", ""))
        if string.find(log_line, "Exception") or string.find(log_line, "Error") or trace_depth > 0 then
            -- Mutate AST harmonic dissonance parameters
            self.fm_index = self.fm_index + 1.5 + (trace_depth * 0.8)
            self.root_freq = self.root_freq * 1.05946 -- Shift up a semitone
        else
            -- Cool down dissonance gradually
            self.fm_index = math.max(0.0, self.fm_index * 0.85)
        end

        -- Self-Modification Rule 2: Memory leak pattern detection (hex pointers / byte counts)
        local leak_bytes = string.match(log_line, "leaked%s+(%d+)") or string.match(log_line, "0x%x+")
        if leak_bytes then
            local amount = tonumber(leak_bytes) or 1024
            -- Modulate decay rate towards infinite feedback / sustained drone
            self.decay_rate = math.max(0.05, self.decay_rate - (amount / 100000))
        else
            -- Restores natural decay standard
            self.decay_rate = math.min(3.0, self.decay_rate + 0.1)
        end
    end
})

-- Sample Input: Raw System Log Stream
local log_stream = {
    "[INFO] System initialized. Allocating buffers.",
    "[INFO] Process 4021 running normally at 0x7fff5fbff000",
    "[ERROR] NullPointerException at com.engine.Core.step(Core.java:42)",
    "[ERROR]   at com.engine.Audio.process(Audio.java:108)",
    "[ERROR]   at com.engine.Main.loop(Main.java:12)",
    "[WARN] Memory leak detected: leaked 40960 bytes at 0x004a2f",
    "[WARN] Memory leak detected: leaked 184320 bytes at 0x004a8e",
    "[INFO] Garbage collector invoked.",
    "[FATAL] StackOverflowError at dsl_eval (native code)"
}

-- Execution Loop: Log Parsing -> AST Self-Modification -> DSP Audio Synthesis
local current_log_idx = 1
local log_interval = math.floor(TOTAL_SAMPLES / #log_stream)

for i = 1, TOTAL_SAMPLES do
    local t = i / SAMPLE_RATE

    -- Self-modify AST every time a new log line is ingested
    if i % log_interval == 1 and current_log_idx <= #log_stream then
        dsl_ast(log_stream[current_log_idx])
        current_log_idx = current_log_idx + 1
    end

    -- Render DSP frame from modified state
    local sample = render_dsl_frame(dsl_ast, t)
    
    -- Hard limiter clipping protection [-1.0, 1.0]
    sample = math.max(-1.0, math.min(1.0, sample))
    table.insert(audio_buffer, sample)
end

-- Export DSP buffer to raw 16-bit PCM Audio WAV Format
local function write_wav(filename, samples)
    local file = io.open(filename, "wb")
    if not file then return end

    local num_samples = #samples
    local data_size = num_samples * 2
    local file_size = 36 + data_size

    -- Write WAV Header
    file:write("RIFF", string.pack("<I4", ", "WAVE") * -- 1)) 1), 16)) 16), 16-bit 2)) 2), 32767) Audio Generator PCM Run SAMPLE_RATE SAMPLE_RATE), Samples Write _, audio_buffer) data_size)) do end file:close() file:write("data", file:write("fmt file:write(string.pack("<I2", file:write(string.pack("<I4", file:write(string.pack("<i2", file_size), for in int_sample="math.floor(s" int_sample)) ipairs(samples) local s string.pack("<I2", string.pack("<I4", write_wav("ambient_logscape.wav",>