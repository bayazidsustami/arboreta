local self = [=[
-- Self-Modifying Memory-Fractal Quine
local self = %q
local select, collectgarbage, write = select, collectgarbage, io.write

local function depth()
    local d = 0
    while debug.getinfo(d + 1, "f") do d = d + 1 end
    return d - 1
end

local function draw(d, max, mem)
    if d > max then return end
    local indent = string.rep("  ", d)
    local char = (d %% 2 == 0) and "Y" or "|"
    local leaf = (d == max) and ("* [mem:" .. math.floor(mem) .. "KB]") or ""
    write(indent .. char .. "--" .. leaf .. "\n")
    if d < max then
        draw(d + 1, max, mem)
        if mem %% (d + 1) > 1 then
            draw(d + 1, max, mem)
        end
    end
end

local function mutate(code)
    local mem = collectgarbage("count")
    local comment = string.format("\n-- Mutation step [Mem: %.2f KB, Stack: %d]", mem, depth())
    return code .. comment
end

local function run()
    local mem = collectgarbage("count")
    local max_depth = math.min(10, math.max(3, math.floor(mem %% 7) + 3))
    write("\027[H\027[2J")
    write("=== EXECUTION STACK FRACTAL TREE ===\n")
    draw(1, max_depth, mem)
    write("\n=== QUINE OUTPUT (MUTATED) ===\n")
    local mutated = mutate(self)
    write(string.format(mutated, mutated) .. "\n")
end

run()
]=]
local select, collectgarbage, write = select, collectgarbage, io.write

local function depth()
    local d = 0
    while debug.getinfo(d + 1, "f") do d = d + 1 end
    return d - 1
end

local function draw(d, max, mem)
    if d > max then return end
    local indent = string.rep("  ", d)
    local char = (d % 2 == 0) and "Y" or "|"
    local leaf = (d == max) and ("* [mem:" .. math.floor(mem) .. "KB]") or ""
    write(indent .. char .. "--" .. leaf .. "\n")
    if d < max then
        draw(d + 1, max, mem)
        if mem % (d + 1) > 1 then
            draw(d + 1, max, mem)
        end
    end
end

local function mutate(code)
    local mem = collectgarbage("count")
    local comment = string.format("\n-- Mutation step [Mem: %.2f KB, Stack: %d]", mem, depth())
    return code .. comment
end

local function run()
    local mem = collectgarbage("count")
    local max_depth = math.min(10, math.max(3, math.floor(mem % 7) + 3))
    write("\027[H\027[2J")
    write("=== EXECUTION STACK FRACTAL TREE ===\n")
    draw(1, max_depth, mem)
    write("\n=== QUINE OUTPUT (MUTATED) ===\n")
    local mutated = mutate(self)
    write(string.format(mutated, mutated) .. "\n")
end

run()