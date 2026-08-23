# Ambient Memory Soundscape
# Generates audio PCM directly to stdout by reading system memory usage.
# Pipe to an audio player: ruby soundscape.rb | aplay -f U8 -r 8000
# or on macOS: ruby soundscape.rb | sox -t raw -r 8000 -b 8 -c 1 -e unsigned-integer - -d

STDOUT.binmode

def get_memory_usage
  case RUBY_PLATFORM
  when /darwin/
    `ps -o rss= -p #{Process.pid}`.to_i rescue 10000
  when /linux/
    File.read('/proc/meminfo').match(/MemAvailable:\s+(\d+)/)&.captures&.first&.to_i rescue 10000
  else
    (GC.stat(:heap_live_slots) || 10000)
  end
end

sample_rate = 8000
t = 0
prev_mem = get_memory_usage
smoothed_delta = 0

loop do
  t += 1
  
  # Sample memory state periodically
  if t % 800 == 0
    current_mem = get_memory_usage
    delta = current_mem - prev_mem
    prev_mem = current_mem
    # Smooth the memory delta to control overtone intensity and bass drops
    smoothed_delta = (smoothed_delta * 0.7) + (delta * 0.3)
  end

  # Base ambient drones
  drone1 = Math.sin(t * 0.015) * 40
  drone2 = Math.cos(t * 0.022) * 30

  # Memory leak detection -> Harmonic overtones (rising frequencies with positive delta)
  leak_intensity = [smoothed_delta, 0].max
  overtone_freq = 0.05 + (leak_intensity * 0.0001)
  overtone = Math.sin(t * overtone_freq) * [leak_intensity * 0.05, 50].min

  # Garbage Collection detection -> Rhythmic bass drop (triggered by negative delta / dropped memory)
  gc_drop = [ -smoothed_delta, 0 ].max
  bass_kick = 0
  if gc_drop > 100
    sub_freq = [0.08 - ((t % 400) * 0.0002), 0.01].max
    bass_kick = Math.sin(t * sub_freq) * [gc_drop * 0.2, 100].min
  end

  # Mix channels into an 8-bit unsigned PCM byte (0-255)
  sample = 128 + drone1 + drone2 + overtone + bass_kick
  sample = [[sample, 0].max, 255].min.to_i

  STDOUT.putc(sample)
  sleep(1.0 / sample_rate) if t % 100 == 0 # Soft pacing check
end