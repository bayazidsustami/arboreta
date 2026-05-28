#!/usr/bin/env ruby
# frozen_string_literal: true

# Required gems: octokit, midilib, rasem
# Install with: gem install octokit midilib rasem
require 'octokit'
require 'midilib/sequence'
require 'midilib/consts'
require 'rasem'

# ---------- CONFIG ----------
GITHUB_REPO = ARGV[0] || 'torvalds/linux' # example repo
OUTPUT_MIDI = 'history.mid'
OUTPUT_SVG  = 'history.svg'
FRAMES      = 60          # number of SVG frames
# ---------------------------

# 1. Fetch commit timestamps from GitHub
client = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
commits = client.commits(GITHUB_REPO, per_page: 100)
timestamps = commits.map { |c| Time.parse(c[:commit][:author][:date]).to_i }

# 2. Map each timestamp to a MIDI note (0‑127) using its binary representation
def timestamp_to_note(ts)
  # simple heuristic: count of 1‑bits + offset
  ((ts.to_s(2).count('1') % 12) + 60) # keep within one octave around middle C
end

notes = timestamps.map { |t| timestamp_to_note(t) }

# 3. Build a MIDI sequence
seq = MIDI::Sequence.new
track = MIDI::Track.new(seq)
seq.tracks << track
track.events << MIDI::Tempo.new(MIDI::Tempo.bpm_to_mpq(120))
track.events << MIDI::ProgramChange.new(0, 0, 0) # piano

# lay notes sequentially, each 1/4 beat long
ticks_per_beat = seq.note_to_delta_time(1) # default resolution
notes.each_with_index do |n, i|
  on  = MIDI::NoteOn.new(0, n, 127, i * ticks_per_beat)
  off = MIDI::NoteOff.new(0, n, 127, (i + 1) * ticks_per_beat)
  track.events << on
  track.events << off
end

File.open(OUTPUT_MIDI, 'wb') { |f| seq.write(f) }
puts "MIDI written to #{OUTPUT_MIDI}"

# 4. Generate an animated SVG that visualizes a kaleidoscopic fractal.
#    The fractal is a simple rotating L-system; colour hue follows note pitch.
class KaleidoSVG
  include Math
  attr_reader :width, :height, :frames, :notes

  def initialize(width, height, frames, notes)
    @width  = width
    @height = height
    @frames = frames
    @notes  = notes
  end

  # produce a point set for a given angle and scale
  def points(angle, scale)
    step = PI / 4
    (0...8).map do |i|
      a = angle + i * step
      [width / 2 + cos(a) * scale, height / 2 + sin(a) * scale]
    end
  end

  def hue_for_note(note)
    ((note - 60) % 12) * 30 % 360
  end

  def build
    svg = Rasem::SVGImage.new(width, height, viewBox: "0 0 #{width} #{height}")
    svg.defs do
      svg.linearGradient(id: 'bg', x1: '0%', y1: '0%', x2: '100%', y2: '100%') do
        svg.stop(offset: '0%', style: 'stop-color:#000020')
        svg.stop(offset: '100%', style: 'stop-color:#001040')
      end
    end
    svg.rect(x: 0, y: 0, width: width, height: height, fill: 'url(#bg)')

    # create a group that will be animated
    svg.g(id: 'kaleido', transform: "rotate(0 #{width/2} #{height/2})") do
      frames.times do |f|
        angle = f * (2 * PI / frames)
        scale = 30 + 10 * sin(f * 0.3)
        pts = points(angle, scale)

        hue = hue_for_note(notes[f % notes.size])
        color = "hsl(#{hue},80%,60%)"

        svg.polygon(points: pts.map { |x, y| "#{x},#{y}" }.join(' '),
                    fill: color,
                    opacity: 0.7) do
          # make each polygon appear only on its frame
          svg.animateAttribute(
            attributeName: 'opacity',
            values: (0..frames).map { |i| i == f ? '0.7' : '0' }.join(';'),
            dur: "#{frames}s",
            repeatCount: 'indefinite')
        end
      end
    end

    # rotate the whole group over time
    svg.animateTransform(
      attributeName: 'transform',
      type: 'rotate',
      from: "0 #{width/2} #{height/2}",
      to:   "360 #{width/2} #{height/2}",
      dur: "#{frames}s",
      repeatCount: 'indefinite')
    svg
  end
end

ksvg = KaleidoSVG.new(800, 800, FRAMES, notes)
File.write(OUTPUT_SVG, ksvg.build.output)
puts "Animated SVG written to #{OUTPUT_SVG}"