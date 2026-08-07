-- LightAutomaton: A Visual Programming Language Interpreter
-- Light rays bounce off ASCII optical elements in an evolving Cellular Automaton grid.

local Stack = {}
local Rays = {}

-- Initial ASCII program and Cellular Automaton grid
local BOARD_STR = [[
....................
.@>..../...\........
...1...|...|........
...2.../...\........
...+................
...P................
....................
..#.................
....................
]]

local board = {}
local height = 0
local width = 0

-- Parse initial board into 2D grid
for line in BOARD_STR:gmatch("[^\r\n]+") do
    height = height + 1
    board[height] = {}
    width = math.max(width, #line)
    for x = 1, #line do
        board[height][x] = line:sub(x, x)
    end
end

-- Directional vectors: 1=Up, 2=Right, 3=Down, 4=Left
local DX = {0, 1, 0, -1}
local DY = {-1, 0, 1, 0}

-- Find emitters (@) to create initial light rays
for y = 1, height do
    for x = 1, width do
        if board[y][x] == '@' then
            table.insert(Rays, {x = x, y = y, dir = 2, active = true})
        end
    end
end

-- Cellular Automaton step: dynamic evolution of optical elements
local function step_automaton()
    local next_board = {}
    for y = 1, height do
        next_board[y] = {}
        for x = 1, width do
            local char = board[y][x] or '.'
            -- Count neighbor mirrors (/ or \)
            local count = 0
            for dy = -1, 1 do
                for dx = -1, 1 do
                    if not (dx == 0 and dy == 0) then
                        local ny, nx = y + dy, x + dx
                        if board[ny] and (board[ny][nx] == '/' or board[ny][nx] == '\\') then
                            count = count + 1
                        end
                    end
                end
            end
            -- CA Rule: Mirrors flip orientation if heavily surrounded by neighboring mirrors
            if char == '/' and count >= 3 then
                next_board[y][x] = '\\'
            elseif char == '\\' and count >= 3 then
                next_board[y][x] = '/'
            else
                next_board[y][x] = char
            end
        end
    end
    board = next_board
end

-- Step active light rays forward and execute instructions on collision
local function step_rays()
    local active_count = 0
    for _, ray in ipairs(Rays) do
        if ray.active then
            active_count = active_count + 1
            ray.x = ray.x + DX[ray.dir]
            ray.y = ray.y + DY[ray.dir]

            -- Check boundaries
            if ray.y < 1 or ray.y > height or ray.x < 1 or ray.x > width then
                ray.active = false
            else
                local cell = board[ray.y][ray.x] or '.'
                
                -- Mirror reflections
                if cell == '/' then
                    local reflect = {2, 1, 4, 3} -- Up->Right, Right->Up, Down->Left, Left->Down
                    ray.dir = reflect[ray.dir]
                elseif cell == '\\' then
                    local reflect = {4, 3, 2, 1} -- Up->Left, Right->Down, Down->Right, Left->Up
                    ray.dir = reflect[ray.dir]
                -- Directional forces
                elseif cell == '^' then ray.dir = 1
                elseif cell == '>' then ray.dir = 2
                elseif cell == 'v' then ray.dir = 3
                elseif cell == '<' then ray.dir = 4
                -- Stack manipulation and I/O operations
                elseif cell >= '0' and cell <= '9' then
                    table.insert(Stack, tonumber(cell))
                elseif cell == '+' then
                    local b = table.remove(Stack) or 0
                    local a = table.remove(Stack) or 0
                    table.insert(Stack, a + b)
                elseif cell == 'P' then
                    local val = table.remove(Stack) or 0
                    print("LIGHT OUTPUT:", val)
                elseif cell == '#' then
                    ray.active = false
                end
            end
        end
    end
    return active_count
end

-- Render grid and active ray positions
local function render()
    local display = {}
    for y = 1, height do
        display[y] = {}
        for x = 1, width do
            display[y][x] = board[y][x] or '.'
        end
    end
    for _, ray in ipairs(Rays) do
        if ray.active and ray.y >= 1 and ray.y <= height and ray.x >= 1 and ray.x <= width then
            display[ray.y][ray.x] = '*'
        end
    end
    print("\n--- CA & Light Ray State ---")
    for y = 1, height do
        print(table.concat(display[y]))
    end
end

-- Main interpreter execution loop
print("Starting Light Automaton Interpreter...")
local steps = 0
while steps < 25 do
    render()
    local active = step_rays()
    if active == 0 then
        print("All light rays terminated.")
        break
    end
    step_automaton()
    steps = steps + 1
end