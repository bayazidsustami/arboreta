require 'digest'

# ==============================================================================
# BARDIC PRISM: An Esoteric Shakespearean Color Palette Compiler
# ==============================================================================
# Translates Shakespearean dramatic text into dynamic, evolving visual palettes
# by analyzing emotional sentiment (via dynamic lexicons) and rhythmic cadence
# (iambic pentameter meters and syllabic flow).
# ==============================================================================

module ShakespeareanAnalyzer
  # Emotional tone map associating keywords with HSV Color Profiles (Hue 0-360, Sat 0-1, Val 0-1)
  EMOTION_LEXICON = {
    tragic:    { keywords: %w[death die blood murder kill grief sorrow tears woe grave doom night shade], h: 0,   s: 0.85, v: 0.3 },
    passionate:{ keywords: %w[love heart beauty sweet fair desire blush kiss passion flame sun light], h: 340, s: 0.9,  v: 0.9 },
    noble:     { keywords: %w[king queen crown honor grace majesty lord virtue gold throne triumph],   h: 45,  s: 0.8,  v: 0.85 },
    envious:   { keywords: %w[jealous envy green snake poison curse treason foul spite bitter shame],  h: 120, s: 0.75, v: 0.5 },
    melancholy:{ keywords: %w[sigh weep lonely cold shadow silent pale breath dream ghost memory],    h: 210, s: 0.5,  v: 0.4 },
    furious:   { keywords: %w[rage anger war storm thunder strike vengeance blade enemy fury fight],   h: 15,  s: 0.95, v: 0.75 }
  }.freeze

  class << self
    def count_syllables(word)
      w = word.downcase.gsub(/[^a-z]/, '')
      return 0 if w.empty?
      return 1 if w.length <= 3
      w.sub!(/(?:|[^laeiouy]|ed|es|e)$/, '')
      w.sub!(/^y/, '')
      w.scan(/[aeiouy]{1,2}/).size.clamp(1, 10)
    end

    def extract_cadence(line)
      words = line.scan(/\b[\w']+\b/)
      syllable_counts = words.map { |w| count_syllables(w) }
      total_syllables = syllable_counts.sum

      # Measure proximity to classic Iambic Pentameter (10 syllables, ~5 stress beats)
      meter_purity = 1.0 - ((total_syllables - 10).abs / 10.0).clamp(0.0, 1.0)
      rhythm_density = words.empty? ? 0 : total_syllables.to_f / words.size

      { total_syllables: total_syllables, purity: meter_purity, density: rhythm_density }
    end

    def analyze_sentiment(line)
      words = line.downcase.scan(/\b[a-z]+\b/)
      scores = Hash.new(0)

      words.each do |word|
        EMOTION_LEXICON.each do |emotion, data|
          scores[emotion] += 1 if data[:keywords].include?(word)
        end
      end

      dominant = scores.max_by { |_, count| count }
      dominant && dominant[1] > 0 ? dominant[0] : :neutral
    end
  end
end

class PaletteCompiler
  # Represents a single state in the visual spectrum trajectory
  ColorNode = Struct.new(:hue, :saturation, :value, :alpha, :hex, :line_text, :cadence)

  def initialize(dramatic_text)
    @text = dramatic_text
    @spectrum = []
  end

  def compile!
    current_hue = 200.0 # Base atmospheric state
    current_sat = 0.5
    current_val = 0.5

    @text.each_line.map(&:strip).reject(&:empty?).each do |line|
      # Skip character speaker headers (e.g., "HAMLET:") but allow them to shift state
      if line =~ /^[A-Z\s]{2,}:$/
        current_hue = (current_hue + seed_from_string(line)) % 360
        next
      end

      sentiment = ShakespeareanAnalyzer.analyze_sentiment(line)
      cadence   = ShakespeareanAnalyzer.extract_cadence(line)

      # Dynamic Color Evolution Mechanics
      if sentiment != :neutral
        target = ShakespeareanAnalyzer::EMOTION_LEXICON[sentiment]
        # Sentiment shifts primary Hue & Saturation
        current_hue = lerp(current_hue, target[:h], 0.45)
        current_sat = lerp(current_sat, target[:s], 0.35)
        current_val = lerp(current_val, target[:v], 0.35)
      else
        # Cadence drifts state in absence of explicit emotion
        current_hue = (current_hue + (cadence[:density] * 12)) % 360
        current_sat = lerp(current_sat, 0.3, 0.1)
      end

      # Rhythm affects Brightness (Value) and Alpha Translucency
      val_mod = (cadence[:purity] * 0.4) + 0.6
      final_val = (current_val * val_mod).clamp(0.1, 1.0)
      alpha = (cadence[:total_syllables] / 12.0).clamp(0.2, 1.0)

      hex = hsv_to_hex(current_hue, current_sat, final_val)
      @spectrum << ColorNode.new(current_hue.round(2), current_sat.round(2), final_val.round(2), alpha.round(2), hex, line, cadence)
    end

    self
  end

  def render_terminal_vis
    puts "\e[1m=== SHAKESPEAREAN PALETTE SPECTRUM ===\e[0m\n\n"
    @spectrum.each_with_index do |node, idx|
      r, g, b = hex_to_rgb(node.hex)
      bg_ansi = "\e[48;2;#{r};#{g};#{b}m\e[38;2;255;255;255m"
      reset   = "\e[0m"

      bar = "  " * (node.cadence[:total_syllables].clamp(1, 16))
      puts sprintf("%02d. %s%s%s | %s | H:%3.0f° S:%0.2f V:%0.2f | \"%s\"",
                    idx + 1, bg_ansi, bar, reset, node.hex, node.hue, node.saturation, node.value, truncate(node.line_text, 40))
    end
  end

  def export_svg(filename = "shakespeare_palette.svg")
    width = 800
    row_height = 40
    height = @spectrum.size * row_height

    svg_content = []
    svg_content << "<svg xmlns=\"[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)\" viewBox=\"0 0 #{width} #{height}\" width=\"100%\" height=\"100%\">"
    svg_content << "<style>text { font-family: monospace; font-size: 12px; fill: #ffffff; }</style>"

    @spectrum.each_with_index do |node, i|
      y = i * row_height
      svg_content << "  <g transform=\"translate(0, #{y})\">"
      svg_content << "    <rect width=\"#{width}\" height=\"#{row_height}\" fill=\"#{node.hex}\" opacity=\"#{node.alpha}\"/>"
      svg_content << "    <text x=\"15\" y=\"25\" text-shadow=\"1px 1px 2px #000\">#{node.hex} | #{node.line_text.gsub('&', '&amp;').gsub('<', '&lt;')}</text>"
      svg_content << "  </g>"
    end

    svg_content << "</svg>"
    File.write(filename, svg_content.join("\n"))
    puts "\n\e[32m[SVG Exported Successfully: #{filename}]\e[0m"
  end

  private

  def lerp(start, finish, factor)
    start + (finish - start) * factor
  end

  def seed_from_string(str)
    Digest::MD5.hexdigest(str).hex % 360
  end

  def hsv_to_hex(h, s, v)
    c = v * s
    x = c * (1 - ((h / 60.0) % 2 - 1).abs)
    m = v - c

    r, g, b = case (h / 60.0).floor
              when 0 then [c, x, 0]
              when 1 then [x, c, 0]
              when 2 then [0, c, x]
              when 3 then [0, x, c]
              when 4 then [x, 0, c]
              else        [c, 0, x]
              end

    rgb = [r, g, b].map { |val| ((val + m) * 255).round.clamp(0, 255) }
    sprintf("#%02X%02X%02X", *rgb)
  end

  def hex_to_rgb(hex)
    hex.match(/^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i).captures.map(&:hex)
  end

  def truncate(str, len)
    str.length > len ? str[0...len-3] + "..." : str
  end
end

# ==============================================================================
# SAMPLE EXECUTION (Macbeth Act 5, Scene 5 extract)
# ==============================================================================

sample_play = <<~SHAKESPEARE
  MACBETH:
  To-morrow, and to-morrow, and to-morrow,
  Creeps in this petty pace from day to day
  To the last syllable of recorded time,
  And all our yesterdays have lighted fools
  The way to dusty death. Out, out, brief candle!
  Life's but a walking shadow, a poor player
  That struts and frets his hour upon the stage
  And then is heard no more: it is a tale
  Told by an idiot, full of sound and fury,
  Signifying nothing.
SHAKESPEARE

compiler = PaletteCompiler.new(sample_play)
compiler.compile!
compiler.render_terminal_vis
compiler.export_svg("macbeth_soliloquy.svg")