# frozen_string_literal: true

# Chaotic 3-Body Polyrhythmic Audio Symphony & Weeping Ink-Wash Calligraphy Renderer
# Pure Ruby (standard library only). Outputs:
#   1. three_body_symphony.wav    (stereo 16-bit PCM polyrhythmic audio)
#   2. weeping_calligraphy.ppm   (sumi-e ink-wash phase-space artwork on rice paper)

SAMPLE_RATE = 44_100
DURATION_SEC = 14.0
TOTAL_SAMPLES = (SAMPLE_RATE * DURATION_SEC).to_i

IMG_W = 1200
IMG_H = 1200

# Body definition: mass, position (x, y), velocity (vx, vy), base frequency, polyrhythm ratio
Body = Struct.new(:name, :m, :x, :y, :vx, :vy, :base_hz, :poly_steps, :phase_accum, :last_pulse_t, keyword_init: true)

class ThreeBodySymphony
  G = 1.65
  SOFTENING = 0.08
  DT = 0.0025

  def initialize
    # Classic chaotic figure-eight / perturbed three-body initial conditions
    @bodies = [
      Body.new(name: 'Tian', m: 1.05, x: -0.97000436, y: 0.24308753, vx: 0.466203685 * 0.96, vy: 0.43236573 * 1.04,
               base_hz: 146.83, poly_steps: 3, phase_accum: 0.0, last_pulse_t: -10.0),
      Body.new(name: 'Di',   m: 0.95, x:  0.97000436, y: -0.24308753, vx: 0.466203685 * 0.96, vy: 0.43236573 * 1.04,
               base_hz: 220.00, poly_steps: 5, phase_accum: 0.0, last_pulse_t: -10.0),
      Body.new(name: 'Ren',  m: 1.15, x:  0.0,        y: 0.0,         vx: -0.93240737 * 0.96, vy: -0.86473146 * 1.04,
               base_hz: 329.63, poly_steps: 7, phase_accum: 0.0, last_pulse_t: -10.0)
    ]
    recenter_momentum!

    # Phase-space points per body: [x_norm, vx_norm, speed, acc_mag, time]
    @phase_trails = Array.new(3) { [] }
    @events = [] # Scheduled audio plucks/pulses: { time:, freq:, amp:, pan:, decay:, harmonic: }
    @sim_time = 0.0
  end

  def recenter_momentum!
    px = @bodies.sum { |b| b.m * b.vx }
    py = @bodies.sum { |b| b.m * b.vy }
    tot_m = @bodies.sum(&:m)
    @bodies.each do |b|
      b.vx -= px / tot_m
      b.vy -= py / tot_m
    end
  end

  def accelerations(state)
    n = state.length
    ax = Array.new(n, 0.0)
    ay = Array.new(n, 0.0)
    (0...n).each do |i|
      ((i + 1)...n).each do |j|
        dx = state[j][2] - state[i][2]
        dy = state[j][3] - state[i][3]
        r2 = dx * dx + dy * dy + SOFTENING * SOFTENING
        inv_r3 = 1.0 / (r2 * Math.sqrt(r2))
        f = G * inv_r3
        ax[i] += f * state[j][0] * dx
        ay[i] += f * state[j][0] * dy
        ax[j] -= f * state[i][0] * dx
        ay[j] -= f * state[i][0] * dy
      end
    end
    [ax, ay]
  end

  # state element: [m, x, y, vx, vy]
  def rk4_step(dt)
    s0 = @bodies.map { |b| [b.m, b.x, b.y, b.vx, b.vy] }

    deriv = lambda do |st|
      ax, ay = accelerations(st)
      st.each_with_index.map { |row, i| [row[3], row[4], ax[i], ay[i]] }
    end

    k1 = deriv.call(s0)
    s2 = s0.each_with_index.map { |r, i| [r[0], r[1] + 0.5 * dt * k1[i][0], r[2] + 0.5 * dt * k1[i][1], r[3] + 0.5 * dt * k1[i][2], r[4] + 0.5 * dt * k1[i][3]] }
    k2 = deriv.call(s2)
    s3 = s0.each_with_index.map { |r, i| [r[0], r[1] + 0.5 * dt * k2[i][0], r[2] + 0.5 * dt * k2[i][1], r[3] + 0.5 * dt * k2[i][2], r[4] + 0.5 * dt * k2[i][3]] }
    k3 = deriv.call(s3)
    s4 = s0.each_with_index.map { |r, i| [r[0], r[1] + dt * k3[i][0], r[2] + dt * k3[i][1], r[3] + dt * k3[i][2], r[4] + dt * k3[i][3]] }
    k4 = deriv.call(s4)

    ax_end, ay_end = accelerations(s4)

    @bodies.each_with_index do |b, i|
      b.x  += (dt / 6.0) * (k1[i][0] + 2.0 * k2[i][0] + 2.0 * k3[i][0] + k4[i][0])
      b.y  += (dt / 6.0) * (k1[i][1] + 2.0 * k2[i][1] + 2.0 * k3[i][1] + k4[i][1])
      b.vx += (dt / 6.0) * (k1[i][2] + 2.0 * k2[i][2] + 2.0 * k3[i][2] + k4[i][2])
      b.vy += (dt / 6.0) * (k1[i][3] + 2.0 * k2[i][3] + 2.0 * k3[i][3] + k4[i][3])

      speed = Math.hypot(b.vx, b.vy)
      acc = Math.hypot(ax_end[i], ay_end[i])
      @phase_trails[i] << [b.x, b.vx, b.y, b.vy, speed, acc, @sim_time]
    end
  end

  def pairwise_tension(idx)
    b = @bodies[idx]
    min_dist = Float::INFINITY
    @bodies.each_with_index do |other, j|
      next if idx == j
      d = Math.hypot(other.x - b.x, other.y - b.y)
      min_dist = d if d < min_dist
    end
    # Closer encounters raise pitch and shorten decay
    1.0 / (0.35 + min_dist)
  end

  def simulate!
    # Map simulation time across audio duration
    sim_span = 18.0
    total_sim_steps = (sim_span / DT).to_i
    pentatonic_mults = [1.0, 9.0 / 8.0, 5.0 / 4.0, 3.0 / 2.0, 5.0 / 3.0, 2.0]

    total_sim_steps.times do |step|
      rk4_step(DT)
      @sim_time += DT
      audio_t = (@sim_time / sim_span) * DURATION_SEC

      @bodies.each_with_index do |b, idx|
        tension = pairwise_tension(idx)
        speed = Math.hypot(b.vx, b.vy)

        # Polyrhythmic phase advance modulated by orbital speed and gravitational tension
        rate = b.poly_steps * (0.65 + 0.35 * tension) * (0.7 + 0.25 * Math.sin(@sim_time * (idx + 1)))
        b.phase_accum += rate * DT

        if b.phase_accum >= 1.0
          b.phase_accum -= 1.0

          # Quantize frequency onto harmonic pentatonic intervals scaled by orbital energy
          note_idx = ((speed * 2.4 + tension * 1.7 + step * 0.03) % pentatonic_mults.length).to_i
          freq = b.base_hz * pentatonic_mults[note_idx] * (0.92 + 0.16 * Math.tanh(b.y))
          pan = Math.tanh(b.x * 1.1) # -1 (left) to +1 (right)
          amp = (0.14 + 0.12 * Math.tanh(speed * 0.6)).clamp(0.05, 0.32)
          decay = (0.18 + 0.28 / tension).clamp(0.12, 0.55)
          harmonic = 1.5 + (speed % 2.5)

          @events << {
            time: audio_t,
            freq: freq,
            amp: amp,
            pan: pan,
            decay: decay,
            harmonic: harmonic
          }
        end
      end
    end
  end

  # Synthesize stereo 16-bit WAV from scheduled polyrhythmic events + subtle drone
  def render_wav(filename = 'three_body_symphony.wav')
    left_buf  = Array.new(TOTAL_SAMPLES, 0.0)
    right_buf = Array.new(TOTAL_SAMPLES, 0.0)

    # Gentle deep bass drone anchored to root & fifth
    TOTAL_SAMPLES.times do |i|
      t = i.to_f / SAMPLE_RATE
      env = Math.sin(Math::PI * (t / DURATION_SEC)) ** 0.35
      drone = 0.045 * env * (Math.sin(2.0 * Math::PI * 73.42 * t) + 0.5 * Math.sin(2.0 * Math::PI * 110.0 * t + 0.3 * Math.sin(2.0 * Math::PI * 0.4 * t)))
      left_buf[i]  += drone
      right_buf[i] += drone
    end

    two_pi = 2.0 * Math::PI
    @events.each do |ev|
      start_idx = (ev[:time] * SAMPLE_RATE).to_i
      next if start_idx >= TOTAL_SAMPLES

      len = (ev[:decay] * 4.5 * SAMPLE_RATE).to_i
      end_idx = [TOTAL_SAMPLES - 1, start_idx + len].min
      f0 = ev[:freq]
      fh = f0 * ev[:harmonic]
      pan_l = Math.cos((ev[:pan] + 1.0) * Math::PI * 0.25)
      pan_r = Math.sin((ev[:pan] + 1.0) * Math::PI * 0.25)

      (start_idx..end_idx).each do |idx|
        tau = (idx - start_idx).to_f / SAMPLE_RATE
        # Pluck envelope: crisp attack, exponential decay, slight pitch glide
        attack = 1.0 - Math.exp(-tau * 180.0)
        envelope = attack * Math.exp(-tau / ev[:decay])
        glide_f = f0 * (1.0 + 0.015 * Math.exp(-tau * 18.0))
        sample = ev[:amp] * envelope * (
          0.72 * Math.sin(two_pi * glide_f * tau) +
          0.28 * Math.sin(two_pi * fh * tau) * Math.exp(-tau * 9.0)
        )
        left_buf[idx]  += sample * pan_l
        right_buf[idx] += sample * pan_r
      end
    end

    # Soft limiter / normalization
    peak = 1e-6
    TOTAL_SAMPLES.times do |i|
      peak = [peak, left_buf[i].abs, right_buf[i].abs].max
    end
    norm = peak > 0.92 ? (0.92 / peak) : 1.0

    pcm = String.new(capacity: TOTAL_SAMPLES * 4)
    TOTAL_SAMPLES.times do |i|
      l_s = (Math.tanh(left_buf[i] * norm * 1.15) * 32_767.0).round.clamp(-32_768, 32_767)
      r_s = (Math.tanh(right_buf[i] * norm * 1.15) * 32_767.0).round.clamp(-32_768, 32_767)
      pcm << [l_s, r_s].pack('s<2')
    end

    byte_rate = SAMPLE_RATE * 2 * 2
    data_size = pcm.bytesize
    riff_size = 36 + data_size

    header = [
      'RIFF', riff_size, 'WAVE',
      'fmt ', 16, 1, 2, SAMPLE_RATE, byte_rate, 4, 16,
      'data', data_size
    ].pack('A4VA4A4VvvVVvvA4V')

    File.binwrite(filename, header + pcm)
  end

  # Render weeping ink-wash calligraphy of phase-space trajectories (x vs vx) onto rice paper
  def render_calligraphy(filename = 'weeping_calligraphy.ppm')
    # Rice-paper base canvas: warm off-white [246, 240, 228] with subtle paper grain
    canvas_r = Array.new(IMG_W * IMG_H, 246.0)
    canvas_g = Array.new(IMG_W * IMG_H, 240.0)
    canvas_b = Array.new(IMG_W * IMG_H, 228.0)

    # Deterministic pseudo-random helper for organic ink wash & weeping drips
    seed = 20261121
    rng = lambda do
      seed = (1_103_515_245 * seed + 12_345) & 0x7fffffff
      seed.to_f / 0x7fffffff
    end

    # Rice paper fibers & gentle wash clouds
    (IMG_W * IMG_H).times do |i|
      x = i % IMG_W
      y = i / IMG_W
      grain = (rng.call - 0.5) * 7.0
      cloud = Math.sin(x * 0.006) * Math.cos(y * 0.005) * 5.0
      canvas_r[i] = (canvas_r[i] + grain + cloud).clamp(0.0, 255.0)
      canvas_g[i] = (canvas_g[i] + grain * 0.9 + cloud * 0.9).clamp(0.0, 255.0)
      canvas_b[i] = (canvas_b[i] + grain * 0.8 + cloud * 0.8).clamp(0.0, 255.0)
    end

    # Ink darkness accumulator [0.0 = dry paper, 1.0+ = deep sumi-e ink]
    ink_map = Array.new(IMG_W * IMG_H, 0.0)

    stamp_ink = lambda do |cx, cy, radius, density|
      r_ceil = radius.ceil
      x0 = [0, (cx - r_ceil).floor].max
      x1 = [IMG_W - 1, (cx + r_ceil).ceil].min
      y0 = [0, (cy - r_ceil).floor].max
      y1 = [IMG_H - 1, (cy + r_ceil).ceil].min
      inv_r2 = 1.0 / [0.25, radius * radius].max

      (y0..y1).each do |py|
        dy = py - cy
        dy2 = dy * dy
        row_offset = py * IMG_W
        (x0..x1).each do |px|
          dx = px - cx
          d2 = dx * dx + dy2
          next if d2 > radius * radius * 1.35

          falloff = Math.exp(-d2 * inv_r2 * 1.45)
          # Slight bristle feathering
          feathered = falloff * (0.82 + 0.28 * Math.sin(px * 0.37 + py * 0.29))
          idx = row_offset + px
          ink_map[idx] += density * feathered
        end
      end
    end

    # Compute phase-space bounds (x vs vx) for centered framing
    all_pts = @phase_trails.flatten(1)
    xs = all_pts.map { |p| p[0] }
    vxs = all_pts.map { |p| p[1] }
    min_x, max_x = xs.minmax
    min_vx, max_vx = vxs.minmax
    span_x = [1e-4, max_x - min_x].max
    span_vx = [1e-4, max_vx - min_vx].max

    margin = 130.0
    usable_w = IMG_W - 2.0 * margin
    usable_h = IMG_H - 2.0 * margin

    to_screen = lambda do |x_val, vx_val|
      sx = margin + ((x_val - min_x) / span_x) * usable_w
      sy = IMG_H - margin - ((vx_val - min_vx) / span_vx) * usable_h
      [sx, sy]
    end

    # Draw phase-space trajectories with variable brush width + weeping ink drips
    @phase_trails.each_with_index do |trail, b_idx|
      body_ink_scale = [0.95, 1.08, 0.88][b_idx]
      prev_sx = nil
      prev_sy = nil

      trail.each_with_index do |pt, idx|
        x_val, vx_val, _y_val, _vy_val, speed, acc, _t = pt
        sx, sy = to_screen.call(x_val, vx_val)

        if prev_sx && prev_sy
          dist = Math.hypot(sx - prev_sx, sy - prev_sy)
          steps = [1, (dist / 2.2).ceil].max
          # Brush widens on high acceleration / tight curves, thins on fast sweeps
          brush_r = (2.2 + 5.5 * Math.tanh(acc * 0.22) - 1.2 * Math.tanh(speed * 0.4)).clamp(1.3, 9.5)
          density = (0.045 + 0.075 * Math.tanh(speed * 0.5)) * body_ink_scale

          (1..steps).each do |s|
            frac = s.to_f / steps
            ix = prev_sx + (sx - prev_sx) * frac + (rng.call - 0.5) * 0.8
            iy = prev_sy + (sy - prev_sy) * frac + (rng.call - 0.5) * 0.8
            stamp_ink.call(ix, iy, brush_r, density)
          end

          # Weeping calligraphy drips: gravity pulls ink downward from heavy/slow-turning points
          if idx % 9 == 0 && (acc > 0.8 || rng.call < 0.22)
            drip_len = (18.0 + 75.0 * rng.call * Math.tanh(acc * 0.4 + 0.2)).clamp(12.0, 110.0)
            drip_steps = (drip_len / 2.5).to_i
            sway_freq = 0.06 + rng.call * 0.08
            sway_amp = 1.2 + rng.call * 2.5

            drip_steps.times do |d|
              df = d.to_f / [1, drip_steps - 1].max
              dy = sy + d * 2.5
              break if dy >= IMG_H - 20

              dx = sx + Math.sin(d * sway_freq + b_idx) * sway_amp * df
              drip_r = (brush_r * 0.65 * (1.0 - 0.65 * df)).clamp(0.7, 5.0)
              drip_dens = 0.032 * (1.0 - 0.75 * df) * body_ink_scale
              stamp_ink.call(dx, dy, drip_r, drip_dens)
            end
          end
        end

        prev_sx = sx
        prev_sy = sy
      end
    end

    # Gentle horizontal & vertical ink-wash bleed pass (sumi-e water diffusion)
    bleed_buf = ink_map.dup
    (1...(IMG_H - 1)).each do |y|
      row = y * IMG_W
      (1...(IMG_W - 1)).each do |x|
        idx = row + x
        center = ink_map[idx]
        next if center < 0.02

        neighbor_avg = 0.25 * (
          ink_map[idx - 1] + ink_map[idx + 1] +
          ink_map[idx - IMG_W] + ink_map[idx + IMG_W]
        )
        # Slightly stronger downward wash bleed
        down_bleed = 0.04 * ink_map[idx - IMG_W]
        bleed_buf[idx] = center * 0.86 + neighbor_avg * 0.10 + down_bleed
      end
    end

    # Composite sumi-e ink onto rice paper
    (IMG_W * IMG_H).times do |i|
      k = Math.tanh(bleed_buf[i] * 1.15)
      canvas_r[i] = (canvas_r[i] * (1.0 - k) + 14.0 * k).clamp(0.0, 255.0)
      canvas_g[i] = (canvas_g[i] * (1.0 - k) + 15.0 * k).clamp(0.0, 255.0)
      canvas_b[i] = (canvas_b[i] * (1.0 - k) + 18.0 * k).clamp(0.0, 255.0)
    end

    # Add a small vermilion artist seal in the lower-right corner
    seal_x0 = IMG_W - 115
    seal_y0 = IMG_H - 115
    seal_size = 46
    (seal_y0...(seal_y0 + seal_size)).each do |y|
      (seal_x0...(seal_x0 + seal_size)).each do |x|
        border = (x - seal_x0) < 4 || (seal_x0 + seal_size - 1 - x) < 4 ||
                 (y - seal_y0) < 4 || (seal_y0 + seal_size - 1 - y) < 4
        inner_motif = ((x - seal_x0) / 8 + (y - seal_y0) / 8) % 2 == 0 &&
                      (x - seal_x0).between?(10, seal_size - 11) &&
                      (y - seal_y0).between?(10, seal_size - 11)
        if border || inner_motif
          idx = y * IMG_W + x
          canvas_r[idx] = 198.0
          canvas_g[idx] = 44.0
          canvas_b[idx] = 36.0
        end
      end
    end

    rgb_bytes = String.new(capacity: IMG_W * IMG_H * 3)
    (IMG_W * IMG_H).times do |i|
      rgb_bytes << [canvas_r[i].round, canvas_g[i].round, canvas_b[i].round].pack('C3')
    end

    File.binwrite(filename, "P6\n#{IMG_W} #{IMG_H}\n255\n" + rgb_bytes)
  end
end

symphony = ThreeBodySymphony.new
symphony.simulate!
symphony.render_wav('three_body_symphony.wav')
symphony.render_calligraphy('weeping_calligraphy.ppm')