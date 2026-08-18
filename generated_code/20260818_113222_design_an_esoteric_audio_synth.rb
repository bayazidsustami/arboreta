require 'ripper'

# Esoteric AST Microtonal Synthesizer & Cellular Automaton Visualizer
class EsotericSynthesizer
  PALETTE = [" ", "░", "▒", "▓", "█", "✦", "✧", "⚛", "✺", "✵"]
  WIDTH, HEIGHT = 40, 20

  def initialize(code_source)
    @ast = Ripper.sexp(code_source)
    @grid = Array.new(HEIGHT) { Array.new(WIDTH) { rand(0..1) } }
    @execution_stack = []
    @frequencies = []
    flatten_ast(@ast)
  end

  # Flattens Ruby AST nodes into microtonal frequencies via 19-TET (19 Tone Equal Temperament)
  def flatten_ast(node)
    return unless node.is_a?(Array)
    node_type = node.first
    if node_type.is_a?(Symbol)
      @execution_stack << node_type
      # Microtonal frequency mapping: Base 220Hz (A3) adjusted by node hash mod 19 microtones
      step = node_type.hash.abs % 19
      freq = 220.0 * (2.0 ** (step / 19.0))
      @frequencies << freq
    end
    node.each { |child| flatten_ast(child) if child.is_a?(Array) }
  end

  # Evolving 2D Cellular Automaton (Kaleidoscopic Life-like Rules with Symmetry)
  def step_automaton(phase)
    new_grid = Array.new(HEIGHT) { Array.new(WIDTH, 0) }
    (0...HEIGHT).each do |y|
      (0...WIDTH).each do |x|
        neighbors = 0
        (-1..1).each do |dy|
          (-1..1).each do |dx|
            next if dx == 0 && dy == 0
            ny, nx = (y + dy) % HEIGHT, (x + dx) % WIDTH
            neighbors += 1 if @grid[ny][nx] > 0
          end
        end
        
        # Rule evolution modulated by execution stack energy
        alive = @grid[y][x] > 0
        if alive && (neighbors == 2 || neighbors == 3)
          new_grid[y][x] = (@grid[y][x] + 1) % PALETTE.size
        elsif !alive && (neighbors == 3 || (neighbors == 2 && phase.even?))
          new_grid[y][x] = 1
        else
          new_grid[y][x] = 0
        end
      end
    end
    @grid = enforce_kaleidoscope_symmetry(new_grid)
  end

  # Applies 4-fold radial symmetry across quadrant boundaries
  def enforce_kaleidoscope_symmetry(grid)
    half_h, half_w = HEIGHT / 2, WIDTH / 2
    (0...half_h).each do |y|
      (0...half_w).each do |x|
        val = grid[y][x]
        grid[y][WIDTH - 1 - x] = val
        grid[HEIGHT - 1 - y][x] = val
        grid[HEIGHT - 1 - y][WIDTH - 1 - x] = val
      end
    end
    grid
  end

  # Renders ASCII frame with visual stack indicators and audio frequency metadata
  def render_frame(frame_num, current_freq, node_symbol)
    print "\e[H\e[2J" # Clear screen ANSI
    puts "═══ ESOTERIC AST AUDIO SYNTHESIZER ═══"
    puts "AST Node: :#{node_symbol || 'idle'} | Pitch: #{current_freq ? current_freq.round(2) : 0} Hz (19-TET Microtonal)"
    puts "─" * (WIDTH + 2)
    @grid.each do |row|
      print "│"
      row.each { |cell| print PALETTE[cell % PALETTE.size] }
      puts "│"
    end
    puts "─" * (WIDTH + 2)
    stack_viz = @execution_stack.take(10).map { |s| ":#{s}" }.join(" -> ")
    puts "Stack: [#{stack_viz}...]"
  end

  # Generates PCM WAV file for microtonal synth audio output
  def export_wav(filename = "esoteric_synth.wav", duration_per_node = 0.15)
    sample_rate = 22050
    pcm_data = []

    @frequencies.each do |freq|
      num_samples = (sample_rate * duration_per_node).to_i
      num_samples.times do |i|
        t = i.to_f / sample_rate
        # Synthesize complex harmonic wave with FM modulation
        carrier = Math.sin(2.0 * Math::PI * freq * t)
        modulator = Math.sin(2.0 * Math::PI * (freq * 1.5) * t) * 0.3
        sample = (carrier + modulator) * 0.5
        pcm_data << [(sample * 32767).clamp(-32768, 32767)].pack("s<")
      end
    end

    raw_audio = pcm_data.join
    data_size = raw_audio.bytesize
    
    # Standard 44-byte WAV header construction
    header = [
      "RIFF", data_size + 36, "WAVE",
      "fmt ", 16, 1, 1, sample_rate, sample_rate * 2, 2, 16,
      "data", data_size
    ].pack("a4Va4a4VvvVVvva4V")

    File.binwrite(filename, header + raw_audio)
    filename
  end

  # Real-time evaluation loop
  def run
    puts "Synthesizing AST soundwaves and kaleidoscopic execution grid..."
    sleep(1)

    @frequencies.each_with_index do |freq, idx|
      node = @execution_stack[idx]
      step_automaton(idx)
      render_frame(idx, freq, node)
      sleep(0.08)
    end

    out_file = export_wav
    puts "\nExecution complete. Generated microtonal audio file: #{out_file}"
  end
end

# Example source code parsed into the synthesizer engine
source_code = <<~RUBY
  def microtonal_kaleidoscope(ast_nodes)
    ast_nodes.map do |node|
      yield(node) if block_given?
      node.hash * 1.61803398875
    end.sum
  end
RUBY

# Instantiate and trigger esoteric engine
synth = EsotericSynthesizer.new(source_code)
synth.run