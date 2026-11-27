-- Self-Evolving Acoustic Cellular Automaton & 3D Topographic Sculpture (Pure Lua)
-- Usage: lua storm_automaton.lua [optional_thunderstorm.wav]

local W, H = 36, 36            -- Cellular automaton grid dimensions
local TERM_W, TERM_H = 92, 34  -- Terminal projection canvas

-- Acoustic frequency bands (Hz) mapped to automaton rule genes
local BANDS = {
  { name = "sub_rumble", f_min = 20,   f_max = 120  },  -- Low thunder: birth threshold bias
  { name = "mid_gust",   f_min = 120,  f_max = 900  },  -- Rain & wind: survival window & phase
  { name = "high_arc",   f_min = 900,  f_max = 5500 }   -- Lightning crackle: mutation rate & height gain
}

-- Seeded PRNG for deterministic repeatability when no WAV file is supplied
local rng_state = 0x5EED1234
local function rand()
  rng_state = (1103515245 * rng_state + 12345) % 2147483648
  return rng_state / 2147483648
end

-- Synthesize an acoustic thunderstorm waveform (rumble bursts, rain noise, crackles)
local function synth_storm_chunk(sample_rate, num_samples, t_offset, seed)
  local samples = {}
  local lp = 0
  for i = 1, num_samples do
    local t = t_offset + (i - 1) / sample_rate
    -- Periodic distant thunder swells + continuous rain hiss + sharp crackle impulses
    local swell = math.max(0, math.sin(t * 0.75 + seed) * math.cos(t * 0.31))
    local sub = math.sin(2 * math.pi * (38 + 14 * math.sin(t * 1.3)) * t) * swell * 1.4
    local white = (rand() * 2 - 1)
    lp = lp * 0.92 + white * 0.08 -- Brownish rain/wind bed
    local crackle = (rand() > 0.996) and ((rand() * 2 - 1) * 2.2 * (0.3 + swell)) or 0
    samples[i] = sub + lp * 0.9 + crackle
  end
  return samples
end

