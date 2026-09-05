class MemoryGrid
  WIDTH = 40
  HEIGHT = 20

  def initialize
    @grid = Array.new(HEIGHT) { Array.new(WIDTH) { rand(2) } }
    @registers = { AX: 0, BX: 0, IP: 0, SP: HEIGHT * WIDTH - 1 }
    @stack = []
  end

  def step!
    # Update Registers & Stack Simulation
    @registers[:IP] = (@registers[:IP] + 1) % (WIDTH * HEIGHT)
    @registers[:AX] = (@registers[:AX] + rand(3) - 1) & 0xFF
    
    if rand < 0.1
      @stack.push(@registers[:AX])
      @registers[:SP] = [@registers[:SP] - 1, 0].max
    elsif rand < 0.1 && !@stack.empty?
      @registers[:BX] = @stack.pop
      @registers[:SP] = [@registers[:SP] + 1, WIDTH * HEIGHT - 1].min
    end

    # Memory map sync: Stack modifies bottom-right memory
    stack_pos = @registers[:SP]
    @grid[stack_pos / WIDTH][stack_pos % WIDTH] = @stack.last ? (@stack.last % 2) : 0

    # Cellular Automaton Step (Conway's Game of Life rules applied to Memory)
    new_grid = Array.new(HEIGHT) { Array.new(WIDTH, 0) }
    
    HEIGHT.times do |y|
      WIDTH.times do |x|
        neighbors = count_neighbors(x, y)
        cell = @grid[y][x]
        
        new_grid[y][x] = if cell == 1 && (neighbors == 2 || neighbors == 3)
                           1
                         elsif cell == 0 && neighbors == 3
                           1
                         else
                           0
                         end
      end
    end
    
    # Kernel Execution Marker (IP location in memory forced ON)
    ip_y = @registers[:IP] / WIDTH
    ip_x = @registers[:IP] % WIDTH
    new_grid[ip_y][ip_x] = 1

    @grid = new_grid
  end

  def render
    print "\e[H\e[2J" # Clear ANSI screen
    puts "=== ESOTERIC KERNEL: MEMORY & STACK CELLULAR AUTOMATON ==="
    puts "REGISTERS | IP: 0x#{@registers[:IP].to_s(16).rjust(4, '0')} | AX: 0x#{@registers[:AX].to_s(16).rjust(2, '0')} | BX: 0x#{@registers[:BX].to_s(16).rjust(2, '0')} | SP: 0x#{@registers[:SP].to_s(16).rjust(4, '0')}"
    puts "-" * (WIDTH * 2 + 1)

    HEIGHT.times do |y|
      row = "|"
      WIDTH.times do |x|
        cell = @grid[y][x]
        is_ip = (y * WIDTH + x) == @registers[:IP]
        is_sp = (y * WIDTH + x) == @registers[:SP]

        if is_ip
          row += "E " # Instruction Pointer Execution Core
        elsif is_sp
          row += "S " # Stack Pointer
        else
          row += cell == 1 ? "█ " : "  " # Cellular Automaton Memory State
        end
      end
      puts row + "|"
    end

    puts "-" * (WIDTH * 2 + 1)
    puts "STACK TOP (#{@stack.size} frames): [#{@stack.last(5).join(', ')}]"
  end

  private

  def count_neighbors(x, y)
    count = 0
    (-1..1).each do |dy|
      (-1..1).each do |dx|
        next if dx == 0 && dy == 0
        nx = (x + dx) % WIDTH
        ny = (y + dy) % HEIGHT
        count += @grid[ny][nx]
      end
    end
    count
  end
end

# Execution Loop
grid = MemoryGrid.new
loop do
  grid.step!
  grid.render
  sleep 0.1
end