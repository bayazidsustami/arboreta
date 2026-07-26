# Generative Poetry Clock & ASCII Telemetry Landscape
# Pipes live memory usage, system state, and global weather into a Markov chain.

require 'net/http'
require 'json'
require 'uri'

# --- Markov Chain Engine ---
class MarkovEngine
  def initialize
    @chain = Hash.new { |h, k| h[k] = [] }
  end

  def train(text)
    words = text.scan(/[a-zA-Z0-9']+|[.,!?]/)
    words.each_cons(2) { |w1, w2| @chain[w1.downcase] << w2 }
  end

  def generate_line(max_words = 7)
    return "the machine slumbers in binary light" if @chain.empty?
    word = @chain.keys.sample
    poem = [word.capitalize]
    (max_words - 1).times do
      next_options = @chain[word.downcase]
      break if next_options.nil? || next_options.empty?
      word = next_options.sample
      poem << word
    end
    poem.join(' ').gsub(/ ([.,!?])/, '\1')
  end
end

# --- Telemetry & Weather Harvester ---
def system_memory_percent
  if File.exist?('/proc/meminfo')
    mem = File.read('/proc/meminfo')
    total = mem[/MemTotal:\s+(\d+)/, 1].to_f
    avail = mem[/MemAvailable:\s+(\d+)/, 1].to_f
    ((total - avail) / total * 100).round(1)
  else
    ((GC.stat(:heap_live_slots).to_f / [GC.stat(:total_freed_slots), 1].max) * 1000).clamp(12.0, 88.0).round(1)
  end
rescue
  42.0
end

def fetch_weather
  lat = rand(-50.0..50.0).round(2)
  lon = rand(-150.0..150.0).round(2)
  url = URI("[https://api.open-meteo.com/v1/forecast?latitude=#](https://api.open-meteo.com/v1/forecast?latitude=#){lat}&longitude=#{lon}&current_weather=true")
  
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true
  http.open_timeout = 2
  http.read_timeout = 2
  
  res = http.request(Net::HTTP::Get.new(url))
  if res.is_a?(Net::HTTPSuccess)
    w = JSON.parse(res.body)['current_weather'] || {}
    { lat: lat, lon: lon, temp: w['temperature'] || 15.0, wind: w['windspeed'] || 5.0, code: w['weathercode'] || 0 }
  else
    { lat: lat, lon: lon, temp: 18.0, wind: 10.0, code: 0 }
  end
rescue
  { lat: lat, lon: lon, temp: 22.0, wind: 8.0, code: 0 }
end

# --- Base Poetic Corpus ---
BASE_CORPUS = <<~TEXT
  The digital pulse hums quiet in the silicon valley of memory.
  Clouds drift across distant coordinate grids under pale starlight.
  Calculated winds whisper through endless threads and ticking clocks.
  Electrons dance through wire streams as time folds into memory cycles.
  Rustling leaves of data float over sky and earth in silent rhythm.
TEXT

# --- Landscape Renderer ---
def render_landscape(width, height, mem_pct, weather, frame)
  symbols = weather[:code] > 50 ? ['|', '.', '`', ' '] : ['^', '#', '~', '*', '"', '.', ' ']
  roughness = 0.05 + (mem_pct / 200.0)
  temp_offset = (weather[:temp] / 10.0)

  grid = Array.new(height) { Array.new(width, ' ') }

  width.times do |x|
    elevation = ((Math.sin((x + frame) * roughness) + Math.cos(x * 0.1)) * 3 + height / 2 + temp_offset).to_i
    elevation = elevation.clamp(1, height - 1)

    (elevation...height).each do |y|
      sym_idx = (y + x + frame) % (symbols.length - 1)
      grid[y][x] = y == elevation ? '^' : symbols[sym_idx]
    end
  end

  grid.map(&:join).join("\n")
end

# --- Main Generative Clock Execution ---
poet = MarkovEngine.new
poet.train(BASE_CORPUS)

weather = fetch_weather
last_weather_check = Time.now

width = 64
height = 8
frame = 0

trap("INT") { puts "\n\n[ Generative Clock Stopped ]"; exit }

loop do
  now = Time.now
  mem = system_memory_percent

  if now - last_weather_check > 15
    weather = fetch_weather
    last_weather_check = now
  end

  telemetry_text = "Memory load stands at #{mem} percent while temperature reads #{weather[:temp]} degrees. " \
                   "Grid coordinates #{weather[:lat]} and #{weather[:lon]} report winds of #{weather[:wind]} knots."
  poet.train(telemetry_text)

  poem = [
    poet.generate_line(6),
    poet.generate_line(8),
    poet.generate_line(5)
  ].join("\n  ")

  landscape = render_landscape(width, height, mem, weather, frame)

  print "\e[H\e[2J" # Clear screen
  puts "╔" + "═" * (width - 2) + "╗"
  puts "║ POETRY CLOCK :: #{now.strftime('%Y-%m-%d %H:%M:%S')}".ljust(width - 1) + "║"
  puts "║ Grid: [#{weather[:lat]}, #{weather[:lon]}] | RAM: #{mem}% | Temp: #{weather[:temp]}°C".ljust(width - 1) + "║"
  puts "╠" + "═" * (width - 2) + "╣"
  puts landscape
  puts "╠" + "═" * (width - 2) + "╣"
  puts "  #{poem}"
  puts "╚" + "═" * (width - 2) + "╝"

  frame += 1
  sleep 1
end