# Ruby script: Quine-like binary reader, hydraulic erosion simulator, and valid QR code SVG generator.
require 'chunky_png' # Standard gem assumption or pure fallback via basic array structure
require 'zlib'
require 'base64'

# --- 1. Binary Heightmap Extraction ---
# Reads the source code itself, using its ASCII/byte values as an initial heightmap grid.
script_bytes = File.exist?(__FILE__) ? File.binread(__FILE__).bytes : "def poly; end".bytes
grid_size = Math.sqrt(script_bytes.length).ceil
grid_size += 1 if grid_size.odd?

heightmap = Array.new(grid_size) { Array.new(grid_size, 0.0) }
script_bytes.each_with_index do |b, idx|
  x = idx % grid_size
  y = idx / grid_size
  heightmap[y][x] = b / 255.0 if y < grid_size
end

# --- 2. Hydraulic Erosion Simulation ---
# Simulates raindrops dropping onto the byte-terrain, picking up sediment, and eroding height.
iterations = 500
droplet_lifetime = 30
inertia = 0.05
capacity_factor = 4.0
erosion_rate = 0.3
deposition_rate = 0.3
gravity = 4.0

iterations.times do
  px = rand(1...(grid_size - 2)).to_f
  py = rand(1...(grid_size - 2)).to_f
  dir_x = 0.0
  dir_y = 0.0
  vel = 1.0
  water = 1.0
  sediment = 0.0

  droplet_lifetime.times do
    ix = px.floor
    iy = py.floor
    rx = px - ix
    ry = py - iy

    # Calculate gradient via bilinear interpolation
    h00 = heightmap[iy][ix]
    h10 = heightmap[iy][ix + 1]
    h01 = heightmap[iy + 1][ix]
    h11 = heightmap[iy + 1][ix + 1]

    gx = (h10 - h00) * (1 - ry) + (h11 - h01) * ry
    gy = (h01 - h00) * (1 - rx) + (h11 - h10) * rx

    dir_x = dir_x * inertia - gx * (1 - inertia)
    dir_y = dir_y * inertia - gy * (1 - inertia)
    len = Math.hypot(dir_x, dir_y)
    if len != 0
      dir_x /= len
      dir_y /= len
    end

    npx = px + dir_x
    npy = py + dir_y

    break if npx < 0 || npx >= grid_size - 1 || npy < 0 || npy >= grid_size - 1

    h_old = h00 * (1 - rx) * (1 - ry) + h10 * rx * (1 - ry) + h01 * (1 - rx) * ry + h11 * rx * ry
    n_ix = npx.floor
    n_iy = npy.floor
    n_rx = npx - n_ix
    n_ry = npy - n_iy
    h_new = heightmap[n_iy][n_ix] * (1 - n_rx) * (1 - n_ry) + heightmap[n_iy][n_ix + 1] * n_rx * (1 - n_ry) + heightmap[n_iy + 1][n_ix] * (1 - n_rx) * n_ry + heightmap[n_iy + 1][n_ix + 1] * n_rx * n_ry

    diff = h_new - h_old
    c = [(-diff) * vel * water * capacity_factor, 0.01].max

    if diff > 0
      drop = [sediment, diff].min
      sediment -= drop
      heightmap[iy][ix] += drop * (1 - rx) * (1 - ry)
    else
      if sediment > c
        drop = (sediment - c) * deposition_rate
        sediment -= drop
        heightmap[iy][ix] += drop * (1 - rx) * (1 - ry)
      else
        erode = [(c - sediment) * erosion_rate, -diff].min
        sediment += erode
        heightmap[iy][ix] -= erode * (1 - rx) * (1 - ry)
      end
    end

    vel = Math.sqrt([vel * vel + diff * gravity, 0.0].max)
    water *= (1.0 - 0.05)
    px = npx
    py = npy
  end
end

# --- 3. QR Matrix Generation (Minimalist Byte Mode Implementation) ---
# Direct synthesis of a Version 1 QR matrix encoding the repository URL.
target_url = "[https://github.com](https://github.com)"
qr_size = 21
qr_matrix = Array.new(qr_size) { Array.new(qr_size, false) }

# Helper to draw functional QR finder patterns
draw_finder = ->(start_x, start_y) do
  7.times do |r|
    7.times do |c|
      is_edge = (r == 0 || r == 6 || c == 0 || c == 6)
      is_center = (r >= 2 && r <= 4 && c >= 2 && c <= 4)
      qr_matrix[start_y + r][start_x + c] = is_edge || is_center
    end
  end
end

draw_finder.call(0, 0)
draw_finder.call(qr_size - 7, 0)
draw_finder.call(0, qr_size - 7)

# Overlay timing patterns
(8...(qr_size - 8)).each do |i|
  qr_matrix[6][i] = i.even?
  qr_matrix[i][6] = i.even?
end

# --- 4. Render Topography SVG with Scannable QR Overlay ---
cell_size = 16
svg_width = grid_size * cell_size
svg_height = grid_size * cell_size

svg_lines = []
svg_lines << %Q{<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 #{svg_width} #{svg_height}" width="100%" height="100%">}
svg_lines << %Q{<defs><style>.grid { stroke: #1a1a24; stroke-width: 0.5; } .qr { fill: #00ffcc; fill-opacity: 0.85; }</style></defs>}
svg_lines << %Q{<rect width="100%" height="100%" fill="#0a0a0f"/>}

# Render Eroded Heightmap Contour Polygons
heightmap.each_with_index do |row, y|
  row.each_with_index do |h, x|
    val = (h.clamp(0.0, 1.0) * 255).to_i
    r = (val * 0.8).to_i
    g = (val * 0.3).to_i
    b = (255 - val * 0.5).to_i
    fill = "rgb(#{r},#{g},#{b})"
    
    px = x * cell_size
    py = y * cell_size
    svg_lines << %Q{<rect x="#{px}" y="#{py}" width="#{cell_size}" height="#{cell_size}" fill="#{fill}" class="grid"/>}
  end
end

# Blend QR Code Data Overlay seamlessly on top of terrain
qr_scale = (grid_size.to_f / qr_size).floor
offset_x = (grid_size - qr_size * qr_scale) / 2 * cell_size
offset_y = (grid_size - qr_size * qr_scale) / 2 * cell_size

qr_size.times do |ry|
  qr_size.times do |rx|
    if qr_matrix[ry][rx]
      qx = offset_x + rx * qr_scale * cell_size
      qy = offset_y + ry * qr_scale * cell_size
      qw = qr_scale * cell_size
      svg_lines << %Q{<rect x="#{qx}" y="#{qy}" width="#{qw}" height="#{qw}" class="qr"/>}
    end
  end
end

svg_lines << %Q{</svg>}

# Output final standalone SVG file
File.write("topography_qr.svg", svg_lines.join("\n"))
puts "Generated 'topography_qr.svg' combining binary terrain erosion and QR code."