# frozen_string_literal: true

# Read the whole poem from STDIN
poem = STDIN.read

# Simple syllable stress estimator: count vowel groups in each word,
# alternating stressed (1) and unstressed (0) per syllable.
vowels = /[aeiouyAEIOUY]+/
stress_bits = []
poem.split(/\s+/).each do |word|
  syllables = word.scan(vowels).size
  syllables.times { |i| stress_bits << (i.even? ? 1 : 0) }
end

# If no bits were found, fallback to a default pattern
stress_bits = [1, 0, 1, 0, 1, 0] if stress_bits.empty?

# Width of the mandala = next odd number >= bits length
width = stress_bits.size
width += 1 if width.even?

# Pad/trim bits to fit width
bits = stress_bits.take(width)
bits += [0] * (width - bits.size) if bits.size < width

# Initialize cellular automaton grid (Rule 90)
generations = 73
grid = Array.new(generations + 1) { Array.new(width, 0) }
grid[0] = bits

# Apply Rule 90 for each generation
generations.times do |g|
  (0...width).each do |x|
    left  = grid[g][(x - 1) % width]
    right = grid[g][(x + 1) % width]
    grid[g + 1][x] = left ^ right
  end
end

# Mapping of cell state to Unicode block elements
glyph = { 0 => '░', 1 => '█' }

# Print the mandala (centered)
grid.each do |row|
  puts row.map { |c| glyph[c] }.join
end