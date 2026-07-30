local function parse_git_graph()
    local commits = {}
    local handle = io.popen("git log --all --graph --pretty=format:'%h|%p|%s' 2>/dev/null")
    if not handle then return commits end

    for line in handle:lines() do
        local graph, payload = line:match("^(%A*)(.*)$")
        if payload and #payload > 0 then
            local hash, parents, subject = payload:match("^([^|]+)|([^|]*)|(.*)$")
            if hash then
                local parent_list = {}
                for p in string.gmatch(parents or "", "%S+") do
                    table.insert(parent_list, p)
                end
                
                local is_merge = #parent_list > 1
                local is_conflict = subject:lower():match("conflict") ~= nil or line:match("[|/\\*]%s+[|/\\*]") ~= nil
                local is_refactor = subject:lower():match("refactor") ~= nil or subject:lower():match("clean") ~= nil
                
                table.insert(commits, {
                    hash = hash,
                    parents = parent_list,
                    is_merge = is_merge,
                    is_conflict = is_conflict,
                    is_refactor = is_refactor,
                    depth = #graph
                })
            end
        end
    end
    handle:close()

    if #commits == 0 then
        -- Fallback mock history if run outside a git repository
        commits = {
            { hash = "a1b2c3d", parents = {"0000000"}, is_merge = false, is_conflict = false, is_refactor = false, depth = 1 },
            { hash = "b2c3d4e", parents = {"a1b2c3d"}, is_merge = false, is_conflict = false, is_refactor = true, depth = 1 },
            { hash = "c3d4e5f", parents = {"a1b2c3d"}, is_merge = false, is_conflict = false, is_refactor = false, depth = 2 },
            { hash = "d4e5f6a", parents = {"b2c3d4e", "c3d4e5f"}, is_merge = true, is_conflict = true, is_refactor = false, depth = 2 },
            { hash = "e5f6a7b", parents = {"d4e5f6a"}, is_merge = false, is_conflict = false, is_refactor = true, depth = 1 },
        }
    end

    return commits
end

-- Audio Engine Setup (31-Tone Equal Temperament / Microtonal Pure Synthesis)
local sample_rate = 44100
local base_freq = 110.0 -- A2 base drone

-- 31-EDO Microtonal converter: frequency = f0 * 2^(step / 31)
local function edo31_to_freq(step)
    return base_freq * (2 ^ (step / 31))
end

-- Simple Sine Wave Generator with envelope
local function generate_tone(freq, duration, amplitude, fm_freq, fm_depth)
    local num_samples = math.floor(sample_rate * duration)
    local samples = {}
    local phase = 0
    local fm_phase = 0
    
    for i = 1, num_samples do
        local t = i / num_samples
        -- Attack-Decay-Sustain-Release Envelope
        local env = math.sin(t * math.pi)
        
        -- Frequency modulation for microtonal texture
        local fm = math.sin(fm_phase) * (fm_depth or 0)
        local sample = math.sin(phase + fm) * amplitude * env
        
        phase = phase + (2 * math.pi * freq / sample_rate)
        if fm_freq then
            fm_phase = fm_phase + (2 * math.pi * fm_freq / sample_rate)
        end
        
        table.insert(samples, sample)
    end
    return samples
end

-- Convert commits into synth events
local function render_ambient_patch(commits)
    local master_buffer = {}
    local total_duration = 0
    
    print("--- GIT GRAPH AMBIENT SYNTHESIS ---")
    print(string.format("Parsed %d commit nodes into 31-EDO microtonal space.\n", #commits))

    for idx, c in ipairs(commits) do
        -- Microtonal pitch mapped from commit hash hexadecimal value
        local hash_val = tonumber(c.hash:sub(1, 4), 16) or 1000
        local microtone_step = (hash_val % 62) - 31 -- 2 octave span in 31-EDO
        local freq = edo31_to_freq(microtone_step)
        
        local duration = c.is_merge and 1.5 or 0.75
        local amp = c.is_refactor and 0.25 or 0.15
        
        local node_samples = {}

        if c.is_conflict then
            -- Polyrhythmic Dissonance: 7:5 ratio microtonal FM synthesis
            local freq_b = edo31_to_freq(microtone_step + 5) -- Dissonant interval
            local tone_a = generate_tone(freq, duration, amp, 7.0, 1.5)
            local tone_b = generate_tone(freq_b, duration, amp, 5.0, 2.0)
            
            for k = 1, math.max(#tone_a, #tone_b) do
                local val_a = tone_a[k] or 0
                local val_b = tone_b[k] or 0
                table.insert(node_samples, val_a + val_b)
            end
            print(string.format("[%s] MERGE CONFLICT -> Polyrhythmic Dissonance (FM 7:5, %.2f Hz / %.2f Hz)", c.hash, freq, freq_b))

        elseif c.is_merge then
            -- Microtonal Merge Swell (Just Intonation resonance)
            node_samples = generate_tone(freq, duration, amp * 1.5, freq * 0.5, 0.8)
            print(string.format("[%s] BRANCH MERGE  -> Microtonal Swell (31-EDO Step: %d, %.2f Hz)", c.hash, microtone_step, freq))

        elseif c.is_refactor then
            -- Clean, Filtered harmonic shimmer
            node_samples = generate_tone(freq * 2, duration * 0.5, amp, nil, 0)
            print(string.format("[%s] REFACTOR      -> Harmonic Shimmer (%.2f Hz)", c.hash, freq * 2))

        else
            -- Ambient Background Drone node
            node_samples = generate_tone(freq, duration, amp * 0.5, 0.2, 0.1)
            print(string.format("[%s] COMMIT        -> Ambient Tone (%.2f Hz)", c.hash, freq))
        end

        for _, s in ipairs(node_samples) do
            table.insert(master_buffer, s)
        end
        total_duration = total_duration + duration
    end

    return master_buffer, total_duration
end

-- Output raw 16-bit PCM audio stream or save to audio pipe
local function play_or_stream(buffer)
    local player = io.popen("aplay -f S16_LE -r 44100 -c 1 2>/dev/null") or io.popen("ffplay -f s16le -ar 44100 -ac 1 -nodisp -autoexit -i - 2>/dev/null")
    
    if not player then
        print("\n[Notice] No standard audio backend (aplay/ffplay) detected. PCM audio generated internally.")
        return
    end

    for _, sample in ipairs(buffer) do
        -- Clamp amplitude
        sample = math.max(-1.0, math.min(1.0, sample))
        local int_val = math.floor(sample * 32767)
        if int_val < 0 then int_val = int_val + 65536 end
        
        local low_byte = string.char(int_val % 256)
        local high_byte = string.char(math.floor(int_val / 256) % 256)
        player:write(low_byte .. high_byte)
    end
    player:close()
end

-- Execution entrypoint
local commits = parse_git_graph()
local audio_buffer, duration = render_ambient_patch(commits)
print(string.format("\nGenerated %.2f seconds of real-time microtonal ambient music.", duration))
play_or_stream(audio_buffer)