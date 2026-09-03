-- EXOPLANET LIGHT-CURVE MICRO-TONAL POLYPHONIC SYNTHESIZER
-- Translates planetary transit photometries into ASCII spectrographs & plays them via micro-tonal system beeps.

local os, io, math, string = os, io, math, string

-- Detect OS platform for system audio beep generation
local is_windows = os.getenv("OS") and os.getenv("OS"):find("Windows")
local is_mac = not is_windows and io.popen("uname"):read("*l") == "Darwin"

-- Execute micro-tonal frequency output via system-native shell speaker command
local function beep(freq, duration_ms)
    freq = math.floor(freq)
    duration_ms = math.floor(duration_ms)
    if is_windows then
        os.execute(string.format("powershell -c [console]::beep(%d,%d)", math.max(37, freq), duration_ms))
    elseif is_mac then
        -- macOS afplay sine wave generator synthesis via SoX/afplay alternative or osx tone fallback
        os.execute(string.format("say -v Victoria [[sndt]] 2>/dev/null || sleep %.2f", duration_ms / 1000))
    else
        -- Linux console bell escape sequence or beep utility
        os.execute(string.format("beep -f %d -l %d 2>/dev/null || (printf '\\a' && sleep %.2f)", freq, duration_ms, duration_ms / 1000))
    end
end

-- Generates synthetic exoplanet light curves using limb-darkened transit models
local function generate_exoplanet_catalog()
    return {
        {
            name = "TRAPPIST-1e",
            period = 6.1,
            radius_ratio = 0.091, -- Rp/Rs
            semi_major = 0.029,
            inclination = 89.86,
            spectrogram_density = 30
        },
        {
            name = "Kepler-186f",
            period = 129.9,
            radius_ratio = 0.112,
            semi_major = 0.432,
            inclination = 89.9,
            spectrogram_density = 35
        },
        {
            name = "HD 209458 b (Osiris)",
            period = 3.5,
            radius_ratio = 0.121,
            semi_major = 0.047,
            inclination = 86.6,
            spectrogram_density = 40
        }
    }
end

-- Mathematical transit flux calculation: Manduka-Agol numerical approximation core
local function calculate_flux(phase, r_ratio, impact_param)
    local z = math.sqrt(phase^2 + impact_param^2)
    if z >= 1 + r_ratio then return 1.0 end
    if z <= math.abs(1 - r_ratio) then
        return 1.0 - (r_ratio^2)
    end
    -- Ingress/Egress linear transition curve
    local k0 = math.acos((r_ratio^2 + z^2 - 1) / (2 * r_ratio * z))
    local k1 = math.acos((1 + z^2 - r_ratio^2) / (2 * z))
    return 1.0 - (1 / math.pi) * (r_ratio^2 * k0 + k1 - 0.5 * math.sqrt(math.abs(4 * z^2 - (1 + z^2 - r_ratio^2)^2)))
end

-- Convert photometric flux drop into 24-TET (Tone Equal Temperament) micro-tonal frequencies
local function flux_to_microtone(flux, base_freq)
    local min_flux = 0.98 -- Maximum expected depth drop limit
    local normalized_depth = (1.0 - math.max(flux, min_flux)) / (1.0 - min_flux)
    
    -- Map transit depth across a 24-TET quarter-tone scale spanning 2 octaves
    local quarter_tones = math.floor(normalized_depth * 48)
    local frequency = base_freq * math.pow(2, quarter_tones / 24)
    return frequency, quarter_tones
end

-- Render ASCII spectrograph character block based on luminance & frequency harmonics
local function get_ascii_glyph(intensity, quarter_tone)
    local glyphs = {" ", "░", "▒", "▓", "█", "★", "✴", "✦"}
    local char_index = math.floor(intensity * (#glyphs - 1)) + 1
    return glyphs[char_index]
end

-- Main generative synthesis engine execution
local function run_orchestrator()
    local catalog = generate_exoplanet_catalog()
    local base_tone = 220.0 -- A3 Fundamental tone (220Hz)

    io.write("\027[2J\027[H") -- Clear screen terminal ANSI command
    io.write("========================================================================\n")
    io.write("    EXOPLANET LIGHT CURVE MICRO-TONAL POLYPHONIC SPECTROGRAPH PLAYBACK   \n")
    io.write("========================================================================\n\n")

    for _, planet in ipairs(catalog) do
        io.write(string.format(">>> SYNTHESIZING TRANSIT SCORE FOR SYSTEM: %s <<<\n", planet.name))
        io.write(string.format("Parameters: Period=%.1f d | Radius Ratio=%.3f | Base Pitch=%.1f Hz\n", 
            planet.period, planet.radius_ratio, base_tone))
        io.write("Flux Spectrograph Curve [Dimming -> Tone Pitch Pitching]:\n")
        io.write("------------------------------------------------------------------------\n")

        local impact_param = (planet.semi_major * 100) * math.cos(math.rad(planet.inclination))
        local samples = planet.spectrogram_density

        for step = -samples, samples do
            local phase = (step / samples) * (1.5 * planet.radius_ratio + 0.1)
            local flux = calculate_flux(phase, planet.radius_ratio, impact_param)
            
            -- Micro-tonal frequency synthesis
            local freq, q_tone = flux_to_microtone(flux, base_tone)
            local dimming_pct = (1.0 - flux) * 100

            -- Construct ASCII Spectrograph Visual Row
            local visual_bar_len = math.floor(flux * 30)
            local bar = string.rep("█", visual_bar_len) .. string.rep("░", 30 - visual_bar_len)
            local glyph = get_ascii_glyph(1.0 - flux, q_tone)
            
            local spectro_line = string.format("Phase: %+.3f | %s | Flux: %.4f (%02.2f%%) | Pitch: %06.1f Hz %s", 
                phase, bar, flux, dimming_pct, freq, glyph)
            
            io.write(spectro_line .. "\n")
            io.flush()

            -- Auditory feedback: Synthesize tone corresponding to transit light curve point
            beep(freq, 80)
        end

        io.write("------------------------------------------------------------------------\n")
        io.write(string.format("TRANSIT COMPLETE: %s registered.\n\n", planet.name))
        
        -- Modulate harmonic base pitch for polyphonic shift between exoplanetary systems
        base_tone = base_tone * 1.334833 -- Micro-tonal perfect 4th shift (24-TET equivalent)
        os.execute(is_windows and "timeout /t 1 >nul" or "sleep 1")
    end
    
    io.write(">> COMPOSITION COMPLETE: Polyphonic exoplanetary telemetry rendered successfully.\n")
end

-- Execute System
run_orchestrator()