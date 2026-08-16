local json = {
    decode = function(str)
        local pressure = tonumber(str:match('"pressure":%s*(%d+%.?%d*)')) or 1013.25
        local humidity = tonumber(str:match('"humidity":%s*(%d+%.?%d*)')) or 50.0
        return { main = { pressure = pressure, humidity = humidity } }
    end
}

local function fetch_weather_data(api_url)
    local mock_json_response = '{"main": {"pressure": 998.5, "humidity": 82.0}}'
    return json.decode(mock_json_response)
end

local function non_euclidean_transform(x, y, curvature)
    local r = math.sqrt(x * x + y * y)
    if r == 0 then return 0, 0 end
    local factor
    if curvature > 0 then
        factor = math.sin(r * curvature) / (r * curvature)
    elseif curvature < 0 then
        local k = math.abs(curvature)
        factor = (math.exp(r * k) - math.exp(-r * k)) / (2 * r * k)
    else
        factor = 1.0
    end
    return x * factor, y * factor
end

local function humidity_to_rgb(humidity, t)
    local hue = (humidity / 100.0 * 0.7 + t * 0.3) % 1.0
    local h = hue * 6
    local c = 0.8
    local x = c * (1 - math.abs(h % 2 - 1))
    local r, g, b = 0, 0, 0
    if h < 1 then r, g, b = c, x, 0
    elseif h < 2 then r, g, b = x, c, 0
    elseif h < 3 then r, g, b = 0, c, x
    elseif h < 4 then r, g, b = 0, x, c
    elseif h < 5 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    return math.floor((r + 0.2) * 255), math.floor((g + 0.2) * 255), math.floor((b + 0.2) * 255)
end

local function generate_origami_svg(filename, weather_data)
    local pressure = weather_data.main.pressure
    local humidity = weather_data.main.humidity
    
    local curvature = (1013.25 - pressure) / 500.0
    local base_nodes = 8
    local rings = 4
    local size = 600
    local cx, cy = size / 2, size / 2

    local file = io.open(filename, "w")
    if not file then error("Could not open file for writing: " .. filename) end

    file:write(string.format('<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" width="%d" height="%d" viewBox="0 0 %d %d">\n', size, size, size, size))
    file:write(string.format('  <rect width="100%%" height="100%%" fill="#1a1a24" />\n'))
    file:write('  <g transform="translate(' .. cx .. ',' .. cy .. ')">\n')

    local grid = {}
    for ring = 1, rings do
        grid[ring] = {}
        local radius = ring * (size * 0.38 / rings)
        local num_points = base_nodes * ring
        for i = 1, num_points do
            local angle = (i - 1) * (2 * math.pi / num_points)
            local raw_x = radius * math.cos(angle)
            local raw_y = radius * math.sin(angle)
            local nx, ny = non_euclidean_transform(raw_x, raw_y, curvature)
            grid[ring][i] = { x = nx, y = ny, angle = angle }
        end
    end

    for ring = 1, rings do
        local points = grid[ring]
        local num_points = #points
        for i = 1, num_points do
            local next_i = (i % num_points) + 1
            local p1 = points[i]
            local p2 = points[next_i]
            
            local fold_type = (i % 2 == 0) and "mountain" or "valley"
            local stroke_dash = (fold_type == "mountain") and "none" or "5,5"
            local stroke_width = (fold_type == "mountain") and "2" or "1.5"
            
            local r, g, b = humidity_to_rgb(humidity, ring / rings)
            local stroke_color = string.format("rgb(%d,%d,%d)", r, g, b)

            file:write(string.format('    <line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="%s" stroke-dasharray="%s" opacity="0.85" />\n',
                p1.x, p1.y, p2.x, p2.y, stroke_color, stroke_width, stroke_dash))

            if ring > 1 then
                local prev_points = grid[ring - 1]
                local prev_idx = math.floor((i - 1) * (#prev_points) / num_points) + 1
                local p_prev = prev_points[prev_idx]
                file:write(string.format('    <line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" stroke-width="1" stroke-dasharray="2,2" opacity="0.5" />\n',
                    p1.x, p1.y, p_prev.x, p_prev.y, stroke_color))
            else
                file:write(string.format('    <line x1="%.2f" y1="%.2f" x2="0" y2="0" stroke="%s" stroke-width="1" stroke-dasharray="2,2" opacity="0.5" />\n',
                    p1.x, p1.y, stroke_color))
            end
        end
    end

    file:write('  </g>\n')
    file:write('</svg>\n')
    file:close()
    print("Printable non-Euclidean origami folding pattern saved to " .. filename)
end

local weather_telemetry = fetch_weather_data("[https://api.openweathermap.org/data/2.5/weather?q=London](https://api.openweathermap.org/data/2.5/weather?q=London)")
generate_origami_svg("origami_pattern.svg", weather_telemetry)