# Virtual Terrarium Memory Leak Simulator in Ruby
# Deliberately leaks heap allocations while rendering a thriving, living ASCII/ANSI terrarium ecosystem.

print "\e[2J\e[?25l"

LEAKED_HEAP = []
WIDTH = 64
HEIGHT = 22

grid = Array.new(HEIGHT) { Array.new(WIDTH, ' ') }

(0...HEIGHT).each do |y|
  (0...WIDTH).each do |x|
    if y == 0 || y == HEIGHT - 1 || x == 0 || x == WIDTH - 1
      grid[y][x] = '#'
    elsif y > HEIGHT - 5
      grid[y][x] = '_'
    else
      grid[y][x] = ' '
    end
  end
end

lichen = [{x: WIDTH / 2, y: HEIGHT - 5, energy: 10}]
leak_size = 0
generation = 0

begin
  loop do
    generation += 1
    
    chunk_size = 1024 * rand(20..80)
    LEAKED_HEAP << ('x' * chunk_size)
    leak_size += chunk_size

    if generation % 2 == 0 && lichen.size < 200
      parent = lichen.sample
      nx = parent[:x] + rand(-3..3)
      ny = parent[:y] + rand(-1..1)
      if nx > 1 && nx < WIDTH - 1 && ny > HEIGHT - 6 && ny < HEIGHT - 1
        lichen << {x: nx, y: ny, energy: 5}
      end
    end

    print "\e[H"
    puts "\e[1;32m=== VIRTUAL TERRARIUM: HEAP ECOSYSTEM SIMULATOR ===\e[0m"
    puts "Leaked Heap: \e[1;31m#{format('%.2f', leak_size / 1024.0 / 1024.0)} MB\e[0m | Objects: \e[1;33m#{LEAKED_HEAP.size}\e[0m | Lichen Colonies: \e[1;32m#{lichen.size}\e[0m"
    puts "-" * WIDTH

    display = grid.map(&:dup)
    lichen.each do |l|
      display[l[:y]][l[:x]] = ['*', 'o', 'x', '%'].sample
    end

    display.each do |row|
      line = row.map do |cell|
        case cell
        when '#' then "\e[90m#\e[0m"
        when '_' then "\e[33m_\e[0m"
        when '*', 'o', 'x', '%' then "\e[32;1m#{cell}\e[0m"
        else ' '
        end
      end.join
      puts line
    end

    puts "\nPress Ctrl+C to harvest the heap and exit."
    sleep 0.12

    if leak_size > 64 * 1024 * 1024
      LEAKED_HEAP.clear
      leak_size = 0
    end
  end
ensure
  print "\e[?25h"
  puts "\nTerrarium reset. Heap reclaimed."
end