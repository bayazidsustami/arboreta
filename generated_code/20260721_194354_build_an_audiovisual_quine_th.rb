q = "q = %p; # Audio-Visual Memory Quine: Swirling ASCII fluid simulation playing live GC memory audio
audio = IO.popen('aplay -q -f u8 -r 8000 2>/dev/null || paplay --raw --rate=8000 --channels=1 2>/dev/null', 'w') rescue nil
code = sprintf(q, q)
t = 0
print \"\e[2J\e[?25l\"
at_exit { print \"\e[?25h\n\" }

loop do
  w, h = 80, 24
  grid = Array.new(h) { Array.new(w, ' ') }
  mem = GC.stat[:heap_live_slots] rescue 40000
  gc_cnt = GC.count

  code.chars.each_with_index do |ch, i|
    next if ch == ' ' || ch == \"\n\"
    r = 3 + 11 * Math.sin(t * 0.03 + i * 0.007)
    angle = t * 0.07 + i * 0.025 + Math.sin(r * 0.4 - t * 0.08)
    x = (w / 2 + r * 2.1 * Math.cos(angle)).to_i
    y = (h / 2 + r * Math.sin(angle)).to_i
    grid[y][x] = ch if x.between?(0, w - 1) && y.between?(0, h - 1)
  end

  print \"\e[H\" + grid.map(&:join).join(\"\n\")

  if audio
    f1 = mem.modulo(350) + 40
    f2 = (gc_cnt * 17).modulo(220) + 30
    pcm = Array.new(200) do |i|
      sample = (Math.sin(i * f1 * 0.0012) * 50 + Math.sin(i * f2 * 0.0018) * 40 + 128).to_i
      sample.clamp(0, 255)
    end
    audio.write(pcm.pack('C*')) rescue nil
  end

  t += 1
  sleep 0.03
end"; # Audio-Visual Memory Quine: Swirling ASCII fluid simulation playing live GC memory audio
audio = IO.popen('aplay -q -f u8 -r 8000 2>/dev/null || paplay --raw --rate=8000 --channels=1 2>/dev/null', 'w') rescue nil
code = sprintf(q, q)
t = 0
print "\e[2J\e[?25l"
at_exit { print "\e[?25h\n" }

loop do
  w, h = 80, 24
  grid = Array.new(h) { Array.new(w, ' ') }
  mem = GC.stat[:heap_live_slots] rescue 40000
  gc_cnt = GC.count

  code.chars.each_with_index do |ch, i|
    next if ch == ' ' || ch == "\n"
    r = 3 + 11 * Math.sin(t * 0.03 + i * 0.007)
    angle = t * 0.07 + i * 0.025 + Math.sin(r * 0.4 - t * 0.08)
    x = (w / 2 + r * 2.1 * Math.cos(angle)).to_i
    y = (h / 2 + r * Math.sin(angle)).to_i
    grid[y][x] = ch if x.between?(0, w - 1) && y.between?(0, h - 1)
  end

  print "\e[H" + grid.map(&:join).join("\n")

  if audio
    f1 = mem.modulo(350) + 40
    f2 = (gc_cnt * 17).modulo(220) + 30
    pcm = Array.new(200) do |i|
      sample = (Math.sin(i * f1 * 0.0012) * 50 + Math.sin(i * f2 * 0.0018) * 40 + 128).to_i
      sample.clamp(0, 255)
    end
    audio.write(pcm.pack('C*')) rescue nil
  end

  t += 1
  sleep 0.03
end