```lua
-- Esoteric State Machine: Cadence Weaver
-- Weaves migrating ASCII birds across the terminal based on input timing.

local io = io
local os = os
local math = math

-- Terminal dimensions (fallback if ioctl fails)
local width, height = 80, 24

-- State machine definition
local StateMachine = {
    state = "IDLE",
    cadence = 0,
    last_time = os.clock(),
    flock_x = 0,
    flock_y = height / 2,
    birds = { ">", "v", "^", "<", "~" },
}

function StateMachine:transition(new_state)
    self.state = new_state
end

function StateMachine:update(dt)
    -- Decay cadence over time
    self.cadence = math.max(0, self.cadence - dt * 2)
    
    if self.cadence > 5 then
        self:transition("HYPER_MIGRATE")
    elseif self.cadence > 2 then
        self:transition("SOARING")
    else
        self:transition("IDLE")
    end

    -- Update flock position based on state velocity
    local speed = 1
    if self.state == "SOARING" then speed = 3
    elseif self.state == "HYPER_MIGRATE" then speed = 6 end

    self.flock_x = (self.flock_x + speed * dt * 5) % width
end

function StateMachine:render()
    -- Clear screen and position cursor
    io.write("\27[2J\27[H")
    
    print("--- AMBIENT CADENCE WEAVER [State: " .. self.state .. "] ---")
    print("Type anything to alter the flock's migration pattern...\n")

    -- Draw empty space with migrating ASCII birds
    for y = 1, height - 4 do
        local line = ""
        for x = 1, width do
            if math.floor(self.flock_x) == x and math.floor(self.flock_y) == y then
                local bird_idx = (math.floor(os.clock() * 5) % #self.birds) + 1
                line = line .. self.birds[bird_idx]
            else
                line = line .. " "
            end
        end
        io.write(line .. "\n")
    end
end

-- Main loop setup (Non-blocking simulated input for standalone safety)
local function run()
    local sm = StateMachine
    local running = true
    
    while running do
        local now = os.clock()
        local dt = now - sm.last_time
        sm.last_time = now

        sm:update(dt)
        sm:render()

        -- Simulate typing cadence increment for demonstration
        sm.cadence = sm.cadence + 0.5
        
        os.execute("sleep 0.1")
    end
end

run()
```