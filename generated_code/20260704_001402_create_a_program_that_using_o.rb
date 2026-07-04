#!/usr/bin/env ruby
# 🎶🌀 Self‑modifying audio‑visual Ruby demo ---------------------------------
# The script reads its own source, turns each Unicode character into a tone,
# and draws a kaleidoscopic fractal in the terminal.  Memory usage drives the
# tempo and colour.  After each pass the script rewrites itself, adding a tiny
# marker so the next run is slightly different (self‑modifying).

require 'io/console'
require 'objspace'

# -------------------------------------------------------------------------
# Helpers
def freq_from_char(ch)
  # Map codepoint (0‑0x10FFFF) to audible range 200‑2000 Hz
  ((ch.ord % 1800) + 200).to_f
end

def duration_from_mem(mem)
  # Faster tempo (shorter notes) when memory usage is high
  base = 0.15
  factor = [1.0, mem / (1024.0 * 1024)].max # scale >1 MiB
  base / factor
end

def play_tone(freq, dur)
  # Use the system 'play' command from SoX if available; otherwise no‑op.
  system("play -n synth #{dur.round(3)} sin #{freq.round(2)} > /dev/null 2>&1")
end

def fractal(lines, depth, max_depth, color)
  return if depth > max_depth
  size = 2 ** (max_depth - depth)
  pattern = Array.new(size) { |i| " " * i + "*" + " " * (size - i - 1) }
  pattern.each do |row|
    puts "\e[38;5;#{color}m#{row}\e[0m"
  end
  sleep(0.02)
  fractal(lines, depth + 1, max_depth, (color + 3) % 256)
end

def memory_usage
  # Approximate live objects size in bytes
  ObjectSpace.memsize_of_all / 1024.0 # KiB
end

# -------------------------------------------------------------------------
# Main loop – read source, emit sound, draw fractal
source = File.read(__FILE__)
source.each_char do |ch|
  mem = memory_usage
  freq = freq_from_char(ch)
  dur  = duration_from_mem(mem)
  play_tone(freq, dur)

  # Colour shifts with memory usage; 30‑215 is a pleasant range.
  colour = 30 + ((mem / 10).to_i % 186)
  fractal([], 0, 4, colour)
end

# -------------------------------------------------------------------------
# Self‑modification: append a tiny comment indicating another pass.
marker = "# 🎵 Pass #{Time.now.to_i}\n"
File.open(__FILE__, 'a') { |f| f.write(marker) }

# End of script. Enjoy the music and the ever‑changing fractal!