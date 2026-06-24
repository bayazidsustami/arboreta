#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# Simple self‑modifying 2‑D cellular automaton that animates a poem.
# Each cell holds a character, colored by part‑of‑speech.
# Transition rule: next word is the one with highest mock similarity
# (same first letter, then length difference) to the current word.
# After each full screen, the script rewrites its own source with the
# updated word list, thus “self‑modifying”.

require 'io/console'

# --- configuration (generated section) ---
# WORDS placeholder will be replaced on each run
WORDS = %w[
the quick brown fox jumps over lazy dog
] # <-- DO NOT EDIT ABOVE THIS LINE

# part‑of‑speech tags for each word (mock data)
POS = %w[det adj adj noun verb prep adj noun]

# color map for parts of speech
COLORS = {
  'det' => 33,  # yellow
  'adj' => 32,  # green
  'noun'=> 36,  # cyan
  'verb'=> 35,  # magenta
  'prep'=> 34,  # blue
}
# --- end configuration ---

# Build grid width based on terminal size
WIDTH = IO.console.winsize[1] rescue 80
HEIGHT = IO.console.winsize[0] rescue 24

# Assemble characters matrix from words
def build_grid(words)
  chars = words.join(' ').chars
  grid = Array.new(HEIGHT) { Array.new(WIDTH, ' ') }
  i = 0
  HEIGHT.times do |y|
    WIDTH.times do |x|
      break if i >= chars.size
      grid[y][x] = chars[i]
      i += 1
    end
    break if i >= chars.size
  end
  grid
end

# Color a character according to its word's POS
def color_grid(grid, words)
  pos_idx = 0
  char_idx = 0
  words.each_with_index do |w, wi|
    w.each_char do |c|
      y = char_idx / WIDTH
      x = char_idx % WIDTH
      break if y >= HEIGHT
      pos = POS[wi] || 'noun'
      color = COLORS[pos] || 37
      grid[y][x] = "\e[#{color}m#{c}\e[0m"
      char_idx += 1
    end
    # add space after each word
    y = char_idx / WIDTH
    x = char_idx % WIDTH
    break if y >= HEIGHT
    grid[y][x] = "\e[0m \e[0m"
    char_idx += 1
  end
  grid
end

# Mock semantic similarity: higher if same first letter, then length closeness
def similarity(a, b)
  score = 0
  score += 5 if a[0] == b[0]
  score -= (a.length - b.length).abs
  score
end

# Choose next word based on similarity to current
def next_word(current, pool)
  pool.max_by { |w| similarity(current, w) }
end

# Render grid to terminal
def render(grid)
  system('clear')
  grid.each { |row| puts row.map { |c| c }.join }
end

# Main loop: one frame per word transition
def run
  loop do
    grid = build_grid(WORDS)
    grid = color_grid(grid, WORDS)
    render(grid)
    sleep 0.8

    # advance each word to its most similar neighbor
    new_words = WORDS.map { |w| next_word(w, WORDS) }
    break if new_words == WORDS # stable

    # self‑modify source file with new word list
    src = File.read(__FILE__)
    new_section = "WORDS = %w[\\n" + new_words.map { |w| w }.join(' ') + "\\n] # <-- DO NOT EDIT ABOVE THIS LINE\n"
    src.sub!(/WORDS = %w\\[.*?\\] # <-- DO NOT EDIT ABOVE THIS LINE/m, new_section)
    File.write(__FILE__, src)

    # reload updated constants for next iteration
    load __FILE__
    break
  end
end

run