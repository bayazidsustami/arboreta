local G=0
local S=[=[local G=%d
local S=%q

-- Self-Modifying Quine: Execution Stack Fluid Dynamics Visualizer
-- Variable mutations act as heat sources; function calls generate turbulent vortices.

local W, H = 50, 16
local grid = {}
for y = 1, H do
    grid[y] = {}
    for x = 1, W do
        grid[y][x] = {u = 0, v = 0, t = 0, d = 0}
    end
end

local palette = " .':-=+*#@$"

-- Injects angular momentum / velocity curl (vortex) on function calls
local function vortex(cx, cy, radius, strength)
    for y = 1, H do
        for x = 1, W do
            local dx, dy = x - cx, y - cy
            local dist = math.sqrt(dx * dx + dy * dy) + 0.1
            if dist < radius then
                local factor = (1 - dist / radius) * strength
                grid[y][x].u = grid[y][x].u - (dy / dist) * factor
                grid[y][x].v = grid[y][x].v + (dx / dist) * factor
            end
        end
    end
end

-- Injects thermal energy / density at mutation coordinates
local function heat(cx, cy, val)
    cx, cy = math.floor(cx), math.floor(cy)
    if cx >= 1 and cx <= W and cy >= 1 and cy <= H then
        grid[cy][cx].t = grid[cy][cx].t + val
        grid[cy][cx].d = grid[cy][cx].d + val
    end
end

-- Eulerian fluid solver step (advection, buoyancy, dissipation)
local function step_fluid()
    local next_grid = {}
    for y = 1, H do
        next_grid[y] = {}
        for x = 1, W do
            local c = grid[y][x]
            -- Thermal buoyancy (hot fluid moves upward)
            c.v = c.v - c.t * 0.04
            
            -- Semi-Lagrangian advection lookup
            local src_x = math.max(1, math.min(W, x - c.u))
            local src_y = math.max(1, math.min(H, y - c.v))
            local ix, iy = math.floor(src_x), math.floor(src_y)
            local src = grid[iy][ix]
            
            next_grid[y][x] = {
                u = src.u * 0.93,
                v = src.v * 0.93,
                t = src.t * 0.88,
                d = src.d * 0.90
            }
        end
    end
    grid = next_grid
end

-- Render fluid field to ASCII buffer
local function render()
    local frame = {"\27[H\27[2J=== EXECUTION STACK FLUID DYNAMICS (Generation " .. G .. ") ==="}
    for y = 1, H do
        local line = {}
        for x = 1, W do
            local cell = grid[y][x]
            local intensity = math.min(1, math.max(0, (cell.t + cell.d) * 0.35))
            local idx = math.floor(intensity * (#palette - 1)) + 1
            line[#line + 1] = palette:sub(idx, idx)
        end
        frame[#frame + 1] = table.concat(line)
    end
    print(table.concat(frame, "\n"))
end

-- Intercept execution stack events using Lua debug hook
local depth = 0
local in_hook = false

debug.sethook(function(event)
    if in_hook then return end
    in_hook = true

    if event == "call" then
        depth = depth + 1
        -- Stack depth determines vortex placement and rotational power
        local cx = math.abs(math.fmod(depth * 7, W - 8)) + 4
        local cy = math.abs(math.fmod(depth * 3, H - 4)) + 2
        vortex(cx, cy, 4.0, 2.2)
    elseif event == "return" or event == "tail return" then
        depth = math.max(0, depth - 1)
    elseif event == "line" then
        local info = debug.getinfo(2, "l")
        if info then
            -- Line executions and state updates act as thermal sources
            local hx = math.abs(math.fmod(info.currentline * 5, W)) + 1
            local hy = math.abs(math.fmod(info.currentline * 3, H)) + 1
            heat(hx, hy, 1.6)
        end
    end

    step_fluid()
    in_hook = false
end, "crl")

-- Recursive workload that induces stack turbulence & mutations
local function recurse_and_mutate(n)
    local state = n * 1.7
    for i = 1, 3 do
        state = state + i * 0.8
    end
    if n > 0 then
        state = state + recurse_and_mutate(n - 1)
    end
    return state
end

-- Run simulation payload
recurse_and_mutate(5)

-- Detach hook & render final fluid simulation state
debug.sethook()
render()

-- Output self-modified source code (Quine propagation)
print("\n-- MODIFIED QUINE SOURCE (Gen " .. (G + 1) .. ") --")
print(string.format(S, G + 1, S))
]=]

print(string.format(S, G, S))