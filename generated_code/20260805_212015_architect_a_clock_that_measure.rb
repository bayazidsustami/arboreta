# Thermal Erosion Call Stack Clock
# A clock measuring time through thermal mass transport across a 2D terrain grid
# shaped directly by live system call stack frames.

class ThermalCallStackClock
  WIDTH = 40
  HEIGHT = 16
  TALUS_THRESHOLD = 0.12  # Material slides if height delta exceeds this threshold
  EROSION_RATE = 0.35     # Mass flux transfer coefficient per step
  SHADE_RAMP = " .:-=+*#%@"

  def initialize
    # Topography grid initialized to flat baseline with small random noise
    @landscape = Array.new(HEIGHT) { Array.new(WIDTH) { rand * 0.1 } }
    @eroded_mass = 0.0
    @start_real_time = Time.now
    @ticks = 0
  end

  # Mutates topography based on the current execution stack
  def deform_landscape_from_stack
    locations = caller_locations
    locations.each_with_index do |loc, depth|
      # Seed landscape coordinate from call stack attributes
      hash = loc.path.hash ^ loc.lineno.hash ^ loc.label.hash ^ (depth * 0x9e3779b9)
      x = (hash.abs + depth * 3) % WIDTH
      y = ((hash.abs >> 3) + depth * 7) % HEIGHT
      
      # Stack presence deposits mass; deeper frames add more potential energy
      mass_deposit = 0.15 + (depth * 0.04)
      @landscape[y][x] += mass_deposit
    end
  end

  # Physically accurate thermal erosion simulation step
  # Material flows down the steepest gradient if local slope exceeds talus angle
  def simulate_thermal_erosion
    transferred_mass = 0.0
    next_landscape = @landscape.map(&:dup)

    HEIGHT.times do |y|
      WIDTH.times do |x|
        current_height = @landscape[y][x]
        
        # Identify orthogonal neighbors within grid bounds
        neighbors = [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]].select do |nx, ny|
          nx.between?(0, WIDTH - 1) && ny.between?(0, HEIGHT - 1)
        end

        # Calculate max elevation drop to neighbor
        max_delta = 0.0
        steepest_target = nil

        neighbors.each do |nx, ny|
          delta = current_height - @landscape[ny][nx]
          if delta > max_delta
            max_delta = delta
            steepest_target = [nx, ny]
          end
        end

        # If slope exceeds critical talus threshold, transfer thermal mass
        if max_delta > TALUS_THRESHOLD && steepest_target
          tx, ty = steepest_target
          slide_amount = (max_delta - TALUS_THRESHOLD) * EROSION_RATE * 0.25
          next_landscape[y][x] -= slide_amount
          next_landscape[ty][tx] += slide_amount
          transferred_mass += slide_amount
        end
      end
    end

    @landscape = next_landscape
    @eroded_mass += transferred_mass
    transferred_mass
  end

  # Displays the landscape topography and thermal clock state in terminal
  def render
    print "\e[H" # Move cursor home
    puts "┌── THERMAL EROSION CALL STACK CLOCK ──────────────────────┐"
    puts "│ Call Stack Depth : %-37d │" % caller_locations.size
    puts "│ Eroded Mass Time : %-37.4f │" % @eroded_mass
    puts "│ Wall Clock Time  : %-34.2fs │" % (Time.now - @start_real_time)
    puts "├" + "─" * WIDTH + "┤"

    # Normalize heightmap for display
    flat = @landscape.flatten
    min_h, max_h = flat.min, flat.max
    range = (max_h - min_h).nonzero? || 1.0

    @landscape.each do |row|
      line = row.map do |val|
        norm = (val - min_h) / range
        char_idx = [(norm * (SHADE_RAMP.length - 1)).round, SHADE_RAMP.length - 1].min
        SHADE_RAMP[[char_idx, 0].max]
      end.join
      puts "│" + line + "│"
    end

    puts "└" + "─" * WIDTH + "┘"
  end

  # Clock tick engine driving dynamic recursive call stack depths
  def tick(depth = 1)
    @ticks += 1
    deform_landscape_from_stack
    
    # Run multiple erosion micro-pulses
    4.times { simulate_thermal_erosion }

    render
    sleep 0.04

    # Recursively alter call stack depth dynamically to continuously reshape terrain
    if depth < 14 && rand > 0.25
      tick(depth + 1)
    elsif depth > 1 && rand > 0.35
      return
    end

    # Resume root pulse loop
    tick(depth) if depth == 1
  end
end

# Main execution loop
print "\e[2J\e[?25l" # Clear screen and hide cursor

trap("INT") do
  print "\e[?25h\e[0m\nClock terminated.\n"
  exit
end

clock = ThermalCallStackClock.new
clock.tick