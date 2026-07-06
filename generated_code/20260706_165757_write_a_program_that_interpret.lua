-- live_automaton_sudoku_poem.lua
-- A playful mock‑up: reads dummy audio spectrum, builds a 1‑D cellular automaton,
-- solves a Sudoku puzzle, encodes a short poem in glider‑like patterns,
-- and streams an SVG animation to stdout.

local math, io, os = math, io, os

-----------------------------------------------------------------
-- 1. Simulated audio spectrum (random histogram updated each tick)
-----------------------------------------------------------------
local function get_spectrum()
    local bins = {}
    for i = 1, 16 do        -- 16 frequency bins
        bins[i] = math.random()
    end
    return bins
end

-----------------------------------------------------------------
-- 2. Derive CA rule from spectrum (Wolfram elementary rule 0‑255)
-----------------------------------------------------------------
local function spectrum_to_rule(spectrum)
    local sum = 0
    for i, v in ipairs(spectrum) do sum = sum + v end
    local rule = math.floor((sum % 1) * 255)   -- map fractional part to 0‑255
    return rule
end

-----------------------------------------------------------------
-- 3. 1‑D cellular automaton step (binary cells)
-----------------------------------------------------------------
local function ca_step(state, rule)
    local new = {}
    local mask = 0
    for i = 1, #state do
        local left  = state[(i-2) % #state + 1]
        local cur   = state[i]
        local right = state[i % #state + 1]
        mask = (left << 2) | (cur << 1) | right
        new[i] = (rule >> mask) & 1
    end
    return new
end

-----------------------------------------------------------------
-- 4. Simple Sudoku generator + solver (hard‑coded puzzle)
-----------------------------------------------------------------
local sudoku = {
    {5,3,0,0,7,0,0,0,0},
    {6,0,0,1,9,5,0,0,0},
    {0,9,8,0,0,0,0,6,0},
    {8,0,0,0,6,0,0,0,3},
    {4,0,0,8,0,3,0,0,1},
    {7,0,0,0,2,0,0,0,6},
    {0,6,0,0,0,0,2,8,0},
    {0,0,0,4,1,9,0,0,5},
    {0,0,0,0,8,0,0,7,9},
}

local function find_empty(board)
    for r = 1,9 do
        for c = 1,9 do
            if board[r][c] == 0 then return r,c end
        end
    end
    return nil
end

local function valid(board, r, c, n)
    for i = 1,9 do
        if board[r][i]==n or board[i][c]==n then return false end
    end
    local br, bc = ((r-1)//3)*3+1, ((c-1)//3)*3+1
    for i = br, br+2 do
        for j = bc, bc+2 do
            if board[i][j]==n then return false end
        end
    end
    return true
end

local function solve(board)
    local r,c = find_empty(board)
    if not r then return true end
    for n = 1,9 do
        if valid(board,r,c,n) then
            board[r][c]=n
            if solve(board) then return true end
            board[r][c]=0
        end
    end
    return false
end

local solved = {}
for i=1,9 do solved[i] = {} for j=1,9 do solved[i][j]=sudoku[i][j] end end
solve(solved)

-----------------------------------------------------------------
-- 5. Poem verses (encoded as glider patterns)
-----------------------------------------------------------------
local verses = {
    "sound",
    "waves",
    "code",
    "flow",
}

-- map each character to a small glider pattern (binary vector)
local function char_to_pattern(ch)
    local bits = {}
    local code = string.byte(ch)
    for i=8,1,-1 do bits[i] = (code >> (8-i)) & 1 end
    return bits
end

-----------------------------------------------------------------
-- 6. SVG streaming
-----------------------------------------------------------------
local width, height = 800, 600
local cellsize = 4
local rows = height // cellsize
local cols = width // cellsize

io.write(string.format([[
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">
<style>rect{stroke:none}</style>
]], width, height, width, height))

local function draw_row(y, state)
    for x=1,#state do
        if state[x]==1 then
            io.write(string.format(
                '<rect x="%d" y="%d" width="%d" height="%d" fill="black"/>',
                (x-1)*cellsize, y*cellsize, cellsize, cellsize))
        end
    end
end

-- initial random CA state
local ca_state = {}
for i=1,cols do ca_state[i] = math.random(0,1) end

-- main loop: 200 frames
for frame=1,200 do
    -- 1) get spectrum and rule
    local spec = get_spectrum()
    local rule = spectrum_to_rule(spec)

    -- 2) evolve CA
    ca_state = ca_step(ca_state, rule)

    -- 3) embed a verse every 50 frames as glider (simple left‑to‑right)
    if frame % 50 == 0 then
        local verse = verses[(frame//50) % #verses + 1]
        local pat = char_to_pattern(verse:sub(1,1))  -- one char per embed
        for i=1,#pat do
            if i <= #ca_state then ca_state[i] = pat[i] end
        end
    end

    -- 4) draw current row
    draw_row(frame % rows, ca_state)

    -- 5) occasional Sudoku overlay (every 100 frames)
    if frame % 100 == 0 then
        for r=1,9 do
            for c=1,9 do
                local val = solved[r][c]
                if val>0 then
                    local x = (c-1)*cellsize*2 + 200
                    local y = (r-1)*cellsize*2 + 50
                    io.write(string.format(
                        '<text x="%d" y="%d" font-size="%d" fill="red">%d</text>',
                        x, y, cellsize*2, val))
                end
            end
        end
    end
end

io.write("</svg>\n")