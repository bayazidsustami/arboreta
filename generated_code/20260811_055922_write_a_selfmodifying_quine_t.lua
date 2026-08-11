-- Self-modifying quine: sonifies source code into microtonal audio spectrum & seeds ASCII fluid dynamics
local C = "local C = %q\nlocal GEN = %d\nlocal SR, FPS, BINS, W, H = 8000, 15, 16, 56, 20\nlocal SPF = math.floor(SR / FPS)\nif arg and arg[0] and arg[0] ~= \"\" then\n  local f = io.open(arg[0], \"w\")\n  if f then f:write(C:format(C, GEN + 1)) f:close() end\nend\nlocal D, Vx, Vy = {}, {}, {}\nfor y = 1, H do\n  D[y], Vx[y], Vy[y] = {}, {}, {}\n  for x = 1, W do D[y][x], Vx[y][x], Vy[y][x] = 0, 0, 0 end\nend\nlocal phases = {0, 0, 0, 0}\nlocal function sleep(n)\n  local t0 = os.clock()\n  while os.clock() - t0 < n do end\nend\nio.write(\"\\27[2J\")\nfor frame = 1, 30 do\n  local audio = {}\n  local freqs = {}\n  for v = 1, 4 do\n    local idx = ((frame * 7 + v * 13 + GEN * 17) % #C) + 1\n    local code_byte = C:byte(idx) or 65\n    local note = code_byte % 57\n    freqs[v] = 110 * (2 ^ (note / 19))\n  end\n  for n = 1, SPF do\n    local sum = 0\n    for v = 1, 4 do\n      phases[v] = phases[v] + 2 * math.pi * freqs[v] / SR\n      sum = sum + math.sin(phases[v])\n    end\n    audio[n] = sum / 4\n  end\n  local spec = {}\n  for b = 1, BINS do\n    local f_bin = 80 * ((1600 / 80) ^ ((b - 1) / (BINS - 1)))\n    local re, im = 0, 0\n    local w = 2 * math.pi * f_bin / SR\n    for n = 1, SPF do\n      re = re + audio[n] * math.cos(w * n)\n      im = im + audio[n] * math.sin(w * n)\n    end\n    spec[b] = math.sqrt(re * re + im * im) / SPF\n  end\n  for b = 1, BINS do\n    local x = math.floor((b - 0.5) * (W / BINS)) + 1\n    if x >= 1 and x <= W then\n      local pwr = spec[b] * 12\n      Vy[H][x] = -pwr * 1.2\n      D[H][x] = D[H][x] + pwr * 2.5\n    end\n  end\n  local D2, Vx2, Vy2 = {}, {}, {}\n  for y = 1, H do\n    D2[y], Vx2[y], Vy2[y] = {}, {}, {}\n    for x = 1, W do\n      local px = math.max(1, math.min(W, x - Vx[y][x]))\n      local py = math.max(1, math.min(H, y - Vy[y][x]))\n      local ix, iy = math.floor(px), math.floor(py)\n      D2[y][x] = D[iy][ix] * 0.94\n      Vy2[y][x] = (Vy[iy][ix] - D[y][x] * 0.02) * 0.90\n      Vx2[y][x] = Vx[iy][ix] * 0.90\n    end\n  end\n  for y = 1, H do\n    for x = 1, W do\n      local ym = math.max(1, y - 1)\n      local yp = math.min(H, y + 1)\n      local xm = math.max(1, x - 1)\n      local xp = math.min(W, x + 1)\n      D[y][x] = D2[y][x] * 0.5 + (D2[ym][x] + D2[yp][x] + D2[y][xm] + D2[y][xp]) * 0.125\n      Vx[y][x] = Vx2[y][x]\n      Vy[y][x] = Vy2[y][x]\n    end\n  end\n  local lines = {\"\\27[H=== SELF-MODIFYING QUINE SONIFIER | GEN: \" .. GEN .. \" | 19-TET MICROTONAL FLUID ===\"}\n  local bar_chars = {\"_\", \".\", \"-\", \":\", \"=\", \"*\", \"#\", \"@\"}\n  local spec_bar = \"SPEC: \"\n  for b = 1, BINS do\n    local h = math.max(1, math.min(8, math.floor(spec[b] * 20) + 1))\n    spec_bar = spec_bar .. bar_chars[h]\n  end\n  lines[#lines + 1] = spec_bar\n  for y = 1, H do\n    local row = \"\"\n    for x = 1, W do\n      local den = D[y][x]\n      if den < 0.08 then\n        row = row .. \" \"\n      else\n        local char_idx = (math.floor(den * 100) + x + y + GEN) % #C + 1\n        local ch = C:sub(char_idx, char_idx)\n        if ch:byte() < 32 or ch == \"\\n\" or ch == \"\\r\" then ch = \"*\" end\n        row = row .. ch\n      end\n    end\n    lines[#lines + 1] = row\n  end\n  io.write(table.concat(lines, \"\\n\") .. \"\\n\")\n  sleep(0.04)\nend\n"
local GEN = 0
local SR, FPS, BINS, W, H = 8000, 15, 16, 56, 20
local SPF = math.floor(SR / FPS)
if arg and arg[0] and arg[0] ~= "" then
  local f = io.open(arg[0], "w")
  if f then f:write(C:format(C, GEN + 1)) f:close() end
