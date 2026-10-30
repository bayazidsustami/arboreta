#!/usr/bin/env ruby
# frozen_string_literal: true

require 'set'

# Text to Labyrinth SVG Encoder
# Encodes any text string into a procedural labyrinth SVG where the core solution path represents the encoded message.
class TextLabyrinthEncoder
  DIRECTIONS = [
    [0, -1], # Up
    [1, 0],  # Right
    [0, 1],  # Down
    [-1, 0]  # Left
  ].freeze

  def initialize(text)
    @text = text
    @cell_size = 24
  end

  # Translates text bytes into a directional walk forming the solution path
  def generate_path
    path = [[0, 0]]
    x, y = 0, 0
    @text.bytes.each do |byte|
      4.times do |i|
        dx, dy = DIRECTIONS[(byte >> (6 - i * 2)) & 3]
        x += dx
        y += dy
        path << [x, y]
      end
    end
    path
  end

  # Renders the labyrinth and embedded path as a clean, responsive SVG
  def to_svg
    path = generate_path
    xs = path.map(&:first)
    ys = path.map(&:last)
    min_x, max_x = xs.min - 2, xs.max + 2
    min_y, max_y = ys.min - 2, ys.max + 2

    w = (max_x - min_x) * @cell_size
    h = (max_y - min_y) * @cell_size

    svg = []
    svg << %(<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="#{min_x * @cell_size} #{min_y * @cell_size} #{w} #{h}" width="#{w}" height="#{h}">)
    svg << %(<style>
      rect { fill: #0f172a; }
      .path { stroke: #f43f5e; stroke-width: 4; fill: none; stroke-opacity: 0.8; stroke-dasharray: 6 4; }
      .start { fill: #22c55e; }
      .end { fill: #eab308; }
    </style>)
    svg << %(<rect width="100%" height="100%" />)

    # Draw the solution path encoding the message
    points = path.map { |x, y| "#{x * @cell_size + @cell_size / 2},#{y * @cell_size + @cell_size / 2}" }.join(' ')
    svg << %(<polyline points="#{points}" class="path" />)

    # Draw entry (green) and exit (gold) nodes
    sx, sy = path.first
    ex, ey = path.last
    svg << %(<circle cx="#{sx * @cell_size + @cell_size / 2}" cy="#{sy * @cell_size + @cell_size / 2}" r="8" class="start" />)
    svg << %(<circle cx="#{ex * @cell_size + @cell_size / 2}" cy="#{ey * @cell_size + @cell_size / 2}" r="8" class="end" />)

    svg << %(</svg>)
    svg.join("\n")
  end
end

if __FILE__ == $0
  input_text = ARGV[0] || "ProceduralLabyrinthCompressionRuby"
  puts TextLabyrinthEncoder.new(input_text).to_svg
end