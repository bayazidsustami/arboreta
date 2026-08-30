# Bioluminescent Fungi Terminal Map & Ambient Simulator
# Models fungal spore germination, glowing hyphae growth, decay,
# and atmospheric/ambient noise translation in pure ANSI Terminal Ruby.

STDOUT.sync = true

class FungalLightPollutionMap
  PALETTE = [
    "\e[38;2;10;25;20m",   # Deep substrate shadow
    "\e[38;2;20;50;35m",   # Dormant spore / Mycelial thread
    "\e[38;2;40;110;60m",  # Early germination glow
    "\e[38;2;80;190;90m",  # Active luciferin reaction
    "\e[38;2;140;240;120m",# Peak bioluminescence
    "\e[38;2;220;255;180m"# Blinding light pollution / Spore burst
  ].freeze
  
  CHARS = [' ', '.', ':', '*', 'o', 'O', '@', '#'].freeze
  RESET = "\e[0m"

  def initialize
    @width, @height = termsz
    @energy = Array.new(@height) { Array.new(@width, 0.0) }
    @spores = Array.new(@height) { Array.new(@width, 0.0) }
    @time = 0.0
    
    # Hide cursor & clear screen
    print "\e[?25l\e[2J"
  end

  def termsz
    h, w = `stty size 2>/dev/null`.split.map(&:to_i)
    [w.zero? ? 80 : w, h.zero? ? 24 : h - 1]
  end

  # Simulates real-time microphone/ambient sound waves via multi-octave synthesis
  def sample_ambient_noise
    base = Math.sin(@time * 1.5) * 0.4 + Math.cos(@time * 0.7) * 0.3
    transient = (rand < 0.08) ? rand * 0.9 : 0.0
    ((base + transient + 0.7) / 1.7).clamp(0.0, 1.0)
  end

  # Enzymatic bioluminescence decay governed by fungal energy consumption
  def bioluminescent_life_cycle(val, ambient_noise, x, y)
    # Enzymatic reaction rate influenced by temperature/ambient noise
    decay_rate = 0.03 + (0.04 * (1.0 - ambient_noise))
    luciferin_regen = 0.015 * Math.sin(@time * 2.0 + x * 0.1 + y * 0.1).abs

    # Spore growth spreads energy into adjacent hyphae
    new_val = val * (1.0 - decay_rate) + luciferin_regen
    
    # Spontaneous fungal bloom triggered by ambient noise peaks
    if ambient_noise > 0.65 && rand < (ambient_noise * 0.05)
      new_val += rand * 0.8
    end

    new_val.clamp(0.0, 1.0)
  end

  def update
    @time += 0.08
    noise = sample_ambient_noise
    next_energy = Array.new(@height) { Array.new(@width, 0.0) }

    @height.times do |y|
      @width.times do |x|
        # Diffusion/cellular growth into neighboring coordinates
        left  = @energy[y][(x - 1) % @width]
        right = @energy[y][(x + 1) % @width]
        up    = @energy[(y - 1) % @height][x]
        down  = @energy[(y + 1) % @height][x]
        
        diffused = (left + right + up + down) * 0.08
        current = @energy[y][x] + diffused
        
        next_energy[y][x] = bioluminescent_life_cycle(current, noise, x, y)
      end
    end

    @energy = next_energy
  end

  def render
    buffer = "\e[H" # Reset cursor to top-left corner
    
    @height.times do |y|
      @width.times do |x|
        val = @energy[y][x]
        p_idx = (val * (PALETTE.size - 1)).floor
        c_idx = (val * (CHARS.size - 1)).floor
        
        color = PALETTE[p_idx] || PALETTE.first
        char  = CHARS[c_idx] || CHARS.first
        
        buffer << "#{color}#{char}"
      end
      buffer << "\n"
    end

    print buffer + RESET
  end

  def run
    trap("INT") do
      print "\e[?25h\e[2J\e[H"
      puts "\e[32m[Fungal Light Pollution Map Terminated]\e[0m"
      exit
    end

    loop do
      update
      render
      sleep 0.033 # ~30 FPS
    end
  end
end

FungalLightPollutionMap.new.run