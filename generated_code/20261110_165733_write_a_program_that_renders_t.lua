-- Living ASCII Fractal Creature reflecting System Error Logs
-- Run in a terminal supporting ANSI escape codes.

math.randomseed(os.time())

local moods = {
    INFO = { char = ".:-=+*#%@", speed = 1, color = "\27[32m", chaos = 0.2 },
    WARN = { char = "~*x%#@MW&", speed = 2, color = "\27[33m", chaos = 0.5 },
    ERROR = { char = "!#$&@X*+~", speed = 4, color = "\27[31m", chaos = 0.9 },
    FATAL = { char = "@#MW&X8%*!", speed = 6, color = "\27[35;1m", chaos = 1.5 }
}

local current_mood = moods.INFO
local logs = {
    "[INFO] System stable. Heartbeat normal.",
    "[WARN] High memory usage detected in worker pool.",
    "[ERROR] Null pointer exception in renderer thread.",
    "[FATAL] Core meltdown imminent! Segmentation fault!"
}

local function render_creature(t, mood)
    local width, height = 40, 15
    io.write("\27[H\27[2J")
    io.write(mood.color)
    
    print("=== EMOTIONAL LOG MONITOR CREATURE ===")
    print("----------------------------------------")

    for y = 0, height do
        local line = ""
        for x = 0, width do
            local val = math.sin(x * 0.2 + t * mood.speed) + math.cos(y * 0.3 - t * 0.5 * mood.chaos)
            local dist = math.sqrt((x - width/2)^2 + (y - height/2)^2)
            local fractal_val = math.sin(dist * 0.3 - t * mood.chaos) + val
            
            local idx = math.floor((math.abs(fractal_val) % 1) * #mood.char) + 1
            line = line .. mood.char:sub(idx, idx)
        end
        print(line)
    end
    io.write("\27[0m")
end

local t = 0
local log_timer = 0
while true do
    t = t + 0.2
    log_timer = log_timer + 1

    if log_timer % 15 == 0 then
        local r = math.random()
        if r < 0.5 then current_mood = moods.INFO
        elseif r < 0.8 then current_mood = moods.WARN
        elseif r < 0.95 then current_mood = moods.ERROR
        else current_mood = moods.FATAL
        end
        print("\nLog Stream: " .. logs[math.random(#logs)])
        os.execute("sleep 1")
    end

    render_creature(t, current_mood)
    os.execute("sleep 0.1")
end