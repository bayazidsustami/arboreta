-- Self‑modifying Lua script that extracts a melody from its own indentation,
-- writes a tiny MIDI file, draws a simple waveform PNG, and rewrites its
-- indentation with a mutated melody for the next run.

local srcfile = arg[0]                -- this script's filename
local midifile = "melody.mid"
local imgfile = "waveform.png"

-- ---------------------------------------------------------------------
-- 1. Read own source, collect indentation lengths (number of leading spaces)
-- ---------------------------------------------------------------------
local indent = {}
for line in io.lines(srcfile) do
    local spaces = line:match("^(%s*)")
    if spaces then indent[#indent+1] = #spaces end
end
if #indent == 0 then indent = {4,2,6,3,5} end   -- fallback melody

-- ---------------------------------------------------------------------
-- 2. Convert indentation pattern to a sequence of MIDI note numbers.
--    We map smallest indentation to C4 (60) and spread over an octave.
-- ---------------------------------------------------------------------
local mn, mx = math.huge, -math.huge
for _,v in ipairs(indent) do mn = math.min(mn,v); mx = math.max(mx,v) end
local notes = {}
for _,v in ipairs(indent) do
    local norm = (v - mn) / (mx - (mn==mx and 1 or mn))   -- avoid div0
    local note = math.floor(60 + norm * 12 + 0.5)          -- 60‑71
    notes[#notes+1] = note
end

-- ---------------------------------------------------------------------
-- 3. Write a minimal MIDI file (format 0, one track, 96 ticks per quarter)
-- ---------------------------------------------------------------------
local function varlen(n)
    local bytes = {}
    repeat
        table.insert(bytes, 1, n % 128)
        n = math.floor(n / 128)
    until n == 0
    for i=1,#bytes-1 do bytes[i] = bytes[i] + 0x80 end
    return string.char(table.unpack(bytes))
end

local function write_midi(notes)
    local out = io.open(midifile, "wb")
    local function write(s) out:write(s) end

    -- Header chunk
    write("MThd")                     -- Chunk type
    write(string.char(0,0,0,6))       -- Header length = 6
    write(string.char(0,0))           -- format 0
    write(string.char(0,1))           -- one track
    write(string.char(0,96))          -- 96 ticks per quarter

    local trackData = {}
    local function t(s) table.insert(trackData,s) end

    t("\x00\xff\x51\x03\x07\xa1\x20")   -- Set tempo 120 BPM (500000 µs)
    t("\x00\xff\x58\x04\x04\x02\x18\x08") -- 4/4 time
    t("\x00\xff\x59\x02\x00\x00")      -- key signature C major

    local tick = 0
    for _,note in ipairs(notes) do
        t(varlen(tick) .. "\x90\x3c" .. string.char(note))   -- Note On, vel 60
        tick = 96                     -- one quarter note length
        t(varlen(tick) .. "\x80\x3c\x00")   -- Note Off
        tick = 0
    end
    t("\x00\xff\x2f\x00")               -- End of track

    local trackBytes = table.concat(trackData)
    write("MTrk")
    write(string.char(
        ( #trackBytes >> 24 ) & 0xFF,
        ( #trackBytes >> 16 ) & 0xFF,
        ( #trackBytes >> 8  ) & 0xFF,
        ( #trackBytes       ) & 0xFF))
    write(trackBytes)
    out:close()
end

write_midi(notes)

-- ---------------------------------------------------------------------
-- 4. Very simple waveform visualization: draw a PNG with red squiggle.
--    Uses the pure‑Lua PNG writer from https://github.com/lunarmodules/luapng
--    (embedded minimal version).
-- ---------------------------------------------------------------------
local png = {}
function png.encode(filename, w, h, pixels)
    local function crc(str)
        local polynomial = 0xedb88320
        local crc = 0xffffffff
        for i=1,#str do
            local byte = str:byte(i)
            crc = crc ~ byte
            for _=1,8 do
                local mask = -(crc & 1)
                crc = (crc >> 1) ~ (polynomial & mask)
            end
        end
        return (crc ~ 0xffffffff)
    end
    local function pack(fmt, ...) return string.pack(fmt, ...) end
    local out = io.open(filename,"wb")
    out:write("\137PNG\r\n\26\n") -- signature

    local ihdr = pack(">I4I4I4BBBBB",
        13, w, h, 8, 2, 0, 0, 0) -- truecolor
    out:write("IHDR")
    out:write(ihdr)
    out:write(pack(">I4", crc("IHDR"..ihdr)))

    local idat = {}
    for y=0,h-1 do
        table.insert(idat, "\0") -- filter type 0
        for x=0,w-1 do
            local i = (y*w + x)*3 + 1
            local r,g,b = pixels[i],pixels[i+1],pixels[i+2]
            table.insert(idat, string.char(r,g,b))
        end
    end
    local raw = table.concat(idat)
    local zlib = require("zlib")
    local comp = zlib.deflate()(raw, "finish")
    out:write("IDAT")
    out:write(comp)
    out:write(pack(">I4", crc("IDAT"..comp)))
    out:write("IEND")
    out:write(pack(">I4", crc("IEND")))
    out:close()
end

local w,h = 256,100
local pixels = {}
for i=1,w*h*3 do pixels[i]=255 end
for x=1,w do
    local y = math.floor( (math.sin(x/10)+1)*h/2 )
    local idx = ((y-1)*w + x)*3 + 1
    pixels[idx]=200; pixels[idx+1]=50; pixels[idx+2]=30   -- red line
end
pcall(function() png.encode(imgfile,w,h,pixels) end) -- ignore if zlib unavailable

-- ---------------------------------------------------------------------
-- 5. Mutate the melody and rewrite indentation for next run.
-- ---------------------------------------------------------------------
math.randomseed(os.time())
local function mutate(arr)
    local res = {}
    for i=1,#arr do
        local delta = math.random(-2,2)
        local v = arr[i] + delta
        if v < 0 then v = 0 end
        res[i] = v
    end
    return res
end
local newIndent = mutate(indent)

local src = {}
for line in io.lines(srcfile) do src[#src+1]=line end
local out = io.open(srcfile..".tmp","w")
local idx = 1
for _,line in ipairs(src) do
    local stripped = line:match("^%s*(.*)$")
    local lead = ""
    if idx <= #newIndent then lead = string.rep(" ", newIndent[idx]) end
    out:write(lead..stripped.."\n")
    idx = idx + 1
end
out:close()
os.remove(srcfile)
os.rename(srcfile..".tmp", srcfile)

print("MIDI written to "..midifile..", waveform attempt saved as "..imgfile)