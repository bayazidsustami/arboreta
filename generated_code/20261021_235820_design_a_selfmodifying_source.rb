# Atmospheric Ruby Interpreter
# Features: Barometric pressure-driven variable mutation & poetic syntax error reflection.

class AtmosphericInterpreter
  POEMS = [
    "A sudden gust disturbs the parser's line,\nAt %{pressure} hPa, logic must resign.",
    "The barometer drops, the brackets drift apart,\nA syntax fracture in the code's cold heart.",
    "Winds of %{pressure} hPa howl through the stack,\nUnbalanced tokens on a stormy track."
  ]

  def initialize
    @environment = {}
  end

  # Simulates local atmospheric pressure reading (hPa)
  def read_pressure
    1013.25 + (Math.sin(Time.now.to_f / 2) * 25.0)
  end

  # Mutates variable names based on atmospheric pressure
  def mutate_variables(pressure)
    mutated = {}
    @environment.each do |key, val|
      new_key = case pressure
      when 0..1000
        key.to_s.reverse.to_sym
      when 1000..1020
        key
      else
        key.to_s.upcase.to_sym
      end
      mutated[new_key] = val
    end
    @environment = mutated
  end

  def execute(source_code)
    pressure = read_pressure.round(2)
    mutate_variables(pressure)

    # Construct binding environment
    b = binding
    @environment.each { |k, v| b.local_variable_set(k, v) }

    begin
      result = eval(source_code, b)
      # Extract updated local variables back into environment
      b.local_variables.each do |var|
        @environment[var] = b.local_variable_get(var)
      end
      result
    rescue Exception => e
      recite_poetry(e, pressure)
    end
  end

  private

  def recite_poetry(error, pressure)
    poem = POEMS.sample % { pressure: pressure }
    puts "\n--- ATMOSPHERIC ANOMALY DETECTED ---"
    puts "Barometric Pressure: #{pressure} hPa"
    puts "Error: #{error.message.strip}"
    puts "\nPoetic Reflection:"
    poem.each_line { |line| puts "  #{line}" }
    puts "------------------------------------\n"
    nil
  end
end

# --- Demonstration ---
if __FILE__ == $0
  interpreter = AtmosphericInterpreter.new

  puts "Running valid code..."
  interpreter.execute("weather_var = 100")
  interpreter.execute("puts \"Value: #{weather_var}\"")

  # Simulating a syntax error to trigger poetic reflection
  puts "\nTriggering syntax error..."
  interpreter.execute("weather_var = ")
end