-- Typographic Ecosystem: Visualizing Lua Memory Stack & GC as ASCII Flora
-- Variables bloom into procedural ASCII flowers; GC acts as a seasonal pruning cycle.

local math_random = math.random
local os_execute = os.execute
local collectgarbage = collectgarbage

-- Flower petal, stem, and soil components for procedural ASCII rendering
local PETALS = { "*", "@", "o", "%", "#", "&", "+", "~", "^", "8" }
local STEMS  = { "|", "Y", "i", "!", ":" }
local SOILS  = { "_", ".", ",", "~", "`" }

-- Helper to pause execution for visual animation pacing
local function sleep(n)
    local t = os.clock() + n
    while os.clock() < t do end
end

-- Clear terminal screen across operating systems
local function clear_screen()
    if package.config:sub(1, 1) == "\\" then
        os_execute("cls")
    else
        os_execute("clear")
    end
end

-- Represents an allocated stack/heap variable growing in the ecosystem
local Flower = {}
Flower.__index = Flower

function Flower.new(id, depth)
    local self = setmetatable({}, Flower)
    self.id = id
    self.depth = depth
    self.age = 1
    self.max_age = math_random(3, 6)
    self.symbol = PETALS[math_random(#PETALS)]
    self.stem_char = STEMS[math_random(#STEMS)]
    -- Allocate actual memory payload to simulate variable allocation weight
    self.payload = string.rep("VARIABLE_DATA_PAYLOAD_", math_random(200, 1000))
    return self
end

function Flower:grow()
    self.age = self.age + 1
end

function Flower:render_crown()
    local radius = self.age
    if radius == 1 then return " (" .. self.symbol .. ") " end
    if radius == 2 then return "(" .. self.symbol .. self.symbol .. self.symbol .. ")" end
    return "{" .. string.rep(self.symbol, radius + 2) .. "}"
end

-- Global ecosystem state tracking active allocations
local Garden = {
    plants = {},
    season = 1,
    generation = 0
}

function Garden:bloom_new_variable()
    self.generation = self.generation + 1
    local plant = Flower.new(self.generation, #self.plants + 1)
    table.insert(self.plants, plant)
end

function Garden:draw()
    clear_screen()
    local mem_kb = collectgarbage("count")
    
    print("==========================================================================")
    print(string.format(" SEASON %d | Memory Weight: %.2f KB | Active Stack Variables: %d", 
          self.season, mem_kb, #self.plants))
    print("==========================================================================")
    print("")

    -- Render blooming variable crowns
    local crown_line = ""
    for _, p in ipairs(self.plants) do
        crown_line = crown_line .. p:render_crown() .. "  "
    end
    print(crown_line)

    -- Render stems reflecting depth and visual hierarchy
    for height = 1, 2 do
        local stem_line = ""
        for _, p in ipairs(self.plants) do
            local crown_len = #p:render_crown()
            local pad_left = string.rep(" ", math.floor((crown_len - 1) / 2))
            local pad_right = string.rep(" ", crown_len - 1 - #pad_left)
            stem_line = stem_line .. pad_left .. p.stem_char .. pad_right .. "  "
        end
        print(stem_line)
    end

    -- Render soil base
    local soil_line = ""
    for _, p in ipairs(self.plants) do
        local soil_patch = string.rep(SOILS[math_random(#SOILS)], #p:render_crown())
        soil_line = soil_line .. soil_patch .. "  "
    end
    print(soil_line)
    print("")
end

function Garden:prune_dead_variables()
    print(" [!] GC Seasonal Pruning Cycle Initiated...")
    local initial_mem = collectgarbage("count")
    
    -- Unreference expired variables simulating out-of-scope stack cleanup
    local retained = {}
    for _, p in ipairs(self.plants) do
        if p.age < p.max_age then
            table.insert(retained, p)
        end
    end
    self.plants = retained
    
    -- Explicitly trigger Garbage Collector
    collectgarbage("collect")
    
    local freed_mem = initial_mem - collectgarbage("count")
    print(string.format(" [*] Pruning Complete: Reclaimed %.2f KB of memory.", math.max(0, freed_mem)))
    sleep(1.5)
end

-- Main Self-Executing Ecosystem Cycle
local function run_ecosystem()
    for cycle = 1, 15 do
        Garden.season = cycle
        
        -- Phase 1: Variable Allocation & Bloom
        local new_vars = math_random(2, 4)
        for _ = 1, new_vars do
            Garden:bloom_new_variable()
        end
        
        -- Phase 2: Age existing variables
        for _, p in ipairs(Garden.plants) do
            p:grow()
        end
        
        Garden:draw()
        sleep(0.8)
        
        -- Phase 3: Seasonal Garbage Collection Pruning every 3 cycles
        if cycle % 3 == 0 then
            Garden:prune_dead_variables()
        end
    end
    
    print("--- Memory Ecosystem Cycle Complete ---")
end

run_ecosystem()