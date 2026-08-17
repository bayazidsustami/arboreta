# Ruby Image-to-Audio Spectrogram Synthesizer & Color Palette Composer
# Compiles an image into a WAV audio file where:
# 1. Image features appear in high-frequency spectrogram analysis (1200 Hz - 7200 Hz).
# 2. Color palette generates a low-frequency ambient chord progression (130 Hz - 600 Hz).

# --- 1. BMP Image I/O & Generator ---

def create_sample_bmp(filename, width = 64, height = 64)
  # Creates a colorful geometric BMP image if no input image is provided
  row_padding = (4 - (width * 3) % 4) % 4
  pixel_rows = []

  height.times do |y|
    row = []
    width.times do |x|
      nx, ny = x.to_f / width, y.to_f / height
      dist = Math.sqrt((nx - 0.5)**2 + (ny - 0.5)**2)

      # Color palette gradients (RGB)
      r = ((Math.sin(nx * Math::PI * 2) + 1) * 127).to_i
      g = ((Math.cos(ny * Math::PI * 2) + 1) * 127).to_i
      b = (dist < 0.35) ? 240 : 60

      # Bright geometric pattern for spectrogram reconstruction
      if dist < 0.22 || (nx - ny).abs < 0.06 || (nx + ny - 1.0).abs < 0.06
        r, g, b = 255, 220, 120
      end

      row << [b, g, r].pack('C3') # BMP pixel format: BGR
    end
    row << ("\x00" * row_padding) if row_padding > 0
    pixel_rows << row.join
  end

  pixel_data = pixel_rows.join
  file_size = 54 + pixel_data.bytesize
  header = [
    "BM", file_size, 0, 54, 40,
    width, height, 1, 24, 0,
    pixel_data.bytesize, 2835, 2835, 0, 0
  ].pack("a2V3V2v2V6")

  File.binwrite(filename, header + pixel_data)
end

def read_bmp(filename)
  data = File.binread(filename)
  return nil unless data[0..1] == 'BM'

  offset = data[10..13].unpack1('V')
  width  = data[18..21].unpack1('V')
  height = data[22..25].unpack1('V')
  bpp    = data[28..29].unpack1('v')
  return nil unless bpp == 24

  h_abs = height.abs
  row_padding = (4 - (width * 3) % 4) % 4
  pixels = Array.new(h_abs) { Array.new(width) }

  pos = offset
  h_abs.times do |y|
    row_idx = height > 0 ? (h_abs - 1 - y) : y # BMP bottom-to-top mapping
    width.times do |x|
      b, g, r = data[pos, 3].unpack('C3')
      pixels[row_idx][x] = [r, g, b]
      pos += 3
    end
    pos += row_padding
  end
  [width, h_abs, pixels]
end

def resample_image(pixels, target_w, target_h)
  # Downsamples image matrix for efficient audio additive synthesis
  orig_h, orig_w = pixels.size, pixels[0].size
  Array.new(target_h) do |ty|
    sy = (ty.to_f / target_h * orig_h).to_i.clamp(0, orig_h - 1)
    Array.new(target_w) do |tx|
      sx = (tx.to_f / target_w * orig_w).to_i.clamp(0, orig_w - 1)
      pixels[sy][sx]
    end
  end
end

# --- 2. Color Palette to Ambient Music Mapper ---

def rgb_to_hsv(r, g, b)
  r, g, b = r / 255.0, g / 255.0, b / 255.0
  max, min = [r, g, b].max, [r, g, b].min
  delta = max - min
  h = if delta.zero?
        0
      elsif max == r
        60 * (((g - b) / delta) % 6)
      elsif max == g
        60 * (((b - r) / delta) + 2)
      else
        60 * (((r - g) / delta) + 4)
      end
  s = max.zero? ? 0 : delta / max
  [h, s, max]
end

# Ambient Pentatonic Scale (Hz): C3, D3, E3, G3, A3, C4, D4, E4
AMBIENT_SCALE = [130.81, 146.83, 164.81, 196.00, 220.00, 261.63, 293.66, 329.63].freeze

def generate_chords_from_palette(pixels, num_chords)
  height, width = pixels.size, pixels[0].size
  chords = []

  num_chords.times do |k|
    x_start = (k * width / num_chords.to_f).round
    x_end   = (((k + 1) * width / num_chords.to_f).round - 1).clamp(0, width - 1)

    r_sum = g_sum = b_sum = count = 0
    height.times do |y|
      (x_start..x_end).each do |x|
        r, g, b = pixels[y][x]
        r_sum += r; g_sum += g; b_sum += b
        count += 1
      end
    end

    hue, sat, val = rgb_to_hsv(r_sum / count, g_sum / count, b_sum / count)
    root_idx = ((hue / 360.0) * AMBIENT_SCALE.size).to_i % AMBIENT_SCALE.size
    root_freq = AMBIENT_SCALE[root_idx]

    # Saturation determines chord color (Maj7, Min7, Sus2)
    intervals = if sat > 0.45
                  [1.0, 1.25, 1.5, 1.875]   # Major 7th
                elsif sat > 0.2
                  [1.0, 1.2, 1.5, 1.777]    # Minor 7th
                else
                  [1.0, 1.125, 1.5, 1.6875] # Sus2 / Soft
                end

    chord_freqs = intervals.map { |r| root_freq * r }
    chords << { freqs: chord_freqs, volume: 0.15 + (val * 0.15) }
  end
  chords
