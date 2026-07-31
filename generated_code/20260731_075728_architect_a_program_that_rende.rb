# Cosmic Heap Map: Interactive procedural star map generated from Ruby's live memory heap
require 'io/console'
require 'objspace'

class CosmicHeapMap
  STAR_GLYPHS = ['·', '.', '•', '*', '✦', '✧', '★', '✸'].freeze
  SPECTRAL_COLORS = [
    "\e[38;5;39m",  # O - Blue
    "\e[38;5;81m",  # B - Deep Sky Blue
    "\e[38;5;255m", # A - White
    "\e[38;5;229m", # F - Pale Yellow
    "\e[38;5;220m", # G - Bright Yellow
    "\e[38;5;208m", # K - Orange
    "\e[38;5;196m"  # M - Red
  ].freeze
  RESET_COLOR = "\e[0m".freeze

  def initialize
    @cam_x = 0.0
    @cam_y = 0.0
    @zoom = 1.0
    @heap_expansions = [] # Buffer to hold live allocations on user demand
    scan_heap
  end

  # Scans ObjectSpace to convert live heap allocations and pointer addresses into star vectors
  def scan_heap
    @stars = []
    @constellations = Hash.new { |h, k| h[k] = [] }

    ObjectSpace.each_object do |obj|
      next if obj.equal?(self) || obj.is_a?(CosmicHeapMap)

      addr = obj.object_id
      size = (ObjectSpace.memsize_of(obj) rescue 8)
      cls = obj.class.to_s

      # Hash pointer address bit patterns to map coordinates
      hash = (addr ^ (addr >> 7) ^ (size << 3)) & 0xFFFFFFFF
      x = ((hash & 0xFFFF) - 0x7FFF) * 0.1
      y = (((hash >> 16) & 0xFFFF) - 0x7FFF) * 0.1

      # Derive luminosity and spectral classification from object size & pointer signatures
      brightness = (size + (addr & 0xFF)) % STAR_GLYPHS.size
      color = SPECTRAL_COLORS[addr % SPECTRAL_COLORS.size]

      star = {
        addr: addr,
        size: size,
        class: cls,
        x: x,
        y: y,
        glyph: STAR_GLYPHS[brightness],
        color: color
      }

      @stars << star
      @constellations[cls] << star if @constellations[cls].size < 10
    end

    # Retain prominent object classes to form constellation lines
    @constellations.select! { |_, v| v.size >= 3 }
  end

  # Allocates dynamic heap objects on command, mutating memory space and expanding the universe
  def mutate_heap!
    150.times do
      @heap_expansions << Array.new(rand(10..100)) { "StarSeed-#{rand}" }
      @heap_expansions << { star_seed: rand, memory_ptr: Time.now.to_f }
    end
    scan_heap
  end

  # Renders the interactive terminal canvas with constellations, stars, and real-time telemetry
  def render(width, height)
    buffer = Array.new(height) { Array.new(width, ' ') }
    color_buffer = Array.new(height) { Array.new(width, RESET_COLOR) }

    mid_x = width / 2.0
    mid_y = height / 2.0

    # Draw constellation lines grouping objects of identical Ruby class
    @constellations.each_value do |stars|
      stars.each_cons(2) do |s1, s2|
        draw_constellation_line(s1, s2, buffer, color_buffer, mid_x, mid_y, width, height)
      end
    end

    # Plot stars generated from heap pointers
    @stars.each do |star|
      sx = ((star[:x] - @cam_x) * @zoom + mid_x).round
      sy = ((star[:y] - @cam_y) * @zoom * 0.5 + mid_y).round # Aspect ratio tweak

      if sx >= 0 && sx < width && sy >= 1 && sy < height - 2
        buffer[sy][sx] = star[:glyph]
        color_buffer[sy][sx] = star[:color]
      end
    end

    # Output buffer with ANSI terminal escapes
    out = ["\e[H\e[2J"]
    total_mem = (ObjectSpace.memsize_of_all rescue @stars.sum { |s| s[:size] })

    out << "\e[1;36m=== RUBY HEAP COSMOS === Stars: #{@stars.size} | Constellations: #{@constellations.size} | Heap Mem: #{total_mem} bytes\e[0m"

    (1...(height - 2)).each do |y|
      row = ""
      current_color = RESET_COLOR
      (0...width).each do |x|
        c = color_buffer[y][x]
        if c != current_color
          row << c
          current_color = c
        end
        row << buffer[y][x]
      end
      row << RESET_COLOR if current_color != RESET_COLOR
      out << row
    end

    out << "\e[37m[WASD / Arrow Keys]: Pan (#{@cam_x.round(1)}, #{@cam_y.round(1)}) | [+/-]: Zoom (#{@zoom.round(2)}x) | [SPACE]: Mutate Heap | [Q]: Quit\e[0m"
    print out.join("\n")
  end

  # Bresenham's line algorithm to render constellation connections in terminal grid
  def draw_constellation_line(s1, s2, buffer, color_buffer, mid_x, mid_y, width, height)
    x0 = ((s1[:x] - @cam_x) * @zoom + mid_x).round
    y0 = ((s1[:y] - @cam_y) * @zoom * 0.5 + mid_y).round
    x1 = ((s2[:x] - @cam_x) * @zoom + mid_x).round
    y1 = ((s2[:y] - @cam_y) * @zoom * 0.5 + mid_y).round

    dx = (x1 - x0).abs
    dy = (y1 - y0).abs
    sx = x0 < x1 ? 1 : -1
    sy = y0 < y1 ? 1 : -1
    err = dx - dy

    cx, cy = x0, y0

    while true
      if cx >= 0 && cx < width && cy >= 1 && cy < height - 2
        if buffer[cy][cx] == ' '
          buffer[cy][cx] = '·'
          color_buffer[cy][cx] = "\e[38;5;240m"
        end
      end
      break if cx == x1 && cy == y1
      e2 = 2 * err
      if e2 > -dy
        err -= dy
        cx += sx
      end
      if e2 < dx
        err += dx
        cy += sy
      end
    end
  end

  # Interactive non-blocking raw terminal event loop
  def run
    STDIN.raw do |stdin|
      print "\e[?25l" # Hide terminal cursor
      loop do
        height, width = STDIN.winsize rescue [24, 80]
        render(width, height)

        if IO.select([stdin], nil, nil, 0.05)
          key = stdin.getc
          case key
          when 'q', 'Q', "\u0003"
            break
          when 'w', 'W', "\e[A"
            @cam_y -= 4.0 / @zoom
          when 's', 'S', "\e[B"
            @cam_y += 4.0 / @zoom
          when 'a', 'A', "\e[D"
            @cam_x -= 4.0 / @zoom
          when 'd', 'D', "\e[C"
            @cam_x += 4.0 / @zoom
          when '+', '='
            @zoom *= 1.25
          when '-', '_'
            @zoom = [@zoom / 1.25, 0.05].max
          when ' '
            mutate_heap!
          end
        end
      end
    ensure
      print "\e[?25h\e[0m\e[H\e[2J" # Restore cursor and clear screen on exit
    end
  end
end

CosmicHeapMap.new.run