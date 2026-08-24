# Real-Time Typographic Landscape Simulator
# Dynamic erosion, deposition, and terrain flow driven by system diagnostic logs.

require 'io/console'

class TypographicLandscape
  # Density map representing terrain elevation/resistance by character
  CHAR_MAP = " .':;-=+*#%@".freeze
  EROSION_CHARS = "░▒▓█".freeze

  def initialize(width = 80, height = 24)
    @width = width
    @height = height
    @poem_lines = [
      "The digital tide recedes into silicon static",
      "Memory allocation flows like glacial rivers",
      "Registers rust in the quiet hum of execution",
      "Threads intertwine, eroding ancient stacks",
      "Signals decay into the quiet abyss of null",
      "Cache misses leave hollow valleys in memory",
      "Interrupts shatter the fragile stillness of loops"
    ]
    
    # Initialize heightmap and character grid
    @grid = Array.new(@height) { Array.new(@width, ' ') }
    @elevation = Array.new(@height) { Array.new(@width, 0.0) }
    @fluid = Array.new(@height) { Array.new(@width, 0.0) }
    
    seed_poem_landscape
  end

  def seed_poem_landscape
    start_y = (@height - @poem_lines.size) / 2
    @poem_lines.each_with_index do |line, idx|
      y = start_y + idx
      start_x = (@width - line.length) / 2
      line.chars.each_with_index do |ch, c_idx|
        x = start_x + c_idx
        if x >= 0 && x < @width && y >= 0 && y < @height
          @grid[y][x] = ch
          # Characters with higher ASCII values carry more initial elevation
          @elevation[y][x] = (ch.ord % 10) / 10.0 + 0.2
        end
      end
    end
  end

  # Ingest mock system diagnostic logs to drive fluid dynamics
  def ingest_log_stream
    log_types = [:cpu_spike, :page_fault, :memory_leak, :io_wait]
    event = log_types.sample
    
    case event
    when :cpu_spike
      # Thermal blast causing sudden fluid surge at center
      x = rand(@width / 4..3 * @width / 4)
      y = rand(@height / 4..3 * @height / 4)
      @fluid[y][x] += 2.5
    when :page_fault
      # Erosion fault lines carving downward
      x = rand(0...@width)
      @fluid[0][x] += 1.8
    when :memory_leak
      # Slow deposition pool forming near bottom corners
      corner_x = rand > 0.5 ? 0 : @width - 1
      @elevation[@height - 1][corner_x] = [@elevation[@height - 1][corner_x] + 0.3, 1.0].min
    when :io_wait
      # Horizontal pulse across a single terrain row
      y = rand(0...@height)
      @width.times { |x| @fluid[y][x] += 0.2 }
    end
  end

  # Simulate cellular fluid flow, erosion, and sediment deposition
  def update_physics
    new_fluid = Array.new(@height) { Array.new(@width, 0.0) }
    
    @height.times do |y|
      @width.times do |x|
        current_f = @fluid[y][x]
        next if current_f <= 0.001

        # Dissipate energy slightly
        current_f *= 0.85

        # Check neighbor slopes for fluid dispersion
        neighbors = []
        [[-1, 0], [1, 0], [0, -1], [0, 1]].each do |dx, dy|
          nx, ny = x + dx, y + dy
          if nx >= 0 && nx < @width && ny >= 0 && ny < @height
            # Flow down elevation gradients
            if @elevation[y][x] + current_f > @elevation[ny][nx]
              neighbors << [nx, ny]
            end
          end
        end

        if neighbors.any?
          flow_per_neighbor = current_f / neighbors.size
          neighbors.each do |nx, ny|
            new_fluid[ny][nx] += flow_per_neighbor
            
            # Erode elevation where fluid flows high velocity
            if flow_per_neighbor > 0.4 && @elevation[y][x] > 0.05
              @elevation[y][x] -= 0.02
              # Erode visual characters
              mutate_character(y, x, -1)
            end
          end
        else
          # Deposit sediment if fluid stalls
          if current_f > 0.5 && @elevation[y][x] < 1.0
            @elevation[y][x] += 0.03
            mutate_character(y, x, 1)
          end
          new_fluid[y][x] += current_f * 0.5
        end
      end
    end

    @fluid = new_fluid
  end

  def mutate_character(y, x, direction)
    current_char = @grid[y][x]
    
    if direction < 0 # Erosion
      if EROSION_CHARS.include?(current_char)
        idx = EROSION_CHARS.index(current_char)
        @grid[y][x] = idx > 0 ? EROSION_CHARS[idx - 1] : ' '
      elsif current_char != ' '
        @grid[y][x] = EROSION_CHARS[3] # Degrade poetic text into digital block particle
      end
    elsif direction > 0 # Deposition
      if current_char == ' '
        @grid[y][x] = CHAR_MAP[1]
      elsif CHAR_MAP.include?(current_char)
        idx = CHAR_MAP.index(current_char)
        @grid[y][x] = CHAR_MAP[[idx + 1, CHAR_MAP.size - 1].min]
      end
    end
  end

  def render
    buffer = "\e[H\e[2J" # Clear screen and reset cursor
    buffer << "=== TYPOGRAPHIC LANDSCAPE SIMULATOR (SYSTEM LOG FLUID DYNAMICS) ===\n"

    @height.times do |y|
      line_str = ""
      @width.times do |x|
        char = @grid[y][x]
        fluid_level = @fluid[y][x]
        
        # Colorize dynamically based on fluid level and elevation state
        if fluid_level > 0.8
          line_str << "\e[36;1m#{char}\e[0m" # Cyan high flow
        elsif fluid_level > 0.2
          line_str << "\e[34m#{char}\e[0m"   # Blue moderate fluid
        elsif @elevation[y][x] > 0.6
          line_str << "\e[33m#{char}\e[0m"   # Yellow high terrain/sediment
        elsif char != ' '
          line_str << "\e[32m#{char}\e[0m"   # Green intact poem terrain
        else
          line_str << ' '
        end
      end
      buffer << line_str << "\n"
    end

    buffer << "[Press Ctrl+C to exit] Logs ingested, text eroding..."
    print buffer
  end

  def run
    system("clear") || system("cls")
    loop do
      ingest_log_stream
      update_physics
      render
      sleep 0.08
    end
  rescue Interrupt
    puts "\nSimulation halted. Terrain state saved to digital memory."
  end
end

# Execution
landscape = TypographicLandscape.new(80, 22)
landscape.run