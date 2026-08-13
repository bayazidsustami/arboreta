-- StackTrace Constellation Visualizer & Generative Audio-Visual Engine
-- Transforms Lua crash stack traces into ASCII/ANSI constellation maps and harmonic audio.

local math_sin, math_cos, math_pi = math.sin, math.cos, math.pi
local math_floor, math_abs, math_random = math.floor, math.abs, math.random

-- Terminal Utilities (ANSI Colors & Formatting)
local function clear_screen() io.write("\27[2J\27[H") end
local function move_cursor(x, y) io.write(string.format("\27[%d;%dH", math_floor(y), math_floor(x))) end
local function color(fg, bold) io.write(string.format("\27[%d;%dm", bold and 1 or 0, fg)) end
local function reset_color() io.write("\27[0m") end

-- Hash string into numerical seed for deterministic placement & harmonic chord generation
local function hash_string(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 2147483647
    end
    return hash
end

-- Generative Music Theory: Map stack frame traits to Harmonic Pentatonic Scales
local BASE_FREQS = { 130.81, 146.83, 164.81, 196.00, 220.00, 261.63, 293.66, 329.63, 392.00, 440.00, 523.25 }
local function generate_chord(err_msg, stack_frames)
    local root_idx = (hash_string(err_msg) % #BASE_FREQS) + 1
    local chord = {}
    for i, frame in ipairs(stack_frames) do
        local offset = (hash_string(frame.func .. tostring(frame.line)) % 5) * 2
        local note_idx = ((root_idx + offset - 1) % #BASE_FREQS) + 1
        table.insert(chord, BASE_FREQS[note_idx])
    end
    return chord
end

-- Synthesize PCM audio WAV file for generated exception chord
local function write_wav_chord(filename, freqs, duration)
    local sample_rate = 22050
    local total_samples = math_floor(sample_rate * duration)
    local file = io.open(filename, "wb")
    if not file then return end

    -- WAV Header
    file:write("RIFF", string.pack("<I4", ") "WAVEfmt "anonymous" "unknown", #frames) #freqs)) #nodes % & (2 (dx (dy (frame.line (step * + - -- / 0, 0.9) 1 1) 1, 1.8) 16)) 16, 1] 2 2)) 2), 2, 22 220 2D 30000 36 8) ANSI Bresenham-style CONSTELLATION Canvas Connecting Constellation Draw ENGINE EXCEPTION Exponential HARMONIC Lines Map Nodes Parse Render Star Stellar Synthesize UNHANDLED VISUALIZER _, amplitude angle="((i" canvas="{}" canvas[y]="{}" canvas[y][x]=" " center_x, center_y="width" chord) clear_screen() color(36, decay do dx, dy="n2.x" end env envelope file:close() file:write("data", file:write(string.pack("<I4I2I2I4I4I2I2", file:write(string.pack("<i2", for frame="frame," frames frames, freq func="func" function height i="1," i, if in into ipairs(frames) ipairs(freqs) layout line line_num line_num, local lx="math_floor(n1.x" ly math.max(1, math.min(32767, math.min(height math.min(width math_abs(dy)) math_cos(angle) math_floor(sample))) math_pi math_pi) math_sin(2 math_sin(angle) multi-frequency n1, n1.x, n1.y n2="nodes[i]," n2.y node nodes="{}" nodes[i not note="chord[i]" nx="math.max(2," nx)) ny="math.max(2," ny)) or parse_stack_trace(trace_str) plot points print("="=====================================================================")" quick radial radius raw render_constellation(err_msg, reset_color() return sample="math.max(-32768," sample)) sample_rate sample_rate, sine src="src" src, stack step="0," steps steps)))) string string.pack("<I4", structured t="0," table.insert(frames, table.insert(nodes, then time="t" time) to total_frames="math.max(1," total_frames) total_samples trace trace_str:gmatch("[^\r\n]+") true) using wave width width, with x="nx," y="ny," { })>= 1 and ly <= height and lx >= 1 and lx <= width then
                canvas[ly][lx] = "."
            end
        end
    end

    for i, node in ipairs(nodes) do
        canvas[node.y][node.x] = (i == 1) and "X" or "*"
    end

    -- Output Canvas
    for y = 1, height do
        io.write("  ")
        for x = 1, width do
            local ch = canvas[y][x]
            if ch == "X" then color(31, true) io.write("★")
            elseif ch == "*" then color(33, true) io.write("✦")
            elseif ch == "." then color(34, false) io.write("·")
            else io.write(" ") end
        end
        reset_color()
        io.write("\n")
    end

    -- Display Exception Metadata & Harmonic Chord Frequencies
    color(31, true) io.write("\nException: ") reset_color() print(err_msg)
    color(35, true) io.write("Harmonic Chord: ") reset_color()
    for _, freq in ipairs(chord) do io.write(string.format("%.1fHz ", freq)) end
    io.write("\n\n")

    color(32, false)
    print("Stack Trace Nodes:")
    for i, n in ipairs(nodes) do
        print(string.format("  [%d] Star @ (%2d, %2d) -> %s:%d in '%s' (Freq: %.1fHz)",
            i, n.x, n.y, n.frame.src, n.frame.line, n.frame.func, n.note))
    end
    reset_color()
end

-- Exception Interceptor & Visualizer Hook
local function capture_and_visualize(faulty_func)
    local ok, err_msg = xpcall(faulty_func, function(err)
        return tostring(err) .. "\n" .. debug.traceback("", 2)
    end)

    if not ok then
        local frames = parse_stack_trace(err_msg)
        local first_line = err_msg:match("([^\r\n]+)") or "Unknown Error"
        local chord = generate_chord(first_line, frames)
        
        -- Generate audio file for the crash chord
        write_wav_chord("crash_harmonic.wav", chord, 1.2)
        
        -- Render ANSI visual map
        render_constellation(first_line, frames, chord)
    end
end

-- Simulation: Execute series of crashing functions to demonstrate system
local function simulate_crashes()
    local function sub_routine_gamma()
        error("NullPointerException: attempted to dereference memory address 0x00000000")
    end
    local function sub_routine_beta() sub_routine_gamma() end
    local function sub_routine_alpha() sub_routine_beta() end

    capture_and_visualize(sub_routine_alpha)
end

-- Run Visualizer
simulate_crashes()