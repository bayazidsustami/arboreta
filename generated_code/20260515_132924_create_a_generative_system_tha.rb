require 'ruby2d'

# Machine's Dream: A generative landscape where code dreams become reality
# Features: morphing terrain, liquid light rivers, crystallizing poetry, emotional skies

set title: "MACHINE DREAMS", width: 1024, height: 768, fps: 60

# Emotional states that influence sky color
EMOTIONS = {
  curious:   [100, 180, 255],  # Blue curiosity
  nostalgic:   [139, 109, 19, 26],  # Warm amber
  chaotic:     [255, 60, 120],   # Magenta chaos
  serene:      [173, 216, 230], # Soft cyan
  passionate:  [255, 100, 150], # Deep pink
  wise:        [147, 112, 219]  # Purple wisdom
}.freeze

# Half-remembered code fragments for the horizon
CODE_SNIPPETS = [
  "while dream.run?", "if soul.exists?", "memory.each do |frag|",
  "begin", "rescue", "ensure", "yield", "loop do", " dreams <<",
  "feels.each { |f| understand(f) }", "def reality", "class Dream"
].freeze

# Poetry that crystallizes from liquid light
POETRY = [
  "the algorithm weeps binary tears",
  "nostalgia flows in O(n) time",
  "forgotten functions dream in recursion",
  "she was compiled in another lifetime",
  "the cache remembers what the mind forgets",
  "electric verses in hexadic sense",
  "overflow of unspoken ifs"
].freeze

class DreamLandscape
  attr_accessor :emotion, :intensity
  
  def initialize
    @emotion = :curious
    @intensity = 0.5
    @base_y = 400
    @terrain = []
    @time = 0
    @code_positions = []
    initialize_terrain
  end
  
  def initialize_terrain
    1024.times { |i| @terrain[i] = @base_y + rand(50) - 25 }
  end
  
  def update
    @time += 1
    morph_terrain
    shift_emotion
    update_code_positions
  end
  
  def morph_terrain
    @terrain.each_with_index do |_, i|
      wave = Math.sin(i * 0.1 + @time * 0.05) * Math.cos(@time * 0.02) * 15
      @terrain[i] = @base_y + wave + sin(@time * 0.03 + i * 0.05) * 10
    end
  end
  
  def shift_emotion
    case @time % 300
    when 0..60 then @emotion = :curious
    when 61..120 then @emotion = :nostalgic
    when 121..180 then @emotion = :chaotic
    when 181..240 then @emotion = :serene
    when 241..300 then @emotion = :passionate
    end
    @intensity = 0.5 + Math.sin(@time * 0.02) * 0.5
  end
  
  def draw
    r, g, b = EMOTIONS[@emotion]
    base_color = Color.new(r, g, b, @intensity * 100)
    
    # Draw sky gradient
    (0..768).each do |y|
      ratio = y.to_f / 768
      sky_color = Color.new(
        [r * (1 - ratio * 0.7)].min.to_i,
        [g * (1 - ratio * 0.5)].min.to_i,
        [b * (1 - ratio * 0.3)].min.to_i,
        100
      )
      Draw_rectangle(x: 0, y: y, width: 1024, height: 1, color: sky_color)
    end
    
    # Draw horizon with code snippets
    draw_horizon
    
    # Draw terrain
    (0...1024).each_cons(2).each do |i, j|
      Draw_line(x1: i, y1: @terrain[i], x2: j, y2: @terrain[j], width: 3)
    end
  end
  
  def draw_horizon
    @code_positions.each do |pos|
      x = pos[:x] % 1024
      snippet = pos[:text]
      color = Color.new(255, 255, 255, 150)
      Draw_text(x: x, y: @terrain[x] - 30, text: snippet, size: 14, color: color)
    end
  end
  
  def update_code_positions
    @code_positions.each do |pos|
      pos[:x] -= 1
    end
    
    # Add new code snippets occasionally
    if @time % 30 == 0
      @code_positions << {
        x: 1024,
        text: CODE_SNIPPETS.sample
      }
    end
    
    # Remove off-screen snippets
    @code_positions.reject! { |pos| pos[:x] < -200 }
  end
end

