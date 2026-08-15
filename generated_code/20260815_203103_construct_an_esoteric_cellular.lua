-- Esoteric Cellular Automaton: Lexical & Syntactic Echoes
-- A self-contained terminal automaton where text cells render characters from a procedural poem.
-- Cells evolve state based on the sentiment and rhythm of neighbor text.

local os, io, string, math = os, io, string, math

-- Terminal ANSI Helpers
local function clearScreen() io.write("\27[2J\27[H") end
local function hideCursor() io.write("\27[?25l") end
local function showCursor() io.write("\27[?25h") end
local function rgbColor(r, g, b, fg)
    local code = fg and "38" or "48"
    return string.format("\27[%s;2;%d;%d;%dm", code, r, g, b)
end
local reset = "\27[0m"
local bold = "\27[1m"
local dim = "\27[2m"

-- Procedural Lexicon and Generator
local subjects = {"shadow", "light", "whisper", "echo", "void", "pulse", "silence", "ember"}
local verbs    = {"fades", "blooms", "drifts", "screams", "dances", "sleeps", "seethes", "glimmers"}
local adjs     = {"cold", "warm", "hollow", "vibrant", "ancient", "fleeting", "dark", "radiant"}

-- Lexical Sentiment Weights (-1.0 to 1.0)
local sentiment = {
    shadow = -0.5, light = 0.8, whisper = 0.1, echo = -0.1, void = -0.9, pulse = 0.6, silence = -0.2, ember = 0.4,
    fades = -0.4, blooms = 0.7, drifts = 0.0, screams = -0.7, dances = 0.6, sleeps = 0.2, seethes = -0.8, glimmers = 0.5,
    cold = -0.6, warm = 0.7, hollow = -0.7, vibrant = 0.9, ancient = 0.1, fleeting = -0.2, dark = -0.6, radiant = 0.9
}

local function randomChoice(t) return t[math.random(#t)] end

local function generatePoemLine()
    return string.format("%s %s %s", randomChoice(adjs), randomChoice(subjects), randomChoice(verbs))
end

-- Automaton Setup
local WIDTH, HEIGHT = 40, 20
local grid = {}

for y = 1, HEIGHT do
    grid[y] = {}
    local line = generatePoemLine()
    for x = 1, WIDTH do
        local charIndex = ((x - 1) % #line) + 1
        local char = line:sub(charIndex, charIndex)
        grid[y][x] = {
            char = char,
            val = math.random(),          -- Energy/State (0.0 to 1.0)
            sentiment = sentiment[char] or 0.0,
            rhythm = (x % 2 == 0) and 1 or -1
        }
    end
end

-- Neighborhood Sentiment & Rhythm Analysis
local function getNeighborhoodMetrics(grid, x, y)
    local totalSent = 0
    local rhythmSync = 0
    local count = 0

    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                local nx = (x + dx - 1) % WIDTH + 1
                local ny = (y + dy - 1) % HEIGHT + 1
                local neighbor = grid[ny][nx]
                
                totalSent = totalSent + neighbor.sentiment
                rhythmSync = rhythmSync + (neighbor.rhythm * grid[y][x].rhythm)
                count = count + 1
            end
        end
    end

    return totalSent / count, rhythmSync / count
end

-- Main Evolution Step
local function step(grid)
    local nextGrid = {}
    local newPoemLine = generatePoemLine()

    for y = 1, HEIGHT do
        nextGrid[y] = {}
        for x = 1, WIDTH do
            local cell = grid[y][x]
            local avgSent, rhythmSync = getNeighborhoodMetrics(grid, x, y)
            
            -- Evolve Energy: Lexical sentiment shifts state, rhythm sync stabilizes/destabilizes
            local newVal = cell.val + (avgSent * 0.15) + (rhythmSync * 0.05)
            newVal = math.max(0, math.min(1, newVal))

            -- Mutate Character based on state transition threshold
            local char = cell.char
            if math.abs(newVal - cell.val) > 0.1 or math.random() < 0.02 then
                local idx = math.random(1, #newPoemLine)
                char = newPoemLine:sub(idx, idx)
            end

            nextGrid[y][x] = {
                char = char,
                val = newVal,
                sentiment = avgSent,
                rhythm = (rhythmSync > 0) and 1 or -1
            }
        end
    end
    return nextGrid
end

-- Render Field to Terminal
local function draw(grid)
    local buffer = {}
    for y = 1, HEIGHT do
        local lineBuffer = {}
        for x = 1, WIDTH do
            local cell = grid[y][x]
            
            -- Map Sentiment to RGB Palette (Negative = Deep Blue/Purple, Positive = Gold/Crimson)
            local r = math.floor(127 + cell.sentiment * 127)
            local g = math.floor(cell.val * 180)
            local b = math.floor(127 - cell.sentiment * 127)
            
            -- Typographic style driven by Syntactic Rhythm
            local style = ""
            if cell.rhythm > 0 and cell.val > 0.5 then
                style = bold
            elseif cell.val < 0.3 then
                style = dim
            end

            local fg = rgbColor(r, g, b, true)
            table.insert(lineBuffer, style .. fg .. cell.char .. reset)
        end
        table.insert(buffer, table.concat(lineBuffer))
    end
    io.write("\27[H" .. table.concat(buffer, "\n") .. "\n")
end

-- Execution Loop
local function run()
    math.randomseed(os.time())
    hideCursor()
    clearScreen()

    for _ = 1, 100 do
        draw(grid)
        grid = step(grid)
        os.execute("sleep 0.08 2>/dev/null || ping -c 1 127.0.0.1 >/dev/null") -- Portable sleep delay
    end

    showCursor()
end

run()