# Self-reading Ruby Audio-Visual Synthesizer
# Converts its own binary byte structure into a real-time ambient drone and reactive ASCII fractal canvas.

require 'io/console'

# 1. Ingest self-executable byte structure
BYTES = File.binread(__FILE__).bytes
SIZE  = BYTES.size

# Terminal view dimensions
ROWS, COLS = 28, 80

# 2. Setup cross-platform audio pipe (APlay for Linux, FFplay, or silent fallback)
audio_cmd = if system('which aplay > /dev/null 2>&1')
  'aplay -q -f U8 -r 11025 2>/dev/null'
elsif system('which ffplay > /dev/null 2>&1')
  'ffplay -nodisp -f u8 -ar 11025 -i pipe:0 -loglevel quiet'
end

audio_pipe = audio_cmd ? IO.popen(audio_cmd, 'w') : nil
$stdout.sync = true

# Prepare terminal screen (clear screen, hide cursor)
print "\e[2J\e[?25l"

# Graceful cleanup on exit
at_exit do
  print "\e[?25h\e[0m\e[2J"
  audio_pipe&.close
end

# Palette for ASCII fractal density
RAMP = " .:-=+*#%@"
PALETTE_LEN = RAMP.length

t = 0

# 3. Main Audio-Visual Synthesis Engine
loop do
  # Extract dynamic modulators from byte structure offsets
  b_pitch1 = BYTES[t % SIZE]
  b_pitch2 = BYTES[(t * 13) % SIZE]
  b_mod    = BYTES[(t * 31) % SIZE] / 255.0

  cx = (b_pitch1 / 255.0 - 0.5) * 1.5
  cy = (b_pitch2 / 255.0 - 0.5) * 1.5
  zoom = 1.0 + Math.sin(t * 0.04) * 0.4

  # Build Reactive ASCII Julia Fractal Frame
  frame = String.new
  ROWS.times do |r|
    y = ((r - ROWS / 2.0) / (ROWS / 2.0)) * zoom + cy
    COLS.times do |c|
      x = ((c - COLS / 2.0) / (COLS / 4.0)) * zoom + cx
      zx, zy = x, y
      iter = 0
      
      12.times do
        break if zx * zx + zy * zy > 4.0
        zx, zy = zx * zx - zy * zy + cx, 2.0 * zx * zy + cy
        iter += 1
      end

      # Blend fractal iteration count with local binary byte structure
      byte_val = BYTES[(r * COLS + c + t) % SIZE]
      shade_idx = ((iter * 2 + byte_val % 4) * b_mod).to_i % PALETTE_LEN
      frame << RAMP[shade_idx]
    end
    frame << "\n"
  end

  # Render ASCII Canvas
  print "\e[H" + frame

  # Generate 128 raw audio samples per frame driven by executable byte harmonies
  if audio_pipe
    audio_buffer = String.new(encoding: 'ASCII-8BIT')
    128.times do |i|
      sample_idx = t * 128 + i
      
      # Polyphonic ambient drone synthesized directly from file bytes
      f1 = (BYTES[sample_idx % SIZE] % 24 + 36) * 2.0
      f2 = (BYTES[(sample_idx * 3) % SIZE] % 24 + 48) * 1.5
      
      wave1 = Math.sin(sample_idx * f1 * 0.0005)
      wave2 = Math.sin(sample_idx * f2 * 0.0007)
      sub   = Math.sin(sample_idx * 55.0 * 0.0005) * 0.5
      
      sample_byte = ((wave1 + wave2 + sub) * 35 + 128).clamp(0, 255).to_i
      audio_buffer << sample_byte.chr
    end

    begin
      audio_pipe.write(audio_buffer)
    rescue Errno::EPIPE
      audio_pipe = nil
    end
  end

  t += 1
  sleep 0.03
end