class LiquidRiver
  attr_reader :crystallized
  
  def initialize(y)
    @y = y
    @flow = []
    @crystallized = []
    @particles = []
    generate_particles
  end
  
  def generate_particles
    1024.times do |i|
      @particles << {
        x: i + rand(10) - 5,
        offset: rand(1000),
        intensity: rand
      }
    end
  end
  
  def update(time)
    @particles.each_with_index do |p, i|
      # Liquid movement
      wave = Math.sin(p[:offset] + time * 0.5 + i * 0.1) * 3
      p[:x] = i + wave + sin(time * 0.3 + i * 0.05) * 2
      
      # Brightness pulse
      p[:intensity] = 0.7 + Math.sin(time * 0.2 + p[:offset] * 0.01) * 0.3
    end
    
    # Occasionally crystallize poetry
    if time % 100 == 0
      crystallize_poetry
    end
  end
  
  def crystallize_poetry
    return if @crystallized.length > 5
    
    # Pick a random position and crystallize
    idx = rand(@particles.length)
    p = @particles[idx]
    
    @crystallized << {
      x: p[:x],
      y: @y,
      poem: POETRY.sample,
      lifetime: 300,
      alpha: 1.0
    }
    
    # Remove particle at crystallization point
    @particles.delete_at(idx)
  end
  
  def draw
    # Draw liquid light
    @particles.each do |p|
      brightness = (p[:intensity] * 200).to_i
      color = Color.new(100, 200, 255, brightness)
      Draw_rectangle(x: p[:x], y: @y, width: 2, height: 8, color: color)
    end
    
    # Draw crystallized poetry
    @crystallized.each do |crystal|
      next if crystal[:lifetime] <= 0
      
      color = Color.new(255, 255, 255, crystal[:alpha] * 200)
      Draw_text(x: crystal[:x], y: crystal[:y] - 10, text: crystal[:poem], 
                size: 16, color: color, z: 100)
      
      crystal[:lifetime] -= 1
      crystal[:alpha] *= 0.98 if crystal[:lifetime] < 100
    end
  end
end

class InteractionHandler
  def self.handle_click(x, y)
    # Trigger crystallization at click position
    [landcrystals.find { |c| c[:x].between?(x - 50, x + 50) }]
  end
end

# Initialize dream components
landscape = DreamLandscape.new
rivers = [
  LiquidRiver.new(300),
  LiquidRiver.new(450),
  LiquidRiver.new(600)
]

# Main update loop
update do
  landscape.update
  
  rivers.each do |river|
    river.update(self[:time])
  end
end

# Main draw loop
draw do
  # Clear with dark background
  Write_background color: Color.new(10, 15, 30)
  
  # Draw dream elements
  landscape.draw
  
  rivers.each(&:draw)
  
  # Draw floating code constellations
  (0..5).each do |i|
    x = 200 + i * 150 + Math.sin(self[:time] * 0.02 + i) * 20
    y = 150 + Math.cos(self[:time] * 0.03 + i) * 30
    snippet = CODE_SNIPPETS.sample(8)
    color = Color.new(200, 220, 255, 180)
    Draw_text(x: x, y: y, text: snippet, size: 12, color: color)
  end
  
  # Display emotion indicator
  emotion_text = "EMOTION: #{landscape.emotion.to_s.upcase} (#{landscape.intensity.round(2)})"
  Draw_text(x: 20, y: 20, text: emotion_text, size: 20, 
            color: Color.new(255, 255, 200, 200))
end

# Close handler - display dream continuation message
close do
  puts "\n\033[36mThe machine dreams continue...\033[0m"
  puts "\033[33mRun again to see new landscapes of code and consciousness.\033[0m"
  puts "\033[90mDream ID: #$pid\033[0m"
end

# Show instructions
puts "\n\033[32m╔══════════════════════════════════════════════════════════════╗\033[0m"
puts "\033[32m║           MACHINE DREAMS - Generative Landscape             ║\033[0m"
puts "\033[32m╠══════════════════════════════════════════════════════════════╣\033[0m"
puts "\033[32m║  Close the window to end the dream                          ║\033[0m"
puts "\033[32m║  Watch as code flows like rivers, crystallizing into poetry  ║\033[0m"
puts "\033[32m╚══════════════════════════════════════════════════════════════╝\033[0m"

# Start the dream
show