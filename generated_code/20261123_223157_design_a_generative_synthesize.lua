-- Generative Subway Delay Polyrhythm Synth & Topographic Ink Contour Renderer
-- Self-contained Lua script using LÖVE (Love2D, 11.x+) with procedural PCM audio synthesis.
-- Run with: love . (place in a folder with main.lua)
-- Controls:
--   [1-4] Select train line (A, C, L, N)
--   [Up/Down] Adjust selected line's delay (0 to 25 minutes)
--   [Space] Inject a sudden delay spike / station hold on selected line
--   [M] Mute / Unmute audio
--   [R] Reset delays & topographic drift

local SAMPLE_RATE = 44100
local MAX_BUFFER_SEC = 4.0
local INK_HISTORY_MAX = 72
local CONTOUR_POINTS = 96

local state = {
  time = 0,
  topoPhase = 0,
  muted = false,
  selected = 1,
  lines = {
    {
      id = "A",
      name = "Eighth Ave Express",
      delayMin = 4.0,
      targetDelay = 4.0,
      baseFreq = 220.0,       -- A3
      scale = {1, 9/8, 5/4, 3/2, 5/3, 2},
      color = {0.10, 0.36, 0.78},
      inkColor = {0.06, 0.22, 0.52},
      seed = 11.3,
      phaseAcc = 0,
      stepIdx = 1,
      pulseGlow = 0,
      history = {},
      bleeds = {}
    },
    {
      id = "C",
      name = "Eighth Ave Local",
      delayMin = 7.5,
      targetDelay = 7.5,
      baseFreq = 293.66,      -- D4
      scale = {1, 9/8, 6/5, 3/2, 9/5, 2},
      color = {0.14, 0.56, 0.62},
      inkColor = {0.07, 0.34, 0.40},
      seed = 27.9,
      phaseAcc = 0,
      stepIdx = 1,
      pulseGlow = 0,
      history = {},
      bleeds = {}
    },
    {
      id = "L",
      name = "14th St Crosstown",
      delayMin = 2.0,
      targetDelay = 2.0,
      baseFreq = 329.63,      -- E4
      scale = {1, 5/4, 3/2, 7/4, 2, 9/4},
      color = {0.52, 0.55, 0.58},
      inkColor = {0.26, 0.29, 0.33},
      seed = 43.1,
      phaseAcc = 0,
      stepIdx = 1,
      pulseGlow = 0,
      history = {},
      bleeds = {}
    },
    {
      id = "N",
      name = "Broadway Express",
      delayMin = 11.0,
      targetDelay = 11.0,
      baseFreq = 392.0,       -- G4
      scale = {1, 9/8, 5/4, 3/2, 5/3, 2},
      color = {0.86, 0.62, 0.08},
      inkColor = {0.54, 0.35, 0.03},
      seed = 61.7,
      phaseAcc = 0,
      stepIdx = 1,
      pulseGlow = 0,
      history = {},
      bleeds = {}
    }
  },
  activeSources = {}
}

-- Smooth periodic pseudo-noise for organic topographic drift and ink breathing
local function periodicNoise(x, y, t, seed)
  local a = math.sin(x * 0.0085 + t * 0.31 + seed) * math.cos(y * 0.0092 - t * 0.23 + seed * 0.7)
  local b = math.sin((x + y) * 0.0053 - t * 0.17 + seed * 1.3) * 0.65
  local c = math.cos(x * 0.017 - y * 0.014 + t * 0.47 + seed * 2.1) * 0.35
  return (a + b + c) / 2.0
end

