-- Evolving Glitch-Folk Lullaby Compiler driven by Weather Radar & Pressure
-- Self-contained pure Lua script (Lua 5.3+ / LuaJIT) that simulates/ingests a
-- real-time radar + barometric stream, compiles a drifting folk lullaby with
-- glitch artifacts, and optionally renders a 16-bit mono WAV file ("lullaby.wav").

local math_sin, math_cos, math_pi, math_floor, math_abs, math_random =
    math.sin, math.cos, math.pi, math.floor, math.abs, math.random

local TAU = 2 * math_pi
local SAMPLE_RATE = 22050
local STANDARD_PRESSURE = 1013.25 -- hPa baseline

-- Folk lullaby motif in MIDI-like semitone offsets above C4 (60)
local FOLK_MOTIF = {
    { note = 0,  dur = 0.75 }, -- C4
    { note = 4,  dur = 0.50 }, -- E4
    { note = 7,  dur = 0.75 }, -- G4
    { note = 9,  dur = 0.50 }, -- A4
    { note = 7,  dur = 0.75 }, -- G4
    { note = 4,  dur = 0.50 }, -- E4
    { note = 2,  dur = 0.75 }, -- D4
    { note = 0,  dur = 1.00 }, -- C4
    { note = 4,  dur = 0.50 }, -- E4
    { note = 7,  dur = 0.50 }, -- G4
    { note = 12, dur = 1.00 }, -- C5
    { note = 9,  dur = 0.50 }, -- A4
    { note = 7,  dur = 0.50 }, -- G4
    { note = 4,  dur = 1.25 }, -- E4
}

-- Convert MIDI note + fractional detune (in semitones) to Hz
local function midi_to_hz(midi_note, detune_semitones)
    return 440.0 * (2.0 ^ (((midi_note + (detune_semitones or 0)) - 69.0) / 12.0))
end

-- Generate one synthetic real-time radar & barometric telemetry frame
local function sample_radar_frame(tick, pressure_hpa)
    -- Slowly sweeping barometric trough with micro-oscillations
    local p = pressure_hpa or (STANDARD_PRESSURE - 18.0 * math_sin(tick * 0.17) - (tick * 0.35))
    if p < 955.0 then p = 955.0 end
    if p > 1035.0 then p = 1035.0 end

    -- Simulate radar reflectivity (dBZ) across azimuth sectors & storm cells
    local sectors = 8
    local cells = {}
    local max_dbz = 5.0
    local mean_dbz = 0.0

    for s = 1, sectors do
        local sweep = math_sin(tick * 0.45 + s * 0.9) * math_cos(tick * 0.13 - s * 0.4)
        local dbz = 12.0 + 38.0 * math_abs(sweep) + 6.0 * math_sin(tick * 1.1 + s * 2.1)
        if dbz < 0 then dbz = 0 end
        cells[s] = dbz
        mean_dbz = mean_dbz + dbz
        if dbz > max_dbz then max_dbz = dbz end
    end
    mean_dbz = mean_dbz / sectors

    -- Glitch density rises as storms intensify and pressure falls
    local pressure_drop = math.max(0.0, STANDARD_PRESSURE - p)
    local glitch_prob = math.min(0.65, (pressure_drop / 60.0) * 0.45 + (max_dbz / 65.0) * 0.25)

    return {
        tick = tick,
        pressure_hpa = p,
        pressure_drop = pressure_drop,
        max_dbz = max_dbz,
        mean_dbz = mean_dbz,
        glitch_prob = glitch_prob,
        cells = cells,
    }
end

