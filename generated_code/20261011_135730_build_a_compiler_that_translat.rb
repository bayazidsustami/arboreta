# Atmospheric Pressure Esoteric Compiler & Generative Creature Gallery
# A complete, self-contained Ruby script that simulates real-time atmospheric
# pressure readings, compiles them into an esoteric language ("BaroScript"),
# and spawns geometric creatures for every syntax error encountered.

require 'io/console'

class Creature
  ATTRS = [:vertices, :color, :mutation, :shape_type]

  def initialize(pressure, error_code)
    # Use atmospheric pressure to determine biological traits
    @vertices = (pressure.abs % 7) + 3 # 3 to 9-sided polygon
    @color = generate_color(pressure)
    @shape_type = [:polygon, :star, :spiral, :fractal_ring][error_code % 4]
    @mutation = error_code
    @age = 0
  end

  def tick
    @age += 1
  end

  def render
    # ASCII/Unicode representation of the geometric creature
    "   /\\   [Entity ##{@mutation}] Vertices: #{@vertices} | Type: #{@shape_type.to_s.upcase} | Color: #{@color} | Age: #{@age}"
  end

  private

  def generate_color(pressure)
    colors = [:cyan, :magenta, :yellow, :green, :red, :blue, :gold]
    colors[(pressure * 10).to_i.abs % colors.length]
  end
end

class BaroCompiler
  def initialize
    @creatures = []
    @error_count = 0
  end

  # Translates raw atmospheric pressure (e.g., in hPa around 1013.25) into esoteric tokens
  def compile_stream(pressure_reading)
    # Esoteric language rules: valid tokens must align with specific pressure intervals
    # Deviations trigger syntax errors, spawning creatures.
    deviation = (pressure_reading - 1013.25).round(2)
    
    token = if deviation.abs < 2.0
      "STABLE_NOP"
    elsif deviation > 0
      @error_count += 1
      spawn_creature(pressure_reading, @error_count)
      "ERR_HIGH_PRESSURE_OVERFLOW"
    else
      @error_count += 1
      spawn_creature(pressure_reading, @error_count)
      "ERR_VACUUM_COLLAPSE"
    end

    { token: token, deviation: deviation, creatures_alive: @creatures.size }
  end

  def tick_gallery
    @creatures.each(&:tick)
  end

  def active_creatures
    @creatures
  end

  private

  def spawn_creature(pressure, err_code)
    creature = Creature.new(pressure, err_code)
    @creatures << creature
    # Keep gallery size manageable
    @creatures.shift if @creatures.length > 10
  end
end

# Main execution loop for the generative art gallery
if __FILE__ == $0
  compiler = BaroCompiler.new
  base_pressure = 1013.25

  puts "=== ATMOSPHERIC PRESSURE GENERATIVE ART GALLERY ==="
  puts "Compiler online. Translating barometric fluctuations into BaroScript..."
  puts "Press Ctrl+C to exit.\n\n"

  loop do
    # Simulate realistic atmospheric breathing (fluctuating pressure)
    fluctuation = (Math.sin(Time.now.to_i * 0.5) * 5.0) + (rand(-15.0..15.0))
    current_pressure = (base_pressure + fluctuation).round(2)

    result = compiler.compile_stream(current_pressure)
    compiler.tick_gallery

    # Clear screen for real-time generative effect (ANSI escape)
    print "\e[H\e[2J"
    puts "========================================================"
    puts " BAROMETRIC TELEMETRY: #{current_pressure} hPa"
    puts " COMPILER TOKEN       : #{result[:token]}"
    puts " PRESSURE DEVIATION   : #{result[:deviation]} hPa"
    puts " TOTAL SYNTAX ERRORS  : #{compiler.active_creatures.size}"
    puts "========================================================"
    puts "\n--- REAL-TIME GENERATIVE CREATURE GALLERY ---"
    
    if compiler.active_creatures.empty?
      puts " (Gallery quiet. Atmosphere stable. Waiting for syntax mutations...)"
    else
      compiler.active_creatures.each_with_index do |creature, idx|
        print "  [#{idx + 1}]"
        puts creature.render
      end
    end

    sleep(1.0)
  end
end