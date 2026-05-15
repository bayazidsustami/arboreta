-- Visual Haiku Spiral Generator
-- This script simulates a "color-syntax" engine to generate a recursive, 
-- Fibonacci-driven visual poem based on a Haiku's linguistic properties.

local haiku = {
    {text = "Silent winter snow", syllables = 5, stress = {1, 0, 1, 0, 1}, valence = 0.2},
    {text = "Crystal breath in frozen air", syllables = 7, stress = {0, 1, 0, 1, 0, 1, 0}, valence = 0.5},
    {text = "Quiet earth dreams deep", syllables = 5, stress = {1, 0, 0, 1, 0}, valence = 0.8}
}

-- Color-based Syntax Mapping (Representing the logic requested)
local Palette = {
    RED = {r=255, g=0, b=0},    -- Control flow / Iteration
    BLUE = {r=0, g=0, b=255},   -- Position / Coordinate
    GREEN = {r=0, g=255, b=0},  -- Texture / Noise
    GOLD = {r=255, g=215, b=0}  -- Final Render
}

-- Fibonacci Sequence generator based on line lengths (5, 7, 5)
local function get_fib_path(n)
    local sequence = {1, 1}
    for i = 3, n do
        table.insert(sequence, sequence[i-1] + sequence[i-2])
    end
    return sequence
end

-- Calculate "Visual Valence" for the kaleidoscope effect
local function get_color_from_valence(v)
    return {
        r = math.floor(255 * v), 
        g = math.floor(255 * (1 - v)), 
        b = math.floor(255 * (0.5 + 0.5 * math.sin(v * math.pi)))
    }
end

-- Main Artwork Generator
local function generate_visual_poem()
    print("--- Initiating Color-Syntax Render ---")
    
    local total_syllables = 0
    for _, line in ipairs(haiku) do total_syllables = total_syllables + line.syllables end
    
    local fibs = get_fib_path(total_syllables)
    local angle = 0
    local radius = 0
    
    -- Simulate the Recursive Spiral
    for i = 1, total_syllables do
        local line_idx = (i <= 5) and 1 or (i <= 12) and 2 or 3
        local line = haiku[line_idx]
        local stress = line.stress[(i - (line_idx == 2 and 5 or line_idx == 3 and 12 or 0)) % #line.stress + 1] or 1
        local color = get_color_from_valence(line.valence)
        
        -- Fibonacci path derivation
        local step = fibs[i] or fibs[#fibs]
        radius = radius + (step * 0.1)
        angle = angle + (math.pi / 2) * (stress == 1 and 1 or -1)
        
        -- Calculate Coordinates (X, Y)
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        
        -- "Texture" is derived from syllable count modulating the output string
        local texture = (line.syllables % 2 == 0) and "◈" or "✧"
        
        -- Outputting the visual element (Representing the kaleidoscope slice)
        print(string.format(
            "Pos: [%.2f, %.2f] | Color: RGB(%d,%d,%d) | Texture: %s | Path: %d",
            x, y, color.r, color.g, color.b, texture, step
        ))
    end
    
    print("--- Render Complete: View through kaleidoscope for full symmetry ---")
end

generate_visual_poem()