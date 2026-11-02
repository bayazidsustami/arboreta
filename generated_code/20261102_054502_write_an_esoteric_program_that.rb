#!/usr/bin/env ruby
# ==============================================================================
# NEOCLASSICAL RUIN: An esoteric live network & audio-reactive ASCII sculpture
# Maps packet loss and environmental pulse into the decay of architectural forms.
# ==============================================================================

require 'socket'
require 'timeout'

WIDTH = 80
HEIGHT = 24

RUIN_BASE = [
  "        /-------------------------/",
  "       /_________________________/",
  "          ||   |     |   |   ||   ",
  "          ||   |     |   |   ||   ",
  "          ||   |     |   |   ||   ",
  "          ||   |     |   |   ||   ",
  "          ||   |     |   |   ||   ",
  "          ||   |     |   |   ||   ",
  "          ||   |     |   |   ||   ",
  "          ||   |     |   |   ||   ",
  "        ~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
  "       . . . . . . . . . . . . . . ."
]

class RuinSculpture
  def initialize
    @loss_history = Array.new(20, 0.0)
    @pulse = 0.0
    @target = '1.1.1.1'
  end

  def measure_network
    lost = 0
    3.times do
      begin
        Timeout.timeout(0.15) do
          TCPSocket.new(@target, 53).close
        end
      rescue
        lost += 1
      end
    end
    loss_rate = lost.to_f / 3.0
    @loss_history.shift
    @loss_history.push(loss_rate)
    @loss_history.sum / @loss_history.size
  end

  def render_frame(loss)
    @pulse += 0.2
    audio_wave = Math.sin(@pulse) * 2

    output = "\e[H\e[2J\e[?25l"
    output += "\e[36m=== NEOCLASSICAL RUIN [Target: #{@target}] Loss: #{(loss * 100).round(1)}% ===\e[0m\n\n"

    canvas = Array.new(HEIGHT - 4) { " " * WIDTH }

    RUIN_BASE.each_with_index do |line, y|
      next if y >= canvas.size
      row = ""
      line.chars.each_with_index do |char, x|
        if char == ' '
          if loss > 0.3 && rand < loss
            row += %w[. , * ~ #].sample
          else
            row += ' '
          end
        else
          if loss > 0.5 && rand < (loss * 0.4)
            row += ' '
          else
            char_code = char.ord + (audio_wave * 0.5).to_i
            row += char_code.chr rescue char
          end
        end
      end
      canvas[y] = row.ljust(WIDTH)
    end

    rubble_line = (HEIGHT - 5)
    if rubble_line >= 0 && rubble_line < canvas.size
      canvas[rubble_line] = canvas[rubble_line].chars.map { |c|
        rand < loss ? %w[# * ~ .].sample : c
      }.join
    end

    output += canvas.join("\n")
    output += "\n\e[33mStatus: #{loss > 0.4 ? 'CRUMBLING RAPIDLY' : loss > 0.1 ? 'WEATHERING' : 'STABLE'}\e[0m"
    print output
  end

  def run
    trap('INT') { print "\e[?25h\e[0m\nExiting...\n"; exit }
    loop do
      loss = measure_network
      render_frame(loss)
      sleep(0.2)
    end
  end
end

RuinSculpture.new.run if __FILE__ == $0