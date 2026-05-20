-- Ambient sound visualizer with cellular automaton and generative poem
-- Self‑contained Lua script (requires Lua 5.3+)

local math, io, os, table = math, io, os, table

-- CONFIGURATION ---------------------------------------------------------
local WIDTH, HEIGHT = 800, 600          -- SVG canvas size
local CELL_SIZE = 10                    -- automaton cell dimension
local GRID_W, GRID_H = WIDTH // CELL_SIZE, HEIGHT // CELL_SIZE
local UPDATE_INTERVAL = 0.2             -- seconds between frames
local PEAK_THRESHOLD = 0.7              -- simulated beat detection threshold
local MAX_FREQ = 2000                   -- max simulated frequency (Hz)
local MIN_FREQ = 20                     -- min simulated frequency (Hz)
local SVG_FILE = "output.svg"

-- STATE -----------------------------------------------------------------
local automaton = {}
for y = 1, GRID_H do
    automaton[y] = {}
    for x = 1, GRID_W do automaton[y][x] = 0 end
end

local poem = {}
local start_time = os.time()
local last_beat = 0

-- HELPERS ---------------------------------------------------------------
local function lin2log(v, vmin, vmax)
    -- map linear [0,1] to logarithmic frequency range
    return math.exp(math.log(vmin) + v * (math.log(vmax) - math.log(vmin)))
end

local function freq2color(f)
    -- non‑linear chromatic mapping: hue follows log(freq)
    local hue = ((math.log(f) - math.log(MIN_FREQ)) / (math.log(MAX_FREQ) - math.log(MIN_FREQ))) * 360
    local s, l = 0.8, 0.5
    local c = (1 - math.abs(2*l - 1)) * s
    local x = c * (1 - math.abs((hue/60) % 2 - 1))
    local m = l - c/2
    local r,g,b
    if hue < 60 then r,g,b=c,x,0
    elseif hue < 120 then r,g,b=x,c,0
    elseif hue < 180 then r,g,b=0,c,x
    elseif hue < 240 then r,g,b=0,x,c
    elseif hue < 300 then r,g,b=x,0,c
    else r,g,b=c,0,x end
    r,g,b = (r+m)*255, (g+m)*255, (b+m)*255
    return string.format("#%02X%02X%02X", math.floor(r), math.floor(g), math.floor(b))
end

local function simulate_spectrum()
    -- generate a fake spectrum of 256 bins with values 0‑1
    local bins = {}
    for i = 1, 256 do bins[i] = math.random() end
    return bins
end

local function dominant_freq(bins)
    local maxv, idx = 0, 1
    for i, v in ipairs(bins) do
        if v > maxv then maxv, idx = v, i end
    end
    local norm = (idx-1)/255           -- 0‑1
    return lin2log(norm, MIN_FREQ, MAX_FREQ), maxv
end

local function next_automaton(bins)
    -- simple rule: cells turn on if corresponding frequency bin exceeds threshold
    for y = 1, GRID_H do
        for x = 1, GRID_W do
            local bin = ((y-1)*GRID_W + x) % #bins + 1
            automaton[y][x] = bins[bin] > PEAK_THRESHOLD and 1 or 0
        end
    end
end

local function update_ca()
    local next = {}
    for y = 1, GRID_H do
        next[y] = {}
        for x = 1, GRID_W do
            local count = 0
            for dy = -1,1 do
                for dx = -1,1 do
                    if not (dx==0 and dy==0) then
                        local nx, ny = (x+dx-1)%GRID_W+1, (y+dy-1)%GRID_H+1
                        count = count + automaton[ny][nx]
                    end
                end
            end
            local alive = automaton[y][x]==1
            next[y][x] = (alive and (count==2 or count==3)) and 1 or (not alive and count==3) and 1 or 0
        end
    end
    automaton = next
end

local function add_poem_line(ts, freq)
    local line = string.format("At %.2fs, the city sang at %.0f Hz.", ts, freq)
    table.insert(poem, line)
    if #poem > 10 then table.remove(poem,1) end
end

local function svg_header()
    return string.format(
        '<?xml version="1.0" standalone="no"?>\n'..
        '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"\n'..
        '"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">\n'..
        '<svg width="%d" height="%d" version="1.1" xmlns="http://www.w3.org/2000/svg">\n',
        WIDTH, HEIGHT)
end

local function svg_footer() return "</svg>\n" end

local function render_svg(bins, domFreq, domAmp, ts)
    local out = io.open(SVG_FILE, "w")
    out:write(svg_header())

    -- draw spectrum as colored bars
    local bar_w = WIDTH / #bins
    for i, v in ipairs(bins) do
        local freq = lin2log((i-1)/255, MIN_FREQ, MAX_FREQ)
        local col = freq2color(freq)
        local h = v * HEIGHT * 0.3
        out:write(string.format(
            '<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s"/>\n',
            (i-1)*bar_w, HEIGHT - h, bar_w, h, col))
    end

    -- draw cellular automaton overlay
    for y = 1, GRID_H do
        for x = 1, GRID_W do
            if automaton[y][x]==1 then
                out:write(string.format(
                    '<rect x="%d" y="%d" width="%d" height="%d" fill="black" opacity="0.6"/>\n',
                    (x-1)*CELL_SIZE, (y-1)*CELL_SIZE, CELL_SIZE, CELL_SIZE))
            end
        end
    end

    -- embed poem
    out:write('<text x="10" y="20" font-family="monospace" font-size="14" fill="black">\n')
    for i, line in ipairs(poem) do
        out:write(string.format('<tspan x="10" dy="1.2em">%s</tspan>\n', line))
    end
    out:write('</text>\n')

    -- timestamp label
    out:write(string.format(
        '<text x="%d" y="%d" font-family="sans" font-size="12" fill="gray">t=%.2fs  peak=%.0f Hz</text>\n',
        WIDTH-150, HEIGHT-10, ts, domFreq))

    out:write(svg_footer())
    out:close()
end

-- MAIN LOOP -------------------------------------------------------------
while true do
    local ts = os.time() - start_time
    local bins = simulate_spectrum()
    local domFreq, domAmp = dominant_freq(bins)

    -- beat detection (simple amplitude threshold)
    if domAmp > PEAK_THRESHOLD and (ts - last_beat) > 0.5 then
        last_beat = ts
        add_poem_line(ts, domFreq)
    end

    next_automaton(bins)   -- feed spectrum into CA seed
    update_ca()           -- evolve CA
    render_svg(bins, domFreq, domAmp, ts)

    os.execute(string.format("sleep %.2f", UPDATE_INTERVAL))
end