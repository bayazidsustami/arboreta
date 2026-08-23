local YarnEngine = {}

-- 1. Program Definition (Knitting Code)
-- 'K' = Knit (Increment cell, advance X)
-- 'P' = Purl (Decrement cell, advance Y)
-- 'S' = Slip (Multiply cell by 2, jump X)
-- 'Y' = Yarn Over (Spread value to 4-way neighbors, move diagonal)
-- 'D' = Drop Stitch (Clear cell, set ripple wave effect)
-- '[' / ']' = Loop while current cell > 0
local source_code = "K[KPPYSK]D[PKSYYK]K[KPYSD]P[SKSYK]D"

-- 2. State & Memory Tapestry Initialization
local WIDTH, HEIGHT = 40, 20
local tapestry = {}
for y = 0, HEIGHT - 1 do
    tapestry[y] = {}
    for x = 0, WIDTH - 1 do tapestry[y][x] = 0 end
end

local needle_x, needle_y = math.floor(WIDTH / 2), math.floor(HEIGHT / 2)
local loom_palette = " .:-=+*#%@"

local function clamp_coords(x, y)
    return x % WIDTH, y % HEIGHT
end

local function draw_loom()
    os.execute(os.getenv("OS") == "Windows_NT" and "cls" or "clear")
    io.write("=== ASCII LOOM: YARN FRACTAL TAPESTRY ===\n\n")
    for y = 0, HEIGHT - 1 do
        local line = "|"
        for x = 0, WIDTH - 1 do
            if x == needle_x and y == needle_y then
                line = line .. "O" -- Needle position
            else
                local val = math.abs(tapestry[y][x])
                local idx = (val % (#loom_palette - 1)) + 1
                line = line .. loom_palette:sub(idx, idx)
            end
        end
        io.write(line .. "|\n")
    end
    io.write("\nNeedle: (" .. needle_x .. ", " .. needle_y .. ") | Stitches Active: " .. #source_code .. "\n")
end

-- 3. Interpreter Loop Execution
local function execute_stitch(pc, loop_stack)
    if pc > #source_code then return false end
    local stitch = source_code:sub(pc, pc)

    if stitch == "K" then
        tapestry[needle_y][needle_x] = tapestry[needle_y][needle_x] + 1
        needle_x, needle_y = clamp_coords(needle_x + 1, needle_y)
    elseif stitch == "P" then
        tapestry[needle_y][needle_x] = tapestry[needle_y][needle_x] - 1
        needle_x, needle_y = clamp_coords(needle_x, needle_y + 1)
    elseif stitch == "S" then
        tapestry[needle_y][needle_x] = (tapestry[needle_y][needle_x] * 2) % 10
        needle_x, needle_y = clamp_coords(needle_x + 2, needle_y)
    elseif stitch == "Y" then
        local v = tapestry[needle_y][needle_x] + 1
        local up_y, dn_y = (needle_y - 1) % HEIGHT, (needle_y + 1) % HEIGHT
        local lf_x, rt_x = (needle_x - 1) % WIDTH, (needle_x + 1) % WIDTH
        tapestry[up_y][needle_x] = (tapestry[up_y][needle_x] + v) % 9
        tapestry[dn_y][needle_x] = (tapestry[dn_y][needle_x] + v) % 9
        tapestry[needle_y][lf_x] = (tapestry[needle_y][lf_x] + v) % 9
        tapestry[needle_y][rt_x] = (tapestry[needle_y][rt_x] + v) % 9
        needle_x, needle_y = clamp_coords(needle_x + 1, needle_y + 1)
    elseif stitch == "D" then
        tapestry[needle_y][needle_x] = 0
        needle_x, needle_y = clamp_coords(needle_x - 1, needle_y - 1)
    elseif stitch == "[" then
        if tapestry[needle_y][needle_x] == 0 then
            local depth = 1
            while depth > 0 and pc < #source_code do
                pc = pc + 1
                local c = source_code:sub(pc, pc)
                if c == "[" then depth = depth + 1
                elseif c == "]" then depth = depth - 1 end
            end
        else
            table.insert(loop_stack, pc)
        end
    elseif stitch == "]" then
        if tapestry[needle_y][needle_x] ~= 0 then
            pc = loop_stack[#loop_stack]
        else
            table.remove(loop_stack)
        end
    end

    return pc + 1
end

-- 4. Main Runtime Loop
local pc = 1
local loop_stack = {}

while pc do
    pc = execute_stitch(pc, loop_stack)
    draw_loom()
    
    -- Sleep briefly for dynamic animation effect
    local start_time = os.clock()
    while os.clock() - start_time < 0.05 do end
end