-- Load 8-bit or 16-bit mono/stereo PCM WAV if a path is given; otherwise synthesize
local function load_audio_source(path)
  if not path then
    return nil, 11025
  end
  local f = io.open(path, "rb")
  if not f then
    return nil, 11025
  end
  local data = f:read("*all")
  f:close()
  if not data or #data < 44 or data:sub(1, 4) ~= "RIFF" or data:sub(9, 12) ~= "WAVE" then
    return nil, 11025
  end

  local function u16(s, pos)
    local b1, b2 = s:byte(pos, pos + 1)
    return b1 + b2 * 256
  end
  local function u32(s, pos)
    local b1, b2, b3, b4 = s:byte(pos, pos + 3)
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
  end
  local function i16(s, pos)
    local v = u16(s, pos)
    return v >= 32768 and v - 65536 or v
  end

  local channels = u16(data, 23)
  local sample_rate = u32(data, 25)
  local bits = u16(data, 35)

  -- Locate "data" chunk
  local pos = 13
  while pos + 8 <= #data do
    local chunk_id = data:sub(pos, pos + 3)
    local chunk_sz = u32(data, pos + 4)
    if chunk_id == "data" then
      local pcm_start = pos + 8
      local pcm_end = math.min(#data, pcm_start + chunk_sz - 1)
      local samples = {}
      local step = (bits == 16 and 2 or 1) * math.max(1, channels)
      for p = pcm_start, pcm_end - step + 1, step do
        if bits == 16 then
          samples[#samples + 1] = i16(data, p) / 32768
        else
          samples[#samples + 1] = (data:byte(p) - 128) / 128
        end
      end
      return samples, sample_rate
    end
    pos = pos + 8 + chunk_sz
    if chunk_sz % 2 == 1 then pos = pos + 1 end
  end
  return nil, 11025
end

-- Goertzel spectral energy at a target frequency bin
local function goertzel_energy(samples, sample_rate, freq)
  local n = #samples
  if n == 0 then return 0 end
  local k = math.floor(0.5 + (n * freq) / sample_rate)
  local w = (2 * math.pi * k) / n
  local cosine = math.cos(w)
  local coeff = 2 * cosine
  local q1, q2 = 0, 0
  for i = 1, n do
    local q0 = coeff * q1 - q2 + samples[i]
    q2 = q1
    q1 = q0
  end
  local power = q1 * q1 + q2 * q2 - q1 * q2 * coeff
  return math.sqrt(math.max(0, power)) / n
end

-- Measure normalized energy across sub-bass, mid, and high acoustic bands
local function analyze_frequencies(samples, sample_rate)
  local energies = {}
  for idx, band in ipairs(BANDS) do
    local sum, count = 0, 0
    local steps = 5
    for s = 0, steps - 1 do
      local f = band.f_min + (band.f_max - band.f_min) * (s / math.max(1, steps - 1))
      sum = sum + goertzel_energy(samples, sample_rate, f)
      count = count + 1
    end
    -- Log-compressed normalization into ~[0, 1]
    local raw = sum / count
    energies[band.name] = math.min(1.0, math.log(1 + raw * 180) / math.log(1 + 180))
  end
  return energies
end

-- Initialize grid state and topographic heightfield
local grid, next_grid, topo = {}, {}, {}
for y = 1, H do
  grid[y], next_grid[y], topo[y] = {}, {}, {}
  for x = 1, W do
    local alive = (rand() < 0.28) and 1 or 0
    grid[y][x] = alive
    next_grid[y][x] = 0
    topo[y][x] = alive * 1.5
  end
end

-- Self-rewriting rule set: birth/survive bitmasks over neighbor counts [0..8] + mutation chance
local rule = {
  birth = { [3] = true },
  survive = { [2] = true, [3] = true },
  mutation = 0.01,
  gene_code = "B3/S23"
}

local function rewrite_rules(e)
  -- Sub-bass rumble shifts birth count between 2 and 4; high crackle expands range
  local b_center = math.floor(2.2 + e.sub_rumble * 1.8 + 0.5)
  local b_spread = (e.high_arc > 0.55) and 1 or 0

  -- Mid gust shifts survival window center between 2 and 5
  local s_min = math.max(1, math.min(6, math.floor(1.5 + e.mid_gust * 2.5 + 0.5)))
  local s_max = math.min(7, s_min + 1 + math.floor(e.sub_rumble * 1.5))

  local birth, survive = {}, {}
  local b_str, s_str = "", ""
  for n = 0, 8 do
    if math.abs(n - b_center) <= b_spread then
      birth[n] = true
      b_str = b_str .. tostring(n)
    end
    if n >= s_min and n <= s_max then
      survive[n] = true
      s_str = s_str .. tostring(n)
    end
  end

  -- Acoustic-driven mutation rate (0.3% up to 7.5%)
  rule.birth = birth
  rule.survive = survive
  rule.mutation = 0.003 + e.high_arc * 0.072
  rule.gene_code = string.format("B%s/S%s m=%.3f", b_str, s_str, rule.mutation)
end

local function count_neighbors(x, y)
  local c = 0
  for dy = -1, 1 do
    local yy = ((y - 1 + dy) % H) + 1
    for dx = -1, 1 do
      if not (dx == 0 and dy == 0) then
        local xx = ((x - 1 + dx) % W) + 1
        c = c + grid[yy][xx]
      end
    end
  end
  return c
end

-- Advance cellular automaton and accumulate topographic relief from mutations
local function step_automaton(e)
  local mutations = 0
  local uplift = 0.6 + e.high_arc * 2.2
  local erosion = 0.04 + e.mid_gust * 0.08

  for y = 1, H do
    for x = 1, W do
      local n = count_neighbors(x, y)
      local cell = grid[y][x]
      local nxt = 0

      if cell == 1 then
        nxt = rule.survive[n] and 1 or 0
      else
        nxt = rule.birth[n] and 1 or 0
      end

      -- Spontaneous acoustic mutation rewrites individual cell state
      if rand() < rule.mutation then
        nxt = 1 - nxt
        mutations = mutations + 1
      end

      next_grid[y][x] = nxt

      -- Mutations and active cells sculpt ridges; dormant cells slowly erode
      local h = topo[y][x]
      if nxt ~= cell then
        h = h + uplift * 1.4
      elseif nxt == 1 then
        h = h + uplift * 0.35
      else
        h = math.max(0, h - erosion)
      end
      topo[y][x] = math.min(18.0, h)
    end
  end

  -- Gentle smoothing pass to form cohesive topographic ridges and valleys
  for y = 1, H do
    local yp = ((y - 2) % H) + 1
    local yn = (y % H) + 1
    for x = 1, W do
      local xp = ((x - 2) % W) + 1
      local xn = (x % W) + 1
      local avg = (topo[y][x] * 4 + topo[yp][x] + topo[yn][x] + topo[y][xp] + topo[y][xn]) / 8
      topo[y][x] = avg
      grid[y][x] = next_grid[y][x]
    end
  end

  return mutations
end

-- Project rotating 3D topographic heightfield onto a 2D character buffer with z-buffering
local SHADE = " .:-=+*#%@"
local function render_3d_sculpture(angle_y, tilt_x, frame_idx, energies, mutations)
  local screen, zbuf = {}, {}
  for r = 1, TERM_H do
    screen[r], zbuf[r] = {}, {}
    for c = 1, TERM_W do
      screen[r][c] = " "
      zbuf[r][c] = -1e9
    end
  end

  local cos_y, sin_y = math.cos(angle_y), math.sin(angle_y)
  local cos_x, sin_x = math.cos(tilt_x), math.sin(tilt_x)
  local scale = math.min(TERM_W * 0.34, TERM_H * 0.55)
  local cx, cy = TERM_W * 0.5, TERM_H * 0.56

  -- Sample grid points in normalized [-1, 1] space
  for gy = 1, H do
    local ny = (gy / H) * 2 - 1
    for gx = 1, W do
      local nx = (gx / W) * 2 - 1
      local h = topo[gy][gx] / 18.0 -- Normalized elevation [0..1]
      local elev = h * 0.72

      -- Rotate around Y (yaw)
      local x1 = nx * cos_y + elev * sin_y
      local z1 = -nx * sin_y + elev * cos_y
      local y1 = ny

      -- Rotate around X (elevation tilt)
      local y2 = y1 * cos_x - z1 * sin_x
      local z2 = y1 * sin_x + z1 * cos_x

      -- Perspective projection
      local fov = 2.6
      local persp = fov / (fov + z2 + 1.4)
      local sx = math.floor(cx + x1 * scale * persp + 0.5)
      local sy = math.floor(cy + y2 * scale * 0.62 * persp + 0.5)

      if sx >= 1 and sx <= TERM_W and sy >= 1 and sy <= TERM_H then
        local depth = persp + h * 0.25
        if depth > zbuf[sy][sx] then
          zbuf[sy][sx] = depth
          local idx = math.max(1, math.min(#SHADE, math.floor(1 + h * (#SHADE - 1) + 0.5)))
          screen[sy][sx] = SHADE:sub(idx, idx)
        end
      end
    end
  end

  local lines = {}
  lines[#lines + 1] = string.format(
    "\27[H\27[2JTHUNDERSTORM ACOUSTIC AUTOMATON | Frame %03d | Rule: %s | Mutations: %d",
    frame_idx, rule.gene_code, mutations
  )
  lines[#lines + 1] = string.format(
    "Acoustic Bands -> Sub(20-120Hz): %.2f | Mid(120-900Hz): %.2f | High(900-5.5kHz): %.2f",
    energies.sub_rumble, energies.mid_gust, energies.high_arc
  )
  for r = 1, TERM_H do
    lines[#lines + 1] = table.concat(screen[r])
  end
  return table.concat(lines, "\n")
end

-- Main execution loop
local wav_samples, sample_rate = load_audio_source(arg and arg[1])
local chunk_size = math.floor(sample_rate * 0.12) -- ~120ms acoustic window per step
local total_frames = 90
local cursor = 1

for frame = 1, total_frames do
  local chunk
  if wav_samples and #wav_samples > 0 then
    chunk = {}
    for i = 1, chunk_size do
      local idx = ((cursor - 1 + i - 1) % #wav_samples) + 1
      chunk[i] = wav_samples[idx]
    end
    cursor = ((cursor - 1 + chunk_size) % #wav_samples) + 1
  else
    chunk = synth_storm_chunk(sample_rate, chunk_size, (frame - 1) * 0.12, 7.0)
  end

  local energies = analyze_frequencies(chunk, sample_rate)
  rewrite_rules(energies)
  local mutations = step_automaton(energies)

  local yaw = frame * 0.085
  local pitch = 0.68 + 0.12 * math.sin(frame * 0.05)
  io.write(render_3d_sculpture(yaw, pitch, frame, energies, mutations) .. "\n")
  io.flush()

  -- Lightweight portable pause (~50ms) without OS-specific C bindings
  local t0 = os.clock()
  while os.clock() - t0 < 0.05 do end
end