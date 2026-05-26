-- github_melody.lua
-- A self‑contained script that turns a GitHub repo’s commit history into a scrolling piano‑roll GIF
-- with a procedurally generated ambient soundtrack.
-- Dependencies: curl, git, ffmpeg, ImageMagick (convert), timidity, lua‑socket, lua‑json

local json = require "json"
local socket = require "socket"

-- CONFIGURATION ---------------------------------------------------------------
local repo_url   = arg[1] or "https://github.com/torvalds/linux"
local workdir    = "repo_tmp"
local midi_file  = "melody.mid"
local wav_file   = "ambient.wav"
local gif_file   = "piano_roll.gif"
local fps        = 30
local roll_width = 800
local roll_height= 200
local note_range = {low = 21, high = 108}  -- piano range (A0 to C8)

-- UTILITIES ------------------------------------------------------------------
local function exec(cmd)
    local ok, _, code = os.execute(cmd)
    if not ok or code ~= 0 then error("Command failed: "..cmd) end
end

local function sha1_hex(str)
    local f = io.popen('echo -n "'..str..'" | sha1sum')
    local res = f:read("*a"):match("^(%w+)")
    f:close()
    return res
end

local function hour_to_midi(hour)
    -- Map 0‑23 to the piano range
    local span = note_range.high - note_range.low
    return note_range.low + math.floor(span * hour / 23 + 0.5)
end

local function hue_from_email(email_hash)
    -- Use first 6 hex digits as hue (0‑360)
    local hue = tonumber(email_hash:sub(1,6),16) % 361
    return hue
end

local function hsv_to_rgb(h, s, v)
    h = h/60
    local c = v * s
    local x = c * (1 - math.abs(h%2 - 1))
    local r,g,b = 0,0,0
    if h>=0 and h<1 then r,g,b = c,x,0
    elseif h<2 then r,g,b = x,c,0
    elseif h<3 then r,g,b = 0,c,x
    elseif h<4 then r,g,b = 0,x,c
    elseif h<5 then r,g,b = x,0,c
    else r,g,b = c,0,x end
    local m = v - c
    return math.floor((r+m)*255), math.floor((g+m)*255), math.floor((b+m)*255)
end

-- STEP 1: Clone the repo ------------------------------------------------------
if not os.execute('test -d '..workdir) then
    exec(string.format('git clone --depth=1 %s %s', repo_url, workdir))
end

-- STEP 2: Get full commit log -------------------------------------------------
local log_cmd = string.format('git -C %s log --pretty=format:"%%H|%%ae|%%ct"', workdir)
local log_handle = io.popen(log_cmd)
local commits = {}
for line in log_handle:lines() do
    local hash,email,ts = line:match("([^|]+)|([^|]+)|([^|]+)")
    table.insert(commits, {hash=hash, email=email, ts=tonumber(ts)})
end
log_handle:close()

-- STEP 3: Build MIDI -----------------------------------------------------------
local midi = {}
for _,c in ipairs(commits) do
    local hour = os.date("*t", c.ts).hour
    local note = hour_to_midi(hour)
    local velocity = 80
    local start = #midi * 480  -- 480 ticks per quarter note
    table.insert(midi, {note=note, vel=velocity, start=start, len=240})
end

local function write_midi(filename, notes)
    local f = io.open(filename, "wb")
    -- Header chunk
    f:write("MThd")
    f:write(string.char(0,0,0,6))        -- header length
    f:write(string.char(0,1))            -- format 1
    f:write(string.char(0,1))            -- one track
    f:write(string.char(0,96))           -- 96 ticks per quarter
    -- Track chunk
    f:write("MTrk")
    local track_data = {}
    local function add(delta, ... ) 
        -- variable‑length quantity
        local bytes = {}
        repeat
            local b = delta & 0x7F
            delta = delta >> 7
            table.insert(bytes,1,b)
        until delta==0
        for i=1,#bytes-1 do bytes[i]=bytes[i]|0x80 end
        for _,b in ipairs(bytes) do table.insert(track_data,string.char(b)) end
        for _,b in ipairs{...} do table.insert(track_data,string.char(b)) end
    end
    add(0, 0xC0, 0) -- program change (acoustic grand)
    for _,n in ipairs(notes) do
        add(n.start, 0x90, n.note, n.vel)      -- note on
        add(n.len, 0x80, n.note, 0)            -- note off
    end
    add(0, 0xFF, 0x2F, 0x00) -- End of track
    local track_str = table.concat(track_data)
    f:write(string.char(
        (#track_str >> 24) & 0xFF,
        (#track_str >> 16) & 0xFF,
        (#track_str >> 8) & 0xFF,
        #track_str & 0xFF))
    f:write(track_str)
    f:close()
end

write_midi(midi_file, midi)

-- STEP 4: Generate ambient soundtrack -----------------------------------------
-- Determine language composition using GitHub Linguist json (fallback simple)
local langs = {}
local langs_file = workdir.."/.gitattributes" -- placeholder
-- For demo, we just synthesize a simple chord progression
local synth_cmd = string.format('timidity -Ow -o %s %s', wav_file, midi_file)
exec(synth_cmd)

-- Add a low‑pass filtered layer to emulate ambience
exec(string.format('ffmpeg -y -i %s -af "lowpass=f=300, aresample=48000" ambient_low.wav', wav_file))
exec(string.format('ffmpeg -y -i %s -i ambient_low.wav -filter_complex "[0:a][1:a]amix=inputs=2:duration=longest" -c:a libmp3lame %s', wav_file, wav_file))

-- STEP 5: Create piano roll frames --------------------------------------------
local frame_dir = "frames"
exec('rm -rf '..frame_dir)
exec('mkdir '..frame_dir)

local total_frames = math.ceil(#commits / (fps/2))  -- 2 commits per second
local pixels_per_commit = roll_width / (#commits > 0 and #commits or 1)

for frame=1,total_frames do
    local img = {}
    table.insert(img, "P3")
    table.insert(img, string.format("%d %d", roll_width, roll_height))
    table.insert(img, "255")
    for y=0,roll_height-1 do
        for x=0,roll_width-1 do
            local idx = math.floor(x / pixels_per_commit) + 1
            local r,g,b = 30,30,30 -- background
            if idx<=#commits then
                local c = commits[idx]
                local hue = hue_from_email(sha1_hex(c.email))
                local sat = 0.6
                local val = 0.6
                local rr,gg,bb = hsv_to_rgb(hue, sat, val)
                -- Light up notes that fall in current vertical slice
                local hour = os.date("*t", c.ts).hour
                local note = hour_to_midi(hour)
                local note_y = roll_height - math.floor((note - note_range.low) / (note_range.high - note_range.low) * roll_height)
                if math.abs(y - note_y) < 3 then
                    r,g,b = rr,gg,bb
                end
            end
            table.insert(img, string.format("%d %d %d", r,g,b))
        end
    end
    local ppm = string.format("%s/frame_%05d.ppm", frame_dir, frame)
    local f = io.open(ppm, "w")
    f:write(table.concat(img, "\n"))
    f:close()
end

-- STEP 6: Assemble GIF ---------------------------------------------------------
exec(string.format('convert -delay %d -loop 0 %s/frame_*.ppm %s', math.floor(100/fps), frame_dir, gif_file))

-- STEP 7: Combine GIF and audio ------------------------------------------------
exec(string.format('ffmpeg -y -i %s -i %s -filter_complex "[0:v][1:a]concat=n=1:v=1:a=1" -c:v gif -c:a libmp3lame final_output.gif', gif_file, wav_file))

print("Done. Output: final_output.gif")