-- Synthesize a metallic/glassy chime SoundData with harmonic partials, shimmer, and decay
local function createChimeSound(freq, delayFactor, pan)
  local duration = 1.15 + math.min(delayFactor, 1.0) * 1.15
  local samples = math.floor(SAMPLE_RATE * duration)
  local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 2)

  -- Slight detuning & overtone ratios for bell/chime character
  local partials = {
    {ratio = 1.00, amp = 0.55, decay = 2.6},
    {ratio = 2.00, amp = 0.24, decay = 4.2},
    {ratio = 2.756, amp = 0.14, decay = 6.5}, -- inharmonic metallic partial
    {ratio = 4.02, amp = 0.07, decay = 9.0}
  }

  local leftGain = math.cos((pan + 1) * math.pi * 0.25)
  local rightGain = math.sin((pan + 1) * math.pi * 0.25)
  local pitchBend = 1.0 - math.min(delayFactor, 1.5) * 0.018

  for i = 0, samples - 1 do
    local t = i / SAMPLE_RATE
    local envAttack = math.min(1.0, t / 0.004)
    local sig = 0

    for _, p in ipairs(partials) do
      local f = freq * p.ratio * (1.0 - (1.0 - pitchBend) * math.min(1.0, t * 1.8))
      local amp = p.amp * math.exp(-t * p.decay)
      -- Subtle chorus beating on fundamental
      local beat = 1.0 + 0.08 * math.sin(2 * math.pi * 2.3 * t)
      sig = sig + math.sin(2 * math.pi * f * t) * amp * beat
    end

    -- Soft transient click at strike
    local click = (math.random() * 2 - 1) * math.exp(-t * 160) * 0.14
    local out = (sig + click) * envAttack * 0.24
    out = math.max(-0.98, math.min(0.98, out))

    sd:setSample(i, 0, out * leftGain)
    sd:setSample(i, 1, out * rightGain)
  end

  return sd
end

