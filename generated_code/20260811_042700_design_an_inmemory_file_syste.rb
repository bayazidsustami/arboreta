# ==============================================================================
# Reversible Cellular Automaton In-Memory File System (RCA-FS)
#
# Encodes binary files into the evolved state of a 1D Second-Order Reversible
# Cellular Automaton (Rule 150 phase space). File retrieval requires computing
# the exact mathematical inverse across time steps to reverse entropy and
# reconstruct original bit patterns.
# ==============================================================================

class AutomatonFS
  # Rule 150 local state transition function: f(L, C, R) = L ^ C ^ R
  RULE = ->(l, c, r) { l ^ c ^ r }

  def initialize
    @storage = {}
  end

  # Encodes binary data into an evolved cellular automaton state
  def write(path, data, generations = 100)
    bits = bytes_to_bits(data)
    len = bits.size

    # Key generation: deterministic boundary condition t=(-1) derived from path
    t_minus_1 = Array.new(len) { |i| (path.bytes.sum + i) & 1 }
    t_0 = bits

    # Evolve cellular grid forward through discrete time steps
    t_prev = t_minus_1
    t_curr = t_0

    generations.times do
      t_next = step_forward(t_prev, t_curr)
      t_prev = t_curr
      t_curr = t_next
    end

    # Store only the evolved boundary state pair (t_N, t_N-1)
    @storage[path] = {
      state_curr: pack_bits(t_curr),
      state_prev: pack_bits(t_prev),
      bit_len: len,
      generations: generations
    }
  end

  # Reconstructs original data by computing backward temporal dynamics
  def read(path)
    record = @storage.fetch(path) { raise "File not found: #{path}" }

    t_future = unpack_bits(record[:state_curr], record[:bit_len])
    t_curr   = unpack_bits(record[:state_prev], record[:bit_len])

    # Reverse entropy: iterate backward T-1 steps to reconstruct t_0
    (record[:generations] - 1).times do
      t_prev = step_backward(t_curr, t_future)
      t_future = t_curr
      t_curr   = t_prev
    end

    bits_to_bytes(t_curr)
  end

  # Visual representation of the stored automaton state
  def visual_snapshot(path, width = 64)
    record = @storage[path]
    return nil unless record
    bits = unpack_bits(record[:state_curr], record[:bit_len]).first(width)
    bits.map { |b| b == 1 ? "█" : "░" }.join
  end

  def files
    @storage.keys
  end

  private

  # Forward time step: S(t+1) = Rule(S(t)) XOR S(t-1)
  def step_forward(t_prev, t_curr)
    len = t_curr.size
    Array.new(len) do |i|
      l = t_curr[(i - 1) % len]
      c = t_curr[i]
      r = t_curr[(i + 1) % len]
      RULE.call(l, c, r) ^ t_prev[i]
    end
  end

  # Backward time step (Temporal Inverse): S(t-1) = Rule(S(t)) XOR S(t+1)
  def step_backward(t_curr, t_future)
    len = t_curr.size
    Array.new(len) do |i|
      l = t_curr[(i - 1) % len]
      c = t_curr[i]
      r = t_curr[(i + 1) % len]
      RULE.call(l, c, r) ^ t_future[i]
    end
  end

  def bytes_to_bits(data)
    data.bytes.flat_map { |b| (0..7).map { |i| (b >> (7 - i)) & 1 } }
  end

  def bits_to_bytes(bits)
    bits.each_slice(8).map do |byte_bits|
      byte_bits.reduce(0) { |acc, bit| (acc << 1) | bit }
    end.pack('C*')
  end

  def pack_bits(bits)
    bits.each_slice(8).map { |b| b.reduce(0) { |acc, bit| (acc << 1) | bit } }.pack('C*')
  end

  def unpack_bits(packed, bit_len)
    bits = packed.unpack('C*').flat_map { |b| (0..7).map { |i| (b >> (7 - i)) & 1 } }
    bits.first(bit_len)
  end
end

# --- Demonstration & Verification ---
fs = AutomatonFS.new

payloads = {
  "/secret.txt" => "Cellular automata can store and invert entropy!",
  "/data.bin"   => [0xDE, 0xAD, 0xBE, 0xEF, 0x42, 0x13, 0x37].pack('C*')
}

puts "=== RCA Cellular Automaton File System ==="
puts

payloads.each do |path, content|
  gens = 128
  puts "Writing '#{path}' (#{content.bytesize} bytes) evolved over #{gens} generations..."
  fs.write(path, content, gens)

  puts "Stored CA Grid Snapshot: [#{fs.visual_snapshot(path)}...]"
  
  puts "Computing temporal inverse back #{gens} steps..."
  restored = fs.read(path)
  
  success = (restored == content)
  puts "Restored Content: #{restored.inspect}"
  puts "Integrity Check: #{success ? 'PASSED (100% Exact Match)' : 'FAILED'}"
  puts "-" * 60
end