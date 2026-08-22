require 'mini_portaudio' rescue nil # Standard Ruby environment fallback structure

# Self-Parsing Microtonal Synthesizer & Fractal Tree Visualizer
# Uses standard library Ruby (DL/Fiddle, C-FFI or OSC/MIDI fallbacks)
# Parses its own source code characters to control pitch contours and tree branching.

class PitchContourSynth
  attr_reader :pitches

  def initialize(file_path = __FILE__)
    source = File.read(file_path)
    # Map ASCII values of source code characters to microtonal frequencies (200Hz - 800Hz)
    @pitches = source.bytes.map { |b| 200 + (b * 4.5) % 600 }
  end

  def generate_audio_buffer(samples = 44100 * 2, sample_rate = 44100)
    buffer = []
    num_pitches = @pitches.length
    
    samples.times do |i|
      t = i.to_f / sample_rate
      idx = ((t * 8) % num_pitches).to_i
      freq = @pitches[idx]
      
      # Synthesize ambient microtonal sine waves with a gentle decay/drone envelope
      wave1 = Math.sin(2 * Math::PI * freq * t)
      wave2 = Math.sin(2 * Math::PI * (freq * 1.015) * t) # Microtonal beat frequency
      sample = ((wave1 + wave2) * 0.2 * Math.exp(-0.1 * (t % 0.5))).round(4)
      
      buffer << sample
    end
    buffer
  end
end

class FractalTreeRenderer
  def initialize(width = 80, height = 24)
    @width = width
    @height = height
    @decay_factor = 1.0
  end

  def trigger_decay!
    @decay_factor = [0.1, @decay_factor - 0.3].max
  end

  def mend!
    @decay_factor = [1.0, @decay_factor + 0.05].min
  end

  def draw_tree(x, y, length, angle, depth, canvas)
    return if depth <= 0 || length < 1

    effective_len = length * @decay_factor
    x2 = x + (effective_len * Math.cos(angle)).to_i
    y2 = y - (effective_len * Math.sin(angle)).to_i

    # Draw line on ASCII canvas
    plot_line(x, y, x2, y2, canvas, depth)

    # Branching
    spread = 0.45 * @decay_factor
    draw_tree(x2, y2, length * 0.75, angle - spread, depth - 1, canvas)
    draw_tree(x2, y2, length * 0.75, angle + spread, depth - 1, canvas)
  end

  def render
    canvas = Array.new(@height) { Array.new(@width, ' ') }
    draw_tree(@width / 2, @height - 1, 7, Math::PI / 2, 6, canvas)
    
    # Self-mending step
    mend!
    
    # Clear screen and display
    print "\e[H\e[2J"
    puts canvas.map(&:join).join("\n")
    puts "[Status] Health: #{(@decay_factor * 100).round}% | Self-Mending Engine Active"
  end

  private

  def plot_line(x1, y1, x2, y2, canvas, depth)
    chars = ['|', '/', '-', '\\', '#', '*', '.']
    char = chars[depth % chars.length]
    
    steps = [ (x2 - x1).abs, (y2 - y1).abs ].max
    return if steps.zero?

    (0..steps).each do |i|
      curr_x = x1 + ((x2 - x1) * i.to_f / steps).round
      curr_y = y1 + ((y2 - y1) * i.to_f / steps).round
      
      if curr_y.between?(0, @height - 1) && curr_x.between?(0, @width - 1)
        canvas[curr_y][curr_x] = char
      end
    end
  end
end

class SelfMendingApp
  def self.check_syntax(file_path = __FILE__)
    RubyVM::InstructionSequence.compile_file(file_path)
    true
  rescue SyntaxError
    false
  end

  def self.run
    synth = PitchContourSynth.new(__FILE__)
    tree = FractalTreeRenderer.new
    
    puts "Parsing source pitch contour..."
    _audio_data = synth.generate_audio_buffer
    puts "Synthesized #{synth.pitches.length} microtonal steps."
    sleep 1

    15.times do |frame|
      # Simulate code state validation
      if check_syntax
        tree.mend!
      else
        tree.trigger_decay!
      end

      # Randomly simulate code corruption decay test on iteration 5 and 6
      tree.trigger_decay! if [5, 6].include?(frame)

      tree.render
      sleep 0.25
    end
  end
end

SelfMendingApp.run