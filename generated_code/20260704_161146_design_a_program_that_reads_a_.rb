require 'opencv'
require 'gosu'
require 'midilib/sequence'
require 'midilib/consts'
require 'wavefile'

# Simple color‑to‑pitch mapping: hue (0‑360) → MIDI note (C3‑C6)
def hue_to_midi(hue)
  base = 48  # C3
  range = 72 # up to C6
  ((hue / 360.0) * range).to_i + base
end

# Extract dominant palette (k‑means) from an OpenCV frame
def dominant_palette(mat, k = 5)
  pixels = mat.reshape(1, mat.rows * mat.cols).to_a.map { |b,g,r| [r,g,b] }
  samples = OpenCV::CvMat.new(pixels.size, 3, OpenCV::CV_32F, pixels)
  criteria = OpenCV::CvTermCriteria.new(10, 1.0)
  flags = OpenCV::KMEANS_PP_CENTERS
  compactness, labels, centers = OpenCV::CvKMeans2(samples, k, criteria, 1, flags)
  centers.to_a.map { |c| c.map { |v| v.to_i } }
end

# Convert RGB to HSV hue component
def rgb_to_hue(r,g,b)
  r_,g_,b_ = r/255.0, g/255.0, b/255.0
  max = [r_,g_,b_].max
  min = [r_,g_,b_].min
  return 0 if max == min
  delta = max - min
  hue = if max == r_
          60 * (((g_ - b_) / delta) % 6)
        elsif max == g_
          60 * ((b_ - r_) / delta + 2)
        else
          60 * ((r_ - g_) / delta + 4)
        end
  hue
end

# Generate one‑second sine wave for a given MIDI note
def synth_note(note, sample_rate = 44100, duration = 1.0)
  freq = 440.0 * (2 ** ((note - 69) / 12.0))
  samples = (sample_rate * duration).to_i
  buffer = Array.new(samples) do |i|
    Math.sin(2 * Math::PI * freq * i / sample_rate) * 0.3
  end
  buffer.pack('f*')
end

# Audio player using WaveFile (writes to temporary wav and spawns system player)
def play_wave(data, sample_rate = 44100)
  fmt = WaveFile::Format.new(:mono, :float, sample_rate)
  buffer = WaveFile::Buffer.new(data, fmt)
  File.open('tmp.wav','wb') { |f| WaveFile::Writer.new(f, fmt) { |w| w.write(buffer) } }
  system("aplay tmp.wav >/dev/null 2>&1")
  File.delete('tmp.wav') rescue nil
end

# Particle class for visualisation
class Particle
  attr_accessor :x, :y, :z, :vx, :vy, :vz, :color
  def initialize(x,y,z,color)
    @x,@y,@z = x,y,z
    @vx = rand(-2..2)
    @vy = rand(-2..2)
    @vz = rand(-2..2)
    @color = color
  end
  def update(audio_amp)
    factor = 1 + audio_amp * 5
    @x += @vx * factor
    @y += @vy * factor
    @z += @vz * factor
    @vx *= 0.99
    @vy *= 0.99
    @vz *= 0.99
  end
  def draw(window)
    size = 3
    sx = @x + window.width/2
    sy = @y + window.height/2
    window.draw_rect(sx, sy, size, size, Gosu::Color.rgba(*@color,255))
  end
end

# Main Gosu window handling webcam, audio and particles
class SynestheticWindow < Gosu::Window
  def initialize
    super 640,480
    self.caption = "Synesthetic Audio‑Visual"
    @cam = OpenCV::CvCapture.open
    @particles = []
    @last_notes = []
    @audio_amp = 0.0
  end

  def update
    frame = @cam.query
    return unless frame
    palette = dominant_palette(frame)
    notes = palette.map { |r,g,b| hue_to_midi(rgb_to_hue(r,g,b)) }
    # play combined note (mix down to mono amplitude)
    audio_data = notes.map { |n| synth_note(n) }.join
    @audio_amp = audio_data.unpack('f*').map(&:abs).max || 0.0
    Thread.new { play_wave(audio_data) } unless notes == @last_notes
    @last_notes = notes

    # generate particles from palette colors
    palette.each do |r,g,b|
      @particles << Particle.new(rand(-200..200), rand(-150..150), 0, [r,g,b])
    end
    @particles.each { |p| p.update(@audio_amp) }
    @particles.reject! { |p| p.x.abs > 400 || p.y.abs > 300 }
  end

  def draw
    @particles.each { |p| p.draw(self) }
  end
end

SynestheticWindow.new.show