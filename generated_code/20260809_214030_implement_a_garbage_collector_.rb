require 'set'

# Poetic Knapsack Garbage Collector
# Reclaims unreferenced memory blocks by solving a 0/1 Dynamic Knapsack problem
# where each block's 'value' is derived from how poetic its raw binary representation sounds.

class MemoryBlock
  attr_reader :id, :data, :size, :references

  CONSONANTS = %w[b d f k l m n p r s t v z].freeze
  VOWELS = %w[a e i o u].freeze

  def initialize(id, bytes, references: [])
    @id = id
    @data = bytes.pack("C*")
    @size = @data.bytesize
    @references = references
  end

  # Translates binary bytes into phonetic syllables and evaluates meter, rhythm, and rhyme
  def poetic_value
    syllables = @data.bytes.map do |b|
      c = CONSONANTS[(b >> 4) % CONSONANTS.size]
      v = VOWELS[(b & 0x0F) % VOWELS.size]
      "#{c}#{v}"
    end

    phonetic = syllables.join
    score = 10

    # Meter: Alternating vowel-consonant flow
    score += 15 if phonetic =~ /([aeiou][bdfklmnprstvz]){2,}/
    # Alliteration: Repeating consonant sounds
    score += 20 if syllables.map { |s| s[0] }.uniq.size == 1 && syllables.size > 1
    # Rhyme: Harmonic end vowels
    score += 15 if syllables.size > 1 && syllables.first[1] == syllables.last[1]

    [score, 1].max
  end

  def phonetic_representation
    @data.bytes.map do |b|
      c = CONSONANTS[(b >> 4) % CONSONANTS.size]
      v = VOWELS[(b & 0x0F) % VOWELS.size]
      "#{c}#{v}"
    end.join("-")
  end
end

class PoeticGarbageCollector
  attr_reader :heap, :roots

  def initialize
    @heap = {}
    @roots = []
  end

  def allocate(id, bytes, references: [])
    block = MemoryBlock.new(id, bytes, references: references)
    @heap[id] = block
    block
  end

  def add_root(id)
    @roots << id if @heap.key?(id)
  end

  # Mark phase: Find reachable objects starting from root nodes
  def find_unreferenced_blocks
    reachable = Set.new
    queue = @roots.dup

    until queue.empty?
      curr_id = queue.shift
      next if reachable.include?(curr_id)

      reachable.add(curr_id)
      if (block = @heap[curr_id])
        queue.concat(block.references)
      end
    end

    @heap.keys - reachable.to_a
  end

  # Sweep phase: Solves 0/1 Knapsack via Dynamic Programming
  # Selects garbage blocks maximizing total poetic value within the reclamation capacity
  def reclaim_poetic_garbage(capacity)
    unreferenced_ids = find_unreferenced_blocks
    blocks = unreferenced_ids.map { |id| @heap[id] }
    n = blocks.size

    # dp[i][w] stores maximum poetic value achievable with first i blocks and weight budget w
    dp = Array.new(n + 1) { Array.new(capacity + 1, 0) }

    (1..n).each do |i|
      block = blocks[i - 1]
      wt = block.size
      val = block.poetic_value

      (0..capacity).each do |w|
        if wt <= w
          dp[i][w] = [dp[i - 1][w], dp[i - 1][w - wt] + val].max
        else
          dp[i][w] = dp[i - 1][w]
        end
      end
    end

    # Backtrack to identify selected memory blocks for reclamation
    reclaimed = []
    w = capacity
    n.downto(1) do |i|
      if dp[i][w] != dp[i - 1][w]
        block = blocks[i - 1]
        reclaimed << block
        w -= block.size
      end
    end

    # Sweep selected memory blocks from heap
    reclaimed.each { |b| @heap.delete(b.id) }
    { reclaimed: reclaimed, total_poetic_value: dp[n][capacity] }
  end
end

# Execution Demonstration
gc = PoeticGarbageCollector.new

# Memory allocation with varying binary payloads
gc.allocate(:root_obj, [0x12, 0x34, 0x56])
gc.allocate(:active_node, [0x11, 0x11], references: [:root_obj])

# Unreferenced garbage blocks
gc.allocate(:alliterative_verse, [0x41, 0x41, 0x41, 0x41]) # Rhyming "ka-ka-ka-ka"
gc.allocate(:rhythmic_haiku, [0x12, 0x21, 0x12, 0x21])     # Harmonic meter
gc.allocate(:binary_prose, [0x00, 0xFF, 0x00, 0xFF, 0x55]) # Heavy memory footprint

gc.add_root(:active_node)

puts "--- HEAP STATE BEFORE GC ---"
gc.heap.each do |id, block|
  puts "Block :#{id.to_s.ljust(18)} | Size: #{block.size}B | Phonetic: '#{block.phonetic_representation}' | Score: #{block.poetic_value}"
end

gc_capacity = 8 # Max bytes buffer for reclamation pass
result = gc.reclaim_poetic_garbage(gc_capacity)

puts "\n--- RECLAIMED POETIC GARBAGE (Buffer Limit: #{gc_capacity} Bytes) ---"
puts "Total Poetic Harmony Score Achieved: #{result[:total_poetic_value]}"
result[:reclaimed].each do |b|
  puts " -> Reclaimed :#{b.id} (Size: #{b.size}B, Verse: '#{b.phonetic_representation}', Score: #{b.poetic_value})"
end

puts "\n--- REMAINING HEAP ---"
puts gc.heap.keys.inspect