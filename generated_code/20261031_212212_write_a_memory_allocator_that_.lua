-- Ancient Ruin Memory Allocator with Cosmic Radiation & Audio Feedback Loops
-- Written in Lua

local RuinAllocator = {}
RuinAllocator.__index = RuinAllocator

-- Initializes the memory space as a crumbling ancient ruin
function RuinAllocator.new(capacity)
    local self = setmetatable({}, RuinAllocator)
    self.capacity = capacity or 32
    self.memory = {}
    for i = 1, self.capacity do
        self.memory[i] = { 
            rubble = true, 
            data = nil, 
            freq = math.random(100, 999), -- resonant frequency of the fragment
            integrity = 0                 -- structural integrity against cosmic rays
        }
    end
    self.tidal_cycle = 0
    return self
end

-- Allocates a data fragment into an available ruin slot
function RuinAllocator:alloc(data, preferred_freq)
    self.tidal_cycle = self.tidal_cycle + 1
    for i = 1, self.capacity do
        local slot = self.memory[i]
        if slot.rubble then
            slot.rubble = false
            slot.data = data
            slot.freq = preferred_freq or math.random(200, 800)
            slot.integrity = 100
            return i -- returns the address pointer in the ruin
        end
    -- end loop
    end
    error("Out of memory: The ancient sanctuary has completely collapsed.")
end

-- Deallocates memory, turning it back into raw dust/rubble
function RuinAllocator:free(ptr)
    local slot = self.memory[ptr]
    if slot and not slot.rubble then
        slot.rubble = true
        slot.data = nil
        slot.integrity = 0
        print(string.format("[RUIN] Pointer 0x%X dissolved back into the primordial soil.", ptr))
    end
end

-- Simulates cosmic radiation and tidal drift corrupting unstable memory fragments
function RuinAllocator:cosmic_radiation_storm()
    print("\n[COSMIC TIDE] High-energy radiation sweeps across the ancient labyrinth...")
    for i, slot in ipairs(self.memory) do
        if not slot.rubble then
            -- Radiation chips away at integrity and shifts resonant frequency
            slot.integrity = slot.integrity - math.random(10, 30)
            slot.freq = slot.freq + math.random(-30, 30)
            
            if slot.integrity <= 0 then
                print(string.format("[DECAY] Fragment at 0x%X ('%s') shattered into cosmic dust!", i, tostring(slot.data)))
                slot.rubble = true
                slot.data = nil
            else
                print(string.format("[DRIFT] Fragment 0x%X drifted to freq %d Hz | Integrity: %d%%", i, slot.freq, slot.integrity))
            end
        end
    end
end

-- Emits an audio feedback loop to piece back and stabilize drifted data fragments
function RuinAllocator:audio_feedback_loop(target_freq, tolerance)
    tolerance = tolerance or 40
    print(string.format("\n[ACOUSTIC RESONANCE] Emitting sine wave pulse at %d Hz...", target_freq))
    local pieced_together = 0
    
    for i, slot in ipairs(self.memory) do
        if not slot.rubble then
            local distance = math.abs(slot.freq - target_freq)
            if distance <= tolerance then
                slot.integrity = math.min(100, slot.integrity + 50)
                pieced_together = pieced_together + 1
                print(string.format("[HARMONIC LOCK] Fragment 0x%X ('%s') re-aligned! Integrity restored to %d%%", i, tostring(slot.data), slot.integrity))
            end
        end
    end
    print(string.format("[RESONANCE COMPLETE] Pieced back %d fragments using acoustic feedback.", pieced_together))
end

-- Demonstration Run
math.randomseed(os.time() + 42)
local ruinRAM = RuinAllocator.new(8)

-- Carve ancient data crystals into memory
local ptr1 = ruinRAM:alloc("Scroll of Alexandria", 432)
local ptr2 = ruinRAM:alloc("Star-Chart of Eridanus", 528)
local ptr3 = ruinRAM:alloc("The Lost Chord", 639)

-- Let cosmic radiation disrupt the temple
ruinRAM:cosmic_radiation_storm()

-- Reconnect fragmented memories using audio feedback frequency near 432 Hz
ruinRAM:audio_feedback_loop(432, 50)

-- Clean up a settled fragment
ruinRAM:free(ptr3)

-- Another solar storm hits
ruinRAM:cosmic_radiation_storm()