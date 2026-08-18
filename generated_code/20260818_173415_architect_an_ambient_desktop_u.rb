require 'tk'
require 'open3'
require 'json'

# --- Configuration & Palette ---
CONFIG = {
  window_width: 1000,
  window_height: 700,
  poll_interval: 3000, # ms
  bg_color: '#0d1117',
  ground_color: '#161b22',
  branch_colors: ['#2ea043', '#238636', '#1e7e34', '#3fb950', '#56d364'],
  flower_colors: ['#f78166', '#d2a8ff', '#79c0ff', '#ffa657', '#ff7b72'],
  repos: ['.'] # Paths to Git repositories to monitor
}.freeze

# --- Git Listener ---
class GitMonitor
  def initialize(repo_paths)
    @repo_paths = repo_paths
    @last_commits = {}
    @resolved_issues = 0
    @commit_count = 0
  end

  def scan!
    new_data = false
    @repo_paths.each do |path|
      next unless Dir.exist?(File.join(path, '.git'))

      # Fetch total commits and last commit hash
      commits = `git -C "#{path}" rev-list --count HEAD 2>/dev/null`.strip.to_i
      last_hash = `git -C "#{path}" rev-parse HEAD 2>/dev/null`.strip

      if @last_commits[path] && @last_commits[path] != last_hash
        new_data = true
      end

      @last_commits[path] = last_hash
      @commit_count += (commits - (@commit_counts_map ||= {})[path].to_i) if @commit_counts_map&.key?(path)
      (@commit_counts_map ||= {})[path] = commits

      # Check for resolved issues in commit messages (e.g., "Fixes #12", "Closes #5")
      logs = `git -C "#{path}" log -n 50 --oneline 2>/dev/null`
      @resolved_issues = logs.scan(/(?:fixes|closes|resolves)\s+#\d+/i).size
    end
    [new_data, @commit_count, @resolved_issues]
  end
end

# --- Procedural Forest Renderer ---
class ForestCanvas
  def initialize(root)
    @canvas = TkCanvas.new(root) do
      background CONFIG[:bg_color]
      highlightthickness 0
      pack(fill: 'both', expand: true)
    end
    @width = CONFIG[:window_width]
    @height = CONFIG[:window_height]
    @rng = Random.new(42)
  end

  def render(repo_count, total_commits, issues_resolved)
    @canvas.delete('all')
    draw_ground

    trees_to_draw = [repo_count, 1].max
    spacing = @width / (trees_to_draw + 1)

    trees_to_draw.times do |i|
      x = spacing * (i + 1)
      y = @height - 40
      base_length = [80 + (total_commits * 2), 180].min
      depth = [5 + (total_commits / 5), 10].min
      
      draw_tree(x, y, -90, base_length, depth, issues_resolved)
    end
  end

  private

  def draw_ground
    TkcRectangle.new(@canvas, 0, @height - 40, @width, @height, 
                     fill: CONFIG[:ground_color], outline: '')
  end

  def draw_tree(x, y, angle, length, depth, remaining_flowers)
    return remaining_flowers if depth <= 0 || length < 4

    # Calculate endpoint using trigonometry
    rad = angle * Math::PI / 180.0
    x_end = x + length * Math.cos(rad)
    y_end = y + length * Math.sin(rad)

    # Draw branch
    color = CONFIG[:branch_colors][depth % CONFIG[:branch_colors].size]
    width = [depth * 1.2, 1].max
    TkcLine.new(@canvas, x, y, x_end, y_end, width: width, fill: color, capstyle: 'round')

    # Recursive branching
    spread = 20 + @rng.rand(15)
    shrink = 0.7 + (@rng.rand * 0.1)

    remaining = remaining_flowers
    remaining = draw_tree(x_end, y_end, angle - spread, length * shrink, depth - 1, remaining)
    remaining = draw_tree(x_end, y_end, angle + spread, length * shrink, depth - 1, remaining)

    # Render blooming flower at terminal tips if resolved issues exist
    if depth <= 2 && remaining > 0
      flower_color = CONFIG[:flower_colors][remaining % CONFIG[:flower_colors].size]
      radius = 4 + @rng.rand(3)
      TkcOval.new(@canvas, x_end - radius, y_end - radius, x_end + radius, y_end + radius, 
               fill: flower_color, outline: '')
      remaining -= 1
    end

    remaining
  end
end

# --- Application Controller ---
class AmbientForestApp
  def initialize
    @root = TkRoot.new do
      title "Git Forest - Ambient Canvas"
      geometry("#{CONFIG[:window_width]}x#{CONFIG[:window_height]}")
      configure(background: CONFIG[:bg_color])
    end

    @monitor = GitMonitor.new(CONFIG[:repos])
    @forest = ForestCanvas.new(@root)

    schedule_poll
  end

  def run
    Tk.mainloop
  end

  private

  def update_forest
    _changed, commits, issues = @monitor.scan!
    repo_count = CONFIG[:repos].size
    @forest.render(repo_count, commits, issues)
  end

  def schedule_poll
    update_forest
    TkTimer.new(CONFIG[:poll_interval], -1, proc { update_forest }).start
  end
end

# Start the ambient monitor
AmbientForestApp.new.run