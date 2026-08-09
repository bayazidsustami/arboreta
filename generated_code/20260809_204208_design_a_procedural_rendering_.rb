# Procedural Git Repository Plant Renderer
#
# Translates Git commit history into a 3D procedural visual model (represented 
# via structured ASCII/ANSI vector projection) where:
#  - Code Churn forms the branch network (length, thickness, & recursion)
#  - Successful builds / clean commits yield blooming flowers
#  - Failed tests / revert commits introduce visual decay and withered leaves

require 'digest'

class GitPlantRenderer
  # ANSI Color Codes for dynamic terminal rendering
  COLOR_STEM   = "\e[32m"
  COLOR_FLOWER = "\e[35m"
  COLOR_DECAY  = "\e[33m"
  COLOR_DEAD   = "\e[31m"
  COLOR_RESET  = "\e[0m"

  Node = Struct.new(:x, :y, :z, :type, :char, :color)

  def initialize(repo_path = '.')
    @repo_path = repo_path
    @nodes = []
  end

  # Extract commit logs using git log
  def fetch_commit_history
    raw_log = `git -C "#{@repo_path}" log --pretty=format:"%h|%s" --shortstat 2>/dev/null`
    return mock_commit_history if raw_log.strip.empty?

    commits = []
    current_commit = nil

    raw_log.each_line do |line|
      line.strip!
      if line =~ /^([a-f0-9]+)\|(.*)$/
        commits << current_commit if current_commit
        current_commit = { hash: $1, msg: $2, additions: 0, deletions: 0 }
      elsif line =~ /(\d+) insertion.*(\d+) deletion/
        current_commit[:additions] = $1.to_i if current_commit
        current_commit[:deletions] = $2.to_i if current_commit
      elsif line =~ /(\d+) insertion/
        current_commit[:additions] = $1.to_i if current_commit
      elsif line =~ /(\d+) deletion/
        current_commit[:deletions] = $1.to_i if current_commit
      end
    end
    commits << current_commit if current_commit
    commits.reverse
  end

  # Fallback generator if run outside a valid git repo
  def mock_commit_history
    [
      { hash: "a1b2c3d", msg: "Initial commit", additions: 50, deletions: 0 },
      { hash: "b2c3d4e", msg: "Add core features", additions: 120, deletions: 10 },
      { hash: "c3d4e5f", msg: "Fix failing tests", additions: 15, deletions: 45 },
      { hash: "d4e5f6a", msg: "BROKEN BUILD: test failure", additions: 80, deletions: 5 },
      { hash: "e5f6a7b", msg: "Refactor engine and cleanup", additions: 40, deletions: 60 },
      { hash: "f6a7b8c", msg: "Release v1.0 [build success]", additions: 200, deletions: 30 }
    ]
  end

  # Grow procedural 3D plant network based on commit mechanics
  def grow_plant(commits)
    x, y, z = 0.0, 0.0, 0.0
    dx, dy, dz = 0.0, 1.0, 0.0 # Initial upward direction

    commits.each_with_index do |commit, index|
      churn = commit[:additions] + commit[:deletions]
      decay = commit[:msg] =~ /fail|fix|bug|broken|revert/i || commit[:deletions] > commit[:additions]
      bloom = commit[:msg] =~ /release|build|pass|feat|merge/i && !decay

      # Stem growth proportional to code churn
      segment_length = [Math.log2(churn + 2).ceil, 1].max
      
      segment_length.times do
        x += dx
        y += dy
        z += dz
        @nodes << Node.new(x, y, z, :stem, "|", COLOR_STEM)
      end

      # Branching angle based on hash digest seed
      seed = Digest::MD5.hexdigest(commit[:hash]).hex
      angle_x = ((seed % 90) - 45) * Math::PI / 180.0
      angle_z = (((seed / 90) % 90) - 45) * Math::PI / 180.0

      dx = Math.sin(angle_x)
      dy = Math.cos(angle_x)
      dz = Math.sin(angle_z)

      # Append leaves, flowers, or visual decay
      if decay
        @nodes << Node.new(x + 0.5, y, z, :decay, "w", COLOR_DECAY)
        @nodes << Node.new(x - 0.5, y - 0.5, z, :decay, "x", COLOR_DEAD)
      elsif bloom
        @nodes << Node.new(x, y + 0.5, z, :flower, "*", COLOR_FLOWER)
        @nodes << Node.new(x + 0.3, y + 0.3, z, :flower, "@", COLOR_FLOWER)
        @nodes << Node.new(x - 0.3, y + 0.3, z, :flower, "@", COLOR_FLOWER)
      else
        @nodes << Node.new(x + 0.4, y, z, :leaf, "o", COLOR_STEM)
      end
    end
  end

  # Project 3D nodes onto 2D ASCII grid buffer
  def render(width = 60, height = 30)
    buffer = Array.new(height) { Array.new(width, " ") }
    
    # Simple isometric projection perspective
    max_y = @nodes.map(&:y).max.to_f
    max_y = 1.0 if max_y == 0

    @nodes.each do |node|
      # Transform 3D (x, y, z) to 2D screen coordinates
      screen_x = ((node.x - node.z) * 1.5 + width / 2).round
      screen_y = (height - 1 - (node.y / max_y * (height - 4))).round

      if screen_x.between?(0, width - 1) && screen_y.between?(0, height - 1)
        buffer[screen_y][screen_x] = "#{node.color}#{node.char}#{COLOR_RESET}"
      end
    end

    # Render frame
    puts "\e[H\e[2J" # Clear screen
    puts "--- Git Procedural Lifecycle Plant ---"
    buffer.each { |row| puts row.join }
    puts "Legend: #{COLOR_STEM}|/o Stem/Leaf#{COLOR_RESET} | #{COLOR_FLOWER}* Bloom#{COLOR_RESET} | #{COLOR_DECAY}w Decay#{COLOR_RESET} | #{COLOR_DEAD}x Withered#{COLOR_RESET}"
  end

  def run
    commits = fetch_commit_history
    grow_plant(commits)
    render
  end
end

GitPlantRenderer.new.run