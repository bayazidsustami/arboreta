local POSITIVE_WORDS = { love = true, joyful = true, bright = true, calm = true, gentle = true, radiant = true, warmth = true, peace = true }
local NEGATIVE_WORDS = { dark = true, void = true, cold = true, chaos = true, storm = true, pulse = true, burn = true, decay = true }

local source_code = [=[
local star = "radiant warmth"
  local planet_one = "bright gentle calm"
    local planet_two = "dark cold void chaos"
  local planet_three = "joyful love peace radiant"
    local planet_four = "burn storm decay pulse"
]=]

local function parse_code_dna(code)
    local planets = {}
    local line_index = 0
    for line in code:gmatch("[^\r\n]+") do
        line_index = line_index + 1
        local indent = #(line:match("^(%s*)") or "")
        local content = line:match("^%s*(.-)%s*$")
        if content ~= "" then
            local word_count = 0
            local total_length = 0
            local sentiment = 0
            for word in content:gmatch("%a+") do
                word_count = word_count + 1
                total_length = total_length + #word
                local lower_w = word:lower()
                if POSITIVE_WORDS[lower_w] then sentiment = sentiment + 1 end
                if NEGATIVE_WORDS[lower_w] then sentiment = sentiment - 1 end
            end
            local avg_length = word_count > 0 and (total_length / word_count) or 3
            local radius = math.max(2, indent + math.floor(avg_length))
            local speed = 0.05 + (1 / (radius + 1)) * 0.15
            local char_code = 64 + (line_index % 26) + 1
            if char_code == 64 or char_code == 79 then char_code = 80 end
            table.insert(planets, {
                radius = radius,
                speed = speed,
                angle = line_index * 1.2,
                symbol = string.char(char_code),
                sentiment = sentiment,
                pulse_phase = line_index * 0.5
            })
        end
    end
    return planets
end

local planets = parse_code_dna(source_code)
local width, height = 59, 29
local center_x, center_y = math.floor(width / 2), math.floor(height / 2)

local function sleep(s)
    local t = os.clock()
    while os.clock() - t < s do end
end

local function clear_screen()
    io.write("\27[H\27[2J")
end

local time = 0
for frame = 1, 150 do
    clear_screen()
    local grid = {}
    for y = 0, height - 1 do
        grid[y] = {}
        for x = 0, width - 1 do grid[y][x] = " " end
    end

    local sun_pulse = math.sin(time * 3)
    local sun_char = sun_pulse > 0.3 and "O" or (sun_pulse < -0.3 and "o" or "☼")
    grid[center_y][center_x] = sun_char

    for _, p in ipairs(planets) do
        p.angle = p.angle + p.speed
        local pulse = math.sin(time * 4 + p.pulse_phase) * (0.5 + math.abs(p.sentiment) * 0.5)
        local cur_radius = math.max(1, p.radius + pulse)
        local px = math.floor(center_x + math.cos(p.angle) * cur_radius * 1.8 + 0.5)
        local py = math.floor(center_y + math.sin(p.angle) * cur_radius + 0.5)
        if py >= 0 and py < height and px >= 0 and px < width then
            grid[py][px] = p.symbol
        end
    end

    local output = {}
    for y = 0, height - 1 do
        local row = {}
        for x = 0, width - 1 do table.insert(row, grid[y][x]) end
        table.insert(output, table.concat(row))
    end
    io.write(table.concat(output, "\n") .. "\n")
    io.write("Solar System DNA - Real-Time Code Parser Simulation\n")
    time = time + 0.15
    sleep(0.05)
end