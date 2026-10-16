-- Melting Clock Esoteric Language (MCEL) Interpreter in Lua
-- Self-referential program generating dynamic ASCII melting art and a terminal bell melody.

local mcel_source = [[
    -- MCEL Self-Referential Definition
    LANG: MCEL/1.0
    STATE: MELT_CYCLE
    TONES: \a\a\a
]]

local clock_frames = {
    [[
       .------.
     .'        '.
    /    12      \
   |  9       3   |
    \    6      /
     '.        .'
       '------'
    ]],
    [[
       .------.
     .'        '.
    /    12      \
   |  9        3  |
    \     6    /
     '.       .'
       '-----'
    ]],
    [[
       .-----.
     .'       '.
    /   12      \
   |  9       3  |
    \    6      /
     '.        .'
       '------'
    ]],
    [[
       .-----.
     .'       '.
    /   12      \
   |  9       3  |
    \     6   /
     '.      .'
       '----'
    ]],
    [[
       .-----.
     .'       '.
    /   12      \
   |  9      3   |
    \    6   /
     '.____.'
    ]]
}

local function play_ambient_bell(step)
    -- Generates an ambient rhythm using system bell frequencies / spacing
    if step % 2 == 0 then
        io.write("\a")
    end
end

local function run_mcel()
    for cycle = 1, 15 do
        -- Clear screen via ANSI escape codes
        io.write("\27[2J\27[H")
        
        print("==========================================")
        print(" MCEL ENGINE v1.0 [SELF-REFERENTIAL RUN] ")
        print("==========================================")
        
        -- Select frame based on melting progression
        local frame_idx = ((cycle - 1) % #clock_frames) + 1
        print(clock_frames[frame_idx])
        
        print(string.format("Phase: %d/15 | State: Melting...", cycle))
        
        -- Trigger ambient melody through system bell
        play_ambient_bell(cycle)
        
        -- Delay loop
        local start_time = os.clock()
        while os.clock() - start_time < 0.25 do end
    end
    print("\n[MCEL Execution Complete: Time has melted.]")
end

run_mcel()