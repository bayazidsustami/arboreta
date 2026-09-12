require 'curses'

# Initialize Curses display & audio environment
Curses.init_screen
Curses.curs_set(0)
Curses.noecho
Curses.stdscr.nodelay = true

WIDTH = Curses.cols
HEIGHT = Curses.lines - 1

# Base pitch frequencies for spatial star coordinates
HARMONIC_FREQS = [261.63, 293.66, 329.63, 349.23, 392.00, 440.00, 493.88, 523.25]
SYMBOLS = %w[. * + o O @ #]

class ConstellationAutomaton
  def initialize
    @grid = Hash.new(0)
    # Seed self-modifying code glider (the "program") into space
    @code_str = File.read(__FILE__) rescue "DYNAMIC_STARFIELD_HARMONY"
    seed_initial_state
    @consumed_dead = 0
  end

  def seed_initial_state
    @code_str.bytes.each_with_index do |b, i|
      x = (i * 7) % WIDTH
      y = (i * 3) % (HEIGHT - 2) + 1
      @grid[[x, y]] = (b % 4) + 1
    end
  end

  def step
    new_grid = Hash.new(0)
    neighborhoods = Hash.new(0)

    # Spatial propagation & neighbor counting
    @grid.each do [x, y], state|
      next if state == 0
      (-1..1).each do |dx|
        (-1..1).each do |dy|
          next if dx == 0 && dy == 0
          nx = (x + dx) % WIDTH
          ny = (y + dy) % HEIGHT
          neighborhoods[[nx, ny]] += 1
        end
      end
    end

    # Esoteric cellular transition rules: consumption of dead space modifies harmony
    neighborhoods.each do |(x, y), count|
      current = @grid[[x, y]]
      if current == 0 && (count == 3 || count == 2)
        # Consuming dead space; mutate state dynamically
        new_grid[[x, y]] = ((count + @consumed_dead) % 6) + 1
        @consumed_dead += 1
      elsif current > 0 && (count == 2 || count == 3)
        # Code propagation continues
        new_grid[[x, y]] = (current % 6) + 1
      end
    end

    # Self-modification: dynamically alter code string based on cellular consumption
    if @consumed_dead % 10 == 0 && !@code_str.empty?
      @code_str = @code_str.rotate_bytes(@consumed_dead % @code_str.bytesize)
    end

    @grid = new_grid
  end

  def render
    Curses.clear
    harmonic_energy = 0

    @grid.each do (x, y), state|
      symbol = SYMBOLS[state % SYMBOLS.size]
      Curses.setpos(y, x)
      Curses.addstr(symbol)
      harmonic_energy += HARMONIC_FREQS[x % HARMONIC_FREQS.size] * state
    end

    # Dynamic Audio-Harmonic Pitch Triggering via System Bell Modulation
    freq_index = (harmonic_energy + @consumed_dead) % HARMONIC_FREQS.size
    pitch_char = (65 + (freq_index % 7)).chr
    
    Curses.setpos(0, 0)
    Curses.addstr("Constellation Harmonic Key: #{pitch_char} | Consumed Void: #{@consumed_dead} | Active Stars: #{@grid.size}")
    
    # Trigger audio pulse when harmonic state shifts significantly
    Curses.beep if @consumed_dead % 5 == 0
    Curses.refresh
  end
end

class String
  def rotate_bytes(n)
    bytes = self.bytes
    bytes.rotate(n).pack('C*')
  end
end

automaton = ConstellationAutomaton.new

begin
  loop do
    automaton.render
    automaton.step
    sleep 0.08
    break if Curses.getch == 'q'
  end
ensure
  Curses.close_screen
end