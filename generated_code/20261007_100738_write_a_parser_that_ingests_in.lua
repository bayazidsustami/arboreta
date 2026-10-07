-- Void Menagerie: Packet Drop to Imaginary Animal Constellation Engine
-- Simulates packet traffic, detects dropped connections, and materializes 
-- shifting vector constellations of surreal fauna.

math.randomseed(os.time())

local function generate_fauna()
    local animals = {"Aether-Stag", "Quantum-Leviathan", "Void-Fox", "Nebula-Hydra"}
    local name = animals[math.random(#animals)]
    
    -- Generate random vertices with hand-drawn jitter
    local vertices = {}
    local count = math.random(5, 9)
    for i = 1, count do
        table.insert(vertices, {
            x = math.random(10, 70) + (math.random() - 0.5) * 2,
            y = math.random(5, 20) + (math.random() - 0.5) * 2,
            symbol = string.char(math.random(33, 126))
        })
    end
    return name, vertices
end

local function render_constellation(name, vertices)
    print(string.format("--- CONNECTION DROPPED: Materializing %s Constellation ---", name))
    
    -- Initialize ASCII vector canvas
    local canvas = {}
    for r = 1, 25 do
        canvas[r] = string.rep(" ", 80)
    end
    
    -- Plot nodes onto canvas
    for _, v in ipairs(vertices) do
        local rx, ry = math.floor(v.x), math.floor(v.y)
        if ry >= 1 and ry <= 25 and rx >= 1 and rx <= 78 then
            canvas[ry] = canvas[ry]:sub(1, rx - 1) .. v.symbol .. canvas[ry]:sub(rx + 1)
        end
    end
    
    -- Output canvas frame
    for _, line in ipairs(canvas) do
        print(line)
    end
    print("----------------------------------------------------------------\n")
end

-- Simulate packet traffic ingestion stream
print("Initializing Packet Traffic Ingestion Stream...")
for packet = 1, 3 do
    local dropped = (math.random() > 0.2)
    if dropped then
        local animal, verts = generate_fauna()
        render_constellation(animal, verts)
    end
end