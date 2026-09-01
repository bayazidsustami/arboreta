-- Setup & Config
local W, H = 80, 40
local grid, nextGrid = {}, {}
local t = 0

-- Chaotic Attractor state (Lorenz system parameters)
local lx, ly, lz = 0.1, 0.0, 0.0
local sigma, rho, beta = 10.0, 28.0, 8.0 / 3.0

-- Palette mapping (density & neighborhood state to ASCII/ANSI color)
local densityChars = { " ", ".", ":", "~", "*", "s", "S", "#", "@" }
local colorCodes   = { 34, 36, 32, 33, 31, 35 } -- Blue, Cyan, Green, Yellow, Red, Magenta

-- Initialize Grid Buffer
for y = 1, H do
    grid[y] = {}
    nextGrid[y] = {}
    for x = 1, W do
        grid[y][x]     = { density = 0, state = 0 }
        nextGrid[y][x] = { density = 0, state = 0 }
    end
end

-- Clear Terminal Utility
local function clearScreen()
    io.write("\27[H")
end

-- Update Chaotic System (Lorenz Attractor) to shift emitter drift
local function updateChaos()
    local dt = 0.01
    local dx = sigma * (ly - lx) * dt
    local dy = (lx * (rho - lz) - ly) * dt
    local dz = (lx * ly - beta * lz) * dt
    lx, ly, lz = lx + dx, ly + dy, lz + dz
end

-- Helper: Get Cellular Automata Rule Output (B3/S23 variant for density drift)
local function executeMicroScript(y, x)
    local cell = grid[y][x]
    local activeNeighbors = 0
    local totalNeighborDensity = 0

    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                local ny, nx = y + dy, x + dx
                if ny >= 1 and ny <= H and nx >= 1 and nx <= W then
                    if grid[ny][nx].density > 0.1 then
                        activeNeighbors = activeNeighbors + 1
                    end
                    totalNeighborDensity = totalNeighborDensity + grid[ny][nx].density
                end
            end
        end
    end

    -- Micro-script: Execute cellular automata transitions
    local nextState = cell.state
    local nextDensity = cell.density

    -- Cellular Rule: Density diffusion driven by neighbors
    if activeNeighbors >= 2 and activeNeighbors <= 4 then
        nextState = (cell.state + 1) % #colorCodes
        nextDensity = math.min(1.0, cell.density + 0.05 + (totalNeighborDensity * 0.02))
    else
        nextState = math.max(0, cell.state - 1)
        nextDensity = math.max(0.0, cell.density - 0.08)
    end

    return nextDensity, nextState
end

-- Main Render/Update Loop
io.write("\27[2J\27[?25l") -- Clear screen and hide cursor

for frame = 1, 300 do
    t = t + 0.05
    updateChaos()

    -- Inject smoke near bottom using chaotic attractor X/Y projection
    local emitterX = math.floor(W / 2 + (lx * 1.5))
    emitterX = math.max(2, math.min(W - 1, emitterX))
    grid[H][emitterX].density = 1.0
    grid[H][emitterX].state   = math.floor(t) % #colorCodes + 1

    if emitterX + 1 <= W then
        grid[H][emitterX + 1].density = 0.8
    end

    -- Process Smoke Dynamics (Advection + Cellular Micro-Scripts)
    for y = 1, H do
        for x = 1, W do
            local cell = grid[y][x]

            if y > 1 then
                -- Buoyant Rising Behavior with Chaotic Wind Turbulence
                local windShift = (math.sin(t + y * 0.1) > 0.3) and 1 or ((math.cos(t * 0.5) > 0.3) and -1 or 0)
                local targetX = math.max(1, math.min(W, x + windShift))
                
                -- Execute local micro-script based on neighbors
                local nDensity, nState = executeMicroScript(y, x)

                -- Rise upwards while taking on updated cellular state
                nextGrid[y - 1][targetX].density = math.min(1.0, nextGrid[y - 1][targetX].density + nDensity * 0.85)
                nextGrid[y - 1][targetX].state   = nState
            end
        end
    end

    -- Swap Buffers & Draw Canvas
    clearScreen()
    local output = {}

    for y = 1, H do
        local line = {}
        for x = 1, W do
            local c = nextGrid[y][x]
            grid[y][x].density = c.density
            grid[y][x].state   = c.state

            -- Reset next buffer
            nextGrid[y][x].density = 0
            nextGrid[y][x].state   = 0

            -- Render Character & Color
            local charIdx = math.floor(c.density * (#densityChars - 1)) + 1
            charIdx = math.max(1, math.min(#densityChars, charIdx))
            local char = densityChars[charIdx]

            if char ~= " " then
                local color = colorCodes[(c.state % #colorCodes) + 1]
                table.insert(line, string.format("\27[%dm%s\27[0m", color, char))
            else
                table.insert(line, " ")
            end
        end
        table.insert(output, table.concat(line))
    end

    io.write(table.concat(output, "\n"))
    
    -- Frame Timing Delay (~30 FPS)
    local start = os.clock()
    while os.clock() - start < 0.033 do end
end

io.write("\27[?25h\n") -- Restore cursor