-- Esoteric Lua Maze-to-MIDI Navigator
-- Navigates the 2D source code ASCII maze topology below from 'S' to 'E' using BFS.
-- Converts each step of the path into a pitch on a harmonic scale and encodes it
-- directly into a binary Type 0 MIDI file ('maze_melody.mid').

local maze_ascii = [[
#####################################
#S  #     #       #         #      #
# # # ### # ##### # ####### # #### #
# #   #   #     #   #     # #    # #
# ##### # ##### ##### ### # #### # #
#     # #     #     #   # #    # # #
##### # ##### ##### # # # #### # # #
#     #     #   #   # # #    #   # #
# ######### ### # ### # #### ##### #
# #       #   #   #   #    #     # #
# # ##### ### ##### ###### ##### # #
#   #   #   #     #      #     #  E#
#####################################]]

-- 1. Parse the ASCII topology into a 2D coordinate grid
local grid, start_pos, end_pos = {}, nil, nil
local row = 1
for line in maze_ascii:gmatch("[^\r\n]+") do
    grid[row] = {}
    for col = 1, #line do
        local ch = line:sub(col, col)
        grid[row][col] = ch
        if ch == 'S' then start_pos = {r = row, c = col} end
        if ch == 'E' then end_pos = {r = row, c = col} end
    end
    row = row + 1
end

-- 2. Traverse the maze using Breadth-First Search (BFS)
local queue = { {pt = start_pos, path = {start_pos}} }
local visited = { [start_pos.r .. "," .. start_pos.c] = true }
local solved_path = nil

while #queue > 0 do
    local current = table.remove(queue, 1)
    local p = current.pt
    if p.r == end_pos.r and p.c == end_pos.c then
        solved_path = current.path
        break
    end

    local neighbors = { {r = p.r - 1, c = p.c}, {r = p.r + 1, c = p.c}, {r = p.r, c = p.c - 1}, {r = p.r, c = p.c + 1} }
    for _, next_p in ipairs(neighbors) do
        local key = next_p.r .. "," .. next_p.c
        if grid[next_p.r] and grid[next_p.r][next_p.c] and grid[next_p.r][next_p.c] ~= '#' and not visited[key] then
            visited[key] = true
            local new_path = {}
            for i, v in ipairs(current.path) do new_path[i] = v end
            table.insert(new_path, {r = next_p.r, c = next_p.c})
            table.insert(queue, {pt = next_p, path = new_path})
        end
    end
end

-- 3. Map path coordinates to a C Pentatonic Minor scale
local pentatonic_scale = {60, 63, 65, 67, 70, 72, 75, 77, 79, 82, 84}
local midi_notes = {}
for _, coord in ipairs(solved_path) do
    local scale_index = ((coord.r * 5 + coord.c * 11) % #pentatonic_scale) + 1
    table.insert(midi_notes, pentatonic_scale[scale_index])
end

-- 4. Helper function to encode 32-bit integers into binary string bytes
local function u32_to_bytes(val)
    return string.char(
        math.floor(val / 16777216) % 256,
        math.floor(val / 65536) % 256,
        math.floor(val / 256) % 256,
        val % 256
    )
end

-- 5. Construct the MIDI Track events
local track_data = ""
track_data = track_data .. "\000\255\081\003\007\161\032" -- Tempo meta event (120 BPM)
track_data = track_data .. "\000\192\011"                 -- Program Change (Instrument 11: Vibraphone)

for _, pitch in ipairs(midi_notes) do
    track_data = track_data .. "\000\144" .. string.char(pitch) .. "\100"  -- Note On (Delta=0, Vel=100)
    track_data = track_data .. "\096\128" .. string.char(pitch) .. "\000"  -- Note Off (Delta=96 ticks)
end
track_data = track_data .. "\000\255\047\000"                             -- End of Track meta event

-- 6. Build MIDI Header and write binary output file
local header_chunk = "MThd\000\000\000\006\000\000\000\001\000\096"
local track_chunk = "MTrk" .. u32_to_bytes(#track_data) .. track_data

local out_file = io.open("maze_melody.mid", "wb")
if out_file then
    out_file:write(header_chunk .. track_chunk)
    out_file:close()
    print("Maze traversed successfully! Output MIDI written to 'maze_melody.mid' (" .. #midi_notes .. " notes generated).")
end