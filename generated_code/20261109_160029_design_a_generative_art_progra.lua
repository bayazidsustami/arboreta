-- Generative Stained Glass Tapestry driven by Seismic Data & Humidity
-- This script simulates incoming seismic wave distortions and local humidity levels,
-- translating them into a geometric stained-glass SVG artwork with color bleeding effects.
-- Run with standard Lua: lua script.lua -> outputs 'seismic_tapestry.svg'

local math = math
local io = io

-- Simulation parameters
local WIDTH, HEIGHT = 1000, 750
local COLS, ROWS = 14, 11
local SEISMIC_MAGNITUDE = 0.85  -- Intensity of seismic tremors (0.0 to 1.0)
local HUMIDITY = 0.75           -- Local humidity level (affects blur/color bleed & palette shifts)

-- Open output SVG file
local filename = "seismic_tapestry.svg"
local file = io.open(filename, "w")
if not file then
    error("Could not open file for writing: " + filename)
end

-- Write SVG header with a Gaussian blur and color matrix filter representing humidity bleed
file:write(string.format([[
<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" width="%d" height="%d" viewBox="0 0 %d %d">
  <defs>
    <filter id="humidity_bleed" x="-15%%" y="-15%%" width="130%%" height="130%%">
      <feGaussianBlur stdDeviation="%.2f" />
      <feColorMatrix type="matrix" values="
        1 0 0 0 0
        0 1 0 0 0
        0 0 1 0 0
        0 0 0 %.2f 0" />
    </filter>
    <style>
      polygon {
        stroke: #0d0d11;
        stroke-width: 4;
        stroke-linejoin: round;
        mix-blend-mode: screen;
      }
    </style>
  </defs>
  <rect width="100%%" height="100%%" fill="#050508"/>
  <g filter="url(#humidity_bleed)">
]], WIDTH, HEIGHT, WIDTH, HEIGHT, HUMIDITY * 5.0, 0.8 + HUMIDITY * 0.2))

-- Generate jittered grid points with epicentric seismic wave interference
local points = {}
local cell_w = WIDTH / COLS
local cell_h = HEIGHT / ROWS

math.randomseed(42) -- Stable pseudo-random seed for organic yet reproducible geometry

for r = 0, ROWS do
    points[r] = {}
    for c = 0, COLS do
        local x = c * cell_w + (math.random() - 0.5) * cell_w * 0.75
        local y = r * cell_h + (math.random() - 0.5) * cell_h * 0.75
        
        -- Calculate seismic radial displacement from center epicenter
        local dx = x - WIDTH / 2
        local dy = y - HEIGHT / 2
        local dist = math.sqrt(dx*dx + dy*dy)
        local wave = math.sin(dist * 0.025 - SEISMIC_MAGNITUDE * 12) * SEISMIC_MAGNITUDE * 45
        
        if dist > 0 then
            x = x + (dx / dist) * wave
            y = y + (dy / dist) * wave
        end
        
        points[r][c] = { x = x, y = y }
    end
end

-- Helper: Convert HSL color space to RGB hex string, modulated by humidity
local function get_stained_glass_color(r, c, seismic, hum)
    local norm_x = c / COLS
    local norm_y = r / ROWS
    
    -- High humidity shifts palette toward deep ocean teals/indigos; low humidity toward amber/ruby
    local base_hue = (norm_x * 90 + norm_y * 110 + hum * 200) % 360
    local saturation = 75 + seismic * 25
    local lightness = 30 + (math.sin(r * 1.5 + c * 2.1) * 0.5 + 0.5) * 35
    
    local h = base_hue / 360
    local s = saturation / 100
    local l = lightness / 100
    
    local function hue2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p)-- Seismic Stained Glass Generative Art Generator in Pure Lua
-- Outputs an SVG file: seismic_tapestry.svg

math.randomseed(os.time())

local width, height = 800, 800
local file = io.open("seismic_tapestry.svg", "w")

file:write(string.format('<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 %d %d" width="%d" height="%d">\n', width, height, width, height))
file:write('<defs>\n  <filter id="bleed">\n    <feGaussianBlur stdDeviation="6" />\n  </filter>\n</defs>\n')
file:write(string.format('<rect width="%d" height="%d" fill="#0a0a0c"/>\n', width, height))

-- Simulate seismic wave displacement field over time/space
local function get_seismic_displacement(x, y, t)
    local wave1 = math.sin(x * 0.03 + t) * math.cos(y * 0.03 - t)
    local wave2 = math.sin(math.sqrt(x*x + y*y) * 0.02 - t * 1.5)
    return (wave1 + wave2) * 12
end

-- Simulate local humidity gradient affecting color diffusion and saturation
local function get_humidity(x, y)
    local val = math.sin(x * 0.008) * math.cos(y * 0.008)
    return (val + 1) / 2 -- Normalized between 0 and 1
end

-- Generate a perturbed geometric mosaic grid (stained glass framework)
local cols, rows = 14, 14
local cell_w = width / cols
local cell_h = height / rows

local points = {}
for r = 0, rows do
    points[r] = {}
    for c = 0, cols do
        local base_x = c * cell_w
        local base_y = r * cell_h
        local seismic = get_seismic_displacement(base_x, base_y, 1.8)
        
        -- Add organic jitter combined with seismic shift
        local jitter_x = (math.random() - 0.5) * cell_w * 0.5
        local jitter_y = (math.random() - 0.5) * cell_h * 0.5
        
        points[r][c] = {
            x = base_x + seismic + jitter_x,
            y = base_y + seismic + jitter_y
        }
    end
end

-- Render the stained glass cells with bleeding color palettes
for r = 0, rows - 1 do
    for c = 0, cols - 1 do
        local p1 = points[r][c]
        local p2 = points[r][c+1]
        local p3 = points[r+1][c+1]
        local p4 = points[r+1][c]

        -- Calculate centroid for regional humidity sampling
        local cx = (p1.x + p2.x + p3.x + p4.x) / 4
        local cy = (p1.y + p2.y + p3.y + p4.y) / 4

        local humidity = get_humidity(cx, cy)
        
        -- Palette mapping: Low humidity = arid ambers/crimsons; High humidity = bleeding emeralds/sapphires
        local hue = math.floor(humidity * 200 + 140) % 360
        local saturation = math.floor(60 + humidity * 40)
        local lightness = math.floor(25 + (1 - humidity) * 35)

        -- Draw color bleed layer (diffused glow mimicking moisture dispersion)
        file:write(string.format(
            '<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="hsl(%d, %d%%, %d%%)" opacity="0.45" filter="url(#bleed)"/>\n',
            p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, p4.x, p4.y, hue, saturation, lightness
        ))

        -- Draw core stained glass facet with dark leading edges
        file:write(string.format(
            '<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" fill="hsl(%d, %d%%, %d%%)" stroke="#050505" stroke-width="3.5" opacity="0.88"/>\n',
            p1.x, p1.y, p2.x, p2.y, p3.x, p3.y, p4.x, p4.y, hue, saturation, lightness + 15
        ))
    end
end

file:write('</svg>\n')
file:close()

print("Generative seismic tapestry successfully rendered to seismic_tapestry.svg")