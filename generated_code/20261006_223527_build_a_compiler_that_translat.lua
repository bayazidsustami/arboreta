local function int_to_bytes(val, num_bytes)
    local t = {}
    for i = num_bytes, 1, -1 do
        t[i] = string.char(val % 256)
        val = math.floor(val / 256)
    end
    return table.concat(t)
end

local function write_var_len(val)
    local buffer = {}
    local rem = val
    local first = true
    repeat
        local b = rem % 128
        rem = math.floor(rem / 128)
        if not first then b = b + 128 end
        table.insert(buffer, 1, string.char(b))
        first = false
    until rem == 0
    return table.concat(buffer)
end

local function compile_to_midi(source_code, filename)
    local stack = {}
    local has_error = false
    local error_pos = 0

    for i = 1, #source_code do
        local c = source_code:sub(i, i)
        if c == '(' or c == '{' or c == '[' then
            table.insert(stack, {char = c, pos = i})
        elseif c == ')' or c == '}' or c == ']' then
            if #stack == 0 then
                has_error = true
                error_pos = i
                break
            else
                table.remove(stack)
            end
        end
    end
    if #stack > 0 then
        has_error = true
        error_pos = stack[#stack].pos
    end

    local events = {}
    local ticks_per_quarter = 480

    local function add_meta_tempo(delta, us)
        table.insert(events, write_var_len(delta) .. "\xFF\x51\x03" .. int_to_bytes(us, 3))
    end

    add_meta_tempo(0, 500000)

    if has_error then
        print("Syntax Error detected at position " .. error_pos .. "! Generating dissonant shrieks...")
        local base_tick = 0
        for i = 1, 15 do
            local note1 = 60 + (i % 3)
            local note2 = 61 + (i % 2)
            local duration = 120
            table.insert(events, write_var_len(base_tick) .. "\x90" .. string.char(note1) .. "\x64")
            table.insert(events, write_var_len(0) .. "\x90" .. string.char(note2) .. "\x50")
            table.insert(events, write_var_len(duration) .. "\x80" .. string.char(note1) .. "\x00")
            table.insert(events, write_var_len(0) .. "\x80" .. string.char(note2) .. "\x00")
            base_tick = 60
        end
    else
        print("Compilation successful! Generating cascading chord symphony...")
        local chords = {
            {60, 64, 67, 71},
            {57, 60, 64, 67},
            {62, 65, 69, 72},
            {67, 71, 74, 77}
        }
        local base_tick = 0
        for _, chord in ipairs(chords) do
            local first = true
            for _, note in ipairs(chord) do
                local dt = first and base_tick or 0
                table.insert(events, write_var_len(dt) .. "\x90" .. string.char(note) .. "\x50")
                first = false
            end
            first = true
            for _, note in ipairs(chord) do
                local dt = first and 480 or 0
                table.insert(events, write_var_len(dt) .. "\x80" .. string.char(note) .. "\x00")
                first = false
            end
            base_tick = 120
        end
    end

    table.insert(events, write_var_len(48) .. "\xFF\x2F\x00")

    local track_data = table.concat(events)
    local track_chunk = "MTrk" .. int_to_bytes(#track_data, 4) .. track_data
    local header_chunk = "MThd\0\0\0\x06\0\0\0\x01" .. int_to_bytes(ticks_per_quarter, 2)

    local midi_file_content = header_chunk .. track_chunk
    local file = io.open(filename, "wb")
    if file then
        file:write(midi_file_content)
        file:close()
        print("Successfully compiled MIDI symphony to: " .. filename)
    else
        print("Error: Could not open file for writing.")
    end
end

local sample_source = "function hello() print('Hello, World!') end"
compile_to_midi(sample_source, "symphony.mid")