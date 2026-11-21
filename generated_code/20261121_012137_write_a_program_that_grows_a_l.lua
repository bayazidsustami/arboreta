-- Self-contained Lua simulation: A growing Game of Life organism ("creature")
-- whose births and deaths trigger polyrhythmic marimba-like voices, while repeated
-- notes slowly erode its birth/survival rule table toward decay.
-- Run with: lua marimba_life.lua [steps] [delay_sec]

local W, H = 36, 18
local steps = tonumber(arg and arg[1]) or 120
local delay = tonumber(arg and arg[2]) or 0.14

-- Rule table: birth[n] (from dead cell with n neighbors) and survive[n] (from live cell)
local rules = {
  birth   = { [3] = true },
  survive = { [2] = true, [3] = true }
}

-- Polyrhythmic voice lanes: { name, mod, pitch_base, row_band, phase_offset }
-- Polyrhythms emerge naturally from grid sectors and step-modulo gating.
local voices = {
  { name = "MAR-A", mod = 3, pitch = 220.00, y0 = 1,  y1 = 6,  shift = 0 }, -- A3 (3-beat)
  { name = "MAR-B", mod = 4, pitch = 261.63, y0 = 6,  y1 = 12, shift = 1 }, -- C4 (4-beat)
  { name = "MAR-C", mod = 5, pitch = 329.63, y0 = 12, y1 = 18, shift = 2 }  -- E4 (5-beat)
}

-- Pentatonic intervals (semitones) for warm wooden marimba timbre
local scale = { 0, 2, 4, 7, 9, 12, 14, 16, 19, 24 }
local recent_notes = {}
local MAX_HISTORY = 12
local erosion = 0

local function sleep(sec)
  if sec <= 0 then return end
  if os.execute then
    -- Portable-ish fallback sleep using ping or lua loop if needed
    local ok = os.execute(string.format("sleep %.3f 2>/dev/null || ping -n 2 127.0.0.1 >nul 2>&1", sec))
    if not ok then
      local t0 = os.clock()
      while os.clock() - t0 < sec do end
    end
  end
end

local function new_grid()
  local g = {}
  for y = 1, H do
    g[y] = {}
    for x = 1, W do g[y][x] = false end
  end
  return g
end

local function stamp(g, pattern, ox, oy)
  for r = 1, #pattern do
    local line = pattern[r]
    for c = 1, #line do
      if line:sub(c, c) == "#" then
        local x = ((ox + c - 2) % W) + 1
        local y = ((oy + r - 2) % H) + 1
        g[y][x] = true
      end
    end
  end
end

-- Seed a composite "creature": an R-pentomino heart + glider buds for organic growth
local function seed_creature()
  local g = new_grid()
  stamp(g, {
    ".##",
    "##.",
    ".#."
  }, math.floor(W / 2) - 1, math.floor(H / 2) - 1)
  stamp(g, { ".#.", "..#", "###" }, 4, 3)
  stamp(g, { "#..", ".##", "##." }, W - 6, H - 5)
  return g
end

local function count_neighbors(g, x, y)
  local n = 0
  for dy = -1, 1 do
    local ny = ((y + dy - 1) % H) + 1
    for dx = -1, 1 do
      if not (dx == 0 and dy == 0) then
        local nx = ((x + dx - 1) % W) + 1
        if g[ny][nx] then n = n + 1 end
      end
    end
  end
  return n
end

