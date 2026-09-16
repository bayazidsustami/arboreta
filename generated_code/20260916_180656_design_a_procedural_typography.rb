#!/usr/bin/env ruby
# frozen_string_literal: true

# Procedural Typography & Atmospheric Pressure Morphing Engine
# Renders a rotating ring of morphing glyphs influenced by real-time barometric pressure.

require 'io/console'

class WeatherStation
  def initialize
    @base_pressure = 1013.25 # hPa standard sea level
  end

  # Simulates real-time pressure fluctuations (can be extended to fetch from an API or hardware sensor)
  def current_pression
    @base_pressure + Math.sin(Time.now.to_f / 4.0) * 12.0 + (rand - 0.5) * 1.5
  end
end

class TypographyEngine
  def initialize
    @weather = WeatherStation.new
    @alphabet = ('A'..'Z').to_a
    @angle = 0.0
  end

  def run
    # Clear screen and hide cursor
    print "\e[2J\e[?25l"
    
    loop do
      pressure = @weather.current_pression
      delta = pressure - 1013.25
      
      # Reset cursor to top-left for smooth animation
      print "\e[H"
      
      puts "=== PROCEDURAL TYPOGRAPHY ENGINE ==="
      puts "Atmospheric Pressure: #{pressure.round(2)} hPa (Delta: #{delta.round(2)})"
      puts "Morph Deformation: #{(delta * 0.08).round(2)} | Rotation: #{@angle.round(2)} rad"
      puts "-" * 42

      render_scene(delta)

      @angle += 0.04
      sleep(0.04)
    end
  ensure
    # Ensure cursor is restored on exit
    print "\e[?25h\n"
  end

  private

  def render_scene(delta)
    width, height = 64, 16
    grid = Array.new(height) { Array.new(width, ' ') }

    @alphabet.each_with_index do |char, idx|
      angle_offset = idx * (2 * Math.PI / @alphabet.length) + @angle
      
      # Procedural radius morphing driven by pressure delta
      dynamic_radius = 20.0 + (delta * 0.15) * Math.sin(angle_offset * 3)
      
      x3d = Math.cos(angle_offset) * dynamic_radius
      y3d = Math.sin(angle_offset) * (dynamic_radius * 0.35) # Perspective squash
      z3d = Math.sin(angle_offset)

      # Depth cull for front-facing hemisphere
      next if z3d < -0.3

      screen_x = (width / 2 + x3d).to_i
      screen_y = (height / 2 + y3d).to_i

      if screen_x >= 0 && screen_x < width && screen_y >= 0 && screen_y < height
        grid[screen_y][screen_x] = char
      end
    end

    grid.each { |row| puts row.join }
  end
end

if __FILE__ == $0
  engine = TypographyEngine.new
  trap('INT') { exit }
  engine.run
end