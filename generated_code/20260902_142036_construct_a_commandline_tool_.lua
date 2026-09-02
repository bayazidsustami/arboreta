local function run_cmd(cmd)
    local handle = io.popen(cmd)
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()
    return result
end

local function parse_git_log()
    local raw_log = run_cmd('git log --graph --oneline --shortstat 2>/dev/null')
    if not raw_log or raw_log == "" then
        print("\27[31mError: Not a git repository or no commit history found.\27[0m")
        os.exit(1)
    end

    local nodes = {}
    local total_churn = 0

    for line in raw_log:gmatch("[^\r\n]+") do
        if line:match("^[%*|%s%/%\\%-]+") then
            local graph, hash, msg = line:match("^([%*|%s%/%\\%-]+)%s+([%a%d]+)%s+(.*)")
            if hash then
                local is_branch = graph:find("[/%\\%-]") ~= nil
                table.insert(nodes, {
                    hash = hash,
                    msg = msg,
                    is_branch = is_branch,
                    churn = 1 -- default base churn
                })
            end
        elseif line:match("changed") then
            local ins = tonumber(line:match("(%d+) insertion")) or 0
            local del = tonumber(line:match("(%d+) deletion")) or 0
            local churn = ins + del
            if #nodes > 0 then
                nodes[#nodes].churn = nodes[#nodes].churn + churn
            end
            total_churn = total_churn + churn
        end
    end
    return nodes, total_churn
end

local function build_bonsai(nodes)
    local width, height = 60, 24
    local grid = {}
    for y = 1, height do
        grid[y] = {}
        for x = 1, width do grid[y][x] = " " end
    end

    -- Draw pot
    local pot_y = height - 2
    for x = 18, 42 do grid[pot_y][x] = "\27[38;5;130m=\27[0m" end
    for x = 20, 40 do grid[pot_y + 1][x] = "\27[38;5;130m\\\27[38;5;94m" .. ("~"):rep(19) .. "/\27[0m" end
    for x = 22, 38 do grid[pot_y + 2][x] = "\27[38;5;130m\\" .. ("_"):rep(15) .. "/\27[0m" end

    -- Trunk and Branch Simulation
    local leaves = {"\27[32m@\27[0m", "\27[32m%\27[0m", "\27[38;5;34m&\27[0m", "\27[38;5;28m*\27[0m", "\27[92m#\27[0m"}
    local curr_x, curr_y = 30, pot_y - 1
    local branch_stack = {}

    for i, node in ipairs(nodes) do
        -- Render trunk segment
        if curr_y > 3 then
            grid[curr_y][curr_x] = "\27[38;5;94m|\27[0m"
            curr_y = curr_y - 1
        end

        -- Branch off on feature fork
        if node.is_branch or i % 3 == 0 then
            local dir = (i % 2 == 0) and 1 or -1
            table.insert(branch_stack, {x = curr_x, y = curr_y, dir = dir, churn = node.churn})
        end
    end

    -- Grow Branches & Leaves
    for _, b in ipairs(branch_stack) do
        local bx, by = b.x, b.y
        local length = math.min(8, math.max(2, math.floor(b.churn / 5) + 2))
        
        for step = 1, length do
            bx = bx + b.dir
            if step % 2 == 0 then by = by - 1 end
            if by > 1 and bx > 2 and bx < width - 1 then
                grid[by][bx] = "\27[38;5;94m" .. (b.dir > 0 and "\\" or "/") .. "\27[0m"
            end
        end

        -- Add foliage cluster based on code churn
        local density = math.min(12, math.max(3, math.floor(b.churn / 2) + 2))
        for _ = 1, density do
            local lx = bx + math.random(-2, 2)
            local ly = by + math.random(-1, 1)
            if ly > 1 and ly < pot_y and lx > 2 and lx < width - 1 then
                grid[ly][lx] = leaves[math.random(#leaves)]
            end
        end
    end

    -- Render canvas
    os.execute("clear || cls")
    print("\27[1m=== Git Commit Bonsai ===\27[0m\n")
    for y = 1, height do
        print(table.concat(grid[y]))
    end
end

-- Main Execution
math.randomseed(os.time())
local nodes, total_churn = parse_git_log()
build_bonsai(nodes)
print(string.format("\n\27[1mTree Stats:\27[0m %d Commits parsed | Total Churn: %d lines\n", #nodes, total_churn))