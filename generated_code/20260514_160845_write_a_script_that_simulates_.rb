# A simple implementation of Conway's Game of Life
# This script uses a 2D array to represent the grid and simulates generations.

class CellularAutomaton
  attr_reader :width, :height, :grid

  def initialize(width, height, density = 0.2)
    @width = width
    @height = height
    # Initialize grid with random alive (true) or dead (false) cells
    @grid = Array.new(height) { Array.new(width) { rand < density } }
  end

  # Computes the next state of the grid based on Conway's rules:
  # 1. Any live cell with < 2 live neighbors dies (underpopulation).
  # 2. Any live cell with 2 or 3 live neighbors lives.
  # 3. Any live cell with > 3 live neighbors dies (overpopulation).
  # 4. Any dead cell with exactly 3 live neighbors becomes alive (reproduction).
  def step
    new_grid = Array.new(@height) { Array.new(@width) }

    @height.times do |y|
      @width.times do |x|
        neighbors = count_neighbors(x, y)
        is_alive = @grid[y][x]

        if is_alive
          new_grid[y][x] = [2, 3].include?(neighbors)
        else
          new_grid[y][x] = (neighbors == 3)
        end
      end
    end

    @grid = new_grid
  end

  # Counts live neighbors in the 3x3 area around (x, y), ignoring the cell itself.
  # Uses wrapping (toroidal) boundaries so the grid is continuous.
  def count_neighbors(x, y)
    count = 0
    (-1..1).each do |dy|
      (-1..1).each do |dx|
        next if dx == 0 && dy == 0

        # Toroidal wrapping logic
        nx = (x + dx) % @width
        ny = (y + dy) % @height

        count += 1 if @grid[ny][nx]
      end
    end
    count
  end

  # Renders the current state to the console
  def display
    # Clear console (works for most terminals)
    print "\e[H\e[2J"
    
    output = @grid.map do |row|
      row.map { |cell| cell ? "█" : " " }.join
    end.join("\n")
    
    puts output
  end
end

# --- Execution Logic ---

# Configuration
WIDTH = 40
HEIGHT = 20
ITERATIONS = 100
SLEEP_TIME = 0.1

# Initialize the simulation
sim = CellularAutomaton.new(WIDTH, HEIGHT, 0.25)

# Main simulation loop
ITERATIONS.times do |i|
  sim.display
  puts "Generation: #{i}"
  sim.step
  sleep(SLEEP_TIME)
end