require 'openssl'

# Topological Spectrum: Translates simulated audio frequencies into an evolving
# ASCII map of an imaginary island whose coastline erodes under heavy bass.

class SpectralMap
  WIDTH = 60
  HEIGHT = 28
  
  # ASCII elevation levels from deep ocean to high mountain peaks
  TERRAIN = [' ', '~', '.', ':', '-', '=', '+', '*', '%', '@', '#']
  
  def initialize
    @seed = Array.new(WIDTH * HEIGHT) { rand * 2.0 - 1.0 }
    @erosion_buffer = Array.new(WIDTH * HEIGHT, 0.0)
    @time = 0.0
  end

  # Simulates spectral frequency bands (Bass, Mids, Treble) and overall loudness
  def analyze_audio_frame(t)
    bass   = (Math.sin(t * 1.5) * 0.5 + 0.5) ** 2 * 1.8 + (rand < 0.1 ? 1.2 : 0.0)
    mids   = (Math.cos(t * 0.8) * 0.5 + 0.5) * 1.2
    treble = (Math.sin(t * 3.1) * 0.5 + 0.5) * 0.9
    loudness = (bass * 0.6 + mids * 0.3 + treble * 0.1)
    { bass: bass, mids: mids, treble: treble, loudness: loudness }
  end

  # Simplified Perlin-like 2D noise generator using SHA256 hashing
  def noise(x, y, z)
    xi, yi, zi = x.floor, y.floor, z.floor
    xf, yf, zf = x - xi, y - yi, z - zi
    
    # Smoothstep interpolation curve
    fade = ->(t) { t * t * t * (t * (t * 6 - 15) + 10) }
    u, v, w = fade.call(xf), fade.call(yf), fade.call(zf)
    
    hash = ->(ix, iy, iz) do
      digest = OpenSSL::Digest::SHA256.digest("#{ix},#{iy},#{iz}")
      (digest[0].ord / 255.0) * 2.0 - 1.0
    end

    # Trilinear interpolation across cube corners
    c000 = hash.call(xi, yi, zi)
    c100 = hash.call(xi + 1, yi, zi)
    c010 = hash.call(xi, yi + 1, zi)
    c110 = hash.call(xi + 1, yi + 1, zi)
    c001 = hash.call(xi, yi, zi + 1)
    c101 = hash.call(xi + 1, yi, zi + 1)
    c011 = hash.call(xi, yi + 1, zi + 1)
    c111 = hash.call(xi + 1, yi + 1, zi + 1)

    x0 = c000 + u * (c100 - c000)
    x1 = c010 + u * (c110 - c010)
    x2 = c001 + u * (c101 - c001)
    x3 = c011 + u * (c111 - c011)

    y0 = x0 + v * (x1 - x0)
    y1 = x2 + v * (x3 - x2)

    y0 + w * (y1 - y0)
  end

  # Multi-octave Fractal Brownian Motion for rich fractal terrain detail
  def fbm(x, y, z, octaves = 4)
    val, freq, amp, max_val = 0.0, 1.0, 1.0, 0.0
    octaves.times do
      val += noise(x * freq, y * freq, z * freq) * amp
      max_val += amp
      amp *= 0.5
      freq *= 2.0
    end
    val / max_val
  end

  def update
    @time += 0.08
    audio = analyze_audio_frame(@time)
    
    center_x, center_y = WIDTH / 2.0, HEIGHT / 2.0
    max_radius = [WIDTH, HEIGHT].min * 0.45

    output = ["\e[H\e[J"] # Clear terminal screen
    output << "=== SPECTRAL TOPOGRAPHY MAP ==="
    output << sprintf("FREQ BANDS | Bass: [%-10s] Mids: [%-10s] Treble: [%-10s]",
                     "#" * (audio[:bass] * 4).clamp(0, 10),
                     "#" * (audio[:mids] * 6).clamp(0, 10),
                     "#" * (audio[:treble] * 8).clamp(0, 10))
    output << "-" * WIDTH

    HEIGHT.times do |y|
      row = ""
      WIDTH.times do |x|
        idx = y * WIDTH + x
        
        # Distance calculation to enforce an island boundary
        dx = (x - center_x) / (WIDTH / 2.0)
        dy = (y - center_y) / (HEIGHT / 2.0)
        dist = Math.sqrt(dx * dx + dy * dy)

        # Base elevation driven by mid/treble frequencies shifting through 3D noise
        nx = x * 0.08 + Math.cos(@time * 0.2) * audio[:mids]
        ny = y * 0.12 + Math.sin(@time * 0.2) * audio[:treble]
        nz = @time * 0.1
        
        raw_elevation = fbm(nx, ny, nz)
        island_mask = (1.0 - (dist / 0.85)).clamp(0.0, 1.0)
        elevation = (raw_elevation + 0.2) * island_mask

        # Coastline erosion logic driven by heavy bass impact
        is_coastline = elevation > 0.15 && elevation < 0.35
        if is_coastline && audio[:bass] > 1.1
          @erosion_buffer[idx] += audio[:bass] * 0.05
        else
          # Slow natural land recovery over time
          @erosion_buffer[idx] = [@erosion_buffer[idx] - 0.005, 0.0].max
        end

        # Apply cumulative erosion factor
        final_elevation = elevation - @erosion_buffer[idx]
        
        # Map elevation to corresponding ASCII glyph
        char_idx = ((final_elevation.clamp(0.0, 1.0)) * (TERRAIN.size - 1)).floor
        row << TERRAIN[char_idx]
      end
      output << row
    end
    
    output << "-" * WIDTH
    output << "Erosion Level: #{"*" * (@erosion_buffer.sum * 0.2).clamp(0, 30)} (Bass Pulse)"
    puts output.join("\n")
  end

  def run
    trap("INT") { puts "\nExiting Spectral Map Visualizer."; exit }
    loop do
      update
      sleep 0.05
    end
  end
end

SpectralMap.new.run