end
local D, Vx, Vy = {}, {}, {}
for y = 1, H do
  D[y], Vx[y], Vy[y] = {}, {}, {}
  for x = 1, W do D[y][x], Vx[y][x], Vy[y][x] = 0, 0, 0 end
end
local phases = {0, 0, 0, 0}
local function sleep(n)
  local t0 = os.clock()
  while os.clock() - t0 < n do end
end
io.write("\27[2J")
for frame = 1, 30 do
  local audio = {}
  local freqs = {}
  for v = 1, 4 do
    local idx = ((frame * 7 + v * 13 + GEN * 17) % #C) + 1
    local code_byte = C:byte(idx) or 65
    local note = code_byte % 57
    freqs[v] = 110 * (2 ^ (note / 19))
  end
  for n = 1, SPF do
    local sum = 0
    for v = 1, 4 do
      phases[v] = phases[v] + 2 * math.pi * freqs[v] / SR
      sum = sum + math.sin(phases[v])
    end
    audio[n] = sum / 4
  end
  local spec = {}
  for b = 1, BINS do
    local f_bin = 80 * ((1600 / 80) ^ ((b - 1) / (BINS - 1)))
    local re, im = 0, 0
    local w = 2 * math.pi * f_bin / SR
    for n = 1, SPF do
      re = re + audio[n] * math.cos(w * n)
      im = im + audio[n] * math.sin(w * n)
    end
    spec[b] = math.sqrt(re * re + im * im) / SPF
  end
  for b = 1, BINS do
    local x = math.floor((b - 0.5) * (W / BINS)) + 1
    if x >= 1 and x <= W then
      local pwr = spec[b] * 12
      Vy[H][x] = -pwr * 1.2
      D[H][x] = D[H][x] + pwr * 2.5
    end
  end
  local D2, Vx2, Vy2 = {}, {}, {}
  for y = 1, H do
    D2[y], Vx2[y], Vy2[y] = {}, {}, {}
    for x = 1, W do
      local px = math.max(1, math.min(W, x - Vx[y][x]))
      local py = math.max(1, math.min(H, y - Vy[y][x]))
      local ix, iy = math.floor(px), math.floor(py)
      D2[y][x] = D[iy][ix] * 0.94
      Vy2[y][x] = (Vy[iy][ix] - D[y][x] * 0.02) * 0.90
      Vx2[y][x] = Vx[iy][ix] * 0.90
    end
  end
  for y = 1, H do
    for x = 1, W do
      local ym = math.max(1, y - 1)
      local yp = math.min(H, y + 1)
      local xm = math.max(1, x - 1)
      local xp = math.min(W, x + 1)
      D[y][x] = D2[y][x] * 0.5 + (D2[ym][x] + D2[yp][x] + D2[y][xm] + D2[y][xp]) * 0.125
      Vx[y][x] = Vx2[y][x]
      Vy[y][x] = Vy2[y][x]
    end
  end
  local lines = {"\27[H=== SELF-MODIFYING QUINE SONIFIER | GEN: " .. GEN .. " | 19-TET MICROTONAL FLUID ==="}
  local bar_chars = {"_", ".", "-", ":", "=", "*", "#", "@"}
  local spec_bar = "SPEC: "
  for b = 1, BINS do
    local h = math.max(1, math.min(8, math.floor(spec[b] * 20) + 1))
    spec_bar = spec_bar .. bar_chars[h]
  end
  lines[#lines + 1] = spec_bar
  for y = 1, H do
    local row = ""
    for x = 1, W do
      local den = D[y][x]
      if den < 0.08 then
        row = row .. " "
      else
        local char_idx = (math.floor(den * 100) + x + y + GEN) % #C + 1
        local ch = C:sub(char_idx, char_idx)
        if ch:byte() < 32 or ch == "\n" or ch == "\r" then ch = "*" end
        row = row .. ch
      end
    end
    lines[#lines + 1] = row
  end
  io.write(table.concat(lines, "\n") .. "\n")
  sleep(0.04)
end