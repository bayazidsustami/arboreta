#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'io/console'
begin
  require 'rqrcode' # gem install rqrcode
rescue LoadError
  abort 'Please install the rqrcode gem: gem install rqrcode'
end

# ---------- Configuration ----------
WIDTH  = 40
HEIGHT = 20
STATES = %w[░ ▒ ▓ █]   # Unicode block elements for 0..3
FPS    = 10
# -----------------------------------

# Read whole file as a string
text = ARGV.empty? ? STDIN.read : File.read(ARGV[0])

# Pre‑process words for hashing
words = text.scan(/\w+/)
word_count = words.size

# Helper: deterministic rolling hash -> integer
def rolling_hash(words, idx)
  slice = words[idx, 5] || []
  Digest::SHA256.hexdigest(slice.join(' ')).hex
end

# Initialise grid from first hashes
grid = Array.new(HEIGHT) do
  Array.new(WIDTH) { STATES[0] }
end

# Populate initial states
(0...HEIGHT).each do |y|
  (0...WIDTH).each do |x|
    h = rolling_hash(words, (y * WIDTH + x) % word_count)
    grid[y][x] = STATES[h % STATES.size]
  end
end

# Compute next state for a cell based on 8 neighbours
def next_state(y, x, grid, words, idx_base, word_count)
  neighbours = [-1, 0, 1].product([-1, 0, 1]) - [[0, 0]]
  sum = 0
  neighbours.each do |dy, dx|
    ny = (y + dy) % grid.size
    nx = (x + dx) % grid[0].size
    sum += STATES.index(grid[ny][nx])
  end
  avg = sum / neighbours.size
  h = rolling_hash(words, (idx_base + y * grid[0].size + x) % word_count)
  (avg + h) % STATES.size
end

# ANSI clear screen
def clear
  print "\e[2J\e[H"
end

# Render grid with color based on state
def render(grid)
  grid.each do |row|
    row.each do |cell|
      case cell
      when '░' then print "\e[38;5;240m#{cell}"
      when '▒' then print "\e[38;5;244m#{cell}"
      when '▓' then print "\e[38;5;247m#{cell}"
      when '█' then print "\e[38;5;255m#{cell}"
      end
    end
    puts "\e[0m"
  end
end

# Main animation loop (run a few cycles)
frames = FPS * 5
frames.times do |frame|
  clear
  render(grid)
  # compute next grid
  new_grid = Array.new(HEIGHT) { Array.new(WIDTH) }
  (0...HEIGHT).each do |y|
    (0...WIDTH).each do |x|
      st = next_state(y, x, grid, words, frame, word_count)
      new_grid[y][x] = STATES[st]
    end
  end
  grid = new_grid
  sleep 1.0 / FPS
end

# ---------- Final frame: QR code ----------
qr = RQRCode::QRCode.new(text, level: :h, size: 6)
module_size = 2 # each module -> 2x1 characters
clear
qr.modules.each_slice(qr.modules.size) do |row|
  line = ''
  row.each do |mod|
    char = mod ? '██' : '  '
    line << char
  end
  puts line
end
puts "\e[0m"
sleep 5  # keep QR on screen briefly before exit