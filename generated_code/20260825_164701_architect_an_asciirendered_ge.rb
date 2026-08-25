class CellularPoetryEcosystem
  WIDTH = 40
  HEIGHT = 16
  STAGES = %w[seed germ bloom decay echo]

  POETIC_DICTIONARY = {
    "000" => "void ",   "001" => "pulse ", "010" => "drift ", "011" => "light ",
    "100" => "wave ",   "101" => "sing ",  "102" => "flow ",  "111" => "spark "
  }

  def initialize(generations = 15)
    @generations = generations
    @grid = Array.new(HEIGHT) { Array.new(WIDTH) { rand < 0.25 ? 1 : 0 } }
    @poem_lines = []
    @frequencies = []
  end

  def evolve!
    new_grid = Array.new(HEIGHT) { Array.new(WIDTH, 0) }
    HEIGHT.times do |r|
      WIDTH.times do |c|
        neighbors = count_neighbors(r, c)
        alive = @grid[r][c] == 1
        new_grid[r][c] = (alive && (neighbors == 2 || neighbors == 3)) || (!alive && neighbors == 3) ? 1 : 0
      end
    end
    @grid = new_grid
  end

  def count_neighbors(r, c)
    count = 0
    (-1..1).each do |dr|
      (-1..1).each do |dc|
        next if dr == 0 && dc == 0
        nr, nc = (r + dr) % HEIGHT, (c + dc) % WIDTH
        count += @grid[nr][nc]
      end
    end
    count
  end

  def render_ascii
    @grid.map { |row| row.map { |cell| cell == 1 ? ["*", "o", "+", ".".freeze].sample : " " }.join }.join("\n")
  end

  def extract_poetic_line(gen)
    density = @grid.flatten.sum
    stage = STAGES[gen % STAGES.size]
    
    # Sample state clusters to build poetic imagery
    words = @grid.first(4).map do |row|
      chunk = row.first(3).join
      POETIC_DICTIONARY[chunk] || "breathe "
    end.join.strip

    "| Gen #{gen.to_s.rjust(2, '0')} [#{stage.upcase}] | #{words} (density: #{density})"
  end

  def map_to_frequency(gen)
    density = @grid.flatten.sum
    # Map cellular density to pentatonic frequency scale (C Major Pentatonic)
    scale = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25]
    freq = scale[density % scale.size] * (1 + (gen % 3) * 0.5)
    freq.round(2)
  end

  def run
    puts "========================================================="
    puts "  GENERATIVE CELLULAR ECOSYSTEM -> POEM -> SOUNDSCAPE   "
    puts "=========================================================\n\n"

    @generations.times do |g|
      puts "--- Generation #{g + 1} ---"
      puts render_ascii
      line = extract_poetic_line(g + 1)
      freq = map_to_frequency(g + 1)
      @poem_lines << line
      @frequencies << freq
      puts line
      puts "Sound Frequency: #{freq} Hz"
      puts "\n"
      evolve!
    end

    generate_html_soundscape
  end

  def generate_html_soundscape
    html_content = <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <title>Cellular Automata Soundscape</title>
        <style>
          body { background: #0f0f17; color: #00ffcc; font-family: monospace; padding: 2rem; }
          .poem { background: #1a1a2e; padding: 1rem; border-radius: 8px; margin-bottom: 1rem; white-space: pre-wrap; }
          button { background: #00ffcc; color: #0f0f17; border: none; padding: 0.75rem 1.5rem; font-weight: bold; cursor: pointer; border-radius: 4px; }
          button:hover { background: #00ccb3; }
        </style>
      </head>
      <body>
        <h1>Ecosystem Visual Poem & Soundscape</h1>
        <div class="poem">#{@poem_lines.join("\n")}</div>
        <button onclick="playSoundscape()">Play Compiled Web Audio Soundscape</button>

        <script>
          const frequencies = #{@frequencies.to_json};
          
          function playSoundscape() {
            const AudioContext = window.AudioContext || window.webkitAudioContext;
            const ctx = new AudioContext();
            
            frequencies.forEach((freq, index) => {
              const osc = ctx.createOscillator();
              const gain = ctx.createGain();
              
              osc.type = index % 2 === 0 ? 'sine' : 'triangle';
              osc.frequency.setValueAtTime(freq, ctx.currentTime + index * 0.4);
              
              gain.gain.setValueAtTime(0.001, ctx.currentTime + index * 0.4);
              gain.gain.exponentialRampToValueAtTime(0.2, ctx.currentTime + index * 0.4 + 0.05);
              gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + index * 0.4 + 0.35);
              
              osc.connect(gain);
              gain.connect(ctx.destination);
              
              osc.start(ctx.currentTime + index * 0.4);
              osc.stop(ctx.currentTime + index * 0.4 + 0.4);
            });
          }
        </script>
      </body>
      </html>
    HTML

    filename = "ecosystem_soundscape.html"
    File.write(filename, html_content)
    puts "========================================================="
    puts "Compiled audio player saved to #{filename}"
    puts "Open #{filename} in a web browser to play the audio!"
    puts "========================================================="
  end
end

CellularPoetryEcosystem.new(12).run