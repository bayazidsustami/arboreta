-- Generative galaxy-to-music script
-- Maps light wavelength (nm) to pitch (MIDI note) and stellar age (Myr) to tempo (BPM)

-- Mock dataset: {name, wavelength_nm, age_myr}
local galaxies = {
    {"Andromeda", 400, 1200},
    {"Sombrero", 550, 800},
    {"Whirlpool", 700, 500},
    {"Messier 87", 350, 2000},
    {"Centaurus A", 600, 1500},
}

-- Convert wavelength (nm) to frequency (THz) using c = λ·ν
local function wavelength_to_frequency_nm(wl_nm)
    local c = 299792.458 -- speed of light in nm·THz
    return c / wl_nm
end

-- Map frequency (THz) to MIDI note (0-127). 440 Hz = A4 = MIDI 69.
-- 1 THz = 1 000 000 Hz
local function frequency_to_midi(freq_thz)
    local freq_hz = freq_thz * 1e12
    local midi = 69 + 12 * math.log(freq_hz / 440, 2)
    return math.max(0, math.min(127, math.floor(midi + 0.5)))
end

-- Map age (Myr) to tempo (BPM). Younger => faster.
local function age_to_bpm(age_myr)
    local min_bpm, max_bpm = 60, 180
    local max_age = 2000 -- assume upper bound in dataset
    local bpm = max_bpm - (age_myr / max_age) * (max_bpm - min_bpm)
    return math.max(min_bpm, math.min(max_bpm, math.floor(bpm + 0.5)))
end

-- Simple note representation
local function note_to_string(midi)
    local names = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}
    local octave = math.floor(midi / 12) - 1
    local name = names[(midi % 12) + 1]
    return name .. octave
end

-- Generate composition data
local composition = {}
for _, g in ipairs(galaxies) do
    local name, wl, age = g[1], g[2], g[3]
    local freq = wavelength_to_frequency_nm(wl)
    local midi = frequency_to_midi(freq)
    local bpm = age_to_bpm(age)
    table.insert(composition, {
        galaxy = name,
        pitch = note_to_string(midi),
        midi  = midi,
        tempo = bpm,
    })
end

-- Output the "score"
print("=== Galactic Sonification ===")
for _, part in ipairs(composition) do
    print(string.format(
        "Galaxy: %-12s | Pitch: %-3s (MIDI %3d) | Tempo: %3d BPM",
        part.galaxy, part.pitch, part.midi, part.tempo
    ))
end

-- Simple playback simulation (seconds per beat)
local function simulate_playback(comp)
    for _, part in ipairs(comp) do
        local beat_sec = 60 / part.tempo
        print(string.format("\nPlaying %s: %s at %d BPM (%.2fs per beat)",
            part.galaxy, part.pitch, part.tempo, beat_sec))
        for i = 1, 4 do -- four beats per galaxy
            io.write(string.format("Beat %d: %s ", i, part.pitch))
            io.flush()
            os.execute("sleep " .. beat_sec) -- Unix; on Windows replace with timeout
        end
        print("\n---")
    end
end

-- Uncomment the following line to hear the timing simulation (requires sleep command)
-- simulate_playback(composition)