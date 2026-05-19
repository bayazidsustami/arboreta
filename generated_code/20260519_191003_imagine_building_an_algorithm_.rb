require 'wavefile'   # gem install wavefile
require 'chunky_png' # gem install chunky_png

# ----------------------------------------------------------------------
# Settings
# ----------------------------------------------------------------------
SAMPLE_RATE = 44_100
DURATION_PER_NOTE = 0.5 # seconds
VOLUME = 0.3

# Simple haunting lullaby: frequencies (Hz)
MELODY = [261.63, 246.94, 220.00, 196.00, 220.00, 246.94, 261.63] # C4, B3, A3, G3, A3, B3, C4

# Fractal river dimensions
IMG_SIZE = 512
MAX_ITER = 100

# ----------------------------------------------------------------------
# Generate audio buffer (sine wave for each note)
# ----------------------------------------------------------------------
samples = []

MELODY.each do |freq|
  (SAMPLE_RATE * DURATION_PER_NOTE).to_i.times do |i|
    t = i.to_f / SAMPLE_RATE
    # Simple sine wave with slight vibrato to simulate "haunting"
    vibrato = Math.sin(2 * Math::PI * 5 * t) * 0.005
    sample = Math.sin(2 * Math::PI * (freq + vibrato) * t) * VOLUME
    samples << (sample * 32_767).to_i
  end
end

# ----------------------------------------------------------------------
# Write WAV file
# ----------------------------------------------------------------------
WaveFile::Writer.new('lullaby.wav', WaveFile::Format.new(:mono, :pcm_16, SAMPLE_RATE)) do |writer|
  buffer = WaveFile::Buffer.new(samples, WaveFile::Format.new(:mono, :pcm_16, SAMPLE_RATE))
  writer.write(buffer)
end

# ----------------------------------------------------------------------
# Map melody to tectonic plate displacements (simple 2D height map)
# ----------------------------------------------------------------------
height_map = Array.new(IMG_SIZE) { Array.new(IMG_SIZE, 0) }

MELODY.each_with_index do |freq, idx|
  # Normalise frequency to [0,1]
  norm = (freq - MELODY.min) / (MELODY.max - MELODY.min)
  # Determine a circular "plate" radius based on note index
  radius = (IMG_SIZE / 6) + idx * 10
  center_x = IMG_SIZE / 2 + Math.sin(idx) * 50
  center_y = IMG_SIZE / 2 + Math.cos(idx) * 50

  IMG_SIZE.times do |y|
    IMG_SIZE.times do |x|
      dx = x - center_x
      dy = y - center_y
      dist = Math.sqrt(dx * dx + dy * dy)
      next if dist > radius
      # Height contribution falls off with distance
      contribution = ((radius - dist) / radius) * norm * 255
      height_map[y][x] += contribution
    end
  end
end

# ----------------------------------------------------------------------
# Generate fractal river based on height map (Mandelbrot-like)
# ----------------------------------------------------------------------
png = ChunkyPNG::Image.new(IMG_SIZE, IMG_SIZE, ChunkyPNG::Color::WHITE)

IMG_SIZE.times do |py|
  IMG_SIZE.times do |px|
    # Use height as seed for complex coordinate
    cx = (px - IMG_SIZE / 2.0) / (IMG_SIZE / 4.0) * (height_map[py][px] / 255.0)
    cy = (py - IMG_SIZE / 2.0) / (IMG_SIZE / 4.0) * (height_map[py][px] / 255.0)

    x = 0.0
    y = 0.0
    iter = 0

    while x*x + y*y <= 4 && iter < MAX_ITER
      xtemp = x*x - y*y + cx
      y = 2*x*y + cy
      x = xtemp
      iter += 1
    end

    # Color based on iteration count, creating a river-like gradient
    hue = (iter * 360 / MAX_ITER) % 360
    sat = 0.7
    val = iter < MAX_ITER ? 0.9 : 0.0

    # Convert HSV to RGB
    c = ChunkyPNG::Color.from_hsv(hue, sat, val)
    png[px, py] = c
  end
end

png.save('tectonic_river.png')

# ----------------------------------------------------------------------
# End of script: produces 'lullaby.wav' and a generative fractal image
# ----------------------------------------------------------------------