end

# --- 3. Audio Synthesis & WAV Exporter ---

def synthesize_audio(pixels, duration_sec = 8.0, sample_rate = 44100)
  height, width = pixels.size, pixels[0].size
  total_samples = (sample_rate * duration_sec).to_i
  buffer = Array.new(total_samples, 0.0)

  # Precompute logarithmically spaced frequencies (1200 Hz - 7200 Hz) for spectrogram rows
  f_min, f_max = 1200.0, 7200.0
  row_freqs = Array.new(height) do |y|
    f_min * ((f_max / f_min) ** ((height - 1 - y).to_f / (height - 1)))
  end

  # Precompute normalized image luminance matrix
  luminance = Array.new(height) do |y|
    Array.new(width) do |x|
      r, g, b = pixels[y][x]
      (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    end
  end

  num_chords = 4
  chords = generate_chords_from_palette(pixels, num_chords)
  samples_per_chord = total_samples.to_f / num_chords

  # Audio rendering loop
  total_samples.times do |i|
    t = i.to_f / sample_rate
    col = [(t / duration_sec * width).to_i, width - 1].min

    # 1. Spectrogram Image Reconstruction (High Frequencies)
    spec_val = 0.0
    height.times do |y|
      lum = luminance[y][col]
      next if lum < 0.03 # Skip dark pixels

      f = row_freqs[y]
      spec_val += lum * Math.sin(2.0 * Math::PI * f * t)
    end

    # 2. Ambient Chord Progression (Low Frequencies)
    chord_idx = [(i / samples_per_chord).to_i, num_chords - 1].min
    chord = chords[chord_idx]

    # Smooth chord crossfade envelope
    pos_in_chord = (i % samples_per_chord) / samples_per_chord
    env = 0.5 * (1.0 - Math.cos(2.0 * Math::PI * pos_in_chord))

    chord_val = 0.0
    chord[:freqs].each do |f|
      # Layer fundamental, detuned warmth oscillator, and sub-octave bass
      chord_val += Math.sin(2.0 * Math::PI * f * t)
      chord_val += 0.3 * Math.sin(2.0 * Math::PI * (f * 1.0025) * t)
      chord_val += 0.4 * Math.sin(2.0 * Math::PI * (f * 0.5) * t)
    end

    buffer[i] = (spec_val * 0.08) + (chord_val * chord[:volume] * env)
  end

  # Normalize audio signal to prevent clipping
  max_amp = buffer.map(&:abs).max
  max_amp = 1.0 if max_amp.zero?
  buffer.map { |s| (s / max_amp * 0.95) }
end

def save_wav(filename, samples, sample_rate = 44100)
  data_size = samples.size * 2
  file_size = 36 + data_size

  # Standard RIFF WAV header
  header = [
    "RIFF", file_size, "WAVE", "fmt ",
    16, 1, 1, sample_rate, sample_rate * 2, 2, 16,
    "data", data_size
  ].pack("a4Va4a4VvvVVvva4V")

  pcm_data = samples.map do |s|
    (s * 32767.0).clamp(-32768, 32767).to_i
  end.pack("s<*")

  File.binwrite(filename, header + pcm_data)
end

# --- 4. Main Execution ---

input_file = ARGV[0] || 'input_image.bmp'
output_file = 'output_spectrogram_ambient.wav'

unless File.exist?(input_file)
  puts "No input file specified. Generating sample image: '#{input_file}'..."
  create_sample_bmp(input_file, 64, 64)
end

puts "Reading image '#{input_file}'..."
w, h, pixels = read_bmp(input_file)

if pixels.nil?
  puts "Error: Unsupported image format. Please supply a 24-bit uncompressed BMP file."
  exit 1
end

# Resample image matrix for optimal frequency resolution and synthesis speed
resampled_pixels = resample_image(pixels, 64, 48)

puts "Synthesizing audio (Spectrogram image painting + Color palette ambient chords)..."
audio_samples = synthesize_audio(resampled_pixels, 8.0, 44100)

puts "Exporting WAV audio to '#{output_file}'..."
save_wav(output_file, audio_samples, 44100)

puts "Done! Play '#{output_file}' in a spectrogram viewer (e.g., Audacity) to see the original image reconstructed in the 1.2 kHz - 7.2 kHz range."