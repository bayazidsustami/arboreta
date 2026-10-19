--[[
  Imaginary Assembly Language Interpreter & ASCII Constellation Renderer
  This program simulates an assembly-like virtual machine where execution flow
  and visual output are driven by ambient sound levels, generating fading ASCII stars.
]]--

local WIDTH, HEIGHT = 50, 20

-- Initialize the rendering grid and decay tracking map
local buffer = {}
local decay_map = {}
for y = 1, HEIGHT do
    buffer[y] = {}
    decay_map[y] = {}
    for x = 1, WIDTH do
        buffer[y][x] = " "
        decay_map[y][x] = 0
    end
end

-- Virtual Machine State
local vm = {
    pc = 1,
    acc = 0,
    sound_level = 0,
    running = true
}

-- Imaginary Assembly Instruction Set:
-- SENSE_MIC  : Captures ambient sound levels into ACC and sound_level
-- PLOT_STAR  : Plots constellation points based on audio intensity
-- DECAY_GRID : Ages and fades existing star characters
-- RENDER     : Outputs the ASCII frame to the terminal
-- SLEEP      : Pauses execution briefly for animation timing
-- JUMP       : Alters program counter for continuous execution loops
local program = {
    { op = "SENSE_MIC" },
    { op = "PLOT_STAR" },
    { op = "DECAY_GRID" },
    { op = "RENDER" },
    { op = "SLEEP", arg = 0.08 },
    { op = "JUMP", arg = 1 }
}

-- Simulates audio hardware sampling (can be mapped to real mic input streams)
local function sample_ambient_audio()
    local t = os.clock()
    -- Dynamic pseudo-audio waveform simulation
    local wave = math.sin(t * 4) * math.cos(t * 2) * 40 + 50
    local noise = math.random(0, 15)
    return math.floor(math.abs(wave + noise)) % 100
end

-- Instruction Handlers
local instructions = {
    SENSE_MIC = function()
        vm.sound_level = sample_ambient_audio()
        vm.acc = vm.sound_level
    end,

    PLOT_STAR = function()
        -- Trigger star formation when sound crosses threshold
        if vm.sound_level > 25 then
            math.randomseed(os.time() + math.floor(os.clock() * 10000))
            local x = (math.abs(math.floor(math.cos(os.clock() * vm.sound_level) * WIDTH)) % WIDTH) + 1
            local y = (math.abs(math.floor(math.sin(os.clock() * vm.sound_level) * HEIGHT)) % HEIGHT) + 1
            
            buffer[y][x] = "*"
            decay_map[y][x] = math.min(6, math.floor(vm.sound_level / 15) + 2)
        end
    end,

    DECAY_GRID = function()
        for y = 1, HEIGHT do
            for x = 1, WIDTH do
                if decay_map[y][x] > 0 then
                    decay_map[y][x] = decay_map[y][x] - 1
                    local level = decay_map[y][x]
                    if level >= 4 then
                        buffer[y][x] = "*"
                    elseif level >= 2 then
                        buffer[y][x] = "+"
                    elseif level == 1 then
                        buffer[y][x] = "."
                    else
                        buffer[y][x] = " "
                    end
                end
            end
        end
    end,

    RENDER = function()
        -- Clear screen and redraw ASCII constellation frame
        io.write("\27[2J\27[H")
        io.write(string.rep("=", WIDTH + 2) .. "\n")
        io.write(string.format("| AUDIO INPUT: %-3d | ACC: %-3d | CONSTELLATION ACTIVE |\n", vm.sound_level, vm.acc))
        io.write(string.rep("=", WIDTH + 2) .. "\n")
        
        for y = 1, HEIGHT do
            io.write("|")
            for x = 1, WIDTH do
                io.write(buffer[y][x])
            end
            io.write("|\n")
        end
        io.write(string.rep("=", WIDTH + 2) .. "\n")
    end,

    SLEEP = function(duration)
        local start = os.clock()
        while os.clock() - start < (duration or 0.1) do end
    end,

    JUMP = function(target)
        vm.pc = target - 1
    end
}

-- Execution Loop (runs for 200 cycles as a runnable demonstration)
local max_cycles = 200
local current_cycle = 0

while vm.running and current_cycle < max_cycles do
    current_cycle = current_cycle + 1
    local instr = program[vm.pc]
    if not instr then break end

    local handler = instructions[instr.op]
    if handler then
        handler(instr.arg)
    end

    vm.pc = vm.pc + 1
    if vm.pc > #program then
        vm.pc = 1
    end
end