-- Mandelbrot ASCII animation using Unicode block characters
-- The program rewrites its own source file to reflect the current frame

local width, height = 80, 24               -- terminal size
local maxIter = 30                         -- escape-time limit
local escape = {}                           -- pre‑computed characters

-- Unicode block characters for shading (from light to dense)
local shades = {"░","▒","▓","█"}

-- Map iteration count to a shade
local function shade(iter)
    if iter >= maxIter then return " " end
    local idx = math.floor(iter / maxIter * #shades) + 1
    return shades[idx]
end

-- Compute one frame of the Mandelbrot set
local function frame(cx, cy, scale)
    local lines = {}
    for y = 0, height-1 do
        local line = {}
        for x = 0, width-1 do
            local zx = (x - width/2) * scale + cx
            local zy = (y - height/2) * scale + cy
            local zx2, zy2 = 0, 0
            local iter = 0
            while zx2+zy2 <= 4 and iter < maxIter do
                zy = 2*zx*zy + zy
                zx = zx2 - zy2 + zx
                zx2, zy2 = zx*zx, zy*zy
                iter = iter + 1
            end
            line[#line+1] = shade(iter)
        end
        lines[#lines+1] = table.concat(line)
    end
    return table.concat(lines, "\n")
end

-- Overwrite this file with new source containing the current frame
local function self_modify(content)
    local src = io.open(arg[0], "w")
    src:write([[
-- Mandelbrot ASCII animation using Unicode block characters
-- The program rewrites its own source file to reflect the current frame

local width, height = 80, 24               -- terminal size
local maxIter = 30                         -- escape-time limit
local escape = {}                           -- pre‑computed characters

local shades = {"░","▒","▓","█"}

local function shade(iter)
    if iter >= maxIter then return " " end
    local idx = math.floor(iter / maxIter * #shades) + 1
    return shades[idx]
end

local function frame(cx, cy, scale)
    local lines = {}
    for y = 0, height-1 do
        local line = {}
        for x = 0, width-1 do
            local zx = (x - width/2) * scale + cx
            local zy = (y - height/2) * scale + cy
            local zx2, zy2 = 0, 0
            local iter = 0
            while zx2+zy2 <= 4 and iter < maxIter do
                zy = 2*zx*zy + zy
                zx = zx2 - zy2 + zx
                zx2, zy2 = zx*zx, zy*zy
                iter = iter + 1
            end
            line[#line+1] = shade(iter)
        end
        lines[#lines+1] = table.concat(line)
    end
    return table.concat(lines, "\n")
end

local function self_modify(content)
    local src = io.open(arg[0], "w")
    src:write(content)
    src:close()
end

local cx, cy, scale = -0.5, 0, 0.005
while true do
    local art = frame(cx, cy, scale)
    os.execute("clear")
    print(art)
    self_modify(string.format([[%s]], art))
    cx = cx + 0.001
    scale = scale * 0.999
    os.execute("sleep 0.1")
end
]], "\n")
    src:close()
end

-- Initial parameters
local cx, cy, scale = -0.5, 0, 0.005

while true do
    local art = frame(cx, cy, scale)
    os.execute("clear")
    print(art)
    self_modify(string.format([[%s]], art))
    cx = cx + 0.001          -- pan right slowly
    scale = scale * 0.999    -- zoom in
    os.execute("sleep 0.1")
end