#!/usr/bin/env ruby
# frozen_string_literal: true

# == Live Color → Music → Mandala ==
# Captures webcam frames, extracts a 4‑color palette,
# maps each colour to a note via a tiny DSL,
# streams MIDI notes, and writes an SVG mandala whose
# geometry follows the music’s spectral centroid and beat.

require 'opencv'
require 'midilib/sequence'
require 'midilib/consts'
require 'securerandom'
require 'json'

# ----- Configuration -------------------------------------------------
WIDTH  = 160
HEIGHT = 120
PALETTE_SIZE = 4
MIDI_OUT = 'live.mid'          # written continuously (simple demo)
SVG_OUT = 'mandala.svg'        # overwritten each frame
FPS      = 15

# ----- Simple LISP‑like DSL -------------------------------------------
# Example DSL:
#   (map (r g b) -> (mod (+ r g b) 12))
#   (scale 48)               # base MIDI note
class DSL
  attr_accessor :mapper, :scale

  def initialize
    @mapper = ->(c) { (c[0] + c[1] + c[2]) % 12 }
    @scale  = 48
  end

  def eval(str)
    tokens = str.gsub(/[()]/, ' \0 ').split
    parse(tokens)
  end

  private

  def parse(tokens)
    token = tokens.shift
    case token
    when 'map'
      # (map (r g b) -> expr)
      tokens.shift # discard '('
      vars = []
      while (v = tokens.shift) != ')'
        vars << v
      end
      tokens.shift # discard '->'
      expr = tokens.shift # very simple: (+ r g b) or (mod (+ r g b) 12)
      @mapper = build_mapper(vars, expr)
    when 'scale'
      @scale = tokens.shift.to_i
    else
      # ignore
    end
  end

  def build_mapper(vars, expr)
    lambda do |col|
      r, g, b = col.map { |c| c / 255.0 }
      binding = {}
      vars.each_with_index { |v, i| binding[v] = [r, g, b][i] }
      eval_lisp(expr, binding) * 12
    end
  end

  def eval_lisp(expr, env)
    case expr
    when /\A\(\s*(\w+)\s+(.+)\)\z/
      op, rest = Regexp.last_match[1], Regexp.last_match[2]
      args = rest.scan(/[\w\.]+/).map { |a| env[a] || a.to_f }
      case op
      when '+' then args.reduce(:+)
      when '-' then args.reduce(:-)
      when '*' then args.reduce(:*)
      when '/' then args.reduce(:/)
      when 'mod' then args[0] % args[1]
      else args.first
      end
    else
      expr.to_f
    end
  end
end

dsl = DSL.new
Thread.new do
  puts "Enter DSL commands (e.g. '(scale 60)' or '(map (r g b) -> (+ r g b))')"
  loop { dsl.eval($stdin.gets.to_s) }
end

# ----- MIDI setup -----------------------------------------------------
seq = MIDI::Sequence.new()
track = MIDI::Track.new(seq)
seq.tracks << track
track.name = 'Live'
track.instrument = MIDI::GM_PATCH_NAMES[0]
track.events << MIDI::Tempo.new(MIDI::Tempo.bpm_to_mpq(120))
track.events << MIDI::MetaEvent.new(MIDI::META_SEQ_NAME, 'LiveCam')

File.open(MIDI_OUT, 'wb') { |f| seq.write(f) }

# ----- SVG helper ------------------------------------------------------
def mandala_svg(points, radius, filename)
  angle = 2 * Math::PI / points
  path = (0...points).map { |i|
    x = radius * Math.cos(i * angle)
    y = radius * Math.sin(i * angle)
    "#{x.round(2)},#{y.round(2)}"
  }.join(' ')
  svg = <<~SVG
    <svg viewBox="-200 -200 400 400" xmlns="http://www.w3.org/2000/svg">
      <polygon points="#{path}" fill="none" stroke="hsl(#{rand(360)},80%,60%)" stroke-width="2"/>
    </svg>
  SVG
  File.write(filename, svg)
end

# ----- Main loop -------------------------------------------------------
capture = OpenCV::CvCapture.open
raise 'Cannot open webcam' unless capture

frame_idx = 0
loop do
  img = capture.query
  break unless img
  img = img.resize(WIDTH, HEIGHT)

  # Flatten pixels => [r,g,b] arrays
  pixels = img.to_a.flat_map { |row| row.each_slice(3).to_a }

  # Simple k‑means like clustering (random sampling for speed)
  centroids = pixels.sample(PALETTE_SIZE).map { |c| c.map(&:to_f) }
  5.times do
    clusters = Array.new(PALETTE_SIZE) { [] }
    pixels.each do |p|
      idx = centroids.each_with_index.min_by { |c, _i| (c.zip(p).map { |a, b| (a - b)**2 }).sum }[1]
      clusters[idx] << p
    end
    centroids = clusters.map { |c| c.empty? ? [0,0,0] : c.transpose.map { |dim| dim.sum / dim.size } }
  end

  # Map each centroid to a midi note
  notes = centroids.map { |c| ((dsl.mapper.call(c) % 12) + dsl.scale).to_i }
  time = (frame_idx * (60.0 / FPS)).to_i

  notes.each do |n|
    track.events << MIDI::NoteOn.new(0, n, 100, time)
    track.events << MIDI::NoteOff.new(0, n, 100, time + (FPS / 2))
  end

  # Compute a crude spectral centroid as average pitch
  centroid = notes.sum / notes.size.to_f

  # Render mandala: number of points = palette size, radius driven by centroid
  mandala_svg(PALETTE_SIZE, 150 + centroid * 5, SVG_OUT)

  # Write updated MIDI (overwrites – for demo purposes)
  File.open(MIDI_OUT, 'wb') { |f| seq.write(f) }

  frame_idx += 1
  sleep 1.0 / FPS
end

capture.release if capture rescue nil