-- Compile a radar frame into a musical event with pressure-driven pitch drift
local function compile_event(frame, step_index, rng_state)
    local motif_step = FOLK_MOTIF[((step_index - 1) % #FOLK_MOTIF) + 1]

    -- As pressure drops, melodies drift flat/warped in a melancholic "barometric pull"
    -- plus a slow undulating wobble proportional to pressure deficit
    local drop = frame.pressure_drop
    local barometric_drift = -(drop / 22.0) -- up to ~2.5 semitones flat at ~55 hPa drop
    local wobble = math_sin(frame.tick * 0.6 + step_index) * (drop / 45.0)

    -- High radar reflectivity occasionally nudges a folk note into a modal neighbor
    local modal_shift = 0
    if frame.max_dbz > 42.0 and (step_index % 3 == 0) then
        modal_shift = -1 -- Dorian/Phrygian shadow under heavy rain
    end

    -- Radar sector dictates stereo/pan or harmonic overtone weight
    local sector = cells_dominant_sector and cells_dominant_sector(frame.cells) or ((step_index % #frame.cells) + 1)
    local radar_hz = 110.0 + frame.cells[sector] * 14.0

    -- Deterministic-friendly pseudo-randomness for reproducible glitch slices
    rng_state = (rng_state * 1664525 + 1013904223) % 4294967296
    local u = rng_state / 4294967296

    local glitch_mode = "clean"
    if u < frame.glitch_prob then
        if u < frame.glitch_prob * 0.45 then
            glitch_mode = "bitcrush"
        elseif u < frame.glitch_prob * 0.80 then
            glitch_mode = "stutter"
        else
            glitch_mode = "phase_tear"
        end
    end

    local base_midi = 60 + motif_step.note + modal_shift
    local total_detune = barometric_drift + wobble
    local freq = midi_to_hz(base_midi, total_detune)

    -- Tempo slows slightly as pressure drops (lullaby heavy with low pressure)
    local tempo_scale = 1.0 + math.min(0.45, drop / 120.0)
    local duration = motif_step.dur * 0.55 * tempo_scale

    return {
        step = step_index,
        base_midi = base_midi,
        detune = total_detune,
        freq = freq,
        radar_hz = radar_hz,
        duration = duration,
        glitch = glitch_mode,
        dbz = frame.max_dbz,
        pressure = frame.pressure_hpa,
    }, rng_state
end

-- Render a single compiled event into PCM samples [-1.0, 1.0]
local function render_event_samples(ev, sample_rate)
    local n_samples = math.max(1, math_floor(ev.duration * sample_rate))
    local out = {}
    local phase = 0.0
    local sub_phase = 0.0
    local radar_phase = 0.0

    -- Bit-depth reduction factor for "bitcrush" glitch mode
    local crush_levels = 16
    if ev.glitch == "bitcrush" then
        crush_levels = math.max(3, math_floor(14 - (ev.dbz / 10.0)))
    end

    -- Stutter slice length in samples
    local stutter_len = math.max(40, math_floor(sample_rate * 0.022))
    local stutter_buf = {}

    for i = 1, n_samples do
        local t = (i - 1) / sample_rate
        local progress = (i - 1) / n_samples

        -- Warm plucked/lullaby envelope: quick soft attack, gentle exponential decay
        local attack = math.min(1.0, progress / 0.06)
        local decay = (1.0 - progress) ^ 1.65
        local env = attack * decay

        -- Folk acoustic-like body: fundamental + soft 2nd & 3rd harmonics
        local tone = 0.65 * math_sin(phase)
                   + 0.22 * math_sin(phase * 2.0 + 0.3)
                   + 0.08 * math_sin(phase * 3.0)
                   + 0.12 * math_sin(sub_phase)

        -- Subtle radar echo shimmer
        local echo = 0.05 * math_sin(radar_phase) * (1.0 - progress)
        local sample = (tone + echo) * env * 0.65

        if ev.glitch == "bitcrush" then
            sample = math_floor(sample * crush_levels + 0.5) / crush_levels
        elseif ev.glitch == "stutter" then
            local idx = ((i - 1) % stutter_len) + 1
            if i <= stutter_len then
                stutter_buf[idx] = sample
            else
                -- Repeat early slice with occasional freeze/skip
                if math_floor(progress * 12) % 2 == 1 then
                    sample = stutter_buf[idx] * env
                end
            end
        elseif ev.glitch == "phase_tear" then
            -- Sudden pitch/phase jump mid-note
            if progress > 0.35 and progress < 0.70 then
                sample = math_sin(phase * 1.498 + math_sin(radar_phase) * 2.5) * env * 0.55
            end
        end

        -- Clamp safely
        if sample > 0.98 then sample = 0.98 end
        if sample < -0.98 then sample = -0.98 end
        out[i] = sample

        -- Advance phases with slight organic micro-drift
        local instant_freq = ev.freq * (1.0 + 0.0015 * math_sin(TAU * 4.5 * t))
        phase = (phase + TAU * instant_freq / sample_rate) % TAU
        sub_phase = (sub_phase + TAU * (ev.freq * 0.5) / sample_rate) % TAU
        radar_phase = (radar_phase + TAU * ev.radar_hz / sample_rate) % TAU
    end

    return out
end

-- Encode a flat sample table [-1.0, 1.0] as an uncompressed 16-bit mono PCM WAV
local function write_wav(filepath, samples, sample_rate)
    local num_samples = #samples
    local byte_rate = sample_rate * 2
    local data_bytes = num_samples * 2
    local chunk_size = 36 + data_bytes

    local function u16_le(n)
        n = math_floor(n) % 65536
        return string.char(n % 256, math_floor(n / 256) % 256)
    end

    local function u32_le(n)
        n = math_floor(n)
        local b0 = n % 256
        local b1 = math_floor(n / 256) % 256
        local b2 = math_floor(n / 65536) % 256
        local b3 = math_floor(n / 16777216) % 256
        return string.char(b0, b1, b2, b3)
    end

    local parts = {
        "RIFF",
        u32_le(chunk_size),
        "WAVE",
        "fmt ",
        u32_le(16),       -- PCM fmt chunk length
        u16_le(1),        -- Linear PCM
        u16_le(1),        -- Mono
        u32_le(sample_rate),
        u32_le(byte_rate),
        u16_le(2),        -- Block align
        u16_le(16),       -- Bits per sample
        "data",
        u32_le(data_bytes),
    }

    for i = 1, num_samples do
        local s = samples[i]
        if s > 1.0 then s = 1.0 elseif s < -1.0 then s = -1.0 end
        local pcm = math_floor(s * 32767)
        if pcm < 0 then pcm = pcm + 65536 end
        parts[#parts + 1] = u16_le(pcm)
    end

    local fh, err = io.open(filepath, "wb")
    if not fh then
        return false, err
    end
    fh:write(table.concat(parts))
    fh:close()
    return true
end

-- Format a compact ASCII bar for terminal telemetry inspection
local function bar(val, max_val, width)
    width = width or 16
    local ratio = math.max(0.0, math.min(1.0, val / max_val))
    local filled = math_floor(ratio * width + 0.5)
    return string.rep("#", filled) .. string.rep(".", width - filled)
end

-- Main compiler loop: ingests radar frames, compiles drifting lullaby, writes WAV
local function compile_glitch_folk_lullaby(total_steps, out_wav_path)
    total_steps = total_steps or 28
    out_wav_path = out_wav_path or "glitch_folk_lullaby.wav"

    local rng_state = 20261127
    local all_samples = {}

    io.write(string.format(
        "%-4s | %-9s | %-8s | %-7s | %-9s | %-10s | %s\n",
        "STEP", "PRESS(hPa)", "DRIFT(st)", "MAX_dBZ", "GLITCH", "FREQ(Hz)", "RADAR FIELD"
    ))
    io.write(string.rep("-", 82) .. "\n")

    for step = 1, total_steps do
        -- Simulate a storm system rolling through and slowly clearing
        local wave = math_sin((step - 1) / total_steps * math_pi)
        local pressure = STANDARD_PRESSURE - (34.0 * wave) + math_sin(step * 0.9) * 2.5

        local frame = sample_radar_frame(step, pressure)
        local ev
        ev, rng_state = compile_event(frame, step, rng_state)

        local ev_samples = render_event_samples(ev, SAMPLE_RATE)
        for i = 1, #ev_samples do
            all_samples[#all_samples + 1] = ev_samples[i]
        end

        io.write(string.format(
            "%-4d | %9.2f | %+8.2f | %7.1f | %-9s | %10.2f | [%s]\n",
            step,
            ev.pressure,
            ev.detune,
            ev.dbz,
            ev.glitch,
            ev.freq,
            bar(ev.dbz, 60.0, 14)
        ))
    end

    local ok, err = write_wav(out_wav_path, all_samples, SAMPLE_RATE)
    io.write(string.rep("-", 82) .. "\n")
    if ok then
        io.write(string.format(
            "Compiled %d events (%.2fs) -> %s\n",
            total_steps,
            #all_samples / SAMPLE_RATE,
            out_wav_path
        ))
    else
        io.write(string.format("WAV export skipped (%s); telemetry stream complete.\n", tostring(err)))
    end
end

compile_glitch_folk_lullaby(28, "glitch_folk_lullaby.wav")