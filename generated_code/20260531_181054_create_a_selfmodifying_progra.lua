-- self_modifying_mandala.lua
-- Real‑time webcam palette → ASCII mandala → IRC stream + hidden palindrome
-- Requires: lua‑socket, lua‑opencv (or OpenCV bindings), lfs

local cv = require "cv"
require "cv.highgui"
require "cv.imgproc"
local socket = require "socket"
local lfs = require "lfs"

local THIS_FILE = debug.getinfo(1, "S").source:sub(2)   -- script path
local IRC_SERVER = "irc.libera.chat"
local IRC_PORT = 6667
local IRC_NICK = "LuaMandalaBot"
local IRC_CHAN = "#lua-mandala"

-- Hidden palindrome (reads same backwards) embedding previous source placeholder
local PALINDROME = "!--[prev]--!lua--[prev]--!"  -- simple reversible marker

-- Open webcam
local cap = cv.VideoCapture{0}
assert(cap:isOpened(), "Cannot open webcam")

-- Connect to IRC
local irc = assert(socket.tcp())
irc:settimeout(0)
irc:connect(IRC_SERVER, IRC_PORT)
irc:send("NICK " .. IRC_NICK .. "\r\n")
irc:send("USER " .. IRC_NICK .. " 0 * :" .. IRC_NICK .. "\r\n")
irc:send("JOIN " .. IRC_CHAN .. "\r\n")

-- ASCII characters ramp
local shades = {" ",".",":","-","=","+", "*", "#", "%", "@"}

-- Helper: get dominant palette (k‑means with k=4)
local function dominant_palette(frame)
    local rows, cols = frame:size()
    local samples = cv.Mat{rows*cols, 3, cv.CV_32F}
    frame:reshape(1, rows*cols):convertTo(samples, cv.CV_32F)
    local criteria = cv.TermCriteria{type=cv.TermCriteria_EPS + cv.TermCriteria_MAX_ITER, maxCount=10, epsilon=1.0}
    local flags = cv.KMEANS_PP_CENTERS
    local compactness, labels, centers = cv.kmeans(samples, 4, nil, criteria, 1, flags)
    return centers   -- 4x3 float matrix (B,G,R)
end

-- Helper: render mandala from palette
local function render_mandala(palette, w, h)
    local out = {}
    local cx, cy = w//2, h//2
    local maxr = math.min(cx, cy)
    for y=0,h-1 do
        local line = {}
        for x=0,w-1 do
            local dx, dy = x-cx, y-cy
            local r = math.sqrt(dx*dx + dy*dy)
            local angle = (math.atan2(dy, dx) + math.pi) / (2*math.pi)  -- 0..1
            local sector = math.floor(angle * #palette) % #palette
            local shade = math.floor((r / maxr) * (#shades-1))
            line[#line+1] = shades[shade+1]
        end
        out[#out+1] = table.concat(line)
    end
    return table.concat(out, "\n")
end

-- Main loop
while true do
    local ok, frame = pcall(cap.read, cap)
    if not ok or not frame or frame.empty then break end

    -- Resize for speed
    cv.resize{frame, frame, {width=160, height=120}}

    -- Get palette
    local palette_mat = dominant_palette(frame)
    local palette = {}
    for i=0, palette_mat:size(1)-1 do
        local b,g,r = palette_mat[i][1], palette_mat[i][2], palette_mat[i][3]
        palette[i+1] = {r=r, g=g, b=b}
    end

    -- Render ASCII mandala
    local ascii = render_mandala(palette, 80, 40)

    -- Send to IRC (split lines to avoid flooding)
    for line in ascii:gmatch("[^\n]+") do
        irc:send("PRIVMSG " .. IRC_CHAN .. " :" .. line .. "\r\n")
        socket.sleep(0.1)
    end

    -- Self‑modify: embed current palette as a comment and preserve previous source via palindrome
    local src = io.open(THIS_FILE, "r"):read("*a")
    local new_src = src:gsub("%-%-%[PALETTE%].-%-%-%[END%]",
        "--[PALETTE]\n-- Palette captured at " .. os.date() .. "\n--" .. PALINDROME .. "\n--[END]")
    local f = io.open(THIS_FILE, "w")
    f:write(new_src)
    f:close()

    socket.sleep(2)   -- pause before next frame
end

cap:release()
irc:close()