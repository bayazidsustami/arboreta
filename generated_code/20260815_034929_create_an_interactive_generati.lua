-- Ambient Audio Calligram & Fluid Dynamics Renderer in Pure Lua
-- Simulates real-time ambient audio noise levels driving a grid-based 2D fluid velocity field.
-- Renders density and velocity as morphing ASCII calligrams using dynamic character mapping and ANSI colors.

local W, H = 70, 24
local density = {}
local vx, vy = {}, {}
local prev_density = {}
local chars = {" ", ".", ":", "-", "=", "+", "*", "%", "@", "#", "█"}
local word_chars = {"S", "O", "U", "N", "D", "W", "A", "V", "E", "E", "C", "H", "O", "F", "L", "U", "I", "D"}

-- Initialize simulation grids for field velocities and fluid density
for y = 1, H do
    density[y], vx[y], vy[y], prev_density[y] = {}, {}, {}, {}
    for x = 1, W do
        density[y][x] = 0
        vx[y][x] = 0
        vy[y][x] = 0
        prev_density[y][x] = 0
    end
end

-- Clear screen and hide cursor for smooth terminal rendering
io.write("\27[2J\27[?25l")

-- Cleanup terminal cursor and screen state on script completion
local function cleanup()
    io.write("\27[?25h\27[0m\27[H\27[2J")
end

-- Ambient noise Level Sampler (Simulates real-time microphone RMS volume fluctuations and spikes)
local function get_ambient_noise(t)
    local base = (math.sin(t * 1.5) + 1) * 0.35
    local spike = (math.sin(t * 7.3) > 0.85) and (math.random() * 0.65) or 0
    local ambient = math.min(1.0, math.max(0.0, base + spike + (math.random() - 0.5) * 0.12))
    return ambient
end

-- Fluid simulation advection, forces, and diffusion logic
local function update_fluid(dt, audio_energy, t)
    -- Inject energy from ambient noise into revolving vortex force sources
    local cx, cy = math.floor(W / 2), math.floor(H / 2)
    local angle = t * 2.5
    local radius = 4 + math.sin(t * 1.2) * 2.5
    local fx = cx + math.floor(math.cos(angle) * radius)
    local fy = cy + math.floor(math.sin(angle) * radius * 0.5)

    if fx >= 2 and fx <= W - 1 and fy >= 2 and fy <= H - 1 then
        density[fy][fx] = density[fy][fx] + audio_energy * 4.5
        vx[fy][fx] = vx[fy][fx] + math.cos(angle) * audio_energy * 3.2
        vy[fy][fx] = vy[fy][fx] + math.sin(angle) * audio_energy * 1.6
    end

    -- Advect velocity and diffuse density field across grid neighbors
    for y = 2, H - 1 do
        for x = 2, W - 1 do
            local old_x = math.max(1, math.min(W, x - vx[y][x] * dt * 2))
            local old_y = math.max(1, math.min(H, y - vy[y][x] * dt * 2))
            
            local ix, iy = math.floor(old_x), math.floor(old_y)
            local d_val = density[iy][ix] or 0

            local neighbor_avg = (
                density[y - 1][x] + density[y + 1][x] +
                density[y][x - 1] + density[y][x + 1]
            ) * 0.25

            prev_density[y][x] = (d_val * 0.82 + neighbor_avg * 0.18) * 0.95
            
            -- Velocity damping
            vx[y][x] = vx[y][x] * 0.91
            vy[y][x] = vy[y][x] * 0.91
        end
    end

    -- Swap grid density buffers
    for y = 1, H do
        for x = 1, W do
            density[y][x] = prev_density[y][x]
        end
    end
end

-- Render morphing ASCII calligram frame with thermal color grading
local function render(t, audio_energy)
    local buffer = {"\27[H"}
    
    -- Visual header showing simulated ambient audio meter
    local meter_len = math.floor(audio_energy * 30)
    local meter = string.rep("█", meter_len) .. string.rep("░", 30 - meter_len)
    table.insert(buffer, string.format("\27[1;36m Ambient Noise Input: [%s] %.1f dB\27[0m\n", meter, audio_energy * 60 + 30))

    for y = 1, H do
        for x = 1, W do
            local val = density[y][x]
            local vel = math.sqrt(vx[y][x]^2 + vy[y][x]^2)
            
            if val < 0.04 then
                table.insert(buffer, " ")
            else
                -- Morph character selection between fluid density scale and word calligram letters
                local char
                if vel > 0.75 then
                    local idx = math.floor((x + y + math.floor(t * 12)) % #word_chars) + 1
                    char = word_chars[idx]
                else
                    local idx = math.min(#chars, math.max(1, math.floor(val * #chars)))
                    char = chars[idx]
                end

                -- Dynamic color based on velocity intensity & fluid density
                local color_code
                if vel > 1.2 then
                    color_code = "\27[38;5;196m" -- High velocity motion (Hot Pink/Red)
                elseif val > 0.5 then
                    color_code = "\27[38;5;220m" -- High density core (Warm Gold)
                elseif val > 0.25 then
                    color_code = "\27[38;5;82m"  -- Medium density ripple (Emerald Green)
                else
                    color_code = "\27[38;5;39m"  -- Low density tail (Deep Cyan)
                end
                
                table.insert(buffer, color_code .. char .. "\27[0m")
            end
        end
        table.insert(buffer, "\n")
    end

    io.write(table.concat(buffer))
    io.flush()
end

-- Precise frame timing sleep helper
local function sleep(n)
    local t0 = os.clock()
    while os.clock() - t0 < n do end
end

-- Main animation loop
local start_time = os.clock()
local frame_dt = 0.033

pcall(function()
    for frame = 1, 600 do
        local t = os.clock() - start_time
        local noise_level = get_ambient_noise(t)
        update_fluid(frame_dt, noise_level, t)
        render(t, noise_level)
        sleep(frame_dt)
    end
end)

cleanup()