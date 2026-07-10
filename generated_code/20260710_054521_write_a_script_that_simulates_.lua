-- Simple 1‑dimensional cellular automaton (Rule 30)
-- Configurable width, generations and rule number

local width = 61           -- number of cells (odd for a centered seed)
local generations = 30     -- how many steps to display
local rule = 30            -- Rule number (0‑255)

-- Convert rule number to a table of 8 bits (index 0‑7)
local function ruleTable(ruleNum)
    local tbl = {}
    for i = 0, 7 do
        tbl[i] = (ruleNum >> i) & 1
    end
    return tbl
end

local r = ruleTable(rule)

-- Initialize first generation: a single live cell in the centre
local state = {}
for i = 1, width do state[i] = 0 end
state[math.floor(width/2)+1] = 1

-- Helper: get cell value with periodic boundary (wrap‑around)
local function get(state, idx)
    if idx < 1 then idx = idx + width end
    if idx > width then idx = idx - width end
    return state[idx]
end

-- Render a state line: live cells as '█', dead as space
local function render(state)
    local line = {}
    for i = 1, width do
        line[i] = state[i] == 1 and "█" or " "
    end
    print(table.concat(line))
end

-- Main loop
for gen = 1, generations do
    render(state)
    local next = {}
    for i = 1, width do
        local left  = get(state, i-1)
        local center = state[i]
        local right = get(state, i+1)
        local pattern = (left << 2) | (center << 1) | right
        next[i] = r[pattern]
    end
    state = next
end