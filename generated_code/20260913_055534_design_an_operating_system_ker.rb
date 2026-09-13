# Ruby Kernel Engine translating Esoteric Array DSL into ASCII Sheet Music
# Synthesizes real-time atmospheric sensor feeds into evolving polyphonic soundscapes.

class EsotericKernelEngine
  PITCHES = %w[C D E F G A B]
  
  def initialize
    @time_step = 0
    # Kernel registers storing real-time atmospheric telemetry (Temp, Pressure, Humidity, CO2)
    @registers = { temp: 21.5, pressure: 1013.2, humidity: 45.0, co2: 412.0 }
  end

  # Simulated real-time sensor interrupts that mutate system registers dynamically
  def fetch_sensor_interrupts!
    @time_step += 1
    @registers[:temp] += rand(-0.4..0.4)
    @registers[:pressure] += rand(-1.2..1.2)
    @registers[:humidity] = (@registers[:humidity] + rand(-0.8..0.8)).clamp(0.0, 100.0)
    @registers[:co2] += rand(-2.0..2.0)
  end

  # Executes esoteric array language vector ops directly on raw kernel memory
  def execute_eso_array_lang(telemetry)
    # Esoteric Array DSL pipeline: Shift, Scale, Dynamic Interleave, Phase Map
    raw_vector = telemetry.values
    scaled     = raw_vector.map.with_index { |v, i| (v * (i + 1) * 0.137) % 28 }
    poly_voices = scaled.each_slice(2).flat_map { |a, b| [a, b, (a + (b || 0)) / 2.0] }
    
    # Map raw numeric vector to 4 distinct musical octave polyphony layers
    poly_voices.first(4).map.with_index do |val, voice_idx|
      note_idx = val.floor % PITCHES.size
      octave   = 3 + voice_idx
      duration = (val % 2 == 0) ? :half : :quarter
      { pitch: PITCHES[note_idx], octave: octave, duration: duration, register_val: val.round(1) }
    end
  end

  # Renders the compiled polyphonic array into visual ASCII stave notation
  def compile_ascii_sheet_music(polyphonic_frame)
    stave_lines = { 'B' => 0, 'A' => 1, 'G' => 2, 'F' => 3, 'E' => 4 }
    grid = Array.new(5) { Array.new(36, ' ') }
    
    polyphonic_frame.each_with_index do |note, idx|
      line_idx = stave_lines[note[:pitch]] || 2
      col_pos  = idx * 8 + 4
      symbol   = note[:duration] == :half ? 'O' : '*'
      
      grid[line_idx][col_pos] = symbol
      grid[line_idx][col_pos + 1] = note[:octave].to_s
    end

    buffer = []
    buffer << "=== KERNEL ATMOSPHERIC SOUNDSCAPE | STEP ##{@time_step} ==="
    buffer << "TELEMETRY: Temp: #{@registers[:temp].round(1)}C | Press: #{@registers[:pressure].round(1)}hPa | Hum: #{@registers[:humidity].round(1)}% | CO2: #{@registers[:co2].round(1)}ppm"
    buffer << "┌" + "─" * 38 + "┐"
    
    line_names = %w[B4 A4 G4 F4 E4]
    grid.each_with_index do |row, i|
      buffer << "#{line_names[i]} ───#{row.join}───"
    end
    
    buffer << "└" + "─" * 38 + "┘"
    buffer << "VOICE POLYPHONY: " + polyphonic_frame.map { |n| "#{n[:pitch]}#{n[:octave]}(#{n[:duration][0].upcase})" }.join(' | ')
    buffer.join("\n")
  end

  def run_kernel_loop(iterations = 4)
    iterations.times do
      fetch_sensor_interrupts!
      polyphonic_frame = execute_eso_array_lang(@registers)
      puts compile_ascii_sheet_music(polyphonic_frame)
      puts "\n"
      sleep(0.3)
    end
  end
end

# Main Execution Trigger
kernel = EsotericKernelEngine.new
kernel.run_kernel_loop(3)