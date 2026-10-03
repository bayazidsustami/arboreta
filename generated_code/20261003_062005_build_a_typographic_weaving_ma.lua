-- Typographic Weaving Machine: Historical Love Letters to Chaotic Geometric Tapestries
-- Uses recursive Bezier curves, prime number offsets, and text character analysis.

local primes = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71}

-- Sample historical love letter (Napoleon Bonaparte to Josephine, 1796)
local letter = "I awaken to you in my memory. Your portrait and the intoxicating evening of yesterday have left no senses at rest. Sweet and incomparable Josephine, what a strange effect you have on my heart!"

-- SVG canvas setup
local width, height = 900, 900
local svg_parts = {}
table.insert(svg_parts, string.format('<svg width="%d" height="%d" xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" style="background:#080812;">', width, height))

-- Helper: generate recursive Bezier curves based on text and prime offsets
local function generate_bezier(x1, y1, x2, y2, depth, prime_idx, char_code)
    if depth <= 0 then
        return ""
    end
    
    local p = primes[(prime_idx % #primes) + 1]
    local offset = (char_code % p) * (depth % 2 == 0 and 1 or -1)
    
    -- Control points influenced by prime offsets and character code
    local cx1 = (x1 + x2) / 2 + offset * math.sin(char_code)
    local cy1 = (y1 + y2) / 2 + offset * math.cos(prime_idx)
    local cx2 = x1 + (x2 - x1) * 0.3 + (p * 0.7)
    local cy2 = y1 + (y2 - y1) * 0.7 - (p * 0.7)

    -- Color shifting based on prime and depth
    local r = (char_code * p * 5) % 256
    local g = (depth * 40 + p * 13) % 256
    local b = (x1 + y1 + char_code * 3) % 256
    local opacity = 0.12 + (depth * 0.04)

    local path = string.format(
        '<path d="M %f %f C %f %f, %f %f, %f %f" stroke="rgb(%d,%d,%d)" stroke-width="%f" fill="none" opacity="%f" />\n',
        x1, y1, cx1, cy1, cx2, cy2, x2, y2, r, g, b, depth * 0.5, opacity
    )

    -- Recursive branches
    local sub1 = generate_bezier(x1, y1, cx1, cy1, depth - 1, prime_idx + 1, char_code + p)
    local sub2 = generate_bezier(cx1, cy1, x2, y2, depth - 1, prime_idx + 2, char_code - p)

    return path .. sub1 .. sub2
end

-- Weave the letter into the tapestry
local x_cursor, y_cursor = width / 2, height / 2
for i = 1, #letter do
    local char = letter:sub(i, i)
    local code = string.byte(char)
    local prime = primes[(i % #primes) + 1]

    -- Target coordinates driven by character codes and primes in a spiral-chaotic weave
    local angle = i * prime * 0.17
    local radius = (i * prime * 3.5) % (width * 0.45)
    local target_x = (width / 2) + radius * math.cos(angle)
    local target_y = (height / 2) + radius * math.sin(angle)

    -- Generate recursive tapestry thread
    local bezier_mesh = generate_bezier(x_cursor, y_cursor, target_x, target_y, 4, i, code)
    table.insert(svg_parts, bezier_mesh)

    -- Update weave cursor
    x_cursor, y_cursor = target_x, target_y
end

table.insert(svg_parts, '</svg>')

-- Output the tapestry to an SVG file
local file = io.open("love_tapestry.svg", "w")
if file then
    file:write(table.concat(svg_parts))
    file:close()
end