local string_char, string_byte, math_floor, math_random, table_insert =
    string.char, string.byte, math.floor, math.random, table.insert

-- Base 2D Quine Source Matrix (Grid size: 16x16)
local source_code = {
    "# > > v . . . . . . . . . . . .",
    ". . . > v . . . . . . . . . . .",
    ". . . . > v . . . . . . . . . .",
    ". . . . . > v . . . . . . . . .",
    ". . . . . . > v . . . . . . . .",
    ". . . . . . . > v . . . . . . .",
    ". . . . . . . . > v . . . . . .",
    ". . . . . . . . . > v . . . . .",
    ". . . . . . . . . . > v . . . .",
    ". . . . . . . . . . . > v . . .",
    ". . . . . . . . . . . . > v . .",
    ". . . . . . . . . . . . . > v .",
    ". . . . . . . . . . . . . . > v",
    "^ . . . . . . . . . . . . . < .",
    ". ^ . . . . . . . . . . . . . .",
    ". . < < < < < < < < < < < < < ."
}

-- Wave-Function Collapse (WFC) Tile Set for 2D Grid
local WFC_TILES = {"+", "-", "|", "/", "\\", "X", " "}
local NOTES = {"C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"}

-- State Representation
local grid = {}
local height = #source_code
local width = #source_code[1]

-- Initialize 2D Memory Grid from Quine Template
for y = 1, height do
    grid[y] = {}
    local x = 1
    for char in source_code[y]:gmatch(".") do
        grid[y][x] = char
        x = x + 1
    end
end

-- Wave Function Collapse Engine: Mutates Quine Source into Maze Pattern
local function wave_function_collapse(grid)
    for y = 1, #grid do
        for x = 1, #grid[y] do
            if math_random() > 0.4 then
                local entropy_tile = WFC_TILES[math_random(1, #WFC_TILES)]
                grid[y][x] = entropy_tile
            end
        end
    end
end

-- 2D Esoteric Interpreter & Audio Path Walker
local function execute_2d_musical_quine(grid)
    local ip_x, ip_y = 1, 1
    local dir_x, dir_y = 1, 0
    local steps = 0
    local max_steps = 32
    local melody = {}

    print("=== SELF-MODIFYING QUINE: INITIAL SOURCE ===")
    for y = 1, #grid do
        print(table.concat(grid[y]))
    end

    print("\n=== COLLAPSING WAVE-FUNCTION MAZE ===")
    wave_function_collapse(grid)

    for y = 1, #grid do
        print(table.concat(grid[y]))
    end

    print("\n=== EXECUTING MAZE PATH AS MUSICAL NOTATION ===")
    while ip_x >= 1 and ip_x <= width and ip_y >= 1 and ip_y <= height and steps < max_steps do
        local cell = grid[ip_y][ip_x] or " "
        
        -- Path direction modification based on collapsed 2D instruction
        if cell == ">" or cell == "-" then dir_x, dir_y = 1, 0
        elseif cell == "<" then dir_x, dir_y = -1, 0
        elseif cell == "v" or cell == "|" then dir_x, dir_y = 0, 1
        elseif cell == "^" then dir_x, dir_y = 0, -1
        elseif cell == "/" then dir_x, dir_y = -dir_y, -dir_x
        elseif cell == "\\" then dir_x, dir_y = dir_y, dir_x
        elseif cell == "+" or cell == "X" then dir_x, dir_y = -dir_x, -dir_y
        end

        -- Map ASCII opcode byte value to pitch index
        local byte_val = string_byte(cell)
        local note_idx = (byte_val % #NOTES) + 1
        table_insert(melody, NOTES[note_idx])

        -- Advance instruction pointer
        ip_x = ip_x + dir_x
        ip_y = ip_y + dir_y
        steps = steps + 1
    end

    print("Synthesized Musical Sequence: " .. table.concat(melody, " -> "))
end

-- Run Self-Modifying Quine Execution
math.randomseed(12345)
execute_2d_musical_quine(grid)