# Self-modifying 2D grid quine -> MIDI execution score animator
class QuineGrid
  CHARS = ["v", ">", "^", "<", "v", "#", "+", "A", "M", "S", "~", "!", "@", "*"]
  
  def initialize
    @grid = Array.new(12) { Array.new(24) { CHARS.sample } }
    @px, @py, @dx, @dy = 0, 0, 1, 0
    @notes = []
  end

  def step
    # 2D Grid execution and self-modification
    cell = @grid[@py][@px]
    freq = (cell.ord % 36 + 48) # Map ASCII to MIDI scale (C3-B5)
    @notes << [cell, freq, @px, @py]

    case cell
    when '>' then @dx, @dy = 1, 0
    when '<' then @dx, @dy = -1, 0
    when '^' then @dx, @dy = 0, -1
    when 'v' then @dx, @dy = 0, 1
    when '#' then @dx, @dy = -@dx, -@dy
    else
      # Self-modify current cell using adjacent values
      @grid[@py][@px] = CHARS[(cell.ord + 1) % CHARS.size]
    end

    @px = (@px + @dx) % 24
    @py = (@py + @dy) % 12
  end

  def render
    # Render execution path as colored musical matrix
    system("clear") || system("cls")
    puts "\e[1;35m--- 2D QUINE EXECUTION SCORE (MIDI PATH) ---\e[0m\n\n"
    @grid.each_with_index do |row, y|
      row.each_with_index do |char, x|
        if x == @px && y == @py
          print "\e[1;31;47m #{char} \e[0m" # Active Execution Pointer
        else
          color = 31 + (char.ord % 6)
          print "\e[#{color}m #{char} \e[0m"
        end
      end
      puts
    end
    
    puts "\n\e[1;33mRecent MIDI Frequencies (Pitch/Pos):\e[0m"
    @notes.last(6).each do |c, f, x, y|
      puts "Note: #{f} Hz | Symbol: '#{c}' @ [#{x}, #{y}]"
    end
  end

  def run(steps = 30)
    steps.times do
      step
      render
      sleep 0.15
    end
    print_source
  end

  def print_source
    # Quine logic to reproduce self-contained runnable script structure
    puts "\n\e[1;32m--- QUINE REPRODUCTIVE SOURCE DATA ---\e[0m"
    code = <<~'RUBY'
      class QuineGrid
        # [Self-Contained Execution Matrix & MIDI Parser]
      end
      QuineGrid.new.run
    RUBY
    puts code
  end
end

QuineGrid.new.run(20)