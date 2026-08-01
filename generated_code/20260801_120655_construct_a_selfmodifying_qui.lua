-- Self-Modifying Fluid Quine
-- Viscosity ~ Time Complexity; Turbulence ~ Dynamic Memory Allocation

local gen = 1
local src = [=[
-- Self-Modifying Fluid Quine
-- Viscosity ~ Time Complexity; Turbulence ~ Dynamic Memory Allocation

local gen = %d
local src = %q

-- Measure complexity & allocate dynamic turbulence memory
local turb_alloc = {}
for i = 1, gen * 50 do table.insert(turb_alloc, {x = i}) end

local fluid, u, v = {}, {}, {}
local width, height = 40, 10
local viscosity = 0.1 + (gen * 0.02) -- Viscosity reflects step complexity

for i = 1, width * height do
   fluid[i] = " "
   u[i] = math.sin(i * 0.15 + gen) * (1.5 - viscosity)
   v[i] = math.cos(i * 0.15 + gen) * (1.5 - viscosity)
end

-- Inject source code characters into fluid velocity field
local code_str = string.format(src, gen, src)
for i = 1, #code_str do
   local char = code_str:sub(i, i)
   if char:match("%S") then
      local x = (i %% width) + 1
      local y = (math.floor(i / width) %% height) + 1
      local idx = x + (y - 1) * width
      local nx = math.floor((x + u[idx]) %% width) + 1
      local ny = math.floor((y + v[idx]) %% height) + 1
      fluid[nx + (ny - 1) * width] = char
   end
end

-- Render Fluid Simulation Canvas
print("-- FLUID SIMULATION FRAME (Gen " .. gen .. ") --")
for y = 1, height do
   local row = ""
   for x = 1, width do
      row = row .. fluid[x + (y - 1) * width]
   end
   print(row)
end
print("------------------------------------------")

-- Print self-modifying source code output (Quine)
print(string.format(src, gen + 1, src))
]=]

local self_code = string.format(src, gen, src)
local runner = load or loadstring
runner(self_code)()