-- Dynamic Starlight Crashmap: Generates a constellation map from runtime crash logs.
-- Parses stress levels (hex addresses/threads), syllable counts (word splits), and sentiment tones.

local math_sin, math_cos, math_rad, math_pi = math.sin, math.cos, math.rad, math.pi
local math_random, math_floor, math_abs = math.random, math.floor, math.abs

-- Sample crash log dataset for dynamic parsing
local sample_logs = {
    "FATAL EXCEPTION: NullPointer dereference at 0x00007FFF8A12B000 thread_main timeout panic crash failure corrupt",
    "WARNING: Memory leak detected in garbage collector allocations infinite recursion stack overflow segment fault",
    "CRITICAL: Kernel panic core dumped memory corruption fault instruction execution abort terminated unexpectedly",
    "ERROR: Buffer overflow detected array index out of bounds deadlock thread race condition access violation",
    "EMERGENCY: System thermal overload CPU throttling Hardware malfunction power failure total collapse shutdown"
}

-- Lexicon for emotional tone analysis
local sentiment_lexicon = {
    critical = -0.9, fatal = -1.0, panic = -0.8, crash = -0.7, failure = -0.8,
    corrupt = -0.6, overflow = -0.5, fault = -0.6, leak = -0.4, timeout = -0.3,
    warning = -0.2, error = -0.5, overload = -0.8, shutdown = -0.9, collapse = -1.0
}

-- Estimates syllable count of a string
local function count_syllables(word)
    local _, count = word:lower():gsub("[aeiouy]+", "")
    return math.max(1, count)
end

-- Extracts structural features from a crash log entry
local function parse_log(log_text)
    local total_syllables = 0
    local sentiment_score = 0
    local stress_indicator = 0
    local words = {}

    for word in log_text:gmatch("%S+") do
        table.insert(words, word)
        total_syllables = total_syllables + count_syllables(word)
        local lower_word = word:lower():gsub("%p", "")
        if sentiment_lexicon[lower_word] then
            sentiment_score = sentiment_score + sentiment_lexicon[lower_word]
        end
    end

    -- Stress derived from hex memory addresses or word patterns
    for hex in log_text:gmatch("0x%x+") do
        stress_indicator = stress_indicator + (tonumber(hex:sub(-4), 16) or 0)
    end
    if stress_indicator == 0 then
        stress_indicator = #log_text * 137.5
    end

    local emotional_tone = sentiment_score / math.max(1, #words)
    return {
        syllables = total_syllables,
        stress = stress_indicator % 1000 / 1000,
        tone = emotional_tone,
        word_count = #words,
        raw = log_text
    }
end

-- Converts log metrics into astronomical constellation star nodes and edges
local function generate_constellation(log_metrics, cx, cy, radius)
    local stars = {}
    local num_stars = math.max(3, math.min(12, log_metrics.syllables % 10 + 3))
    local angle_step = (2 * math_pi) / num_stars
    local stress_factor = log_metrics.stress
    local tone_shift = log_metrics.tone

    for i = 1, num_stars do
        local angle = (i - 1) * angle_step + (stress_factor * math_pi)
        local dist = radius * (0.3 + 0.7 * math_abs(math_sin(angle * (1 + stress_factor))))
        local x = cx + dist * math_cos(angle)
        local y = cy + dist * math_sin(angle)

        -- Magnitude (brightness/size) determined by stress and emotional tone
        local magnitude = math.max(1.0, (1.0 - tone_shift) * 3.5 + (stress_factor * 2.0))
        table.insert(stars, {x = x, y = y, mag = magnitude})
    end

    -- Construct geometric skeleton (edges) based on star proximities and tone
    local edges = {}
    for i = 1, #stars do
        local next_idx = (i % #stars) + 1
        table.insert(edges, {p1 = stars[i], p2 = stars[next_idx]})
        if math_sin(i + stress_factor * 10) > 0 and #stars > 4 then
            local skip_idx = ((i + 1) % #stars) + 1
            table.insert(edges, {p1 = stars[i], p2 = stars[skip_idx]})
        end
    end

    return {stars = stars, edges = edges, metrics = log_metrics}
end

-- Renders the generated star map in ASCII format
local function render_ascii_starmap(width, height, constellations)
    local grid = {}
    for y = 1, height do
        grid[y] = {}
        for x = 1, width do
            grid[y][x] = " "
        end
    end

    -- Render constellation connections
    for _, const in ipairs(constellations) do
        for _, edge in ipairs(const.edges) do
            local x1, y1 = math_floor(edge.p1.x), math_floor(edge.p1.y)
            local x2, y2 = math_floor(edge.p2.x), math_floor(edge.p2.y)
            local steps = math.max(math_abs(x2 - x1), math_abs(y2 - y1))
            if steps > 0 then
                for s = 0, steps do
                    local t = s / steps
                    local gx = math_floor(x1 + (x2 - x1) * t + 0.5)
                    local gy = math_floor(y1 + (y2 - y1) * t + 0.5)
                    if gx >= 1 and gx <= width and gy >= 1 and gy <= height then
                        if grid[gy][gx] == " " then
                            grid[gy][gx] = "."
                        end
                    end
                end
            end
        end
    end

    -- Render star nodes with brightness mapped to magnitude
    local mag_chars = {"*", "O", "@", "#", "X"}
    for _, const in ipairs(constellations) do
        for _, star in ipairs(const.stars) do
            local gx, gy = math_floor(star.x + 0.5), math_floor(star.y + 0.5)
            if gx >= 1 and gx <= width and gy >= 1 and gy <= height then
                local char_idx = math.min(#mag_chars, math.max(1, math_floor(star.mag)))
                grid[gy][gx] = mag_chars[char_idx]
            end
        end
    end

    -- Output map to terminal
    print(string.rep("=", width))
    print(" GENERATIVE CRASH LOG STAR MAP")
    print(string.rep("=", width))
    for y = 1, height do
        print(table.concat(grid[y]))
    end
    print(string.rep("=", width))
end

-- Main Execution
math.randomseed(os.time())
local map_width, map_height = 80, 24
local constellations = {}

local centers = {
    {x = 20, y = 8},  {x = 60, y = 8},
    {x = 20, y = 18}, {x = 60, y = 18},
    {x = 40, y = 13}
}

for i, log in ipairs(sample_logs) do
    local metrics = parse_log(log)
    local center = centers[i] or {x = math_random(10, 70), y = math_random(5, 20)}
    local constellation = generate_constellation(metrics, center.x, center.y, 7)
    table.insert(constellations, constellation)
end

render_ascii_starmap(map_width, map_height, constellations)

print("\nParsed Log Metrics:")
for i, c in ipairs(constellations) do
    print(string.format(" Constellation %d | Syllables: %2d | Stress: %.2f | Tone: %.2f",
        i, c.metrics.syllables, c.metrics.stress, c.metrics.tone))
end