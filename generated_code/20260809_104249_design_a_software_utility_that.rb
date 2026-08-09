# GC Terrarium: Turning Ruby GC Logs into a Sound-Reactive Digital Eco-System
# Allocated objects grow as flora; deallocated objects decay into musical chords.

require 'io/console'

class GCTerrarium
  PLANT_TYPES = [
    { seed: '🌱', grown: '🌿', flower: '🌸', pitch: 60 }, # C4
    { seed: '🌱', grown: '🌵', flower: '🌼', pitch: 64 }, # E4
    { seed: '🌱', grown: '🌾', flower: '🌻', pitch: 67 }, # G4
    { seed: '🌱', grown: '🎋', flower: '🌺', pitch: 71 }, # B4
    { seed: '🌱', grown: '🍄', flower: '🪷', pitch: 72 }  # C5
  ]

  CHORDS = {
    major7: [0, 4, 7, 11],
    minor7: [0, 3, 7, 10],
    sus4:   [0, 5, 7, 12]
  }

  DECAY_STAGES = ['🥀', '🍂', '🍁', '✨', ' ']

  def initialize(width = 60, height = 18)
    @width = width
    @height = height
    @flora = {} # id -> {x, y, type, stage, health, age}
    @decomposing = [] # [{x, y, stage, frame, chord_notes}]
    @sound_waves = [] # Visual sound reactivity ripples
    @lock = Mutex.new
    @running = true
    @gc_stats = { allocs: 0, frees: 0 }
  end

  def start
    setup_terminal
    GC::Profiler.enable

    threads = []
    threads << Thread.new { simulate_gc_activity }
    threads << Thread.new { render_loop }

    trap('INT') { @running = false }
    threads.each(&:join)
  ensure
    restore_terminal
  end

  private

  def setup_terminal
    print "\e[?25l\e[2J" # Hide cursor, clear screen
  end

  restore_terminal = lambda do
    print "\e[?25h\e[0m\e[H\e[2J"
  end

  define_method(:restore_terminal, &restore_terminal)

  # Simulates continuous memory allocations & periodic GC sweeps
  def simulate_gc_activity
    heap = []
    while @running
      sleep(rand(0.05..0.2))

      @lock.synchronize do
        # 1. Allocation -> Spawns Flora
        if rand < 0.7
          1.upto(rand(1..3)) do
            obj = "Object_#{rand(10_000)}"
            heap << obj
            spawn_flora(obj.object_id)
            @gc_stats[:allocs] += 1
          end
        end

        # 2. Deallocation / GC Cycle -> Triggers Decomposition & Sound Chord
        if heap.size > 25 || rand < 0.3
          freed = heap.shift(rand(3..8))
          freed.each do |obj|
            trigger_decay(obj.object_id)
            @gc_stats[:frees] += 1
          end
          GC.start(full_mark: false)
        end
      end
    end
  end

  def spawn_flora(id)
    x = rand(2..@width - 3)
    y = rand(3..@height - 2)
    @flora[id] = {
      x: x,
      y: y,
      type: PLANT_TYPES.sample,
      age: 0,
      bloom: false
    }
  end

  def trigger_decay(id)
    plant = @flora.delete(id)
    return unless plant

    # Generate a musical chord based on the plant's root pitch
    base_pitch = plant[:type][:pitch]
    chord_pattern = CHORDS.values.sample
    chord_notes = chord_pattern.map { |interval| base_pitch + interval }

    @decomposing << {
      x: plant[:x],
      y: plant[:y],
      stage: 0,
      notes: chord_notes
    }

    # Create soundwave ripple visualizer
    @sound_waves << { x: plant[:x], y: plant[:y], radius: 1, max: rand(3..6) }
    play_audio_tone(chord_notes.first)
  end

  # Emit audio tone using terminal bell or OS synthesizer
  def play_audio_tone(midi_pitch)
    # Simple terminal bell fallback for audible feedback
    print "\a"
    # Async sound synthesis via system call if available (macOS / Linux fallback)
    Thread.new do
      freq = 440.0 * (2.0**((midi_pitch - 69) / 12.0))
      if RUBY_PLATFORM =~ /darwin/
        system("afplay /System/Library/Sounds/Tink.aiff >/dev/null 2>&1 &")
      elsif RUBY_PLATFORM =~ /linux/
        system("speaker-test -t sine -f #{freq.to_i} -l 1 >/dev/null 2>&1 &")
      end
    end
  end

  def render_loop
    while @running
      update_state
      draw_terrarium
      sleep(0.08)
    end
  end

  def update_state
    @lock.synchronize do
      # Age flora
      @flora.each_value do |f|
        f[:age] += 1
        f[:bloom] = true if f[:age] > 15
      end

      # Progress decomposition into energy
      @decomposing.each do |d|
        d[:stage] += 1
      end
      @decomposing.reject! { |d| d[:stage] >= DECAY_STAGES.size }

      # Expand soundwaves
      @sound_waves.each { |w| w[:radius] += 1 }
      @sound_waves.reject! { |w| w[:radius] > w[:max] }
    end
  end

  def draw_terrarium
    buffer = String.new
    buffer << "\e[H" # Move cursor home

    # Header
    buffer << "\e[1;32m🌱 GC SOUND-REACTIVE TERRARIUM 🌱\e[0m\n"
    buffer << "\e[90mAllocations: #{@gc_stats[:allocs]} | Collections: #{@gc_stats[:frees]} | Active Flora: #{@flora.size}\e[0m\n"
    buffer << "┌" + "─" * @width + "┐\n"

    # Grid map
    grid = Array.new(@height) { Array.new(@width, ' ') }

    @lock.synchronize do
      # Draw Soundwaves
      @sound_waves.each do |w|
        (-w[:radius]..w[:radius]).each do |dx|
          (-w[:radius]..w[:radius]).each do |dy|
            if (dx.abs == w[:radius] || dy.abs == w[:radius])
              nx, ny = w[:x] + dx, w[:y] + dy
              if nx.between?(0, @width - 1) && ny.between?(0, @height - 1)
                grid[ny][nx] = "\e[36m~\e[0m"
              end
            end
          end
        end
      end

      # Draw Flora
      @flora.each_value do |f|
        icon = f[:bloom] ? f[:type][:flower] : (f[:age] > 5 ? f[:type][:grown] : f[:type][:seed])
        grid[f[:y]][f[:x]] = icon
      end

      # Draw Decay / Harmonics
      @decomposing.each do |d|
        symbol = DECAY_STAGES[d[:stage]] || '✨'
        grid[d[:y]][d[:x]] = "\e[35m#{symbol}\e[0m"
      end
    end

    # Render frame
    grid.each do |row|
      buffer << "│" + row.join + "│\n"
    end
    buffer << "└" + "─" * @width + "┘\n"
    buffer << "\e[90mPress Ctrl+C to exit. Deallocations decay into musical chord frequencies.\e[0m"

    print buffer
  end
end

GCTerrarium.new.start