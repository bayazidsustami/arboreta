#!/usr/bin/env ruby
# Simple sound‑reactive mandala demo.
# Uses Unicode combining marks to “draw” and a tiny Brain‑fuck interpreter
# as the esolang snippet attached to each cell. Audio input is faked with
# random values so the script stays self‑contained.

require 'io/console'

W = 40
H = 20
TICKS = 200          # how many frames to render
COMB = ["\u0300","\u0301","\u0302","\u0303","\u0305","\u0307","\u0308","\u030a","\u030c","\u030f"]
BASE = "·"            # base glyph for empty cells

# tiny brain‑fuck programs (max 8 commands) that produce a byte 0‑255
SNIPS = [
  "++>+[-<+>]" ,     # simple loop
  "+[>+<-]" ,        # increment neighbour
  "+++[>+++<-]" ,    # multiply
  ">>+<<[-]" ,       # move and cancel
  "[-]" ,            # zero
  "+[>+>+<<-]>>[-<<+>>]" , # copy
  "++++[>++++<-]>." ,# output 'A'
  "+++[>+++<-]>." ,  # output 'C'
]

# Each cell stores a snippet, a tape and a pointer
Cell = Struct.new(:code, :ip, :tape, :ptr)

grid = Array.new(H) { Array.new(W) { 
  Cell.new(SNIPS.sample, 0, Array.new(10,0), 0)
}}

def step_brainfuck(cell, steps=10)
  code = cell.code
  ip   = cell.ip
  tape = cell.tape
  ptr  = cell.ptr
  steps.times do
    break if ip >= code.length
    case code[ip]
    when '>'
      ptr = (ptr + 1) % tape.length
    when '<'
      ptr = (ptr - 1) % tape.length
    when '+'
      tape[ptr] = (tape[ptr] + 1) % 256
    when '-'
      tape[ptr] = (tape[ptr] - 1) % 256
    when '.'
      # no output, we’ll use cell value later
    when ','
      # ignore input
    when '['
      if tape[ptr] == 0
        # jump forward
        open = 1
        while open > 0
          ip += 1
          break if ip >= code.length
          open += 1 if code[ip] == '['
          open -= 1 if code[ip] == ']'
        end
      end
    when ']'
      if tape[ptr] != 0
        # jump back
        close = 1
        while close > 0
          ip -= 1
          break if ip < 0
          close += 1 if code[ip] == ']'
          close -= 1 if code[ip] == '['
        end
      end
    end
    ip += 1
  end
  cell.ip = ip % code.length
  cell.ptr = ptr
  cell.tape = tape
  tape[ptr]
end

def render(grid)
  out = ""
  grid.each do |row|
    row.each do |cell|
      val = cell.tape[cell.ptr]
      comb = COMB[val % COMB.size]
      out << BASE + comb
    end
    out << "\n"
  end
  out
end

def clear_screen
  print "\e[2J\e[H"
end

clear_screen
TICKS.times do |tick|
  # fake audio amplitude: 0..1
  amp = rand
  # number of cells to disturb proportional to amplitude
  disturb = (amp * 30).to_i
  disturb.times do
    y = rand(H)
    x = rand(W)
    cell = grid[y][x]
    # mutate snippet rarely
    cell.code = SNIPS.sample if rand < 0.05
    # run its tiny brainfuck
    step_brainfuck(cell)
  end
  # render
  clear_screen
  puts "Mandala – tick #{tick+1} – amplitude #{'%.2f' % amp}"
  puts render(grid)
  sleep 0.05
end

puts "\nFinished."