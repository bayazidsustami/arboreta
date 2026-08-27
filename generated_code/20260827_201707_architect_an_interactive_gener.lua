-- Real-time Self-Organizing ASCII Canvas in Lua
-- Simulates sentiment analysis & rhythmic cadence from system log streams to drive ASCII typography

local math_random, math_sin, math_cos, math_abs, math_floor = math.random, math.sin, math.cos, math.abs, math.floor
local os_time, os_clock = os.time, os.clock

-- Configuration
local WIDTH, HEIGHT = 80, 24
local DENSITY_CHARS = "@#S%?*+;:,. "
local SENTIMENT_WORDS = {
    positive = { "success", "ok", "ready", "connected", "completed", "passed", "valid", "active" },
    negative = { "error", "fail", "failed", "critical", "warning", "denied", "fatal", "timeout", "bug" }
}

-- Sample Log Stream Generator
local LOG_SOURCES = { "AUTH", "KERNEL", "NET", "DB", "CRON", "HTTP" }
local LOG_MESSAGES = {
    "connection established successfully",
    "critical failure in database cluster",
    "user authentication passed",
    "timeout waiting for response payload",
    "scheduled background job completed ok",
    "access denied for untrusted origin",
    "system memory active and optimal"
}

local function generate_log()
    local source = LOG_SOURCES[math_random(#LOG_SOURCES)]
    local msg = LOG_MESSAGES[math_random(#LOG_MESSAGES)]
    return string.format("[%s] %s: %s", os.date("!%X"), source, msg)
end

-- Sentiment & Cadence Analysis
local function analyze_log(log_str)
    local lower = log_str:lower()
    local score = 0
    for _, word in ipairs(SENTIMENT_WORDS.positive) do
        if lower:find(word, 1, true) then score = score + 1 end
    end
    for _, word in ipairs(SENTIMENT_WORDS.negative) do
        if lower:find(word, 1, true) then score = score - 1 end
    end
    
    -- Normalize sentiment score to [-1, 1]
    local sentiment = math.max(-1, math.min(1, score))
    local cadence = #log_str % 10 / 10.0 -- Derived pulse weight
    return sentiment, cadence
end

-- Particle Class for Self-Organizing Typography Canvas
local Particle = {}
Particle.__index = Particle

function Particle.new(x, y, char)
    return setmetatable({
        x = x, y = y,
        vx = 0, vy = 0,
        base_x = x, base_y = y,
        char = char or "*",
        energy = 1.0
    }, Particle)
end

function Particle:update(sentiment, cadence, time)
    -- Target position shifts based on emotional sentiment (positive expands/waves, negative contracts/distorts)
    local wave = math_sin(time * (1 + cadence * 3) + self.base_x * 0.1) * (1 + sentiment)
    local target_x = self.base_x + wave * sentiment
    local target_y = self.base_y + math_cos(time + self.base_y * 0.1) * cadence * 2

    -- Spring physics pull toward shifting target
    local dx = target_x - self.x
    local dy = target_y - self.y
    self.vx = (self.vx + dx * 0.05) * 0.85
    self.vy = (self.vy + dy * 0.05) * 0.85

    self.x = self.x + self.vx
    self.y = self.y + self.vy
end

-- ASCII Canvas Setup
local canvas = {}
local particles = {}
local log_queue = {}

-- Initialize particles in a grid topology
for y = 1, HEIGHT do
    canvas[y] = {}
    for x = 1, WIDTH do
        canvas[y][x] = " "
        if math_random() < 0.15 then
            table.insert(particles, Particle.new(x, y, DENSITY_CHARS:sub(math_random(1, #DENSITY_CHARS), math_random(1, #DENSITY_CHARS))))
        end
    end
end

-- ANSI Display Helpers
local function clear_screen()
    io.write("\27[2J\27[H")
end

local function draw_canvas(current_log, sentiment)
    -- Clear internal grid buffer
    for y = 1, HEIGHT do
        for x = 1, WIDTH do
            canvas[y][x] = " "
        end
    end

    -- Render particles onto buffer
    for _, p in ipairs(particles) do
        local rx, ry = math_floor(p.x + 0.5), math_floor(p.y + 0.5)
        if rx >= 1 and rx <= WIDTH and ry >= 1 and ry <= HEIGHT then
            canvas[ry][rx] = p.char
        end
    end

    -- Build frame output string
    local frame = {}
    table.insert(frame, "\27[1;36m=== REAL-TIME LOG SENTIMENT ASCII CANVAS ===\27[0m\n")
    
    for y = 1, HEIGHT do
        local line = {}
        for x = 1, WIDTH do
            table.insert(line, canvas[y][x])
        end
        table.insert(frame, table.concat(line) .. "\n")
    end

    -- Colorized status footer
    local color = sentiment > 0 and "\27[1;32m" or (sentiment < 0 and "\27[1;31m" or "\27[1;33m")
    table.insert(frame, string.format("STREAM: %s\nSENTIMENT SCORE: %s%.2f\27[0m\n", current_log or "Initializing...", color, sentiment))

    io.write(table.concat(frame))
    io.flush()
end

-- Main Event Loop
local function main()
    math.randomseed(os_time())
    local start_time = os_clock()
    local last_log_time = 0
    local current_sentiment, current_cadence = 0, 0
    local current_log = ""

    clear_screen()

    -- Run loop for 20 seconds as a demonstration
    while (os_clock() - start_time) < 20 do
        local now = os_clock()
        local elapsed = now - start_time

        -- Ingest live log stream periodically
        if now - last_log_time > (0.5 + math_random() * 1.5) then
            current_log = generate_log()
            current_sentiment, current_cadence = analyze_log(current_log)
            last_log_time = now
            
            -- Scatter dynamic chars based on cadence intensity
            local idx = math_floor((current_sentiment + 1) * 5) + 1
            local char_set = DENSITY_CHARS:sub(math.max(1, idx), math.min(#DENSITY_CHARS, idx + 3))
            for _, p in ipairs(particles) do
                if math_random() < 0.2 then
                    p.char = char_set:sub(math_random(1, #char_set), math_random(1, #char_set))
                end
            end
        end

        -- Update particle locations
        for _, p in ipairs(particles) do
            p:update(current_sentiment, current_cadence, elapsed)
        end

        -- Render frame
        clear_screen()
        draw_canvas(current_log, current_sentiment)

        -- Micro sleep pause (primitive timing control)
        local sleep_until = os_clock() + 0.05
        while os_clock() < sleep_until do end
    end
end

main()