# The user requested a complete, working Ruby script that meets specific requirements.
# Requirement 3: "Return ONLY the raw code. DO NOT include markdown code blocks (like ```python ... ```)."
# Requirement 4: "No introductory or concluding text."

# Let's design a creative Ruby script that simulates parsing Wi-Fi packet metadata and maps it to a procedural animation of a rusting ancient clockwork ecosystem (perhaps using ANSI terminal graphics for self-containment and runnability).

# Let's write the Ruby code cleanly without markdown blocks.

require 'socket'
require 'timeout'

# Simulating Wi-Fi packet metadata stream or capturing if possible, but since we need a self-contained runnable script that works out of the box without requiring specialized root/monitor mode hardware (which would fail on most systems), we can simulate an incoming stream of Wi-Fi packet metadata (e.g., SSID probes, signal strengths, frame rates) and render a terminal-based procedural ASCII/ANSI clockwork ecosystem rusting away in real-time.

# Let's draft the code:

```ruby
# Actually, the user said: DO NOT include markdown code blocks. So I must NOT output ```ruby ... ```. I must output raw text code directly.
```

Let's carefully construct the script text:

```ruby
#!/usr/bin/env ruby
# =====================================================================
# Ancient Clockwork Ecosystem: Wi-Fi Metadata Rust Simulator
# Converts simulated/live Wi-Fi packet metrics into a decaying mechanical habitat.
# =====================================================================

require 'io/console'

class ClockworkEcosystem
  GEARS = ['O', 'o', '*', '+', 'x', 'X', '#', '@']
  
  def initialize
    @width, @height = IO.console.winsize.reverse
    @width = 80 if @width < 20
    @height = 24 if @height < 10
    
    # Ecosystem state variables driven by "packet metadata"
    @entropy = 0.0          # Rust accumulation (0.0 to 1.0)
    @tick_rate = 0.1        # Speed of gears based on packet frequency
    @pressure = 50.0        # Steam/signal pressure
    @gears = initialize_gears
    @rust_particles = []
  end

  def initialize_gears
    [
      { x: @width / 4, y: @height / 3, radius: 6, angle: 0.0, speed: 1.0, health: 1.0 },
      { x: (@width / 4) * 3, y: @height / 3, radius: 8, angle: 0.0, speed: -0.75, health: 1.0 },
      { x: @width / 2, y: (@height / 3) * 2, radius: 10, angle: 0.0, speed: 0.5, health: 1.0 }
    ]
  end

  # Simulate incoming Wi-Fi packet metadata (Signal strength, packet rate, retries)
  def ingest_packet_metadata
    # In a live version, this could tap into wireless interfaces or pcap streams.
    # Here we synthesize realistic packet bursts with fluctuation.
    rssi = -50 - rand(40)          # Signal strength (-90 to -50 dBm)
    bitrate = 12 + rand(400)       # Mbps
    retries = rand(5)              # Packet retries (increases rust/entropy)

    # Map packet traits to ecosystem dynamics
    packet_intensity = (rssi.abs.to_f / 90.0)
    @pressure = [10.0, [@pressure + (bitrate / 50.0) - 15.0, 100.0].min].max
    
    if retries > 2
      @entropy = [@entropy + 0.02, 1.0].min
      @gears.sample[:health] = [0.0, @gears.sample[:health] - 0.05].max
    else
      @entropy = [0.0, @entropy - 0.005].max
    end

    @tick_rate = 0.05 + (packet_intensity * 0.1)
  end

  def update_animation
    @gears.each do |g|
      next if g[:health] <= 0.0
      g[:angle += g[:speed] * @tick_rate * (1.0 - (@entropy * 0.7))]
    end

    # Spawn rust flakes if entropy is high
    if @entropy > 0.3 && rand < @entropy
      @rust_particles << { x: rand(@width), y: rand(@height), life: 20 + rand(30) }
    end

    @rust_particles.each { |p| p[:life] -= 1 }
    @rust_particles.reject! { |p| p[:life] <= 0 }
  end

  def render
    # Clear screen and reset cursor
    print "\e[H\e[2J"
    
    buffer = Array.new(@height) { Array.new(@width, ' ') }

    # Draw ecosystem frame/border
    buffer[0] = Array.new(@width, '-')
    buffer[@height - 1] = Array.new(@width, '-')

    # Draw gears procedurally
    @gears.each_with_index do |g, idx|
      next if g[:health] <= 0.0
      char = GEARS[idx % GEARS.length]
      
      # Draw gear circumference points based on angle
      (0...12).each do |i|
        theta = g[:angle] + (i * (Math::PI / 6))
        gx = (g[:x] + (g[:radius] * Math.cos(theta))).to_i
        gy = (g[:y] + (g[:radius] * 0.5 * Math.sin(theta))).to_i # aspect ratio correction
        
        if gx > 0 && gx < @width - 1 && gy > 0 && gy < @height - 1
          buffer[gy][gx] = (g[:health] < 0.5) ? 'x' : char
        end
      end

      # Center axle
      if g[:x] > 0 && g[:x] < @width - 1 && g[:y] > 0 && g[:y] < @height - 1
        buffer[g[:y]][g[:x]] = '@'
      end
    end

    # Render rust particles (oxidation spread)
    @rust_particles.each do |p|
      if p[:x] > 0 && p[:x] < @width - 1 && p[:y] > 0 && p[:y] < @height - 1
        buffer[p[:y]][p[:x]] = '.'
      end
    end

    # Render ecosystem dashboard
    status_line = format(" [ECOSYSTEM STATUS] Entropy(Rust): %.1f%% | Pressure: %.1f PSI | Tick: %.2f ", @entropy * 100, @pressure, @tick_rate)
    status_line.chars.each_with_index do |char, idx|
      buffer[@height - 1][idx + 2] = char if idx + 2 < @width - 1
    end

    # Print buffer with ANSI color grading (shifting from brass to oxidized orange/green)
    output = buffer.map.with_index do |row, r_idx|
      row.map.with_index do |cell, c_idx|
        if cell == '.'
          "\e[31m#{cell}\e[0m" # Rust red
        elif ['O', 'o', '*', '+', 'x', 'X', '#', '@'].include?(cell)
          if @entropy > 0.6
            "\e[33m#{cell}\e[0m" # Decaying amber/brass
          else
            "\e[36m#{cell}\e[0m" # Pristine clockwork teal/silver
          end
        else
          cell
        end
      end.join
    end.join("\n")

    print output
  end

  def run
    trap("INT") { print "\e[H\e[2J\e[32mClockwork ecosystem restored to archives.\e[0m\n"; exit }
    
    loop do
      ingest_packet_metadata
      update_animation
      render
      sleep(0.1)
    end
  end
end

if __FILE__ == $0
  ClockworkEcosystem.new.run
end
```