local function freq_from_cell(base_hz, x, y)
  local idx = ((x * 3 + y * 5) % #scale) + 1
  local semi = scale[idx]
  return base_hz * (2 ^ (semi / 12))
end

local function note_label(hz)
  local notes = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
  local midi = math.floor(69 + 12 * math.log(hz / 440) / math.log(2) + 0.5)
  local name = notes[(midi % 12) + 1]
  local oct = math.floor(midi / 12) - 1
  return string.format("%s%d", name, oct)
end

-- Erodes rule table when a note repeats within recent memory:
-- slightly favors decay/instability as repetition accumulates.
local function erode_rules_on_repeat(note_key)
  local repeats = 0
  for _, prev in ipairs(recent_notes) do
    if prev == note_key then repeats = repeats + 1 end
  end
  table.insert(recent_notes, note_key)
  if #recent_notes > MAX_HISTORY then
    table.remove(recent_notes, 1)
  end

  if repeats > 0 then
    erosion = erosion + 1
    -- Every few repeats, weaken a survival rule or mutate a birth rule
    if erosion % 2 == 1 then
      -- Drop a survival count (preferring higher neighbor counts so colonies thin out)
      for n = 8, 1, -1 do
        if rules.survive[n] and not (n == 2 and erosion < 8) then
          rules.survive[n] = nil
          return string.format("ERODED survive[%d] (repeat x%d)", n, repeats)
        end
      end
    else
      -- Shift birth rules: occasionally add a brittle birth or clear an old one
      local cand = ((erosion * 3) % 7) + 1
      if rules.birth[cand] and cand ~= 3 then
        rules.birth[cand] = nil
        return string.format("ERODED birth[%d] (repeat x%d)", cand, repeats)
      elseif not rules.birth[cand] and cand >= 4 then
        rules.birth[cand] = true
        return string.format("MUTATED birth[%d] (repeat x%d)", cand, repeats)
      end
    end
  end
  return nil
end

-- Synthesize a short wooden marimba strike to a temp WAV and play asynchronously if available
local function pluck_marimba(hz, amp)
  if not os.execute then return end
  local sr = 11025
  local dur = 0.14
  local samples = math.floor(sr * dur)
  local path = "/tmp/lua_marimba_hit.wav"
  local f = io.open(path, "wb")
  if not f then return end

  -- Marimba has a bright 4x harmonic transient that decays rapidly over a warm fundamental
  local data_size = samples * 2
  local function u16(v) return string.char(v % 256, math.floor(v / 256) % 256) end
  local function u32(v)
    return string.char(
      v % 256,
      math.floor(v / 256) % 256,
      math.floor(v / 65536) % 256,
      math.floor(v / 16777216) % 256
    )
  end

  f:write("RIFF", u32(36 + data_size), "WAVEfmt ", u32(16), u16(1), u16(1),
          u32(sr), u32(sr * 2), u16(2), u16(16), "data", u32(data_size))

  for i = 0, samples - 1 do
    local t = i / sr
    local env1 = math.exp(-t * 22)
    local env4 = math.exp(-t * 85) * math.max(0, 1 - t * 25)
    local s1 = math.sin(2 * math.pi * hz * t) * env1
    local s4 = math.sin(2 * math.pi * (hz * 4) * t) * env4 * 0.45
    local val = math.max(-1, math.min(1, (s1 + s4) * amp))
    local pcm = math.floor(val * 32767)
    if pcm < 0 then pcm = pcm + 65536 end
    f:write(u16(pcm))
  end
  f:close()

  -- Non-blocking playback if a lightweight CLI player exists; silent otherwise
  os.execute("(aplay -q " .. path .. " || afplay " .. path .. " || ffplay -nodisp -autoexit -loglevel quiet " .. path .. ") >/dev/null 2>&1 &")
end

local function rules_summary()
  local b, s = {}, {}
  for n = 0, 8 do
    if rules.birth[n] then b[#b + 1] = tostring(n) end
    if rules.survive[n] then s[#s + 1] = tostring(n) end
  end
  return "B" .. table.concat(b, "") .. "/S" .. table.concat(s, "")
end

local function render(g, step, births, deaths, fired_str, erosion_msg)
  io.write("\027[H\027[J") -- clear screen & home cursor
  print(string.format("Step %03d/%03d | Rules: %-10s | Erosion: %02d | Births:%2d Deaths:%2d",
                      step, steps, rules_summary(), erosion, births, deaths))
  print("+" .. string.rep("-", W) .. "+")
  for y = 1, H do
    local row = {}
    for x = 1, W do
      row[x] = g[y][x] and "O" or "."
    end
    print("|" .. table.concat(row) .. "|")
  end
  print("+" .. string.rep("-", W) .. "+")
  if fired_str ~= "" then
    print("Marimba: " .. fired_str)
  else
    print("Marimba: (rest)")
  end
  if erosion_msg then
    print("Rule Erosion: " .. erosion_msg)
  else
    print("Rule Erosion: stable")
  end
end

local grid = seed_creature()
math.randomseed(os.time())

for step = 1, steps do
  local next_g = new_grid()
  local births, deaths = 0, 0
  local events = {}

  for y = 1, H do
    for x = 1, W do
      local n = count_neighbors(grid, x, y)
      local alive = grid[y][x]
      if alive then
        if rules.survive[n] then
          next_g[y][x] = true
        else
          next_g[y][x] = false
          deaths = deaths + 1
          events[#events + 1] = { x = x, y = y, kind = "death" }
        end
      else
        if rules.birth[n] then
          next_g[y][x] = true
          births = births + 1
          events[#events + 1] = { x = x, y = y, kind = "birth" }
        else
          next_g[y][x] = false
        end
      end
    end
  end

  -- Drive polyrhythmic voices from births/deaths falling in each lane's phase & band
  local fired_labels = {}
  local erosion_msg = nil
  for _, v in ipairs(voices) do
    if ((step + v.shift) % v.mod) == 0 then
      for _, ev in ipairs(events) do
        if ev.y >= v.y0 and ev.y < v.y1 then
          local hz = freq_from_cell(v.pitch, ev.x, ev.y)
          local nlabel = note_label(hz)
          local key = v.name .. ":" .. nlabel
          fired_labels[#fired_labels + 1] = string.format("%s[%s:%.0fHz]", v.name, nlabel, hz)
          local msg = erode_rules_on_repeat(key)
          if msg then erosion_msg = msg end
          local amp = (ev.kind == "birth") and 0.35 or 0.22
          pluck_marimba(hz, amp)
          break -- one strike per polyrhythmic lane per active beat
        end
      end
    end
  end

  grid = next_g
  render(grid, step, births, deaths, table.concat(fired_labels, " "), erosion_msg)
  sleep(delay)
end