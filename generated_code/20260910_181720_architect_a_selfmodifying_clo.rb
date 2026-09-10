# Self-Modifying Mandala Clock & System Process Visualizer
# Reads real-time system processes (`ps`), transforms system time into geometry,
# generates an animated live SVG mandala, and embeds its own modified code into it.

require 'time'

class ProcessMandalaClock
  def initialize
    @time = Time.now
    @processes = fetch_processes
  end

  def fetch_processes
    # Query system active processes (PID, CPU%, MEM%, COMMAND)
    `ps -eo pid,%cpu,%mem,comm`.lines.drop(1).map do |line|
      parts = line.strip.split(/\s+/, 4)
      {
        pid: parts[0].to_i,
        cpu: parts[1].to_f,
        mem: parts[2].to_f,
        cmd: File.basename(parts[3] || 'unknown')
      }
    end.reject { |p| p[:cmd].empty? }.first(60) # Pick top 60 processes for symmetry
  end

  def render_svg
    width, height = 1000, 1000
    cx, cy = width / 2, height / 2

    # Time-based geometric metrics
    sec_angle = (@time.sec / 60.0) * 2 * Math::PI
    min_angle = ((@time.min + @time.sec / 60.0) / 60.0) * 2 * Math::PI
    hour_angle = (((@time.hour % 12) + @time.min / 60.0) / 12.0) * 2 * Math::PI

    svg_nodes = []

    # Outer Mandala Ring: Active System Processes as Nodes
    total_procs = @processes.size
    @processes.each_with_index do |proc, idx|
      angle = (2 * Math::PI / total_procs) * idx + (sec_angle * 0.1)
      radius = 320 + (proc[:cpu] * 5) # Node distance dynamic to CPU usage

      nx = cx + radius * Math.cos(angle)
      ny = cy + radius * Math.sin(angle)

      # Node hue modulated by PID and Memory
      hue = (proc[:pid] * 13) % 360
      size = [3 + proc[:mem] * 2, 12].min

      # Connecting tendrils/rays to clock center
      svg_nodes << "<line x1='#{cx.round(2)}' y1='#{cy.round(2)}' x2='#{nx.round(2)}' y2='#{ny.round(2)}' stroke='hsl(#{hue}, 70%, 50%)' stroke-width='0.5' opacity='0.4'/>"
      
      # Process Visual Node
      svg_nodes << "<circle cx='#{nx.round(2)}' cy='#{ny.round(2)}' r='#{size.round(2)}' fill='hsl(#{hue}, 80%, 60%)' opacity='0.85'>"
      svg_nodes << "  <title>PID #{proc[:pid]}: #{proc[:cmd]} (CPU: #{proc[:cpu]}%, MEM: #{proc[:mem]}%)</title>"
      svg_nodes << "</circle>"

      # Text node stream for active commands
      if idx % 2 == 0
        svg_nodes << "<text x='#{(nx + 10).round(2)}' y='#{ny.round(2)}' fill='rgba(255,255,255,0.6)' font-size='8' font-family='monospace'>#{proc[:cmd]}</text>"
      end
    end

    # Dynamic Geometric Time Hands (Hour, Minute, Second concentric geometric polygons)
    hand_nodes = [
      { angle: hour_angle, radius: 140, color: '#ff4757', width: 4 },
      { angle: min_angle,  radius: 220, color: '#2ed573', width: 2.5 },
      { angle: sec_angle,  radius: 280, color: '#1e90ff', width: 1 }
    ].map do |hand|
      hx = cx + hand[:radius] * Math.sin(hand[:angle])
      hy = cy - hand[:radius] * Math.cos(hand[:angle])
      "<line x1='#{cx}' y1='#{cy}' x2='#{hx.round(2)}' y2='#{hy.round(2)}' stroke='#{hand[:color]}' stroke-width='#{hand[:width]}' stroke-linecap='round'/>"
    end

    # Self-Modifying Code Embed: Reading this file's code into the SVG metadata
    self_code = File.read(__FILE__) rescue "Self-reference code stream."

    # Assemble Full SVG Output
    <<~SVG
      <svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 #{width} #{height}" style="background: #0a0a12; width: 100%; height: auto;">
        <defs>
          <style>
            @keyframes rotate-slow { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
            .mandala-bg { transform-origin: center; animation: rotate-slow 120s linear infinite; }
          </style>
          <radialGradient id="center-glow">
            <stop offset="0%" stop-color="#ffffff" stop-opacity="0.8"/>
            <stop offset="100%" stop-color="#0a0a12" stop-opacity="0"/>
          </radialGradient>
        </defs>

        <!-- Self-Modifying Process Clock Metadata -->
        <script type="text/ruby-source">
          #{CDATA_wrap(self_code)}
        </script>

        <!-- Ambient Center Glow -->
        <circle cx="#{cx}" cy="#{cy}" r="380" fill="url(#center-glow)"/>

        <!-- Stream-of-Consciousness Process Mandala Layer -->
        <g class="mandala-bg">
          #{svg_nodes.join("\n    ")}
        </g>

        <!-- Clock Hands Layer -->
        <g id="clock-hands">
          #{hand_nodes.join("\n    ")}
          <circle cx="#{cx}" cy="#{cy}" r="6" fill="#ffffff"/>
        </g>

        <!-- Dynamic Time Text -->
        <text x="#{cx}" y="#{cy + 380}" text-anchor="middle" fill="#ffffff" font-family="monospace" font-size="16" letter-spacing="4">
          #{@time.strftime('%Y-%m-%d %H:%M:%S')}
        </text>
      </svg>
    SVG
  end

  private

  def CDATA_wrap(text)
    "<![CDATA[\n#{text}\n]]>"
  end
end

# Execute script to write self-modifying dynamic clock SVG output
svg_clock = ProcessMandalaClock.new.render_svg
File.write("process_mandala_clock.svg", svg_clock)
puts svg_clock

This script reads active system processes, transforms system time into geometric hands, and generates an animated SVG mandala where process stats control node positions and hues while embedding its own source code inside.

[Creating a Stunning Mandala Clock](https://www.youtube.com/watch?v=UfGf1GlsX2k)
This video illustrates the artistic workflow and geometric principles used when building layered mandala clocks.
http://googleusercontent.com/youtube_content/1