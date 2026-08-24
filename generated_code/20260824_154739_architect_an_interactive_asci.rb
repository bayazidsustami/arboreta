# Interactive ASCII Fluid Simulation & Source Code Deformer
# Instructions: Run in a terminal (e.g., `ruby fluid.rb`). Press 'q' to quit, or hit keys to ripple.

require 'io/console'

WIDTH = 80
HEIGHT = 24
DAMPING = 0.96

# Read the executing source code text
CODE_TEXT = File.exist?(__FILE__) ? File.read(__FILE__) : "Ruby Fluid Simulation Source Code"
CODE_CHARS = CODE_TEXT.gsub(/\s+/, ' ').chars

# Wave equation grids (height maps)
$buffer1 = Array.new(HEIGHT) { Array.new(WIDTH, 0.0) }
$buffer2 = Array.new(HEIGHT) { Array.new(WIDTH, 0.0) }

def render(char_index)
  # Clear screen and move cursor to top-left
  print "\e[2J\e[H"
  
  HEIGHT.times do |y|
    row_str = ""
    WIDTH.times do |x|
      # Compute fluid displacement from neighbors
      if y > 0 && y < HEIGHT - 1 && x > 0 && x < WIDTH - 1
        $buffer2[y][x] = (
          $buffer1[y-1][x] +
          $buffer1[y+1][x] +
          $buffer1[y][x-1] +
          $buffer1[y][x+1]
        ) / 2.0 - $buffer2[y][x]
        $buffer2[y][x] *= DAMPING
      end

      # Displace character index based on local wave height
      displacement = $buffer2[y][x].round
      idx = (char_index + y * WIDTH + x + displacement) % CODE_CHARS.length
      
      # Select character and apply ASCII shading based on wave intensity
      char = CODE_CHARS[idx]
      val = $buffer2[y][x].abs
      if val > 15
        row_str << "\e[1;36m#{char}\e[0m" # Cyan high energy
      elsif val > 5
        row_str << "\e[34m#{char}\e[0m"   # Blue medium energy
      else
        row_str << char
      end
    end
    puts row_str
  end

  # Swap wave buffers
  $buffer1, $buffer2 = $buffer2, $buffer1
end

def disturb(x, y, strength = 50.0)
  (-2..2).each do |dy|
    (-2..2).each do |dx|
      nx, ny = x + dx, y + dy
      if nx >= 0 && nx < WIDTH && ny >= 0 && ny < HEIGHT
        $buffer1[ny][nx] += strength / (1 + dx*dx + dy*dy)
      end
    end
  end
end

# Non-blocking input handling setup
$stdin.raw!
$stdin.echo = false

# Initial gravitational ripple in the center
disturb(WIDTH / 2, HEIGHT / 2, 100.0)

char_offset = 0
begin
  loop do
    # Check for user keypress without blocking
    if IO.select([$stdin], nil, nil, 0.03)
      key = $stdin.read_nonblock(10) rescue nil
      break if key == 'q' || key == "\u0003" # Quit on 'q' or Ctrl+C
      
      # Drop a wave at a random location upon any keypress
      disturb(rand(2...(WIDTH - 2)), rand(2...(HEIGHT - 2)), rand(40.0..80.0))
    end

    render(char_offset)
    char_offset = (char_offset + 1) % CODE_CHARS.length
    sleep 0.03
  end
ensure
  # Restore terminal state on exit
  $stdin.cooked!
  $stdin.echo = true
  print "\e[2J\e[H\e[0m"
end