# Shell History 3D Fractal Maze Generator
# Translates shell history into a 3D printable STL mesh where
# successful commands carve navigable paths and errors create physical dead ends.

require 'digest'

class ShellMazeSTL
  VOXEL_SIZE = 4.0
  WALL_HEIGHT = 8.0
  BASE_HEIGHT = 2.0

  def initialize(output_file = 'shell_maze.stl')
    @output_file = output_file
    @history = load_shell_history
  end

  def generate
    grid, size = build_fractal_grid
    facets = generate_mesh(grid, size)
    write_stl(facets)
  end

  private

  # Load and classify shell history commands
  def load_shell_history
    history_files = ['~/.zsh_history', '~/.bash_history', '~/.history'].map { |f| File.expand_path(f) }
    file = history_files.find { |f| File.exist?(f) && File.size(f) > 0 }

    lines = if file
      File.readlines(file, encoding: 'binary', invalid: :replace)
          .map { |l| l.encode('UTF-8', invalid: :replace, undef: :replace).sub(/^:\s*\d+:\d+;/, '').strip }
          .reject(&:empty?)
    else
      [
        'git status', 'cd project', 'make', 'error: build failed', 
        'npm test', 'syntax error near token', 'docker run -d redis', 
        'permission denied', 'python script.py', 'exit 1'
      ]
    end

    lines.last(64).map do |cmd|
      # Detect execution errors via keywords or deterministically hash if ambiguous
      is_error = cmd.match?(/\b(err|error|fail|failed|fatal|denied|cannot|invalid|127|130)\b/i) || 
                 (Digest::MD5.hexdigest(cmd).hex % 6 == 0)
      { cmd: cmd, error: is_error }
    end
  end

  # Generate 2D/3D fractal grid structure mapped to history
  def build_fractal_grid
    depth = 3
    size = 2**depth * 2 + 1
    grid = Array.new(size) { Array.new(size, true) } # true = wall, false = path

    # Carve recursive fractal grid
    carve_fractal = ->(x, y, sz, step) do
      return if sz < 3
      mid_x = x + sz / 2
      mid_y = y + sz / 2

      (x..x + sz - 1).each do |cx|
        (y..y + sz - 1).each do |cy|
          cmd_idx = (cx * 7 + cy * 13 + step) % @history.size
          cmd_data = @history[cmd_idx]

          # Successful commands carve paths; errors retain walls (dead ends)
          unless cmd_data[:error]
            grid[cx][cy] = false if cx == mid_x || cy == mid_y
          end
        end
      end

      half = sz / 2
      carve_fractal.call(x, y, half, step + 1)
      carve_fractal.call(x + half, y, half, step + 2)
      carve_fractal.call(x, y + half, half, step + 3)
      carve_fractal.call(x + half, y + half, half, step + 4)
    end

    carve_fractal.call(0, 0, size, 0)

    # Ensure entrance and exit paths exist
    grid[0][1] = false
    grid[size - 1][size - 2] = false

    [grid, size]
  end

  # Construct 3D triangles for the voxel walls and baseplate
  def generate_mesh(grid, size)
    facets = []

    # Solid Baseplate
    base_min = 0.0
    base_max = size * VOXEL_SIZE
    add_box(facets, 0, base_max, 0, base_max, -BASE_HEIGHT, 0)

    # Add Maze Wall Blocks
    size.times do |r|
      size.times do |c|
        if grid[r][c]
          x1 = r * VOXEL_SIZE
          x2 = x1 + VOXEL_SIZE
          y1 = c * VOXEL_SIZE
          y2 = y1 + VOXEL_SIZE
          add_box(facets, x1, x2, y1, y2, 0, WALL_HEIGHT)
        end
      end
    end

    facets
  end

  # Helper to construct a 3D box out of 12 triangular facets
  def add_box(facets, x1, x2, y1, y2, z1, z2)
    corners = [
      [x1, y1, z1], [x2, y1, z1], [x2, y2, z1], [x1, y2, z1], # bottom
      [x1, y1, z2], [x2, y1, z2], [x2, y2, z2], [x1, y2, z2]  # top
    ]

    faces = [
      [0, 1, 2, 3, [0, 0, -1]], # Bottom
      [4, 7, 6, 5, [0, 0,  1]], # Top
      [0, 4, 5, 1, [0, -1, 0]], # Front
      [2, 6, 7, 3, [0,  1, 0]], # Back
      [0, 3, 7, 4, [-1, 0, 0]], # Left
      [1, 5, 6, 2, [1,  0, 0]]  # Right
    ]

    faces.each do |a, b, c, d, norm|
      facets << { normal: norm, verts: [corners[a], corners[b], corners[c]] }
      facets << { normal: norm, verts: [corners[a], corners[c], corners[d]] }
    end
  end

  # Output binary-formatted or ASCII STL mesh
  def write_stl(facets)
    File.open(@output_file, 'w') do |f|
      f.puts "solid shell_history_fractal_maze"
      facets.each do |facet|
        n = facet[:normal]
        f.puts "  facet normal #{n[0]} #{n[1]} #{n[2]}"
        f.puts "    outer loop"
        facet[:verts].each do |v|
          f.puts "      vertex #{v[0]} #{v[1]} #{v[2]}"
        end
        f.puts "    endloop"
        f.puts "  endfacet"
      end
      f.puts "endsolid shell_history_fractal_maze"
    end
    puts "Successfully rendered shell history maze into '#{@output_file}' with #{facets.size} facets."
  end
end

ShellMazeSTL.new.generate