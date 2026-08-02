# Executable Ruby Quine: Renders source code as an ASCII fluid simulation driven by CPU thermal metrics
$code = <<~'RUBY'
# Thermal-driven ASCII Fluid Simulation Quine
require 'io/console'

def fetch_thermal_factor
  # Read Linux CPU temp sysfs interface or fallback to system metrics
  temp = nil
  ['/sys/class/thermal/thermal_zone0/temp', '/sys/class/hwmon/hwmon0/temp1_input'].each do |path|
    if File.exist?(path)
      temp = File.read(path).to_f / 1000.0
      break
    end
  end
  # Fallback metric if hardware thermal sensors are inaccessible
  temp ||= (45.0 + (GC.stat[:heap_free_slots] % 30))
  temp
end

# Reconstruct complete source code string (Quine self-representation)
source_code = "$code = <<~'RUBY'\n" + $code + "RUBY\neval $code"

# Simulation grid configuration
width, height = 80, 24
chars = source_code.chars.reject { |c| c == "\r" }

# Velocity and density field initialization
u = Array.new(height) { Array.new(width, 0.0) }
v = Array.new(height) { Array.new(width, 0.0) }
grid = Array.new(height) { Array.new(width, ' ') }

# Seed grid with source code characters
chars.each_with_index do |ch, i|
  r, c = (i / width) % height, i % width
  grid[r][c] = ch
end

# Animate fluid flow in terminal
print "\e[2J\e[?25l" rescue nil
at_exit { print "\e[?25h\e[0m\n" rescue nil }

t = 0.0
loop do
  temp = fetch_thermal_factor
  # Turbulence vector magnitude scales with CPU temperature/throttling
  turbulence = [(temp - 30.0) / 25.0, 0.1].max

  # Update velocity field with thermal turbulence vectors
  height.times do |y|
    width.times do |x|
      u[y][x] = Math.sin(x * 0.15 + t * turbulence) * turbulence
      v[y][x] = Math.cos(y * 0.15 + t * 0.8) * turbulence * 0.5
    end
  end

  # Render advecting source code characters as fluid particles
  frame = String.new
  height.times do |y|
    width.times do |x|
      src_x = (x - u[y][x] * 3).round % width
      src_y = (y - v[y][x] * 3).round % height
      ch = grid[src_y][src_x]
      frame << (ch == "\n" ? ' ' : ch)
    end
    frame << "\n"
  end

  print "\e[H" + frame
  print "CPU Thermal Metric: #{'%.1f' % temp}°C | Turbulence: #{'%.2f' % turbulence} | Press Ctrl+C to exit"
  sleep 0.04
  t += 0.1
  break unless $stdout.tty?
end
RUBY
eval $code