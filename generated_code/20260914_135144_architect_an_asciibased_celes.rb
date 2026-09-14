#!/usr/bin/env ruby
# Celestial Navigator: Translates real-time system metrics into a generative ASCII star map.
# - CPU spikes trigger hyper-localized Solar Flares (🔥/💥).
# - High/growing memory usage manifests as decaying Supernovas (🌟 -> ✨ -> 🌫️).
# - Active system load generates a dynamic background constellation field.

require 'io/console'

class CelestialNavigator
  MAP_WIDTH = 70
  MAP_HEIGHT = 20

  SOLAR_FLARE_SYMBOLS = ['💥', '🔥', '⚡', '☀️']
  SUPERNOVA_STAGES   = ['🌟', '✨', '💫', '░']
  BACKGROUND_STARS   = ['.', '·', '°', ' ', ' ', ' ']

  def initialize
    @supernovas = []
    @prev_memory = get_memory_mb
  end

  def run
    print "\e[2J\e[H\e[?25l" # Clear screen & hide cursor
    trap('INT') { cleanup }

    loop do
      cpu_load = get_cpu_load
      curr_memory = get_memory_mb
      mem_delta = curr_memory - @prev_memory
      @prev_memory = curr_memory

      # Spawn supernova on significant memory expansion or high total memory threshold
      if mem_delta > 1.5 || (curr_memory > 500 && rand < 0.3)
        @supernovas << { x: rand(2...MAP_WIDTH - 2), y: rand(2...MAP_HEIGHT - 2), stage: 0 }
      end

      render_map(cpu_load, curr_memory)
      sleep 0.4
    end
  rescue Interrupt
    cleanup
  end

  private

  def get_cpu_load
    # Cross-platform CPU load sampling (estimates load percentage 0-100)
    if RUBY_PLATFORM =~ /darwin/
      `ps -A -o %cpu | awk '{s+=$1} END {print s}'`.to_f / 4.0
    elsif RUBY_PLATFORM =~ /linux/
      `top -bn1 | grep "Cpu(s)" | sed "s/.*, *\\([0-9.]*\\)%* id.*/\\1/"`.strip.to_f.yield_self { |idle| 100.0 - idle }
    else
      rand(5.0..45.0) # Fallback heuristic
    end
  rescue
    rand(10.0..30.0)
  end

  def get_memory_mb
    # Returns resident set size in MB
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    100.0
  end

  def render_map(cpu, mem)
    buffer = Array.new(MAP_HEIGHT) { Array.new(MAP_WIDTH) { BACKGROUND_STARS.sample } }

    # Render CPU Solar Flares
    if cpu > 15.0
      flare_count = [(cpu / 15.0).to_i, 8].min
      flare_count.times do
        fx = rand(1...MAP_WIDTH - 1)
        fy = rand(1...MAP_HEIGHT - 1)
        buffer[fy][fx] = SOLAR_FLARE_SYMBOLS.sample
      end
    end

    # Render & update decaying Memory Supernovas
    @supernovas.reject! { |nova| nova[:stage] >= SUPERNOVA_STAGES.size }
    @supernovas.each do |nova|
      buffer[nova[:y]][nova[:x]] = SUPERNOVA_STAGES[nova[:stage]]
      nova[:stage] += 1 if rand < 0.5 # Decaying state transition
    end

    # Construct ANSI frame
    frame = "\e[H"
    frame << "╭" + "─" * MAP_WIDTH + "╮\n"
    frame << "│" + " CELESTIAL NAVIGATOR // REAL-TIME SYSTEM STAR MAP ".center(MAP_WIDTH) + "│\n"
    frame << "├" + "─" * MAP_WIDTH + "┤\n"

    buffer.each do |row|
      frame << "│" + row.join + "│\n"
    end

    frame << "├" + "─" * MAP_WIDTH + "┤\n"
    status = " CPU: #{'%.1f' % cpu}% #{cpu > 40 ? '🔥 [FLARING]' : '✨ [STABLE]'} | RSS: #{'%.1f' % mem}MB | SUPERNOVAS: #{@supernovas.size} "
    frame << "│" + status.center(MAP_WIDTH) + "│\n"
    frame << "╰" + "─" * MAP_WIDTH + "╯\n"

    print frame
  end

  def cleanup
    print "\e[?25h\e[2J\e[H" # Restore cursor and clear screen
    exit
  end
end

CelestialNavigator.new.run