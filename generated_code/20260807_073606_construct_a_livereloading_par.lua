-- Git History to MIDI Live-Reloading Parser
-- Reads raw git log data, maps commits to multi-track MIDI, and generates dissonant clusters on merge conflicts.

local TARGET_FILE = arg[1] or "git_history.log"
local OUTPUT_MIDI = "commit_score.mid"
local RELOAD_INTERVAL = 1.0

-- Big-endian integer encoding helpers for Standard MIDI Files
local function pack_be32(val)
    return string.char(
        math.floor(val / 16777216) % 256,
        math.floor(val / 65536) % 256,
        math.floor(val / 256) % 256,
        val % 256
    )
end

local function pack_be16(val)
    return string.char(
        math.floor(val / 256) % 256,
        val % 256
    )
end

-- Encodes MIDI Variable-Length Quantity (VLQ) for delta times
local function write_vlq(val)
    local buffer = {}
    local v = val
    repeat
        local byte = v % 128
        v = math.floor(v / 128)
        if #buffer > 0 then byte = byte + 128 end
        table.insert(buffer, 1, string.char(byte))
    until v == 0
    return table.concat(buffer)
end

-- Assembles tracks into a valid Format 1 multi-track MIDI file binary string
local function build_midi(tracks)
    local header = "MThd" .. pack_be32(6) .. pack_be16(1) .. pack_be16(#tracks) .. pack_be16(480)
    local midi_data = { header }

    for track_idx, events in ipairs(tracks) do
        local track_bytes = {}
        -- Set Tempo (120 BPM) & Assign Instrument Patch based on Track
        table.insert(track_bytes, write_vlq(0) .. string.char(0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20))
        table.insert(track_bytes, write_vlq(0) .. string.char(0xC0 + ((track_idx - 1) % 16), (track_idx * 20) % 128))

        for _, ev in ipairs(events) do
            local status = (ev.type == "on" and 0x90 or 0x80) + ((track_idx - 1) % 16)
            table.insert(track_bytes, write_vlq(ev.delta) .. string.char(status, ev.note % 128, ev.vel % 128))
        end

        -- End of Track event
        table.insert(track_bytes, write_vlq(0) .. string.char(0xFF, 0x2F, 0x00))
        local content = table.concat(track_bytes)
        table.insert(midi_data, "MTrk" .. pack_be32(#content) .. content)
    end

    return table.concat(midi_data)
end

-- Parses raw git log stream & conflict syntax into harmonized multi-track events
local function parse_git_log(filepath)
    local f = io.open(filepath, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()

    local tracks = { {}, {}, {}, {} } -- 4 Channels: Main Branch, Feature Branch, Commits, Conflicts
    local seed = 1337
    local function pseudo_rand(max)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return (seed % max)
    end

    for line in content:gmatch("[^\r\n]+") do
        -- Detect conflict markers (<<<<<<<, =======, >>>>>>>, or 'conflict')
        if line:find("<<<<<<<") or line:find("=======") or line:find(">>>>>>>") or line:find("[Cc]onflict") then
            -- Trigger unpredictable polyphonic dissonance (microtonal clusters, tritones, minor 2nds)
            local base_note = 42 + pseudo_rand(30)
            local dissonance_count = 4 + pseudo_rand(4)
            
            for i = 1, dissonance_count do
                -- Stack jarring interval offsets across parallel tracks
                local interval = (i % 2 == 0) and 1 or 6 -- Minor seconds & Tritones
                local pitch = math.min(127, math.max(0, base_note + (i * interval) + (pseudo_rand(3) - 1)))
                local track_target = ((i - 1) % #tracks) + 1
                
                table.insert(tracks[track_target], { type = "on", note = pitch, vel = 100 + pseudo_rand(27), delta = 0 })
                table.insert(tracks[track_target], { type = "off", note = pitch, vel = 0, delta = 180 + pseudo_rand(300) })
            end
        else
            -- Map standard commit hashes to harmonic pitch scale
            local hash = line:match("%x%x%x%x%x%x%x+")
            if hash then
                local hash_num = tonumber(hash:sub(1, 4), 16) or 0
                local track_id = (hash_num % #tracks) + 1
                local scale = { 0, 2, 4, 7, 9, 12, 14, 16 } -- Major Pentatonic mapping
                local note = 48 + scale[(hash_num % #scale) + 1]
                local duration = 240 + (hash_num % 480)

                table.insert(tracks[track_id], { type = "on", note = note, vel = 75 + (hash_num % 45), delta = 120 })
                table.insert(tracks[track_id], { type = "off", note = note, vel = 0, delta = duration })
            end
        end
    end

    return tracks
end

-- Native filesystem mtime check for live re-parsing
local function get_mtime(filepath)
    local p = io.popen("stat -c %Y " .. filepath .. " 2>/dev/null || stat -f %m " .. filepath .. " 2>/dev/null")
    if not p then return 0 end
    local result = p:read("*a")
    p:close()
    return tonumber(result:match("%d+")) or 0
end

-- Creates seed mock git history if no file provided
local function ensure_target_exists()
    local f = io.open(TARGET_FILE, "r")
    if not f then
        local mock = io.open(TARGET_FILE, "w")
        if mock then
            mock:write("commit a1b2c3d4e5f67890 (HEAD -> main)\nAuthor: Dev <dev@synth.io>\n\n    feat: engine architecture\n")
            mock:write("<<<<<<< HEAD\n    conflict: state mutation overlap\n=======\n    conflict: async stream race condition\n>>>>>>> feature/polyphony\n")
            mock:write("commit f9e8d7c6b5a43210\nAuthor: Bot <bot@synth.io>\n\n    fix: resolved merge conflict with dissonance\n")
            mock:close()
        end
    end
end

-- Main Live Reload Loop
ensure_target_exists()
print("[Git-MIDI Parser] Watching log target: '" .. TARGET_FILE .. "'")
local last_mtime = -1

while true do
    local mtime = get_mtime(TARGET_FILE)
    if mtime > 0 and mtime ~= last_mtime then
        last_mtime = mtime
        print("[Git-MIDI Parser] Change detected! Re-parsing history & generating score...")
        
        local tracks = parse_git_log(TARGET_FILE)
        if tracks then
            local midi_binary = build_midi(tracks)
            local out = io.open(OUTPUT_MIDI, "wb")
            if out then
                out:write(midi_binary)
                out:close()
                print("[Git-MIDI Parser] Score successfully compiled -> " .. OUTPUT_MIDI)
            end
        end
    end
    
    os.execute("sleep " .. tostring(RELOAD_INTERVAL) .. " 2>/dev/null || timeout " .. tostring(RELOAD_INTERVAL) .. " >nul 2>&1")
end