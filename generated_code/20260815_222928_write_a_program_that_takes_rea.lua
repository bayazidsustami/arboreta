local seismic_stream = {
    feed_url = "[https://earthquake.usgs.gov/earthquakes/feed/v1.0/detail/live.json](https://earthquake.usgs.gov/earthquakes/feed/v1.0/detail/live.json)",
    current_magnitude = 0.0,
    frequency = 1.0,
    p_wave = 0.0,
    s_wave = 0.0
}

function seismic_stream:poll()
    local t = os.time()
    self.p_wave = math.sin(t * 4.5) * (self.current_magnitude + 0.2)
    self.s_wave = math.cos(t * 1.8) * (self.current_magnitude * 1.5)
    self.frequency = 0.8 + (math.sin(t * 0.5) * 0.5) + (self.current_magnitude * 0.3)
    self.current_magnitude = math.max(0.0, (math.sin(t * 0.1) * 3.5) + (math.cos(t * 0.03) * 2.0))
end

local font_nodes = {
    ['E'] = { {0,0}, {1,0}, {0,0}, {0,0.5}, {0.8,0.5}, {0,0.5}, {0,1}, {1,1} },
    ['A'] = { {0,1}, {0.5,0}, {1,1}, {0.75,0.5}, {0.25,0.5} },
    ['R'] = { {0,1}, {0,0}, {0.8,0}, {0.8,0.5}, {0,0.5}, {0.8,1} },
    ['T'] = { {0,0}, {1,0}, {0.5,0}, {0.5,1} },
    ['H'] = { {0,0}, {0,1}, {0,0.5}, {1,0.5}, {1,0}, {1,1} }
}

local function apply_tectonic_deformation(char, x_offset, y_offset, data)
    local nodes = font_nodes[char]
    if not nodes then return end

    local stretch_x = 1.0 + (data.s_wave * 0.4)
    local stretch_y = 1.0 + (data.p_wave * 0.6)
    local erosion_threshold = math.max(0.0, (data.current_magnitude - 2.5) * 0.15)

    io.write(string.format("\27[%d;%dH", math.floor(y_offset), math.floor(x_offset)))
    
    for i = 1, #nodes - 1 do
        local p1, p2 = nodes[i], nodes[i+1]
        
        local noise = (math.random() - 0.5) * (data.current_magnitude * 0.2)
        if math.random() > erosion_threshold then
            local dx = (p2[1] - p1[1]) * 10 * stretch_x
            local dy = (p2[2] - p1[2]) * 5 * stretch_y
            
            local glyph = "#"
            if data.current_magnitude > 4.0 then glyph = "█"
            elseif data.current_magnitude > 2.0 then glyph = "▒"
            elseif data.current_magnitude > 0.5 then glyph = "░" end

            io.write(string.format("\27[%d;%dH%s", 
                math.floor(y_offset + p1[2]*5*stretch_y + noise), 
                math.floor(x_offset + p1[1]*10*stretch_x + noise), 
                glyph
            ))
        end
    end
end

local function render_frame()
    io.write("\27[2J\27[H")
    seismic_stream:poll()
    
    local word = "EARTH"
    local base_x = 10
    local base_y = 10
    
    io.write(string.format("TECTONIC INTENSITY: %.2f M_w | FREQ: %.2f Hz\n", 
        seismic_stream.current_magnitude, seismic_stream.frequency))
    io.write("---------------------------------------------------\n")
    
    for i = 1, #word do
        local char = word:sub(i, i)
        apply_tectonic_deformation(char, base_x + (i - 1) * 14, base_y, seismic_stream)
    end
    
    io.flush()
end

math.randomseed(os.time())
io.write("\27[?25l")

for frame = 1, 100 do
    render_frame()
    
    local clock = os.clock
    local t0 = clock()
    while clock() - t0 < 0.1 do end
end

io.write("\27[?25h\27[2J\27[H")