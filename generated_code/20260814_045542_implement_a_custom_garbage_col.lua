-- Custom Garbage Collector & ASCII Topography Generator
-- Emulates memory allocation and GC collection to render dynamic 3D-ish terrain maps.

local math_floor, math_max, math_min = math.floor, math.max, math.min
local MAP_W, MAP_H = 50, 22
local heightmap = {}

-- Initialize heightmap grid
for y = 1, MAP_H do
    heightmap[y] = {}
    for x = 1, MAP_W do
        heightmap[y][x] = 0
    end
end

-- Custom Heap and Allocation Tracker
local Heap = { objects = {} }

-- Allocate a pseudo-variable in memory
function Heap:allocate(name, size)
    local obj = { id = name, size = size, address = tostring({}):sub(8) }
    setmetatable(obj, {
        __gc = function(o)
            -- When Lua or custom GC drops object, convert its address/size into terrain elevation
            local addr_hash = 0
            for i = 1, #o.address do
                addr_hash = (addr_hash + o.address:byte(i) * i) % 256
            end
            local target_x = (addr_hash % MAP_W) + 1
            local target_y = (math_floor(addr_hash * 1.3) % MAP_H) + 1
            local elevation = (o.size % 8) + 2
            
            -- Deposit elevation wave into heightmap
            for dy = -2, 2 do
                for dx = -2, 2 do
                    local nx, ny = target_x + dx, target_y + dy
                    if nx >= 1 and nx <= MAP_W and ny >= 1 and ny <= MAP_H then
                        local dist = math.sqrt(dx*dx + dy*dy)
                        heightmap[ny][nx] = math_min(9, heightmap[ny][nx] + math_max(0, elevation - dist * 1.5))
                    end
                end
            end
        end
    })
    table.insert(self.objects, obj)
    return obj
end

-- Custom GC sweep step
function Heap:sweep()
    if #self.objects > 8 then
        for _ = 1, math.random(1, 4) do
            if #self.objects > 0 then
                local idx = math.random(1, #self.objects)
                self.objects[idx] = nil
                table.remove(self.objects, idx)
            end
        end
    end
    collectgarbage("collect") -- Force Lua GC run to trigger __gc finalizers
end

-- ASCII visualizer (Topographic Isometric projection)
local CHARS = " .:-=+*#%@"

local function render(frame)
    local buffer = {}
    table.insert(buffer, "\27[H\27[2J") -- Clear terminal screen (ANSI escape)
    table.insert(buffer, "=== GC TOPOGRAPHY MAP: FORGOTTEN VARIABLES ===\n")
    
    for y = 1, MAP_H do
        local line = {}
        for x = 1, MAP_W do
            -- Apply dynamic wave decay / erosion over time
            local h = heightmap[y][x]
            if h > 0 then
                heightmap[y][x] = math_max(0, h - 0.08)
            end
            
            -- Render height character
            local idx = math_floor(h) + 1
            idx = math_max(1, math_min(#CHARS, idx))
            table.insert(line, CHARS:sub(idx, idx))
        end
        table.insert(buffer, table.concat(line) .. "\n")
    end
    table.insert(buffer, string.format("Active Heap Objects: %d | Total Memory: %d KB | Frame: %d\n", #Heap.objects, collectgarbage("count"), frame))
    print(table.concat(buffer))
end

-- Sleep utility
local function sleep(n)
    local t = os.clock()
    while os.clock() - t < n do end
end

print("Starting Garbage Collector Topography Generator...")
sleep(1)

local frame = 0
while true do
    frame = frame + 1
    
    -- Simulate continuous allocation of variables
    for _ = 1, math.random(2, 5) do
        Heap:allocate("var_" .. math.random(1000, 9999), math.random(10, 100))
    end
    
    -- Execute custom GC step to discard memory blocks
    Heap:sweep()
    
    -- Render evolving 3D ASCII map
    render(frame)
    sleep(0.08)
end