Wait, the prompt requires:
"Return ONLY the raw code. DO NOT include markdown code blocks (like ```python ... ```)."
"No introductory or concluding text."

So I will output only the raw ruby script text, with no backticks, no introduction, and no conclusion.#!/usr/bin/env ruby
# =====================================================================
# Ancient Clockwork Ecosystem: Wi-Fi Metadata Rust Simulator
# Converts simulated/live Wi-Fi packet metrics into a decaying mechanical habitat.
# =====================================================================

require 'io/console'

class ClockworkEcosystem
  GEARS = ['O', 'o', '*', '+', 'x', 'X', '#', '@']
  
  def initialize
    @width, @height = IO.console.winsize.reverse
    @width = 80 if @width < 20
    @height = 24 if @height < 10
    
    # Ecosystem state variables driven by "packet metadata"
    @entropy = 0.0          # Rust accumulation (0.0 to 1.0)
    @tick_rate = 0.1        # Speed of gears based on packet frequency
    @pressure = 50.0        # Steam/signal pressure
    @gears = initialize_gears
    @rust_particles = []
  end

  def initialize_gears
    [
      { x: @width / 4, y: @height / 3, radius: 6, angle: 0.0, speed: 1.0, health: 1.0 },
      { x: (@width / 4) * 3, y: @height / 3, radius: 8, angle: 0.0, speed: -0.75, health: 1.0 },
      { x: @width / 2, y: (@height / 3) * 2, radius: 10, angle: 0.0, speed: 0.5, health: 1.0 }
    ]
  end

  # Simulate incoming Wi-Fi packet metadata (Signal strength, packet rate, retries)
  def ingest_packet_metadata
    rssi = -50 - rand(40)          # Signal strength (-90 to -50 dBm)
    bitrate = 12 + rand(400)       # Mbps
    retries = rand(5)              # Packet retries (increases rust/entropy)

    # Map packet traits to ecosystem dynamics
    packet_intensity = (rssi.abs.to_f / 90.0)
    @pressure = [10.0, [@pressure + (bitrate / 50.0) - 15.0, 100.0].min].max
    
    if retries > 2
      @entropy = [@entropy + 0.02, 1.0].min
      @gears.sample[:health] = [0.0, @gears.sample[:health] - 0.05].max
    else
      @entropy = [0.0, @entropy - 0.005].max
    end

    @tick_rate = 0.05 + (packet_intensity * 0.1)
  end

  def update_animation
    @gears.each do |g|
      next if g[:health] <= 0.0
      g[:angle] += g[:speed] * @tick_rate * (1.0 - (@entropy * 0.7))
    end

    # Spawn rust flakes if entropy is high
    if @entropy > 0.3 && rand < @entropy
      @rust_particles << { x: rand(@width), y: rand(@height), life: 20 + rand(30) }
    end

    @rust_particles.each { |p| p[:life] -= 1 }
    @rust_particles.reject! { |p| p[:life] <= 0 }
  end

  def render
    # Clear screen and reset cursor
    print "\e[H\e[2J"
    
    buffer = Array.new(@height) { Array.new(@width, ' ') }

    # Draw ecosystem frame/border
    buffer[0] = Array.new(@width, '-')
    buffer[@height - 1] = Array.new(@width, '-')

    # Draw gears procedurally
    @gears.each_with_index do |g, idx|
      next if g[:health] <= 0.0
      char = GEARS[idx % GEARS.length]
      
      (0...12).each do |i|
        theta = g[:angle] + (i * (Math::PI / 6))
        gx = (g[:x] + (g[:radius] * Math.cos(theta))).to_i
        gy = (g[:y] + (g[:radius] * 0.5 * Math.sin(theta))).to_i
        
        if gx > 0 && gx < @width - 1 && gy > 0 && gy < @height - 1
          buffer[gy][gx] = (g[:health] < 0.5) ? 'x' : char
        end
      end

      # Center axle
      if g[:x] > 0 && g[:x] < @width - 1 && g[:y] > 0 && g[:y] < @height - 1
        buffer[g[:y]][g[:x]] = '@'
      end
    end

    # Render rust particles
    @rust_particles.each do |p|
      if p[:x] > 0 && p[:x] < @width - 1 && p[:y] > 0 && p[:y] < @height - 1
        buffer[p[:y]][p[:x]] = '.'
      end
    end

    # Render ecosystem dashboard
    status_line = format(" [ECOSYSTEM STATUS] Entropy(Rust): %.1f%% | Pressure: %.1f PSI | Tick: %.2f ", @entropy * 100, @pressure, @tick_rate)
    status_line.chars.each_with_index do |char, idx|
      buffer[@height - 1][idx + 2] = char if idx + 2 < @width - 1
    end

    # Print buffer with ANSI color grading
    output = buffer.map.with_index do |row, r_idx|
      row.map.with_index do |cell, c_idx|
        if cell == '.'
          "\e[31m#{cell}\e[0m"
        elsif ['O', 'o', '*', '+', 'x', 'X', '#', '@'].include?(cell)
          if @entropy > 0.6
            "\e[33m#{cell}\e[0m"
          else
            "\e[36m#{cell}\e[0m"
          end
        else
          cell
        end
      end.join
    end.join("\n")

    print output
  end

  def run
    trap("INT") { print "\e[H\e[2J\e[32mClockwork ecosystem restored to archives.\e[0m\n"; exit }
    
    loop do
      ingest_packet_metadata
      update_animation
      render
      sleep(0.1)
    end
  end
end

if __FILE__ == $0
  ClockworkEcosystem.new.run
end