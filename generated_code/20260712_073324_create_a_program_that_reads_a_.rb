#!/usr/bin/env ruby
# frozen_string_literal: true

# --------------------------------------------------------------
# Real‑time ASCII mural driven by a fake transit GPS stream.
# Each "vehicle" updates a cellular automaton (CA) whose rule
# number is derived from the phonetic sounds of the current
# station name (simple hash → 0‑255).  Cells show traffic density
# (brightness) and a haiku line built from the last three stops.
# --------------------------------------------------------------

require 'io/console'
require 'thread'

# ---------- Configuration ----------
WIDTH  = 80
HEIGHT = 24
FPS    = 5                     # redraws per second
STATIONS = %w[Arbor Oakridge Pinecrest Willow
             Cedarfield Maplewood Birchdale
             Redwood Hilltop Evergreen
             Sapphire Lakefront] # sample station names
# --------------------------------------------------------------

# Simple phonetic hash: sum of consonants' positions in alphabet modulo 256
def phonetic_rule(name)
  sum = name.downcase.each_char.reduce(0) do |s,ch|
    if ch =~ /[bcdfghjklmnpqrstvwxz]/
      s + (ch.ord - 'a'.ord + 1)
    else
      s
    end
  end
  sum % 256
end

# Generate a haiku line from three station names (5‑7‑5 syllable pattern simulated)
def haiku_line(last3)
  return '' if last3.empty?
  words = last3.map { |n| n.split('').sample(3).join.capitalize }
  case last3.size
  when 1 then words.first            # 5 syl placeholder
  when 2 then words.join(' ')        # 7 syl placeholder
  else          words.join(' ')      # 5 syl placeholder
  end
end

# Simple 1‑dimensional CA update (rule 0‑255)
def ca_step(cells, rule)
  new_cells = cells.dup
  0.upto(cells.size - 1) do |i|
    left  = cells[(i - 1) % cells.size]
    selfc = cells[i]
    right = cells[(i + 1) % cells.size]
    idx   = (left << 2) | (selfc << 1) | right
    new_cells[i] = (rule >> idx) & 1
  end
  new_cells
end

# ANSI color helpers
def color_escape(bright)
  # map brightness 0‑1 to grayscale ANSI 232‑255
  level = 232 + (bright * 23).to_i
  "\e[38;5;#{level}m"
end

def reset_escape
  "\e[0m"
end

# Shared data structures
ca_rows   = Array.new(HEIGHT) { Array.new(WIDTH, 0) }
last_stops = []
mutex = Mutex.new

# Simulated GPS stream thread
Thread.new do
  loop do
    station = STATIONS.sample
    rule    = phonetic_rule(station)

    # Insert new row at top based on rule applied to previous top row
    top = ca_rows.first
    new_row = ca_step(top, rule)
    mutex.synchronize do
      ca_rows.pop
      ca_rows.unshift(new_row)
      last_stops.shift if last_stops.size >= 3
      last_stops << station
    end

    sleep 1.0 / FPS
  end
end

# Main rendering loop
loop do
  mutex.synchronize do
    # Clear screen
    print "\e[2J\e[H"
    # Render each cell
    ca_rows.each_with_index do |row, y|
      row.each_with_index do |cell, x|
        # traffic density = count of 1s in column neighbourhood
        density = ca_rows.map { |r| r[x] }.sum / HEIGHT.to_f
        char = cell == 1 ? '█' : ' '
        print "#{color_escape(density)}#{char}"
      end
      print reset_escape
      puts
    end

    # Haiku at bottom
    haiku = haiku_line(last_stops)
    puts "\e[33m#{haiku.ljust(WIDTH)}\e[0m"
  end
  sleep 1.0 / FPS
end