# Haikulang Interpreter: An esoteric machine where memory decays into primes
# unless fed valid 5-7-5 Japanese morae haikus.

class HaikuInterpreter
  # Simple primality test and generator
  def self.prime?(n)
    return false if n <= 1
    (2..Math.sqrt(n)).none? { |i| (n % i).zero? }
  end

  def self.next_prime(n)
    n += 1
    n += 1 until prime?(n)
    n
  end

  # Simplified Japanese mora counter for hiragana and katakana
  def self.count_morae(line)
    kana = line.scan(/[\u3040-\u309F\u30A0-\u30FF]/)
    kana.empty? ? line.strip.split(/\s+/).size : kana.size
  end

  def self.valid_haiku?(input_lines)
    return false if input_lines.size != 3
    morae = input_lines.map { |l| count_morae(l) }
    morae == [5, 7, 5]
  end

  def initialize(program)
    @program = program
    @ip = 0
    @memory = Hash.new(0)
    @pointer = 0
    @decay_timers = Hash.new(5) # Steps before memory decays into a prime
  end

  def run
    while @ip < @program.length
      execute_instruction(@program[@ip])
      apply_decay
      @ip += 1
    end
  end

  private

  def execute_instruction(inst)
    case inst
    when '+' then @memory[@pointer] += 1
    when '-' then @memory[@pointer] -= 1
    when '>' then @pointer += 1
    when '<' then @pointer = [@pointer - 1, 0].max
    when '.' then print @memory[@pointer].chr rescue print '?'
    when ','
      print "\n[MEMORY DECAY WARNING] Feed a valid Japanese haiku (5-7-5) to stabilize memory: \n"
      lines = 3.times.map { gets&.chomp }.compact
      if self.class.valid_haiku?(lines)
        puts "-> Haiku accepted! Memory stabilized."
        @decay_timers.keys.each { |k| @decay_timers[k] = 10 }
      else
        puts "-> Invalid haiku! Memory turbulence increases."
        @memory[@pointer] = self.class.next_prime(@memory[@pointer])
      end
    end
  end

  def apply_decay
    @decay_timers.each do |addr, timer|
      @decay_timers[addr] = timer - 1
      if @decay_timers[addr] <= 0
        @memory[addr] = self.class.next_prime(@memory[addr])
        @decay_timers[addr] = 5
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  sample_program = "+ + + + + + + + + + . , + + + ."
  interpreter = HaikuInterpreter.new(sample_program.split)
  interpreter.run
end