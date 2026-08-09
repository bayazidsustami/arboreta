# Self-Rewriting ASCII Memory Kaleidoscope & Procedural Poetry Glitch Engine
# Measures system RAM to drive symmetrical ASCII matrices and poetry generation.
# As available RAM decreases, coherent poetry degrades into glitched visual noise.

require 'io/console'

# Memory metrics collector supporting Linux, macOS, and graceful fallbacks
def get_memory_info
  if File.exist?('/proc/meminfo')
    mem = {}
    File.readlines('/proc/meminfo').each do |line|
      parts = line.split(':')
      mem[parts[0].trim] = parts[1].to_i * 1024 if parts.size == 2 rescue nil
    end
    total = mem['MemTotal'] || 1
    available = mem['MemAvailable'] || mem['MemFree'] || total
    return (available.to_f / total.to_f).clamp(0.05, 1.0)
  elsif RUBY_PLATFORM =~ /darwin/
    vm = `vm_stat 2>/dev/null`
    pages_free = vm[/Pages free:\s+(\d+)/, 1].to_i
    pages_spec = vm[/Pages speculative:\s+(\d+)/, 1].to_i
    pages_inactive = vm[/Pages inactive:\s+(\d+)/, 1].to_i
    pages_active = vm[/Pages active:\s+(\d+)/, 1].to_i
    pages_wired = vm[/Pages wired down:\s+(\d+)/, 1].to_i
    total_pages = [pages_free + pages_spec + pages_inactive + pages_active + pages_wired, 1].max
    avail_pages = pages_free + pages_spec + pages_inactive
    return (avail_pages.to_f / total_pages.to_f).clamp(0.05, 1.0)
  end
  # Simulated dynamic pressure wave fallback if system metrics are unavailable
  (0.5 + 0.45 * Math.sin(Time.now.to_f * 0.5)).clamp(0.05, 1.0)
rescue
  (0.5 + 0.45 * Math.sin(Time.now.to_f * 0.5)).clamp(0.05, 1.0)
end

# Poetry vocabulary seeds for dynamic procedural poem generation
NOUNS = %w[ether byte echo current shadow pulse void cycle silicon crystal mirror flux dynamic threshold spark]
VERBS = %w[weaves bleeds hums refracts dissolves drifts ignites expands echoes glimmers fractures flows]
ADJS  = %w[luminous silent digital fractal transient infinite glowing chaotic frozen recursive shifting]
GLITCH_CHARS = %w[@ # $ % & * ! ? + = ~ ^ < > / \ | : ; █ ▓ ▒ ░ ░ ▒ ▓ █ Ϡ ϡ Ϙ Ϟ Ϛ ϛ Ϝ Ϟ]

# Generates procedural poem line or glitched string based on RAM health ratio (0.0 to 1.0)
def generate_poetry_line(mem_ratio)
  if rand > (mem_ratio * 1.2)
    # Devolve into glitched noise when memory pressure is high
    len = rand(20..45)
    Array.new(len) { GLITCH_CHARS.sample }.join
  else
    # Coherent procedural poetry structure
    templates = [
      "the %s %s %s through %s",
      "when %s %s, the %s becomes %s",
      "a %s %s of %s in %s",
      "every %s %s inside the %s"
    ]
    sprintf(templates.sample, ADJS.sample, NOUNS.sample, VERBS.sample, NOUNS.sample)
  end
end

# Renders octal-symmetric ASCII kaleidoscope grid centered around memory state
def render_kaleidoscope(width, height, frame, mem_ratio)
  half_w = width / 2
  half_h = height / 2
  grid = Array.new(height) { " " * width }
  palette = mem_ratio > 0.4 ? " .:-=+*#%@" : GLITCH_CHARS.join

  (0...half_h).each do |y|
    (0...half_w).each do |x|
      dx = (x - half_w / 2.0) / (half_w / 2.0)
      dy = (y - half_h / 2.0) / (half_h / 2.0)
      dist = Math.sqrt(dx * dx + dy * dy)
      angle = Math.atan2(dy, dx)
      
      # Modulate symmetry fold frequency with memory availability
      folds = (4 + (1.0 - mem_ratio) * 12).to_i
      folded_angle = (angle * folds / (2 * Math::PI)).sin rescue Math.sin(angle * folds)
      
      val = Math.sin(dist * 8.0 - frame * 0.15 + folded_angle * 3.0)
      
      # Inject corruption noise into visual grid as RAM drops
      if rand > mem_ratio
        char = GLITCH_CHARS.sample
      else
        idx = ((val + 1.0) / 2.0 * (palette.length - 1)).to_i.clamp(0, palette.length - 1)
        char = palette[idx]
      end

      # Octal quarter-mirror reflection
      cx1, cx2 = half_w - 1 - x, half_w + x
      cy1, cy2 = half_h - 1 - y, half_h + y

      grid[cy1][cx1] = char rescue nil
      grid[cy1][cx2] = char rescue nil
      grid[cy2][cx1] = char rescue nil
      grid[cy2][cx2] = char rescue nil
    end
  end
  grid
end

# Terminal display driver with self-rewriting frame loop
def main
  $stdout.sync = true
  print "\e[?25l\e[2J" # Hide cursor and clear screen

  frame = 0
  poetry_buffer = []
  max_poetry_lines = 4

  loop do
    begin
      rows, cols = $stdout.winsize rescue [24, 80]
      cols = [cols, 40].max
      rows = [rows, 15].max
      
      mem_ratio = get_memory_info
      k_height = [rows - max_poetry_lines - 3, 8].max
      
      grid = render_kaleidoscope(cols, k_height, frame, mem_ratio)
      
      # Evolve poetry periodically based on frame ticks
      if frame % 4 == 0
        poetry_buffer.unshift(generate_poetry_line(mem_ratio))
        poetry_buffer.pop if poetry_buffer.size > max_poetry_lines
      end

      # Self-rewrite terminal canvas using ANSI cursor movement
      buffer = "\e[1;1H"
      
      # Header status bar
      status = " [ RAM AVAILABLE: %5.1f%% ]  " % (mem_ratio * 100)
      bar_width = [cols - status.length - 4, 10].max
      filled = (bar_width * mem_ratio).to_i
      bar = "█" * filled + "░" * (bar_width - filled)
      buffer << "\e[1;36m#{status}[#{bar}]\e[0m\n"
      
      # Kaleidoscope output
      grid.each do |line|
        color = mem_ratio > 0.5 ? "\e[34m" : (mem_ratio > 0.25 ? "\e[33m" : "\e[31m")
        buffer << "#{color}#{line}\e[0m\n"
      end

      # Procedural poetry section
      buffer << "\e[1;35m--- PROCEDURAL MEMORY ECHOES ---\e[0m\n"
      poetry_buffer.each do |poem|
        buffer << poem.center(cols)[0...cols] << "\n"
      end

      print buffer
      frame += 1
      sleep 0.08
    rescue Interrupt
      break
    end
  end
ensure
  print "\e[?25h\e[0m\e[2J\e[1;1H" # Restore cursor and clean terminal
end

main