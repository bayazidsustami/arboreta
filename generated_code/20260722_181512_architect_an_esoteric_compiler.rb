# System Log Sonified Stained-Glass Esoteric Compiler
# Translates raw log streams into a self-assembling stained glass window matrix.
# Memory leaks decay acoustic color frequencies, while unhandled exceptions shatter glass into light particles.

class EsotericLogCompiler
  ANSI_CLEAR = "\e[2J\e[H\e[?25l"
  ANSI_RESET = "\e[0m\e[?25h"

  # Simulated raw log stream used when no input file is provided
  RAW_LOG_STREAM = [
    "[INFO] Kernel initialized. Allocating memory blocks.",
    "[WARN] Memory leak at 0x004F2: 4096 bytes unfreed.",
    "[INFO] System daemon thread started.",
    "[WARN] Memory leak expanding at 0x004F2: acoustic decay shift +15%",
    "[FATAL] UnhandledException: SegmentFault in Thread 0x88F",
    "[WARN] Memory leak cascading at 0x008A1: resonant frequency decay",
    "[ERROR] Critical failure: Glass matrix structural collapse!"
  ]

  Particle = Struct.new(:x, :y, :vx, :vy, :glyph, :rgb, :life)

  def initialize(logs = RAW_LOG_STREAM)
    @logs = logs
    @width = 60
    @height = 20
    @glass_matrix = Array.new(@height) { Array.new(@width) { nil } }
    @particles = []
    @acoustic_leaks = []
  end

  # Step 1: Parse and compile logs into visual-acoustic AST tokens
  def compile!
    @logs.each_with_index do |line, idx|
      case line
      when /Memory leak/i
        # Leaks become decaying color-shifting audio frequencies
        bytes = line.scan(/\d+/).first.to_i rescue 1024
        freq = 200 + (bytes % 500)
        rgb = [(freq * 2) % 255, 120, 255 - (freq % 200)]
        @acoustic_leaks << { freq: freq, decay: 0.94, rgb: rgb }
        plant_glass_node(idx, rgb, "▓")
      when /UnhandledException|FATAL|ERROR/i
        # Exceptions trigger structural shatter into light particles
        40.times do
          @particles << Particle.new(
            @width / 2.0, @height / 2.0,
            rand(-2.5..2.5), rand(-1.8..1.8),
            ["✦", "✧", "•", "*", "░", "♦"].sample,
            [255, rand(100..220), rand(50..180)],
            rand(12..30)
          )
        end
      else
        # Normal ops form stable, radiant stained-glass framing
        rgb = [rand(30..90), rand(100..200), rand(180..255)]
        plant_glass_node(idx, rgb, "█")
      end
    end
  end

  # Step 2: Assemble stained glass geometric patterns
  def assemble_window!
    @height.times do |y|
      @width.times do |x|
        next if @glass_matrix[y][x]
        dx = (x - @width / 2.0).abs
        dy = (y - @height / 2.0).abs
        dist = Math.sqrt(dx**2 + dy**2)
        r = (Math.sin(dist * 0.4) * 127 + 128).to_i
        g = (Math.cos(dist * 0.2) * 127 + 128).to_i
        b = ((r + g) / 2) % 255
        @glass_matrix[y][x] = { char: "░", rgb: [r, g, b] }
      end
    end
  end

  # Step 3: Execute interactive animation & acoustic synthesis
  def run
    compile!
    assemble_window!

    print ANSI_CLEAR
    trap("INT") { print ANSI_RESET; exit }

    45.times do
      print "\e[H"
      canvas = @glass_matrix.map { |row| row.map(&:dup) }

      # Color-shift acoustics from memory leak decay
      @acoustic_leaks.each do |leak|
        leak[:rgb][0] = (leak[:rgb][0] * leak[:decay]).to_i % 255
        leak[:rgb][1] = (leak[:rgb][1] + 12) % 255
      end

      # Particle physics update for shattered glass
      @particles.each do |p|
        p.x += p.vx
        p.y += p.vy
        p.life -= 1
        ix, iy = p.x.round, p.y.round
        if iy.between?(0, @height - 1) && ix.between?(0, @width - 1)
          canvas[iy][ix] = { char: p.glyph, rgb: p.rgb }
        end
      end
      @particles.reject! { |p| p.life <= 0 }

      # Render ANSI TrueColor buffer
      frame = +""
      canvas.each do |row|
        row.each do |tile|
          r, g, b = tile[:rgb]
          frame << "\e[38;2;#{r};#{g};#{b}m#{tile[:char]}"
        end
        frame << "\n"
      end

      # Audio pulse simulation via terminal bell for sonification
      frame << "\a" if rand < 0.25 && !@acoustic_leaks.empty?

      print frame
      sleep 0.08
    end

    print ANSI_RESET
  end

  private

  def plant_glass_node(seed, rgb, char)
    x = (seed * 11) % @width
    y = (seed * 5) % @height
    @glass_matrix[y][x] = { char: char, rgb: rgb }
  end
end

EsotericLogCompiler.new.run