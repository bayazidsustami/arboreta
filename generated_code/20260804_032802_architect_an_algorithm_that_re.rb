# Git Fluid Tapestry: Generative Fluid Dynamics from Git Commit History
# Simulates fluid flow where commits inject energy/density, merges induce rotational vortexes,
# and bug fixes dissipate turbulence via increased viscosity damping.
# Renders directly to terminal via ANSI RGB color gradients and Unicode density blocks.

require 'open3'

class GitFluidTapestry
  WIDTH = 70
  HEIGHT = 35
  DENSITY_RAMP = [' ', '░', '▒', '▓', '█'].freeze

  def initialize
    @u = Array.new(HEIGHT) { Array.new(WIDTH, 0.0) }       # X-velocity
    @v = Array.new(HEIGHT) { Array.new(WIDTH, 0.0) }       # Y-velocity
    @density = Array.new(HEIGHT) { Array.new(WIDTH, 0.0) } # Fluid density
    @r = Array.new(HEIGHT) { Array.new(WIDTH, 0.0) }       # Red color component
    @g = Array.new(HEIGHT) { Array.new(WIDTH, 0.0) }       # Green color component
    @b = Array.new(HEIGHT) { Array.new(WIDTH, 0.0) }       # Blue color component
    @viscosity = 0.96
  end

  # Main execution loop
  def run
    commits = load_git_history
    setup_terminal

    commits.each_with_index do |commit, index|
      apply_commit_impulse(commit, index, commits.size)
      
      # Animate dynamic fluid physics between commits
      12.times do
        update_physics
        render_frame(commit[:subject])
        sleep 0.04
      end
    end
  ensure
    restore_terminal
  end

  private

  # Fetches real git commit logs or falls back to synthetic history if outside a repo
  def load_git_history
    out, _, status = Open3.capture3("git log --pretty=format:'%h|%p|%s' --stat -n 35")
    return parse_git_log(out) if status.success? && !out.strip.empty?

    generate_mock_history
  end

  def parse_git_log(log_text)
    commits = []
    current = nil

    log_text.each_line do |line|
      line.strip!
      if line =~ /^([0-9a-f]+)\|([^|]*)\|(.+)$/
        commits << current if current
        parents = $2.split
        current = {
          hash: $1,
          is_merge: parents.size > 1,
          subject: $3,
          additions: 0,
          deletions: 0,
          is_fix: !($3 =~ /fix|bug|patch|resolve|clean/i).nil?
        }
      elsif line =~ /(\d+)\s+insertion.*?(\d+)\s+deletion/
        current[:additions] += $1.to_i if current
        current[:deletions] += $2.to_i if current
      end
    end
    commits << current if current
    commits.compact
  end

  def generate_mock_history
    [
      { hash: "a1b2c3d", is_merge: false, subject: "Initial feature commit", additions: 140, deletions: 10, is_fix: false },
      { hash: "e4f5g6h", is_merge: false, subject: "Fix memory leak in buffer", additions: 25, deletions: 30, is_fix: true },
      { hash: "7890abc", is_merge: true,  subject: "Merge pull request #42 from dev", additions: 350, deletions: 120, is_fix: false },
      { hash: "def1234", is_merge: false, subject: "Refactor core loop & resolve bugs", additions: 50, deletions: 90, is_fix: true },
      { hash: "5678ghi", is_merge: true,  subject: "Merge branch 'main' into release", additions: 500, deletions: 200, is_fix: false }
    ]
  end

  # Maps commit dynamics onto fluid state: merges swirl, fixes smooth turbulence, lines add mass
  def apply_commit_impulse(commit, idx, total)
    cx = ((idx + 1).to_f / (total + 1) * (WIDTH - 10) + 5).to_i
    cy = HEIGHT / 2 + rand(-5..5)
    
    impact = [(commit[:additions] + commit[:deletions]) / 15.0 + 3.0, 15.0].min

    # Bug fix: dissipates turbulence by dampening local velocity and smoothing field
    if commit[:is_fix]
      radius = 6
      (-radius..radius).each do |dy|
        (-radius..radius).each do |dx|
          nx, ny = cx + dx, cy + dy
          if valid_cell?(nx, ny)
            @u[ny][nx] *= 0.3
            @v[ny][nx] *= 0.3
            @g[ny][nx] = [@g[ny][nx] + 1.2, 2.5].min # Green healing pulse
          end
        end
      end
    end

    # Merge commit: creates a rotational vortex field
    if commit[:is_merge]
      vortex_strength = impact * 0.8
      radius = 5
      (-radius..radius).each do |dy|
        (-radius..radius).each do |dx|
          nx, ny = cx + dx, cy + dy
          next unless valid_cell?(nx, ny)

          dist = Math.sqrt(dx*dx + dy*dy) + 0.1
          @u[ny][nx] += (-dy / dist) * vortex_strength
          @v[ny][nx] += (dx / dist) * vortex_strength
          @density[ny][nx] += impact * 0.5
          @r[ny][nx] = [@r[ny][nx] + 2.0, 3.0].min # Crimson energy pulse
        end
      end
    else
      # Standard commit: linear thrust impulse
      angle = rand * 2 * Math::PI
      @u[cy][cx] += Math.cos(angle) * impact
      @v[cy][cx] += Math.sin(angle) * impact
      @density[cy][cx] += impact
      @b[cy][cx] = [@b[cy][cx] + 2.0, 3.0].min
    end
  end

  # Naviers-Stokes inspired lightweight diffusion & advection solver
  def update_physics
    next_u = Array.new(HEIGHT) { Array.new(WIDTH, 0.0) }
    next_v = Array.new(HEIGHT) { Array.new(WIDTH, 0.0) }
    next_d = Array.new(HEIGHT) { Array.new(WIDTH, 0.0) }

    (1...(HEIGHT - 1)).each do |y|
      (1...(WIDTH - 1)).each do |x|
        # Advection step
        src_x = (x - @u[y][x]).clamp(0, WIDTH - 1)
        src_y = (y - @v[y][x]).clamp(0, HEIGHT - 1)
        
        ix, iy = src_x.to_i, src_y.to_i
        
        next_u[y][x] = @u[iy][ix] * @viscosity
        next_v[y][x] = @v[iy][ix] * @viscosity
        next_d[y][x] = (@density[iy][ix] * 0.98) + 
                       0.05 * (@density[y-1][x] + @density[y+1][x] + @density[y][x-1] + @density[y][x+1]) / 4.0
        
        # Color diffusion
        @r[y][x] *= 0.95
        @g[y][x] *= 0.95
        @b[y][x] *= 0.95
      end
    end

    @u, @v, @density = next_u, next_v, next_d
  end

  def render_frame(commit_msg)
    buffer = "\e[H" # Move cursor to top-left
    buffer << "\e[1mGit Tapestry Fluid Visualizer\e[0m | Active: \e[33m#{commit_msg[0..45]}\e[0m\e[K\n"
    buffer << "─" * WIDTH << "\n"

    HEIGHT.times do |y|
      WIDTH.times do |x|
        d = @density[y][x].clamp(0.0, 1.0)
        char = DENSITY_RAMP[(d * (DENSITY_RAMP.size - 1)).round]
        
        # Calculate ANSI truecolor based on state fields
        cr = (@r[y][x] * 100 + d * 150).clamp(0, 255).to_i
        cg = (@g[y][x] * 120 + d * 180).clamp(0, 255).to_i
        cb = (@b[y][x] * 200 + d * 255).clamp(0, 255).to_i

        buffer << "\e[38;2;#{cr};#{cg};#{cb}m#{char}"
      end
      buffer << "\e[0m\n"
    end

    print buffer
  end

  def valid_cell?(x, y)
    x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT
  end

  def setup_terminal
    print "\e[?25l\e[2J" # Hide cursor & clear screen
  end

  def restore_terminal
    print "\e[?25h\e[0m\n" # Restore cursor & color reset
  end
end

GitFluidTapestry.new.run