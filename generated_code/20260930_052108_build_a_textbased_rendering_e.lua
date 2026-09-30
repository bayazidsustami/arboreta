local function fib(n)
    if n <= 1 then return n end
    local a, b = 0, 1
    for i = 2, n do
        a, b = b, a + b
    end
    return b
end

local function get_trace()
    local trace = {}
    for i = 2, 10 do
        local info = debug.getinfo(i, "Sln")
        if not info then break end
        table.insert(trace, {
            name = info.name or "anonymous",
            linedefined = info.linedefined or 0,
            what = info.what or "Lua"
        })
    end
    if #trace == 0 then
        -- Fallback mock stack if debug info is bare
        trace = {
            {name = "crash_handler", linedefined = 42},
            {name = "recursive_bloom", linedefined = 17},
            {name = "fib_offset", linedefined = 8},
            {name = "root_init", linedefined = 1}
        }
    end
    return trace
end

local function render_mandala()
    local width, height = 61, 31
    local cx, cy = math.floor(width / 2), math.floor(height / 2)
    
    local grid = {}
    for y = 1, height do
        grid[y] = {}
        for x = 1, width do
            grid[y][x] = " "
        end
    end

    local trace = get_trace()
    local box_chars = {"─", "│", "┌", "┐", "└", "┘", "┼", "╭", "╮", "╰", "╯", "╱", "╲", "*", "o", "•"}

    -- Recursive Fibonacci blossom generator mapping stack frames
    local function draw_petal(x, y, depth, angle, length)
        if depth <= 0 or length < 1 then return end
        
        local f = fib(depth + 2)
        local rad = angle + (f % 5) * 0.2
        local nx = math.floor(x + math.cos(rad) * length + 0.5)
        local ny = math.floor(y + math.sin(rad) * length * 0.5 + 0.5)

        if nx >= 1 and nx <= width and ny >= 1 and ny <= height then
            local char_idx = ((nx + ny + depth) % #box_chars) + 1
            grid[ny][nx] = box_chars[char_idx]
        end

        local offset = (f % 3) + 1
        draw_petal(nx, ny, depth - 1, angle + 0.785, length - offset)
        draw_petal(nx, ny, depth - 1, angle - 0.785, length - offset)
    end

    -- Seed the mandala using stack trace metadata
    for i, frame in ipairs(trace) do
        local depth = math.min(#trace + 2, 7)
        local base_angle = (i * 2 * math.pi) / #trace
        local length = (frame.linedefined % 7) + 4
        draw_petal(cx, cy, depth, base_angle, length)
    end

    -- Center core representing the crash point
    grid[cy][cx] = "◎"

    -- Assemble and print output
    local output = {}
    table.insert(output, "--- CRASH TRACE BOTANICAL MANDALA ---")
    for y = 1, height do
        table.insert(output, table.concat(grid[y]))
    end
    table.insert(output, "Status: Process terminated gracefully via recursive floral bloom.")
    
    return table.concat(output, "\n")
end

print(render_mandala())