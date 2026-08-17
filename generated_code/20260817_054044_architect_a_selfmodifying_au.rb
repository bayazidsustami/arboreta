require 'io/console'

class AudioASCIIEngine
  WIDTH = 80
  HEIGHT = 24
  SAMPLES = 64
  
  CHARS = [' ', '.', ':', '-', '=', '+', '*', '%', '@', '#']
  
  DYNAMIC_PALETTES = [
    # Neon Cyan & Magenta
    ->(v) { "\e[38;2;#{ (v * 255).to_i };#{ ((1 - v) * 100).to_i };255m" },
    # Deep Cyberpunk Sunset
    ->(v) { "\e[38;2;255;#{ (v * 150).to_i };#{ ((1 - v) * 200).to_i }m" },
    # Matrix Green / Acid
    ->(v) { "\e[38;2;#{ (v * 100).to_i };#{ (v * 255).to_i };#{ ((1 - v) * 50).to_i }m" },
    # Fire Spectrum
    ->(v) { "\e[38;2;255;#{ (v**2 * 255).to_i };#{ (v**4 * 100).to_i }m" }
  ]

  def initialize
    @t = 0.0
    @audio_sim = Array.new(SAMPLES, 0.0)
    @palette_index = 0
    @phrases = ["SYNTH", "PULSE", "RUBY", "AUDIO", "FLOW", "MORPH", "WAVE"]
    @phrase_idx = 0
    @base_dna = method(:render_wave_canvas)
  end

  def run
    setup_terminal
    loop do
      read_input
      synthesize_audio_input
      evolve_source_dna if (@t % 15.0).between?(0, 0.05)
      
      canvas = render_frame
      display(canvas)
      
      @t += 0.08
      sleep 0.03
    end
  rescue Interrupt
    cleanup
  end

  private

  def setup_terminal
    print "\e[?25l\e[2J" # Hide cursor & clear screen
  end

  def cleanup
    print "\e[?25h\e[0m\e[2J\e[H" # Restore cursor & colors
    puts "Engine Safely Terminated."
  end

  def read_input
    return unless $stdin.ready?
    char = $stdin.getch
    case char
    when ' ' then @palette_index = (@palette_index + 1) % DYNAMIC_PALETTES.size
    when 'w' then @phrase_idx = (@phrase_idx + 1) % @phrases.size
    when 'q' then raise Interrupt
    end
  end

  # Simulates live spectral frequency analysis (Bass, Mid, Treble) with procedural harmonics
  def synthesize_audio_input
    bass = (Math.sin(@t * 1.5) ** 4) * 0.9 + (Math.cos(@t * 0.7) * 0.2)
    mids = (Math.sin(@t * 3.2 + 1.0) ** 2) * 0.7
    treble = (Math.sin(@t * 8.0) * Math.cos(@t * 4.0)).abs * 0.8
    
    SAMPLES.times do |i|
      pos = i.to_f / SAMPLES
      wave = case pos
             when 0.0..0.33 then bass * Math.sin(pos * 10 + @t * 2)
             when 0.33..0.66 then mids * Math.sin(pos * 20 - @t * 3)
             else treble * Math.sin(pos * 40 + @t * 5)
             end
      @audio_sim[i] = [@audio_sim[i] * 0.6 + wave.abs * 0.4, 1.0].min
    end
  end

  # Self-modifying engine logic: dynamically overwrites core rendering behavior at runtime
  def evolve_source_dna
    eval_code = case rand(3)
    when 0
      "def render_wave_canvas(x, y, amp, bass)\n" \
      "  Math.sin(x * 0.15 + @t * 2.0) * Math.cos(y * 0.2 - bass * 3.0) + (amp * 0.8)\n" \
      "end"
    when 1
      "def render_wave_canvas(x, y, amp, bass)\n" \
      "  dist = Math.sqrt((x - #{WIDTH/2})**2 + (y - #{HEIGHT/2})**2)\n" \
      "  Math.sin(dist * 0.3 - @t * 3.0 + amp * 4.0) * (1.0 - [dist/30.0, 1.0].min)\n" \
      "end"
    else
      "def render_wave_canvas(x, y, amp, bass)\n" \
      "  Math.sin(x * 0.08 + y * 0.12 + @t) * Math.sin(amp * 5.0 - y * 0.3)\n" \
      "end"
    end
    
    self.class.class_eval(eval_code)
  end

  def render_wave_canvas(x, y, amp, bass)
    Math.sin(x * 0.1 + @t) + Math.cos(y * 0.2 + amp * 2.0)
  end

  def render_frame
    buffer = Array.new(HEIGHT) { Array.new(WIDTH, ' ') }
    color_buffer = Array.new(HEIGHT) { Array.new(WIDTH, "") }
    
    palette = DYNAMIC_PALETTES[@palette_index]
    bass_freq = @audio_sim[0..10].sum / 11.0
    word = @phrases[@phrase_idx]

    # Render procedural ASCII landscape based on dynamic audio modulation
    HEIGHT.times do |y|
      WIDTH.times do |x|
        freq_idx = ((x.to_f / WIDTH) * (SAMPLES - 1)).to_i
        amp = @audio_sim[freq_idx] || 0.0
        
        # Invoke dynamic or evolved wave calculation
        val = render_wave_canvas(x, y, amp, bass_freq)
        normalized = ((val + 1.0) / 2.0).clamp(0.0, 1.0)
        
        char_idx = (normalized * (CHARS.size - 1)).round
        buffer[y][x] = CHARS[char_idx]
        color_buffer[y][x] = palette.call(normalized)
      end
    end

    # Overlay dynamic audio-reactive ASCII typography at center canvas
    text_scale = 1.0 + (bass_freq * 0.8)
    start_x = (WIDTH - (word.length * 2 * text_scale)).to_i / 2
    center_y = HEIGHT / 2

    word.chars.each_with_index do |char, char_i|
      cx = start_x + (char_i * 2 * text_scale).to_i
      next if cx < 0 || cx >= WIDTH - 2
      
      # Transform typography relative to dynamic frequencies
      y_offset = (Math.sin(@t * 4.0 + char_i) * (bass_freq * 4.0)).to_i
      cy = center_y + y_offset
      next if cy < 1 || cy >= HEIGHT - 1

      3.times do |dx|
        3.times do |dy|
          target_x = cx + dx
          target_y = cy + dy - 1
          if target_x.between?(0, WIDTH - 1) && target_y.between?(0, HEIGHT - 1)
            buffer[target_y][target_x] = (dx == 1 && dy == 1) ? char : '+'
            color_buffer[target_y][target_x] = "\e[38;2;255;255;255m\e[1m" # Highlight text
          end
        end
      end
    end

    # Composite final ANSI string output buffer
    out = "\e[H"
    HEIGHT.times do |y|
      WIDTH.times do |x|
        out << color_buffer[y][x] << buffer[y][x]
      end
      out << "\n"
    end
    out << "\e[0m\e[K[SPACE]: Palette | [W]: Switch Word | [Q]: Quit | Status: Dynamic Engine Evolving..."
  end

  def display(frame)
    print frame
    $stdout.flush
  end
end

AudioASCIIEngine.new.run