-- Decentralized Gossip Protocol via Favicon Tapestries
-- A poetic simulation in pure Lua

math.randomseed(os.time())

-- Helper: Generate a pseudo-random color palette for the tapestry
local function random_color()
    local palette = {"#FF5733", "#33FF57", "#3357FF", "#F3FF33", "#FF33F3", "#33FFF3", "#000000", "#FFFFFF"}
    return palette[math.random(#palette)]
end

-- Node definition representing a peer in the gossip network
local Node = {}
Node.__index = Node

function Node.new(id)
    local self = setmetatable({}, Node)
    self.id = id
    self.gossip_ledger = { "Genesis: The web is woven." }
    self.tapestry = {}
    -- Initialize a 16x16 pixel grid (favicon dimensions)
    for y = 1, 16 do
        self.tapestry[y] = {}
        for x = 1, 16 do
            self.tapestry[y][x] = "#000000"
        end
    end
    return self
end

-- Weave incoming gossip into the 16x16 favicon tapestry
function Node:weave(message)
    table.insert(self.gossip_ledger, message)
    -- Mutate pixels based on the character codes of the message
    for i = 1, #message do
        local char_code = message:byte(i)
        local x = (char_code % 16) + 1
        local y = (math.floor(char_code / 16) % 16) + 1
        self.tapestry[y][x] = random_color()
    end
end

-- Render the tapestry as a simulated browser favicon data string
function Node:render_favicon()
    local pixels = 0
    for y = 1, 16 do
        for x = 1, 16 do
            if self.tapestry[y][x] ~= "#000000" then
                pixels = pixels + 1
            end
        end
    end
    return string.format("Node_%d [Favicon Tapestry Active: %d active threads woven, Ledger Size: %d]", 
        self.id, pixels, #self.gossip_ledger)
end

-- Simulate the Gossip Network Exchange
local function run_simulation()
    print("Initializing Decentralized Favicon Gossip Network...")
    
    local nodes = {
        Node.new(1),
        Node.new(2),
        Node.new(3)
    }

    local rumors = {
        "The browser tab breathes in sync with the cluster.",
        "Pixels align to form the consensus.",
        "A stray packet ripples across the DOM.",
        "Decentralization lives in the icon bar."
    }

    -- Run for a few gossip epochs
    for epoch = 1, 3 do
        print("\n--- Epoch " .. epoch .. " ---")
        for _, sender in ipairs(nodes) do
            local rumor = rumors[math.random(#rumors)]
            -- Gossip to all other nodes
            for _, receiver in ipairs(nodes) do
                if sender.id ~= receiver.id then
                    receiver:weave("Node " .. sender.id .. " says: " .. rumor)
                end
            end
        end

        -- Display current browser tab favicon states
        for _, node in ipairs(nodes) do
            print(node:render_favicon())
        end
    end
    
    print("\nNetwork converged. Tapestries fully synchronized across tabs.")
end

run_simulation()