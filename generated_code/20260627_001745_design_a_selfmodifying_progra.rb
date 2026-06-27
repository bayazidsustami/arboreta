#!/usr/bin/env ruby
# Self‑modifying visual sculpture
# hidden hex string between markers __HEX__ ... __ENDHEX__
# The program reads it, creates a mesh, renders SVG, updates its source.

require 'base64'

SOURCE = File.expand_path(__FILE__)

# ---------- utilities ----------
def read_self
  File.read(SOURCE)
end

def write_self(new_source)
  File.write(SOURCE, new_source)
end

def extract_hex(src)
  src[/__HEX__(.*?)__ENDHEX__/m, 1].to_s.strip
end

def cpu_temp
  path = '/sys/class/thermal/thermal_zone0/temp'
  if File.exist?(path)
    (File.read(path).to_i / 1000.0)
  else
    42.0 # fallback
  end
end

# simple base‑91 encoding (RFC 7851 subset)
BASE91_CHARS = (33..126).map(&:chr).join
def base91_encode(data)
  n = 0
  b = 0
  out = +''
  data.each_byte do |c|
    n |= c << b
    b += 8
    while b > 13
      v = n & 8191
      n >>= 13
      b -= 13
      out << BASE91_CHARS[(v % 91)] << BASE91_CHARS[(v / 91)]
    end
  end
  if b > 0
    out << BASE91_CHARS[(n % 91)] << BASE91_CHARS[(n / 91)]
  end
  out
end

# ---------- L‑system ----------
def lsystem(seed_hex, iterations = 4)
  rng = Random.new(seed_hex.to_i(16))
  axiom = 'F'
  rules = { 'F' => 'F+F--F+F' }
  seq = axiom
  iterations.times { seq = seq.chars.map { |c| rules[c] || c }.join }
  angle = 25 + rng.rand(35) # 25..60 degrees
  turtle(seq, angle * Math::PI / 180)
end

def turtle(instructions, angle)
  x = y = 0.0
  dir = 0.0
  stack = []
  verts = []
  step = 10.0
  verts << [x, y, 0.0]
  instructions.each_char do |c|
    case c
    when 'F'
      x += step * Math.cos(dir)
      y += step * Math.sin(dir)
      verts << [x, y, 0.0]
    when '+'
      dir += angle
    when '-'
      dir -= angle
    when '['
      stack << [x, y, dir]
    when ']'
      x, y, dir = stack.pop
    end
  end
  verts
end

# ---------- SVG rendering ----------
def render_svg(verts, temp)
  hue = ((temp % 100) / 100.0) * 360
  color = "hsl(#{hue.round},80%,50%)"
  points = verts.map { |v| "#{v[0]},#{v[1]}" }.join(' ')
  <<~SVG
  <?xml version="1.0" encoding="UTF-8"?>
  <svg xmlns="http://www.w3.org/2000/svg" width="500" height="500" viewBox="-250 -250 500 500">
    <polygon points="#{points}" fill="none" stroke="#{color}" stroke-width="2">
      <animateTransform attributeName="transform" attributeType="XML"
        type="rotate" from="0 0 0" to="360 0 0" dur="20s" repeatCount="indefinite"/>
    </polygon>
  </svg>
  SVG
end

# ---------- main ----------
src = read_self
hex = extract_hex(src)
hex = 'deadbeef' if hex.empty? # default seed

verts = lsystem(hex)
svg = render_svg(verts, cpu_temp)

# write SVG to file for viewing
File.write('sculpture.svg', svg)

# Encode vertex data (float binary) to base‑91
binary = verts.flat_map { |v| v.map { |f| [f].pack('E') } }.join
encoded = base91_encode(binary)

# replace hidden block with new encoded data
new_src = src.sub(/__HEX__.*?__ENDHEX__/m, "__HEX__#{encoded}__ENDHEX__")
write_self(new_src)