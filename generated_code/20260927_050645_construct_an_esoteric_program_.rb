# Constellation Weaver - An esoteric ASCII poetry visualizer driven by memory address coordinates
# Run in your terminal with: ruby script.rb

POEMS = [
  "Silent stars drift through the heap",
  "Garbage collectors fall asleep",
  "Pointers dangle in the dark",
  "Ghostly echoes leave their mark",
  "Allocations bleed and glow",
  "Byte by byte, the numbers flow"
]

# Generate spatial coordinates from transient memory allocations (simulated leaks)
def fetch_stellar_coordinates
  loop do
    # Allocate unreferenced strings to capture real memory address shifts via object_id
    debris = 5.times.map { "leak_#{rand(10**8)}".to_sym }
    xs = debris.map { |d| (d.object_id >> 3) % 70 + 5 }
    ys = debris.map { |d| (d.object_id >> 6) % 20 + 3 }
    yield xs.zip(ys)
    sleep(0.15)
  end
end

# Prepare terminal
print "\e[2J\e[?25l"

begin
  step = 0
  fetch_stellar_coordinates do |coords|
    print "\e[H"
    print "\e[38;5;240m--- MEMORY HEAP CONSTELLATION MAP (Press Ctrl+C to exit) ---\e[0m\n\n"
    
    current_verse = POEMS[(step / 5) % POEMS.length]
    
    coords.each_with_index do |(x, y), idx|
      char = current_verse[idx % current_verse.length]
      # Draw poetry characters at coordinates derived from memory addresses
      print "\e[#{y};#{x}H\e[38;5;#{46 + idx * 30}m✦ #{char}\e[0m"
    end

    step += 1
  end
ensure
  # Restore terminal state on exit
  print "\e[?25h\e[2J\e[H"
  puts "The cosmos settles back into the void."
end