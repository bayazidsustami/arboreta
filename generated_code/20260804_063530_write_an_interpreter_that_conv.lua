-- Stained Glass Trace Interpreter
-- Converts live execution trace & GC events into an evolving stained-glass terminal canvas.

local math_random = math.random
local math_abs = math.abs

-- Canvas settings
local WIDTH = 40
local HEIGHT = 20
local seeds = {}
local gc_fractures = {}

-- Palette of stained glass ANSI 256-color codes
local PALETTE = {196, 202, 226, 46, 51, 21, 129, 201, 208, 118, 39, 171}

-- Initialize Voronoi diagram seeds for stained-glass pane effect
local function init_seeds(num)
    seeds = {}
    for i = 1, num do
        seeds[i] = {
            x = math_random(1, WIDTH),
            y = math_random(1, HEIGHT),
            color = PALETTE[math_random(1, #PALETTE)]
        }
    end
end

-- Distance function for Voronoi cells with aspect correction
local function dist(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = (y1 - y2) * 2
    return math.sqrt(dx * dx + dy * dy)
end

-- Render canvas to ANSI terminal
local function render()
    io.write("\27[2J\27[H")
    io.write("=== LIVE EXECUTION STAINED-GLASS INTERPRETER ===\n")
    
    local buffer = {}
    for y = 1, HEIGHT do
        for x = 1, WIDTH do
            local min_d1, min_d2 = 999, 999
            local nearest_seed = seeds[1]
            
            for i = 1, #seeds do
                local d = dist(x, y, seeds[i].x, seeds[i].y)
                if d < min_d1 then
                    min_d2 = min_d1
                    min_d1 = d
                    nearest_seed = seeds[i]
                elseif d < min_d2 then
                    min_d2 = d
                end
            end
            
            -- Lead line boundary between cells or fracture
            local is_lead = (min_d2 - min_d1) < 0.8
            local is_fracture = false
            
            for _, f in ipairs(gc_fractures) do
                if math_abs((x + y) - f.diag) < f.intensity then
                    is_fracture = true
                    break
                end
            end
            
            if is_fracture then
                -- Shimmering fracture effect from GC event
                local shimmer_char = (math_random() > 0.5) and "✦" or "✧"
                table.insert(buffer, string.format("\27[38;5;231m%s", shimmer_char))
            elseif is_lead then
                -- Lead metal strip framing glass panes
                table.insert(buffer, "\27[38;5;236m┼")
            else
                -- Stained glass pane character and color
                table.insert(buffer, string.format("\27[38;5;%dm█", nearest_seed.color))
            end
        end
        table.insert(buffer, "\27[0m\n")
    end
    
    io.write(table.concat(buffer))
    io.write(string.format("Active Seeds: %d | Fractures: %d | Memory: %.2f KB\n", 
        #seeds, #gc_fractures, collectgarbage("count")))
end

local last_mem = collectgarbage("count")

-- Debug hook that runs on live code execution
local function execution_hook()
    local current_mem = collectgarbage("count")
    
    -- Shift glass seeds based on execution progression
    if #seeds > 0 then
        local idx = math_random(1, #seeds)
        seeds[idx].x = (seeds[idx].x + math_random(-1, 1) - 1) % WIDTH + 1
        seeds[idx].y = (seeds[idx].y + math_random(-1, 1) - 1) % HEIGHT + 1
    end
    
    -- GC Event Trigger: Memory drop triggers visual fracture line
    if current_mem < last_mem - 0.2 then
        table.insert(gc_fractures, {
            diag = math_random(2, WIDTH + HEIGHT),
            intensity = math_random(1, 2),
            life = 4
        })
    end
    last_mem = current_mem
    
    -- Fade out old GC fractures
    for i = #gc_fractures, 1, -1 do
        gc_fractures[i].life = gc_fractures[i].life - 1
        if gc_fractures[i].life <= 0 then
            table.remove(gc_fractures, i)
        end
    end
    
    render()
end

-- Target workload producing execution flow and garbage
local function workload()
    for i = 1, 120 do
        local temp = {}
        for j = 1, 80 do
            temp[j] = { val = j, str = "glass_" .. j }
        end
        if i % 12 == 0 then
            collectgarbage("collect")
        end
    end
end

-- Initialize and run interpreter trace
math.randomseed(os.time())
init_seeds(16)

debug.sethook(execution_hook, "l", 15)
workload()
debug.sethook()

render()
io.write("\nTrace complete. Stained-glass window state finalized.\n")