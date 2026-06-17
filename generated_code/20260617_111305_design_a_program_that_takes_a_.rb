require 'opencv'
require 'midilib/sequence'
require 'midilib/consts'
require 'gosu'
require 'matrix'

# Simple K-means for dominant colors (2 clusters)
def dominant_colors(frame, k=2)
  rows = frame.rows
  cols = frame.cols
  data = []
  rows.times do |y|
    cols.times do |x|
      b,g,r = frame[y,x].to_a
      data << [r,g,b]
    end
  end
  centers = data.sample(k).map(&:dup)
  5.times do
    clusters = Array.new(k){[]}
    data.each do |pix|
      dists = centers.map { |c| Math.sqrt((c[0]-pix[0])**2 + (c[1]-pix[1])**2 + (c[2]-pix[2])**2) }
      clusters[dists.each_with_index.min[1]] << pix
    end
    centers = clusters.map { |c| c.empty? ? [0,0,0] : c.reduce([0,0,0]){ |s,p| [s[0]+p[0],s[1]+p[1],s[2]+p[2]] }.map{ |v| v / c.size } }
  end
  centers.map { |c| c.map(&:to_i) }
end

# Map a RGB color to a note in a custom pentatonic scale
SCALE = [0, 2, 4, 7, 9]  # intervals semitones from root
ROOT_MIDI = 60            # middle C

def color_to_midi(rgb)
  brightness = rgb.sum / 3.0
  hue = Math.atan2(Math.sqrt(3)*(rgb[1]-rgb[2]), 2*rgb[0]-rgb[1]-rgb[2]) * 180/Math::PI
  hue = (hue + 360) % 360
  degree = (hue / 360.0 * SCALE.size).floor % SCALE.size
  octave = (brightness / 255.0 * 2).floor + 3
  ROOT_MIDI + SCALE[degree] + 12*octave
end

# Minimal MIDI player using a synth (system must have timidity or similar)
class MidiPlayer
  def initialize
    @seq = MIDI::Sequence.new
    @track = MIDI::Track.new(@seq)
    @seq.tracks << @track
    @track.events << MIDI::Tempo.new(MIDI::Tempo.bpm_to_mpq(120))
    @track.events << MIDI::MetaEvent.new(MIDI::META_SEQ_NAME, 'RubyAV')
    @track.events << MIDI::ProgramChange.new(0, 1, 0) # acoustic piano
  end

  def add_note(note, dur=120)
    @track.events << MIDI::NoteOn.new(0, note, 100, 0)
    @track.events << MIDI::NoteOff.new(0, note, 0, dur)
  end

  def play
    File.open('tmp.mid','wb'){|f| @seq.write(f) }
    pid = spawn("timidity -iA tmp.mid")
    Process.detach(pid)
    sleep 0.1
  end
end

# Simple kaleidoscopic mandala using Gosu
class MandalaWindow < Gosu::Window
  def initialize
    super 640,480
    self.caption = "Audio‑Visual Poem"
    @angle = 0.0
    @colors = [Gosu::Color::WHITE]
  end

  def update
    @angle += 0.02
  end

  def draw
    cx = width/2
    cy = height/2
    radius = 200
    12.times do |i|
      rot = @angle + i * Math::PI/6
      x = cx + radius * Math.cos(rot)
      y = cy + radius * Math.sin(rot)
      Gosu.draw_line(cx,cy,x,y,@colors[i%@colors.size],0)
    end
  end

  def set_colors(cols)
    @colors = cols.map{|c| Gosu::Color.rgba(c[0],c[1],c[2],255)}
  end
end

# Main loop
cam = OpenCV::CvCapture.open
player = MidiPlayer.new
window = MandalaWindow.new

loop do
  frame = cam.query
  break unless frame
  colors = dominant_colors(frame, 4)
  notes = colors.map { |c| color_to_midi(c) }
  notes.each { |n| player.add_note(n, 60) }
  player.play
  window.set_colors(colors)
  window.show if !window.closed?
  # small pause to keep pace
  sleep 0.05
end

cam.close if cam end.