require 'rexml/document'

# Weather Data Generator: Simulates real-time atmospheric readings
class WeatherStation
  attr_reader :temperature, :humidity, :pressure, :wind_speed

  def initialize
    @temperature = 20.0 # Celsius
    @humidity = 50.0    # Percentage
    @pressure = 1013.25 # hPa
    @wind_speed = 10.0  # knots
  end

  # Evolves atmospheric state continuously
  def tick
    @temperature += rand(-0.5..0.5)
    @humidity    = (@humidity + rand(-1.0..1.0)).clamp(0.0, 100.0)
    @pressure    += rand(-0.2..0.2)
    @wind_speed  = (@wind_speed + rand(-0.5..0.5)).clamp(0.0, 60.0)
  end
end

# Harmonic Translator: Converts weather variables into musical frequencies and waves
class MusicHarmonizer
  BASE_FREQ = 220.0 # A3 note in Hz

  def initialize(station)
    @station = station
  end

  # Maps temperature to fundamental frequency pitch, pressure to octave scaling,
  # humidity to harmonic overtones count, and wind speed to modulation frequency
  def synthesize_frame(time_step, width, points_count = 200)
    fundamental = BASE_FREQ * (2.0 ** ((@station.temperature - 20.0) / 12.0))
    octave_shift = (@station.pressure - 1013.25) / 50.0
    freq = fundamental * (2.0 ** octave_shift)

    harmonics = [1, 2, 3, 5, 8].take((@station.humidity / 20.0).ceil.clamp(1, 5))
    wind_mod = @station.wind_speed / 5.0

    points = []
    points_count.times do |i|
      x = (i.to_f / (points_count - 1)) * width
      t = (i.to_f / points_count) * 2 * Math::PI

      # Composite wave synthesis
      y_val = harmonics.each_with_index.sum do |h, idx|
        amplitude = 1.0 / (idx + 1)
        Math.sin(h * (t * (freq / 50.0) + time_step) + Math.sin(wind_mod * time_step)) * amplitude
      end

      points << [x, y_val]
    end

    points
  end
end

# Vector Graphic Visualizer: Render harmonized waveforms as dynamic SVG score streams
class Visualizer
  WIDTH = 800
  HEIGHT = 400
  SCORE_HISTORY = 5

  def initialize
    @history = []
  end

  def add_waveform(points)
    @history.unshift(points)
    @history.pop if @history.length > SCORE_HISTORY
  end

  def render_svg(time_step)
    doc = REXML::Document.new
    svg = doc.add_element('svg', {
      'xmlns' => '[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)',
      'viewBox' => "0 0 #{WIDTH} #{HEIGHT}",
      'style' => 'background: #0d1117;'
    })

    # Render musical staff background lines
    5.times do |i|
      y = 100 + i * 50
      svg.add_element('line', {
        'x1' => 0, 'y1' => y, 'x2' => WIDTH, 'y2' => y,
        'stroke' => '#30363d', 'stroke-width' => 1
      })
    end

    # Render harmonized score layers (historical decay visualization)
    @history.each_with_index do |points, idx|
      opacity = (1.0 - (idx.to_f / SCORE_HISTORY)).round(2)
      stroke_color = idx.zero? ? '#58a6ff' : '#1f6feb'
      stroke_width = idx.zero? ? 3.5 : 1.5
      mid_y = HEIGHT / 2.0
      scale_y = 60.0

      path_data = points.map.with_index do |(x, y), i|
        command = i.zero? ? 'M' : 'L'
        "#{command} #{x.round(2)} #{(mid_y - y * scale_y).round(2)}"
      end.join(' ')

      svg.add_element('path', {
        'd' => path_data,
        'fill' => 'none',
        'stroke' => stroke_color,
        'stroke-width' => stroke_width,
        'stroke-opacity' => opacity,
        'stroke-linecap' => 'round'
      })
    end

    doc.to_s
  end
end

# Main Controller Engine
station = WeatherStation.new
harmonizer = MusicHarmonizer.new(station)
visualizer = Visualizer.new

# Generate a sequence of evolving musical score SVG frames
10.times do |step|
  station.tick
  waveform = harmonizer.synthesize_frame(step * 0.5, Visualizer::WIDTH)
  visualizer.add_waveform(waveform)
  svg_output = visualizer.render_svg(step * 0.5)

  # Write SVG frame output
  filename = "weather_score_frame_#{step + 1}.svg"
  File.write(filename, svg_output)
  puts "Generated #{filename} - Temp: #{station.temperature.round(1)}C, Hum: #{station.humidity.round(1)}%, Press: #{station.pressure.round(1)}hPa, Wind: #{station.wind_speed.round(1)}kt"
end