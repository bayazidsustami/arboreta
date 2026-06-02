require 'opencv'
require 'gosu'

# Simple L‑system implementation
class LSystem
  attr_accessor :axiom, :rules, :depth

  def initialize(axiom, rules, depth)
    @axiom = axiom
    @rules = rules
    @depth = depth
  end

  def generate
    current = @axiom.dup
    @depth.times do
      next_seq = ""
      current.each_char { |ch| next_seq << (@rules[ch] || ch) }
      current = next_seq
    end
    current
  end
end

# Helper to extract dominant color (average) and main edge orientation
module FrameAnalysis
  def self.dominant_color(img)
    mean = img.mean
    OpenCV::CvScalar.new(mean[0], mean[1], mean[2])
  end

  def self.edge_orientation(img)
    gray = img.BGR2GRAY
    gx = gray.sobel(1, 0, 3)
    gy = gray.sobel(0, 1, 3)
    angle = OpenCV::CvMat.zeros(img.rows, img.cols, OpenCV::CV_32F)
    img.rows.times do |y|
      img.cols.times do |x|
        ax = gx[y, x].abs
        ay = gy[y, x].abs
        angle[y, x] = Math.atan2(ay, ax)
      end
    end
    # Return average orientation as a simple proxy
    sum = 0.0
    count = img.rows * img.cols
    img.rows.times { |y| img.cols.times { |x| sum += angle[y, x] } }
    sum / count
  end
end

# Gosu window that draws webcam + L‑system vines
class LiveFractal < Gosu::Window
  def initialize
    super 640, 480
    self.caption = "Live L‑system Fractals"

    @capture = OpenCV::CvCapture.open(0) # webcam
    @font = Gosu::Font.new(self, Gosu.default_font_name, 20)

    @lsystem = LSystem.new("F", {"F" => "F[+F]F[-F]F"}, 3)
    @angle = 25.0
    @step = 5
    @depth = 3
    @hue_shift = 0.0
  end

  def update
    # grab frame
    frame = @capture.query
    return unless frame

    # analyse frame
    color = FrameAnalysis.dominant_color(frame)
    orient = FrameAnalysis.edge_orientation(frame)

    # map analysis to L‑system parameters
    @angle = 15 + (orient * 180 / Math::PI) % 45
    @depth = 2 + ((color[0] + color[1] + color[2]) / (255.0 * 3) * 3).to_i
    @lsystem.depth = @depth
    @hue_shift = (color[0] / 255.0) * 360

    # mutate rules slightly each frame for dynamism
    mutate_rules!
  end

  def draw
    # draw webcam background
    frame = @capture.query
    if frame
      img = frame.to_IplImage
      Gosu.draw_rect(0, 0, width, height, 0xff_000000, 0)
      texture = Gosu::Image.new(self, img.to_blob, width: img.width, height: img.height)
      texture.draw(0, 0, 0)
    end

    # draw L‑system vines
    seq = @lsystem.generate
    x, y = width / 2, height
    angle = -90.0
    stack = []
    seq.each_char do |ch|
      case ch
      when "F"
        nx = x + @step * Math.cos(angle * Math::PI / 180)
        ny = y + @step * Math.sin(angle * Math::PI / 180)
        Gosu.draw_line(x, y, hue_to_color(@hue_shift), nx, ny, hue_to_color(@hue_shift), 1)
        x, y = nx, ny
      when "+"
        angle += @angle
      when "-"
        angle -= @angle
      when "["
        stack.push([x, y, angle])
      when "]"
        x, y, angle = stack.pop if stack.any?
      end
    end

    @font.draw_text("Depth: #{@depth}  Angle: #{@angle.round}", 10, 10, 2, 1, 1, Gosu::Color::WHITE)
  end

  # Simple rule mutation: randomly replace a character in a rule
  def mutate_rules!
    @lsystem.rules.each do |k, v|
      if rand < 0.02 # 2% chance per frame
        idx = rand(v.length)
        new_sym = ["F", "+", "-", "[", "]"].sample
        v[idx] = new_sym
      end
    end
  end

  # Convert hue (0‑360) to a Gosu RGB integer
  def hue_to_color(h)
    h = h % 360
    i = (h / 60).floor
    f = h / 60 - i
    p = 0
    q = (1 - f) * 255
    t = f * 255
    case i
    when 0 then Gosu::Color.rgba(255, t, p, 255)
    when 1 then Gosu::Color.rgba(q, 255, p, 255)
    when 2 then Gosu::Color.rgba(p, 255, t, 255)
    when 3 then Gosu::Color.rgba(p, q, 255, 255)
    when 4 then Gosu::Color.rgba(t, p, 255, 255)
    else        Gosu::Color.rgba(255, p, q, 255)
    end
  end
end

LiveFractal.new.show