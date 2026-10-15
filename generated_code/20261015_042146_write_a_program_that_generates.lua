-- Sumerian Wi-Fi Oracle: An evolving text adventure driven by simulated wireless interference
-- Requirements: Standard Lua 5.1+ interpreter

math.randomseed(os.time())

-- Fragmentary Sumerian lines representing atmospheric/signal states
local sumerian_poetry = {
    { line = "The storm rages over the ziggurat of Eridu...", signal_bias = 0.2 },
    { line = "Enlil's wind scatters the clay tablets into the void...", signal_bias = 0.5 },
    { line = "In the silence of the reed hut, the whisper of the gods is faint...", signal_bias = 0.8 },
    { line = "The great bull of heaven tramples the router of the abyss...", signal_bias = 0.1 },
}

-- Simulate real-time Wi-Fi interference (returns a fluctuation value between 0.0 and 1.0)
local function read_wifi_interference()
    -- Simulates packet jitter using system time micro-fluctuations
    local jitter = (os.clock() * 1000) % 1
    return (math.sin(jitter * math.pi) + 1) / 2
end

-- Select narrative node based on interference pattern
local function get_poetic_state(interference)
    local best_match = sumerian_poetry[1]
    local min_diff = math.abs(interference - best_match.signal_bias)
    for _, poetry in ipairs(sumerian_poetry) do
        local diff = math.abs(interference - poetry.signal_bias)
        if diff < min_diff then
            min_diff = diff
            best_match = poetry
        end
    end
    return best_match
end

-- Main game loop
print("=== THE EPIC OF THE ETHERNET ===")
print("Tuning into the ancient frequencies...\n")

for step = 1, 3 do
    local interference = read_wifi_interference()
    local state = get_poetic_state(interference)
    
    print(string.format("[Packet Jitter: %.3f]", interference))
    print("Sumerian Oracle Speaks: " .. state.line)
    print("Choices forged in the static:")
    print("  1. Offer a libation of clarified butter to the access point.")
    print("  2. Inscribe a cuneiform packet header into the clay.")
    print("  3. Disconnect and await the flood.")
    print("\n--- Evolving Reality Shift ---\n")
    
    -- Simulate short delay for real-time feel
    local start = os.time()
    repeat until os.time() > start + 1
end

print("The connection fades into myth. End of transmission.")