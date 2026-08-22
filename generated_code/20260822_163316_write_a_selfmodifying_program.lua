local math, string, table = math, string, table

-- [Self-Modifying Source Definition]
local source_code = [[
local notes = {261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25}
local grid_size = 32
local cell_grid = {}

for i = 1, grid_size do
    cell_grid[i] = {}
    for j = 1, grid_size do
        cell_grid[i][j] = math.random(0, 1)
    end
end

local function count_neighbors(g, x, y)
    local count = 0
    for dx = -1, 1 do
        for dy = -1, 1 do
            if not (dx == 0 and dy == 0) then
                local nx, ny = ((x + dx - 1) % grid_size) + 1, ((y + dy - 1) % grid_size) + 1
                count = count + g[nx][ny]
            end
        end
    end
    return count
end

local function step_automaton(g)
    local next_grid = {}
    local active_count = 0
    for i = 1, grid_size do
        next_grid[i] = {}
        for j = 1, grid_size do
            local neighbors = count_neighbors(g, i, j)
            if g[i][j] == 1 then
                next_grid[i][j] = (neighbors == 2 or neighbors == 3) and 1 or 0
            else
                next_grid[i][j] = (neighbors == 3) and 1 or 0
            end
            if next_grid[i][j] == 1 then active_count = active_count + 1 end
        end
    end
    return next_grid, active_count
end

local function render_visuals(src, grid, frame)
    local char_set = {" ", ".", ":", "*", "o", "O", "#", "@"}
    local output = {}
    table.insert(output, "\27[2J\27[H")
    table.insert(output, string.format("=== STACK AUTOMATON FRAME: %04d ===\n", frame))
    
    local src_idx = 1
    local src_len = #src
    
    for i = 1, grid_size do
        local line = ""
        for j = 1, grid_size do
            local state = grid[i][j]
            if state == 1 and src_idx <= src_len then
                local ch = src:sub(src_idx, src_idx)
                if ch == "\n" or ch == " " then ch = "." end
                line = line .. "\27[38;5;" .. (160 + (i + j) % 60) .. "m" .. ch .. "\27[0m"
            else
                line = line .. char_set[(state * 3 + (i + j) % 3) + 1]
            end
            src_idx = src_idx + 1
        end
        table.insert(output, line)
    end
    return table.concat(output, "\n")
end

local function decay_source(src, level)
    local chars = " .:-=+*#%@"
    local res = {}
    for i = 1, #src do
        local ch = src:sub(i, i)
        if math.random() < level and ch ~= "\n" then
            local r_idx = math.random(1, #chars)
            table.insert(res, chars:sub(r_idx, r_idx))
        else
            table.insert(res, ch)
        end
    end
    return table.concat(res)
end

local function play_harmony(active, frame)
    local base_note = notes[(active % #notes) + 1]
    local harmonic_ratio = 1 + ((frame * 3) % 7) * 0.25
    local freq = base_note * harmonic_ratio
    print(string.format("\27[33m♪ Harmonic Output: %.2f Hz (Active Cells: %d)\27[0m", freq, active))
end

-- Execution Loop
local current_src = source_code
for frame = 1, 40 do
    local active
    cell_grid, active = step_automaton(cell_grid)
    
    -- Visual decay of self-modifying source code based on stack execution
    current_src = decay_source(current_src, 0.03)
    
    -- Render Cellular Automaton & Decaying Text
    print(render_visuals(current_src, cell_grid, frame))
    
    -- Generate Harmonic Musical Sequence
    play_harmony(active, frame)
    
    -- Execution delay
    local t = os.clock()
    while os.clock() - t < 0.1 do end
end
]]

-- Load and execute the self-modifying stack controller
local executable = load(source_code)
executable()