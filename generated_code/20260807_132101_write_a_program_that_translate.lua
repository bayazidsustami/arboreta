-- Git Commit History to Polyphonic Audio Generator (WAV Output)
-- Translates git history into a musical composition:
--   - Regular commits generate melodic pitch notes
--   - Branch merges produce harmonic chord triads
--   - Force pushes cause abrupt key shifts (transpositions)
--   - Memory leaks alter tempo/BPM dynamically in real time

local sample_rate = 44100
local scale_intervals = {0, 2, 4, 5, 7, 9, 11, 12} -- Major scale intervals
local current_key_offset = 0                      -- Transposition in semitones

-- Convert scale index & key shift to frequency (A3 = 220Hz baseline)
local function note_to_freq(note_index, key_shift)
    local semitones = scale_intervals[(note_index % #scale_intervals) + 1] + 
                      math.floor(note_index / #scale_intervals) * 12 + key_shift
    return 220 * (2 ^ (semitones / 12))
end

-- Sample Git History representing events in a project
local git_history = {
    { type = "commit", message = "Initial commit", hash = "a1b2c3d" },
    { type = "commit", message = "Add user authentication module", hash = "b2c3d4e" },
    { type = "commit", message = "Fix typo in documentation", hash = "c3d4e5f" },
    { type = "merge", message = "Merge branch 'feature/auth' into main", hash = "d4e5f6a" },
    { type = "commit", message = "Refactor database queries", hash = "e5f6a7b" },
    { type = "memory_leak", message = "WIP: cache query results without eviction", hash = "f6a7b8c" },
    { type = "commit", message = "Optimize image processing", hash = "a7b8c9d" },
    { type = "force_push", message = "Rewrite history to remove sensitive credentials", hash = "b8c9d0e" },
    { type = "commit", message = "Fix broken tests after rewrite", hash = "c9d0e1f" },
    { type = "merge", message = "Merge branch 'feature/payments' into main", hash = "d0e1f2a" },
    { type = "memory_leak", message = "Unclosed file handles in log processor", hash = "e1f2a3b" },
    { type = "commit", message = "Hotfix memory release in loop", hash = "f2a3b4c" },
    { type = "merge", message = "Merge branch 'release/v1.0' into main", hash = "a3b4c5d" }
}

local bpm = 120
local audio_samples = {}

-- Synthesizes sine wave with smooth ADSR attack/release envelope
local function generate_sine(freq, duration, amplitude)
    local num_samples = math.floor(sample_rate * duration)
    local samples = {}
    local attack = sample_rate * 0.02
    local release = sample_rate * 0.1

    for i = 1, num_samples do
        local t = (i - 1) / sample_rate
        local env = 1.0
        if i < attack then
            env = i / attack
        elseif i > (num_samples - release) then
            env = (num_samples - i) / release
        end
        samples[i] = math.sin(2 * math.pi * freq * t) * amplitude * env
    end
    return samples
end

print("Translating Git history into sound waves...")

-- Process git events into audio
for idx, commit in ipairs(git_history) do
    local beat_duration = 60 / bpm
    
    if commit.type == "force_push" then
        -- Force push: Abrupt key shift (+5 semitones)
        current_key_offset = current_key_offset + 5
        print(string.format("[%s] FORCE PUSH -> Key shift! Transposed +5 semitones.", commit.hash))
        local glitch = generate_sine(880, beat_duration * 0.4, 0.4)
        for _, s in ipairs(glitch) do table.insert(audio_samples, s) end

    elseif commit.type == "memory_leak" then
        -- Memory leak: Accelerates tempo dramatically + dissonant tone
        bpm = bpm + 40
        print(string.format("[%s] MEMORY LEAK -> Tempo accelerated to %d BPM!", commit.hash, bpm))
        local freq = note_to_freq(idx, current_key_offset + 1) -- Dissonant minor 2nd
        local leak_tone = generate_sine(freq, beat_duration, 0.5)
        for _, s in ipairs(leak_tone) do table.insert(audio_samples, s) end

    elseif commit.type == "merge" then
        -- Branch merge: Harmonic chord (Triad - Root, Major 3rd, Perfect 5th)
        print(string.format("[%s] MERGE -> Harmonic Chord Triad", commit.hash))
        local f1 = note_to_freq(idx, current_key_offset)
        local f2 = note_to_freq(idx + 2, current_key_offset)
        local f3 = note_to_freq(idx + 4, current_key_offset)
        
        local w1 = generate_sine(f1, beat_duration * 1.5, 0.25)
        local w2 = generate_sine(f2, beat_duration * 1.5, 0.25)
        local w3 = generate_sine(f3, beat_duration * 1.5, 0.25)
        
        for i = 1, #w1 do
            table.insert(audio_samples, w1[i] + w2[i] + w3[i])
        end

    else
        -- Normal commit: Melodic single note derived from commit hash
        local hash_val = tonumber(commit.hash:sub(1, 2), 16) or idx
        local note_idx = hash_val % 8
        local freq = note_to_freq(note_idx, current_key_offset)
        print(string.format("[%s] COMMIT -> Note: %.1f Hz", commit.hash, freq))
        local note = generate_sine(freq, beat_duration, 0.3)
        for _, s in ipairs(note) do table.insert(audio_samples, s) end
    end
end

-- Binary packing helpers for WAV header construction
local function pack_int16(val)
    val = math.max(-32768, math.min(32767, math.floor(val)))
    if val < 0 then val = val + 65536 end
    return string.char(val % 256, math.floor(val / 256) % 256)
end

local function pack_int32(val)
    return string.char(
        val % 256,
        math.floor(val / 256) % 256,
        math.floor(val / 65536) % 256,
        math.floor(val / 16777216) % 256
    )
end

-- Generate PCM WAV output file
local data_size = #audio_samples * 2
local file_size = 36 + data_size

local header = "RIFF" .. pack_int32(file_size) .. "WAVE" ..
               "fmt " .. pack_int32(16) .. pack_int16(1) .. pack_int16(1) ..
               pack_int32(sample_rate) .. pack_int32(sample_rate * 2) ..
               pack_int16(2) .. pack_int16(16) ..
               "data" .. pack_int32(data_size)

local file = io.open("git_composition.wav", "wb")
if file then
    file:write(header)
    for _, sample in ipairs(audio_samples) do
        file:write(pack_int16(sample * 32700))
    end
    file:close()
    print("\nAudio successfully saved to 'git_composition.wav'!")
end