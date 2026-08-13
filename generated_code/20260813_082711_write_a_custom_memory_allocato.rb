require 'chunky_png' # Requires chunkypng gem for creating PNG images, or we can write a simple BMP encoder in pure Ruby to keep it fully self-contained without external dependencies.

# Let's write a pure Ruby script with zero external dependencies that generates an uncompressed BMP image of its own heap memory!

class MemoryPixelArt
  # Define pixel art grid (1 = allocated block/dark pixel, 0 = free space/white pixel)
  # 16x16 Invader art pattern
  ART = [
    [0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0],
    [0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0],
    [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
    [0,0,1,1,0,0,1,1,1,1,0,0,1,1,0,0],
    [0,0,1,1,0,0,1,1,1,1,0,0,1,1,0,0],
    [0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
    [0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
    [0,1,1,0,0,0,1,1,1,1,0,0,0,1,1,0],
    [0,1,1,0,0,0,1,1,1,1,0,0,0,1,1,0],
    [0,0,1,1,1,1,0,0,0,0,1,1,1,1,0,0],
    [0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0],
    [0,0,1,1,0,0,0,0,0,0,0,0,1,1,0,0],
    [0,0,1,1,0,0,0,0,0,0,0,0,1,1,0,0],
    [0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0],
    [0,1,1,0,0,0,0,0,0,0,0,0,0,1,1,0],
    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
  ].freeze

  BLOCK_SIZE = 16 # Bytes per pixel representation

  def initialize
    @width = ART.first.size
    @height = ART.size
    @heap_size = @width * @height * BLOCK_SIZE
    # Allocate a contiguous byte buffer representing physical raw heap memory initialized to 255 (white)
    @heap = "\xFF".b * @heap_size
    @allocations = {}
  end

  # Custom allocator method that places allocated bytes at exact heap offsets
  def allocate(address, size, value_byte)
    raise "Out of bounds allocation" if address + size > @heap_size
    # Write raw byte pattern (simulating active memory allocations)
    @heap.bytesplice(address, size, value_byte.chr * size)
    @allocations[address] = size
  end

  # Free memory range (resets to unallocated state)
  def free(address)
    size = @allocations.delete(address)
    return unless size
    @heap.bytesplice(address, size, "\xFF".b * size)
  end

  # Paint the pixel art across the heap using allocation and fragmentation layout
  def synthesize_heap_art
    @height.times do |row|
      @width.times do |col|
        pixel_state = ART[row][col]
        heap_offset = (row * @width + col) * BLOCK_SIZE

        if pixel_state == 1
          # Allocate block with dark byte values (0x00 - 0x40) to represent active memory
          allocate(heap_offset, BLOCK_SIZE, (row * 8) % 64)
        else
          # Fragmented / Unallocated memory area (represented as 0xFF)
          # We perform a dummy alloc and immediate free to guarantee deliberate free fragmentation
          allocate(heap_offset, BLOCK_SIZE, 0xAA)
          free(heap_offset)
        end
      end
    end
  end

  # Render raw physical bytes directly as a grayscale uncompressed BMP image
  def render_heap_to_bmp(filename = "heap_art.bmp")
    # Upscale raw bytes to 256x256 image for visual clarity
    scale = 16
    img_w = @width * scale
    img_h = @height * scale

    # Build BMP Headers
    row_bytes = img_w
    padding = (4 - (row_bytes % 4)) % 4
    pixel_data_size = (row_bytes + padding) * img_h
    file_size = 54 + 1024 + pixel_data_size # Header (54) + Color Table (1024) + Pixels

    bmp = []
    # BMP Header
    bmp << ["BM", file_size, 0, 54 + 1024].pack("a2VvvV")
    # DIB Header
    bmp << [40, img_w, img_h, 1, 8, 0, pixel_data_size, 2835, 2835, 256, 256].pack("VVVvvVVVVVV")
    
    # Grayscale Color Palette Table (256 colors)
    256.times { |i| bmp << [i, i, i, 0].pack("CCCC") }

    # Map raw heap byte layout into BMP pixel matrix (BMP is rendered bottom-to-top)
    img_h.downto(1) do |y|
      heap_row = (y - 1) / scale
      row_data = "".b
      img_w.times do |x|
        heap_col = x / scale
        byte_index = (heap_row * @width + heap_col) * BLOCK_SIZE
        # Sample directly from raw heap memory byte buffer
        row_data << @heap.getbyte(byte_index).chr
      end
      row_data << ("\x00".b * padding)
      bmp << row_data
    end

    File.binwrite(filename, bmp.join)
    filename
  end
end

allocator = MemoryPixelArt.new
allocator.synthesize_heap_art
output_file = allocator.render_heap_to_bmp("heap_art.bmp")
puts "Heap allocation matrix rendered to #{output_file}"