#!/usr/bin/env ruby
# Conway's Game of Life on a Torus corrupting an embedded haiku into a melting candle

HAIKU = [
  "Silent autumn leaves,",
  "Drifting down to frozen earth,",
  "Time begins to melt."
]

WIDTH = 44
HEIGHT = 22

# Initialize grid from the embedded haiku centered on the canvas
grid = Array.new(HEIGHT) { Array.new(WIDTH, 0) }
start_row = (HEIGHT - HAIKU.size) / 2
HAIKU.each_with_index do |line, r_idx|
  start_col = (WIDTH - line.length) / 2
  line.chars.each_with_index do |char, c_idx|
    grid[start_row + r_idx][start_col + c_idx] = (char != ' ' ? 1 : 0)
  end
end

def count_neighbors(grid, r, c)
  h = grid.size
  w = grid[0].size
  count = 0
  (-1..1).each do |dr|
    (-1..1).each do |dc|
      next if dr == 0 && dc == 0
      nr = (r + dr) % h
      nc = (c + dc) % w
      count += grid[nr][nc]
    end
  end
  count
end

def step_gol(grid)
  h = grid.size
  w = grid[0].size
  new_grid = Array.new(h) { Array.new(w, 0) }
  (0...h).each do |r|
    (0...w).each do |c|
      neighbors = count_neighbors(grid, r, c)
      if grid[r][c] == 1
        new_grid[r][c] = (neighbors == 2 || neighbors == 3) ? 1 : 0
      else
        new_grid[r][c] = (neighbors == 3) ? 1 : 0
      end
    end
  end
  new_grid
end

def render_grid(grid)
  grid.map { |row| row.map { |cell| cell == 1 ? '█' : ' ' }.join }.join("\n")
end

# Clear screen once at start
print "\e[2J"

# Phase 1: Toroidal Game of Life corruption of the haiku
35.times do |i|
  print "\e[H"
  puts "=== PHASE I: THE CORRUPTION OF POETRY (Step #{i + 1}/35) ==="
  puts render_grid(grid)
  grid = step_gol(grid)
  sleep(0.12)
end

# Phase 2: Transition into a melting ASCII candle
candle_height = 10
melt_steps = 35

melt_steps.times do |i|
  print "\e[H"
  puts "=== PHASE II: THE MELTING CANDLE (Frame #{i + 1}/#{melt_steps}) ==="
  
  output = []
  flame_styles = ['(v)', '(\\)', '(/)', '(*)']
  flame = (i % 2 == 0) ? flame_styles[rand(flame_styles.size)] : ' | '
  
  # Top spacing
  margins = [HEIGHT - candle_height - (i / 3), 2].max
  margins.times { output << "" }
  
  # Flame and wick
  output << (" " * (WIDTH / 2 - 1) + flame)
  output << (" " * (WIDTH / 2) + "|")
  
  # Candle body getting shorter as it melts
  current_height = [candle_height - (i / 3), 2].max
  current_height.times do |ch|
    drip = (ch == current_height - 1 && i > 5) ? "~" * [i, 12].min : " "
    body = " " * ((WIDTH - 10) / 2) + "||" + drip + "||"
    output << body
  end
  
  # Wax pool expanding at the bottom
  pool_width = 8 + [i * 2, WIDTH - 4].min
  output << (" " * ((WIDTH - pool_width) / 2) + "_" * pool_width)
  
  # Pad to maintain consistent height
  while output.size < HEIGHT
    output.unshift("")
  end
  
  puts output[0...HEIGHT].join("\n")
  sleep(0.12)
end

print "\e[H\e[2J"
puts "The poem has melted away into silence."