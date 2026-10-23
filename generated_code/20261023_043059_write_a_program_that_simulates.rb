# Digital Ecosystem Simulator in Ruby
# Predators (Variable Names) consume Foliage (Comments) based on CPU execution speed.

class Ecosystem
  def initialize
    @foliage = [
      "# Tender green comment sprout",
      "# Lush explanatory thicket",
      "# Wild drifting documentation",
      "# Ancient fossilized docstring"
    ]
    @predators = [:AlphaVariable, :BetaCollector, :DeltaConsumer, :OmegaMutator]
    @cpu_speed_metric = benchmark_cpu
  end

  # Measures relative CPU speed by running a fast iterative calculation
  def benchmark_cpu
    start_time = Time.now
    100_000.times { Math.sqrt(rand(1000)) }
    duration = Time.now - start_time
    # Inverse scale: faster duration means higher metabolic activity
    [ (1.0 / [duration, 0.0001].max).to_i, 10 ].max
  end

  def simulate(cycles = 3)
    puts "=== Digital Ecosystem Initialized ==="
    puts "Detected CPU Metabolic Rate: #{@cpu_speed_metric} units\n\n"

    cycles.times do |cycle|
      puts "--- Cycle #{cycle + 1} ---"
      
      # Foliage grows based on CPU speed
      new_foliage = "# Sprout of cycle #{cycle + 1}"
      @foliage << new_foliage
      puts "Foliage grew: #{new_foliage}"

      # Predators hunt foliage
      if @foliage.any? && @predators.any?
        predator = @predators.sample
        consumed = @foliage.pop
        puts "Predator `#{predator}` aggressively consumed: #{consumed}"
      end

      # Evolution phase
      if @cpu_speed_metric > 50 && @predators.size < 8
        mutant = :"Mutant_#{rand(1000..9999)}"
        @predators << mutant
        puts "Evolution Event: High CPU energy spawned new predator `#{mutant}`!"
      end

      puts "Ecosystem State -> Predators: #{@predators.size}, Foliage patches: #{@foliage.size}\n\n"
      sleep(0.5)
    end
  end
end

Ecosystem.new.simulate(3)