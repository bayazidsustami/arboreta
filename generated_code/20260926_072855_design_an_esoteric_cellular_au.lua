-- Esoteric cellular automaton watercolor landscape painter
local math, os, io = math, os, io
local width, height = 50, 18
local grid, next_grid = {}, {}

math.randomseed(12345)
local palette = {
    "\27[48;5;153m ", -- soft sky
    "\27[48;5;110m~", -- flowing water
    "\27[48;5;108m^", -- distant peak
    "\27[48;5;71m*",  -- foliage
    "\27[48;5;138m.", -- earth
}

for y = 1, height do
    grid[y], next_grid[y] = {}, {}
    for x = 1, width do
        grid[y][x] = math.random(1, #palette)
    end
end

io.write("\27[2J\27[?25l")

for frame = 1, 100 do
    local out = {"\27[H"}
    for y = 1, height do
        for x = 1, width do
            table.insert(out, palette[grid[y][x]])
        end
        table.insert(out, "\27[0m\n")
    end
    io.write(table.concat(out))
    io.flush()

    for y = 1, height do
        for x = 1, width do
            local sum, count = 0, 0
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local ny, nx = y + dy, x + dx
                    if ny >= 1 and ny <= height and nx >= 1 and nx <= width then
                        sum = sum + grid[ny][nx]
                        count = count + 1
                    end
                end
            end
            local m = math.floor(sum / count)
            if (x * y + frame) % 11 == 0 then
                next_grid[y][x] = (m + math.random(0, 1)) % #palette + 1
            else
                next_grid[y][x] = (grid[y][x] + m) % #palette + 1
            end
        end
    end
    grid, next_grid = next_grid, grid
    os.execute("sleep 0.08")
end

io.write("\27[?25h\27[0m\n")