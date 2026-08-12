require 'net/http'
require 'json'
require 'uri'

# ==============================================================================
# Spacetime-Warped Self-Balancing Binary Search Tree
# Node rotations and rebalancing thresholds dynamically warp based on 
# live LIGO Gravitational Wave telemetry h(t) or simulated black hole inspirals.
# ==============================================================================

class GravitationalWaveTelemetry
  LIGO_API_URL = "[https://gracedb.ligo.org/api/superevents/?limit=1&format=json](https://gracedb.ligo.org/api/superevents/?limit=1&format=json)"

  def initialize
    @time = 0.0
  end

  # Fetches live spacetime strain proxy from LIGO GraceDB, with fallback to simulated inspiral.
  def current_strain
    uri = URI(LIGO_API_URL)
    req = Net::HTTP::Get.new(uri)
    req['Accept'] = 'application/json'
    
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 1, open_timeout: 1) do |http|
      http.request(req)
    end

    if res.is_a?(Net::HTTPSuccess)
      data = JSON.parse(res.body)
      event = data['num_results'].to_i > 0 ? data['superevents'].first : nil
      if event && event['far']
        far = event['far'].to_f
        return [(1.0 / (1.0 + Math.log10(far.abs + 1e-30).abs)), 0.05].max
      end
    end
    simulated_inspiral_strain
  rescue StandardError
    simulated_inspiral_strain
  end

  private

  # Simulates binary black hole inspiral strain h(t) = A(t) * cos(phi(t))
  def simulated_inspiral_strain
    @time += 0.15
    tc = 20.0 # Coalescence timescale
    tau = [tc - (@time % tc), 0.01].max
    amplitude = 0.001 * (tau ** -0.25)
    frequency = 30.0 * (tau ** -0.375)
    strain = amplitude * Math.cos(frequency * @time)
    strain.abs.clamp(0.01, 2.5)
  end
end

class SpacetimeBST
  class Node
    attr_accessor :key, :value, :left, :right, :height, :mass

    def initialize(key, value)
      @key = key
      @value = value
      @left = nil
      @right = nil
      @height = 1
      @mass = (key.to_s.bytes.sum % 10) + 1 # Mass property distorting local tree geometry
    end
  end

  def initialize
    @root = nil
    @telemetry = GravitationalWaveTelemetry.new
  end

  def height(node)
    node ? node.height : 0
  end

  def update_height(node)
    return unless node
    node.height = 1 + [height(node.left), height(node.right)].max
  end

  # Effective balance factor warped by gravitational strain metric g_μν
  def balance_factor(node)
    return 0 unless node
    raw_balance = height(node.left) - height(node.right)
    strain = @telemetry.current_strain
    (raw_balance * (1.0 + strain)).round
  end

  # Right Rotation (Geodesic adjustment)
  def rotate_right(y)
    x = y.left
    t2 = x.right

    x.right = y
    y.left = t2

    update_height(y)
    update_height(x)
    x
  end

  # Left Rotation (Geodesic adjustment)
  def rotate_left(x)
    y = x.right
    t2 = y.left

    y.left = x
    x.right = t2

    update_height(x)
    update_height(y)
    y
  end

  def insert(key, value)
    @root = insert_node(@root, key, value)
  end

  def insert_node(node, key, value)
    return Node.new(key, value) unless node

    if key < node.key
      node.left = insert_node(node.left, key, value)
    elsif key > node.key
      node.right = insert_node(node.right, key, value)
    else
      node.value = value
      return node
    end

    update_height(node)
    rebalance(node)
  end

  # Rebalances tree dynamically based on spacetime curvature metric
  def rebalance(node)
    bf = balance_factor(node)
    strain = @telemetry.current_strain

    # High gravitational wave strain induces frame-dragging rotations
    if bf > 1 || (strain > 0.8 && height(node.left) > height(node.right))
      if balance_factor(node.left) < 0
        node.left = rotate_left(node.left)
      end
      return rotate_right(node)
    end

    if bf < -1 || (strain > 0.8 && height(node.right) > height(node.left))
      if balance_factor(node.right) > 0
        node.right = rotate_right(node.right)
      end
      return rotate_left(node)
    end

    node
  end

  # Search path with relativistic time dilation & dynamic path bending
  def search(key)
    strain = @telemetry.current_strain
    steps = 0
    current = @root

    puts "\n--- [Spacetime Curvature Metric h(t) = #{'%.5f' % strain}] ---"

    while current
      steps += 1
      # Time dilation effect on traversal cost based on strain and node mass
      dilated_cost = 1.0 + (strain * current.mass)
      sleep(0.0005 * dilated_cost)

      if key == current.key
        puts "Found '#{key}' in #{steps} geodesic hops (Time dilation factor: #{'%.3f' % dilated_cost}x)"
        return current.value
      elsif key < current.key
        # Gravitational lensing: severe strain occasionally bends path towards heavier branch
        if strain > 1.2 && rand < 0.15 && current.right
          current = current.right
        else
          current = current.left
        end
      else
        current = current.right
      end
    end

    puts "Key '#{key}' lost beyond the event horizon after #{steps} steps."
    nil
  end

  # Visual representation of tree topology flexing under strain
  def display(node = @root, prefix = '', is_left = true)
    return unless node
    puts "#{prefix}#{is_left ? '├── ' : '└── '}[#{node.key}] (h=#{node.height}, mass=#{node.mass})"
    display(node.left, "#{prefix}#{is_left ? '│   ' : '    '}", true) if node.left
    display(node.right, "#{prefix}#{is_left ? '│   ' : '    '}", false) if node.right
  end
end

# Execution Demo
tree = SpacetimeBST.new
data_keys = [42, 15, 88, 7, 23, 71, 99, 3, 11, 19, 36, 64, 91, 100]

puts "=================================================================="
puts "  Spacetime-Warped BST: Live Gravitational Wave Telemetry Engine  "
puts "=================================================================="

data_keys.each do |k|
  tree.insert(k, "Val-#{k}")
end

puts "\nCurrent Spacetime Tree Topology:"
tree.display

puts "\nExecuting search queries under dynamic strain fluctuations:"
[23, 91, 7, 100, 999].each do |k|
  tree.search(k)
end