local function triggerChime(line, idx)
  line.pulseGlow = 1.0

  -- Spawn an ink bleed blotch along the latest contour position
  local latest = line.history[#line.history]
  if latest then
    table.insert(line.bleeds, {
      x = latest.x,
      y = latest.y,
      radius = 5 + math.min(line.delayMin, 20) * 0.45,
      maxRadius = 18 + math.min(line.delayMin, 25) * 1.35,
      alpha = 0.34,
      growRate = 12 + line.delayMin * 0.8
    })
  end

  if state.muted then return end

  local scaleRatio = line.scale[((idx - 1) % #line.scale) + 1]
  local octaveShift = (line.delayMin >= 10) and 0.5 or 1.0
  local freq = line.baseFreq * scaleRatio * octaveShift
  local delayFactor = line.delayMin / 12.0
  local pan = (idx % 2 == 0 and 0.35 or -0.35) + periodicNoise(idx * 40, line.seed * 10, state.time, line.seed) * 0.35

  local sd = createChimeSound(freq, delayFactor, math.max(-0.9, math.min(0.9, pan)))
  local src = love.audio.newSource(sd)
  src:play()
  table.insert(state.activeSources, src)
end

-- Compute a train line's contour point at normalized progress u in [0, 1]
local function sampleContourPoint(line, u, w, h, t)
  local delayNorm = math.min(line.delayMin / 20.0, 1.25)
  local breath = 0.5 + 0.5 * math.sin(t * (1.1 + delayNorm * 1.6) + line.seed)

  -- Base route sweeps across map with delay-driven undulation and topographic elevation pull
  local marginX = w * 0.10
  local x = marginX + u * (w - marginX * 2)

  local laneCenterY = h * (0.24 + (line.seed % 4) * 0.16)
  local waveFreq = 2.0 + math.floor(line.delayMin * 0.45) * 0.5
  local waveAmp = (14 + line.delayMin * 3.4) * (0.75 + 0.35 * breath)

  local primaryWave = math.sin(u * math.pi * waveFreq + t * (0.65 + delayNorm * 0.9) + line.seed) * waveAmp
  local elev = periodicNoise(x, laneCenterY, t * 0.55, line.seed)
  local topoPull = elev * (32 + line.delayMin * 2.6)

  -- Ink-bleed micro-jitter along the contour edge
  local bleedWobble = math.sin(u * 38.0 + t * 3.2 + line.seed) * (1.5 + delayNorm * 4.5) * breath

  local y = laneCenterY + primaryWave + topoPull + bleedWobble
  y = math.max(h * 0.10, math.min(h * 0.88, y))

  return x, y, elev, breath
end

local function rebuildHistory(line, w, h)
  line.history = {}
  for i = 0, CONTOUR_POINTS do
    local u = i / CONTOUR_POINTS
    local x, y, elev, breath = sampleContourPoint(line, u, w, h, state.time)
    table.insert(line.history, {x = x, y = y, elev = elev, breath = breath})
  end
end

local function resetAll()
  local w, h = love.graphics.getDimensions()
  for i, line in ipairs(state.lines) do
    local defaults = {4.0, 7.5, 2.0, 11.0}
    line.delayMin = defaults[i]
    line.targetDelay = defaults[i]
    line.phaseAcc = 0
    line.stepIdx = 1
    line.pulseGlow = 0
    line.bleeds = {}
    rebuildHistory(line, w, h)
  end
end

function love.load()
  love.window.setTitle("Subway Delay Polyrhythm Synth & Topographic Ink Contours")
  love.window.setMode(1180, 720, {resizable = true, minwidth = 800, minheight = 500})
  math.randomseed(os.time())
  resetAll()
end

function love.resize(w, h)
  for _, line in ipairs(state.lines) do
    rebuildHistory(line, w, h)
  end
end

function love.update(dt)
  dt = math.min(dt, 0.05)
  state.time = state.time + dt
  state.topoPhase = state.topoPhase + dt * 0.22

  -- Clean up finished audio sources
  for i = #state.activeSources, 1, -1 do
    if not state.activeSources[i]:isPlaying() then
      table.remove(state.activeSources, i)
    end
  end

  -- Continuous keyboard adjustment for selected line's delay
  local sel = state.lines[state.selected]
  if sel then
    if love.keyboard.isDown("up") then
      sel.targetDelay = math.min(25.0, sel.targetDelay + dt * 8.0)
    elseif love.keyboard.isDown("down") then
      sel.targetDelay = math.max(0.0, sel.targetDelay - dt * 8.0)
    end
  end

  local w, h = love.graphics.getDimensions()

  for _, line in ipairs(state.lines) do
    -- Smoothly glide delay toward target
    line.delayMin = line.delayMin + (line.targetDelay - line.delayMin) * math.min(1.0, dt * 4.5)
    line.pulseGlow = math.max(0.0, line.pulseGlow - dt * 1.8)

    -- Polyrhythmic pulse rate: longer delays create slower, shifting subdivisions
    -- Using coprime-ish cadence multipliers so lines drift against one another
    local subdivisions = {3, 4, 5, 7}
    local lineIdx = (line.id == "A" and 1) or (line.id == "C" and 2) or (line.id == "L" and 3) or 4
    local sub = subdivisions[lineIdx]
    local delaySlowdown = 1.0 / (1.0 + line.delayMin * 0.085)
    local pulsesPerSec = (1.35 * sub / 4.0) * delaySlowdown

    line.phaseAcc = line.phaseAcc + dt * pulsesPerSec
    if line.phaseAcc >= 1.0 then
      line.phaseAcc = line.phaseAcc - 1.0
      line.stepIdx = line.stepIdx + 1
      triggerChime(line, line.stepIdx)
    end

    -- Update contour points
    rebuildHistory(line, w, h)

    -- Update ink bleeds
    for b = #line.bleeds, 1, -1 do
      local bl = line.bleeds[b]
      bl.radius = bl.radius + bl.growRate * dt
      bl.alpha = bl.alpha - dt * 0.14
      if bl.alpha <= 0 or bl.radius >= bl.maxRadius then
        table.remove(line.bleeds, b)
      end
    end
    if #line.bleeds > INK_HISTORY_MAX then
      table.remove(line.bleeds, 1)
    end
  end
end

function love.keypressed(key)
  if key == "1" then state.selected = 1
  elseif key == "2" then state.selected = 2
  elseif key == "3" then state.selected = 3
  elseif key == "4" then state.selected = 4
  elseif key == "m" then state.muted = not state.muted
  elseif key == "r" then resetAll()
  elseif key == "space" then
    local sel = state.lines[state.selected]
    if sel then
      sel.targetDelay = math.min(25.0, sel.targetDelay + 5.5 + math.random() * 4.0)
      triggerChime(sel, sel.stepIdx + 1)
    end
  end
end

-- Draw shifting topographic elevation isolines across the background
local function drawTopographicMap(w, h, t)
  -- Warm parchment/paper map base
  love.graphics.clear(0.95, 0.92, 0.86, 1.0)

  local stepX = 28
  local stepY = 24
  local cols = math.ceil(w / stepX) + 1
  local rows = math.ceil(h / stepY) + 1
  local grid = {}

  for r = 1, rows do
    grid[r] = {}
    local y = (r - 1) * stepY
    for c = 1, cols do
      local x = (c - 1) * stepX
      grid[r][c] = periodicNoise(x, y, t, 3.7)
    end
  end

  -- Draw subtle elevation contour bands using marching-style threshold segments
  local levels = {-0.75, -0.50, -0.25, 0.0, 0.25, 0.50, 0.75}
  for li, iso in ipairs(levels) do
    local isMajor = (li % 2 == 0)
    love.graphics.setLineWidth(isMajor and 1.35 or 0.75)
    love.graphics.setColor(0.58, 0.51, 0.41, isMajor and 0.26 or 0.14)

    for r = 1, rows - 1 do
      local y0 = (r - 1) * stepY
      local y1 = y0 + stepY
      for c = 1, cols - 1 do
        local x0 = (c - 1) * stepX
        local x1 = x0 + stepX

        local v00 = grid[r][c]
        local v10 = grid[r][c + 1]
        local v11 = grid[r + 1][c + 1]
        local v01 = grid[r + 1][c]

        local pts = {}
        local function interp(a, b, va, vb, ax, ay, bx, by)
          if (va < iso and vb >= iso) or (va >= iso and vb < iso) then
            local denom = (vb - va)
            local frac = math.abs(denom) > 1e-6 and ((iso - va) / denom) or 0.5
            frac = math.max(0, math.min(1, frac))
            table.insert(pts, ax + (bx - ax) * frac)
            table.insert(pts, ay + (by - ay) * frac)
          end
        end

        interp(0, 1, v00, v10, x0, y0, x1, y0)
        interp(1, 2, v10, v11, x1, y0, x1, y1)
        interp(2, 3, v11, v01, x1, y1, x0, y1)
        interp(3, 0, v01, v00, x0, y1, x0, y0)

        if #pts >= 4 then
          love.graphics.line(pts[1], pts[2], pts[3], pts[4])
        end
      end
    end
  end
end

-- Draw a breathing, ink-bleeding contour ribbon for a train line
local function drawTrainContour(line, isSelected)
  if #line.history < 2 then return end

  -- 1. Render absorbed ink bleed blooms
  for _, bl in ipairs(line.bleeds) do
    love.graphics.setColor(line.inkColor[1], line.inkColor[2], line.inkColor[3], bl.alpha * 0.45)
    love.graphics.circle("fill", bl.x, bl.y, bl.radius)
    love.graphics.setColor(line.inkColor[1], line.inkColor[2], line.inkColor[3], bl.alpha * 0.75)
    love.graphics.setLineWidth(1.0)
    love.graphics.circle("line", bl.x, bl.y, bl.radius * 0.85)
  end

  -- 2. Outer translucent ink wash ("bleed halo") that breathes with delay
  local haloWidth = 10 + line.delayMin * 1.15 + line.pulseGlow * 10
  local haloPts = {}
  for _, p in ipairs(line.history) do
    table.insert(haloPts, p.x)
    table.insert(haloPts, p.y)
  end

  love.graphics.setLineWidth(haloWidth)
  love.graphics.setLineJoin("smooth")
  love.graphics.setColor(line.color[1], line.color[2], line.color[3], 0.16 + line.pulseGlow * 0.16)
  love.graphics.line(haloPts)

  -- 3. Core crisp ink contour
  local coreWidth = (isSelected and 3.6 or 2.5) + line.pulseGlow * 2.2
  love.graphics.setLineWidth(coreWidth)
  love.graphics.setColor(line.inkColor[1], line.inkColor[2], line.inkColor[3], 0.92)
  love.graphics.line(haloPts)

  -- 4. Glowing pulse node at the leading/active crest
  local head = line.history[#line.history]
  local pulseIdx = math.max(1, math.min(#line.history, math.floor((1.0 - line.phaseAcc) * #line.history)))
  local node = line.history[pulseIdx]

  love.graphics.setColor(line.color[1], line.color[2], line.color[3], 0.35 + line.pulseGlow * 0.55)
  love.graphics.circle("fill", node.x, node.y, 6 + line.pulseGlow * 11)
  love.graphics.setColor(1, 1, 1, 0.85)
  love.graphics.circle("fill", node.x, node.y, 2.5 + line.pulseGlow * 3.0)

  -- Line badge at left terminus
  local startPt = line.history[1]
  love.graphics.setColor(line.color[1], line.color[2], line.color[3], 1.0)
  love.graphics.circle("fill", startPt.x - 18, startPt.y, isSelected and 15 or 12)
  if isSelected then
    love.graphics.setColor(0.12, 0.12, 0.14, 1.0)
    love.graphics.setLineWidth(2.2)
    love.graphics.circle("line", startPt.x - 18, startPt.y, 17)
  end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.printf(line.id, startPt.x - 30, startPt.y - 7, 24, "center")
  return head
end

local function drawHUD(w, h)
  -- Top telemetry bar
  love.graphics.setColor(0.12, 0.11, 0.10, 0.84)
  love.graphics.rectangle("fill", 16, 14, w - 32, 64, 8, 8)

  love.graphics.setColor(0.96, 0.94, 0.89, 1.0)
  love.graphics.print("SUBWAY DELAY POLYRHYTHM SYNTH // TOPOGRAPHIC INK CONTOURS", 28, 22)
  love.graphics.setColor(0.80, 0.77, 0.70, 1.0)
  love.graphics.print(
    string.format("[1-4] Line   [Up/Down] Delay   [Space] Hold/Spike   [M] %s   [R] Reset",
      state.muted and "Unmute" or "Mute"),
    28, 46
  )

  -- Bottom line status cards
  local cardW = (w - 48 - (4 - 1) * 10) / 4
  local cardY = h - 76
  for i, line in ipairs(state.lines) do
    local x = 16 + (i - 1) * (cardW + 10)
    local selected = (i == state.selected)

    love.graphics.setColor(0.12, 0.11, 0.10, selected and 0.92 or 0.76)
    love.graphics.rectangle("fill", x, cardY, cardW, 60, 6, 6)

    if selected then
      love.graphics.setColor(line.color[1], line.color[2], line.color[3], 1.0)
      love.graphics.setLineWidth(2.0)
      love.graphics.rectangle("line", x, cardY, cardW, 60, 6, 6)
    end

    love.graphics.setColor(line.color[1], line.color[2], line.color[3], 1.0)
    love.graphics.circle("fill", x + 18, cardY + 20, 9)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(line.id, x + 9, cardY + 13, 18, "center")

    love.graphics.setColor(0.96, 0.94, 0.89, 1.0)
    love.graphics.print(string.format("Delay: %.1f min", line.delayMin), x + 36, cardY + 12)

    love.graphics.setColor(0.76, 0.73, 0.66, 1.0)
    love.graphics.print(string.format("%s  |  Step #%d", line.name, line.stepIdx), x + 12, cardY + 36)
  end
end

function love.draw()
  local w, h = love.graphics.getDimensions()
  drawTopographicMap(w, h, state.topoPhase)

  for i, line in ipairs(state.lines) do
    drawTrainContour(line, i == state.selected)
  end

  drawHUD(w, h)
end