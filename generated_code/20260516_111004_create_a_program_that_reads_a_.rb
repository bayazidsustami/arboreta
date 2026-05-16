#!/usr/bin/env ruby
# PoemSculpture: Converts poem lines into a 3D-printable STL model
# Each line becomes a rectangular prism where:
#   Height = character count (rhythm/flow)
#   Width = word count (complexity)  
#   Depth = vowel count (sonic quality)

class PoemSculpture
  DEFAULT_POEM = <<~POEM
    Roses are red
    Violets are blue
    Sugar is sweet
    And so are you
  POEM

  def initialize(poem = nil)
    @poem = poem || DEFAULT_POEM
    @lines = @poem.split("\n").map(&:strip).reject(&:empty?)
  end

  def calculate_dimensions(line)
    chars = line.length
    words = line.split.length
    vowels = line.scan(/[aeiouAEIOU]/).length
    { height: chars * 2.5, width: words * 4.0, depth: [voids = vowels * 2.5, 3.0].max }
  end

  def generate_stl(filename = "poem_sculpture.stl")
    triangles = []
    @lines.each_with_index do |line, i|
      dims = calculate_dimensions(line)
      x_pos = i * (dims[:width] + 5)
      triangles.concat build_box(x_pos, 0, 0, dims[:width], dims[:height], dims[:depth])
    end
    write_stl_file(filename, triangles)
    puts "Generated #{filename} with #{@lines.size} shapes representing your poem."
    puts "Each shape: Height=#{dims[:height].round}mm, Width=#{dims[:width].round}mm, Depth=#{dims[:depth].round}mm"
  end

  private

  def build_box(x, y, z, w, h, d)
    v = ->(dx, dy, dz) [x + dx, y + dy, z + dz]
    triangles = []
    faces = [
      [[0,0,0], [w,0,0], [w,h,0],  [0,0,0], [w,h,0], [0,h,0]],
      [[0,0,d], [0,h,d],  [w,h,d],   [0,0,d],  [w,h,d],  [w,0,d]],
      [[0,0,0], [0,h,0], [0,h,d],   [0,0,0], [0,h,d],  [0,0,d]],
      [[w,0,0], [w,0,d],  [w,h,d],  [w,0,0], [w,h,d],  [w,h,0]],
      [[0,0,0], [w,0,d],  [w,0,0], [0,0,0], [0,0,d], [w,0,d]],
      [[0,h,0], [0,h,d],  [w,h,d],   [0,h,0], [w,h,d],  [w,h,0]]
    ]
    faces.each { |face| triangles << face.map { |c| v.call(*c) } }
    triangles
  end

  def write_stl_file(filename, triangles)
    File.open(filename, "w") do |f|
      f.puts "solid poem_sculpture"
      triangles.each do |t|
        f.puts "  facet normal 0 0 0"
        f.puts "    outer loop"
        t.each { |v| f.puts "      vertex #{v[0].round(4)} #{v[1].round(4)} #{v[2].round(4)}" }
        f.puts "    endloop"
        f.puts "  endfacet"
      end
      f.puts "endsolid poem_sculpture"
    end
  end
end

poem_input = ARGV[0] ? File.read(ARGV[0]) : nil
sculpture = PoemSculpture.new(poem_input)
sculpture.generate_stl