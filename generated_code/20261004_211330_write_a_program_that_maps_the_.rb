# Pixel Decay & Microtonal Soundscape Generator
# Simulates 1000 recursive JPEG compression cycles and synthesizes a microtonal WAV file.

WIDTH = 64
HEIGHT = 64
CYCLES = 1000
SAMPLE_RATE = 44100

# Initialize synthetic photograph pixel matrix
pixels = HEIGHT.times.map do |y|
  WIDTH.times.map do |x|
    [Math.sin(x.to_f / 4.0) * 127 + 128, Math.cos(y.to_f / 4.0) * 127 + 128, (x ^ y) % 256]
  end
end

# 31-tone equal temperament (31-EDO) microtonal frequency mapping
def microtonal_freq(step)
  440.0 * (2.0 ** (step / 31.0))
end

current_pixels = pixels.map { |row| row.map(&:dup) }
events = []

# Simulate 1000 recursive compression cycles and accumulate artifact energy
CYCLES.times do |i|
  quantization_factor = 1 + (i / 50)
  artifact_energy = 0.0

  current_pixels = current_pixels.map do |row|
    row.map do |px|
      new_px = px.map { |c| ((c / (quantization_factor * 2.0)).round * (quantization_factor * 2.0)).clamp(0, 255) }
      diff = px.zip(new_px).sum { |a, b| (a - b).abs }
      artifact_energy += diff
      new_px
    end
  end

  # Trigger microtonal chime on significant decay phase shifts
  if artifact_energy > (WIDTH * HEIGHT * 1.5) / (1.0 + i * 0.005)
    pitch_step = (artifact_energy.to_i % 62) - 31
    freq = microtonal_freq(pitch_step)
    amplitude = [(artifact_energy / (WIDTH * HEIGHT * 255.0)), 1.0].min
    events << { freq: freq, amp: amplitude, cycle: i }
  end
end

# Synthesize audio samples for the generated events
duration_per_event = 0.2
total_duration = [CYCLES * 0.01, events.length * 0.04].max
num_samples = (SAMPLE_RATE * total_duration).to_i
samples = Array.new(num_samples, 0.0)

events.each_with_index do |ev, idx|
  start_sample = (idx * (SAMPLE_RATE * 0.015)).to_i
  event_samples = (SAMPLE_RATE * duration_per_event).to_i
  
  event_samples.times do |s|
    t = s.to_f / SAMPLE_RATE
    env = Math.exp(-t * 12.0) # exponential acoustic decay envelope
    sample_val = ev[:amp] * env * Math.sin(2 * Math.PI * ev[:freq] * t)
    target_idx = start_sample + s
    if target_idx < num_samples
      samples[target_idx] += sample_val
    end
  end
end

# Normalize and convert samples to 16-bit PCM integer format
max_val = samples.map(&:abs).max
max_val = 1.0 if max_val == 0
samples = samples.map { |s| (s / max_val * 32767).clamp(-32768, 32767).to_i }

# Write out a valid PCM WAV file
wav_filename = "pixel_decay_soundscape.wav"
File.open(wav_filename, "wb") do |f|
  f.write("RIFF")
  f.write([36 + samples.length * 2].pack("V"))
  f.write("WAVE")
  f.write("fmt ")
  f.write([16].pack("V"))
  f.write([1].pack("v"))
  f.write([1].pack("v"))
  f.write([SAMPLE_RATE].pack("V"))
  f.write([SAMPLE_RATE * 2].pack("V"))
  f.write([2].pack("v"))
  f.write([16].pack("v"))
  f.write("data")
  f.write([samples.length * 2].pack("V"))
  f.write(samples.pack("v*"))
end

puts "Generated microtonal soundscape: #{wav_filename} (#{events.size} artifact chimes synthesized across #{CYCLES} compression cycles)."