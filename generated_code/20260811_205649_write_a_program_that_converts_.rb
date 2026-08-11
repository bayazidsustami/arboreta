# Binary to Harmonious MIDI Converter & Reconstructor
# Encodes arbitrary binary executables into harmoniously tuned pentatonic MIDI scores.
# Reversing the MIDI score (retrograde) and decoding reconstructs the exact original binary.

module BinaryToMidi
  # C Major Pentatonic scale notes across multiple octaves (16 pitches)
  # Pentatonic scales ensure harmonious, consonant musicality regardless of note sequence.
  PENTATONIC = [48, 50, 52, 55, 57, 60, 62, 64, 67, 69, 72, 74, 76, 79, 81, 84].freeze

  # Variable Length Quantity encoder for Standard MIDI delta times
  def self.encode_vlq(val)
    bytes = [val & 0x7F]
    while (val >>= 7) > 0
      bytes.unshift((val & 0x7F) | 0x80)
    end
    bytes.pack('C*')
  end

  # Converts executable binary data into a musically harmonious MIDI score (Format 0)
  def self.encode(binary_data)
    notes = binary_data.bytes.map do |b|
      high_nibble = (b >> 4) & 0x0F
      low_nibble  = b & 0x0F
      pitch    = PENTATONIC[high_nibble]
      velocity = 60 + low_nibble * 4 # Dynamic velocity range [60..120]
      [pitch, velocity]
    end
    build_midi(notes)
  end

  # Constructs Standard MIDI file bytes from an array of [pitch, velocity] pairs
  def self.build_midi(notes)
    events = []
    events << "\x00\xFF\x51\x03\x07\xA1\x20" # Set Tempo: 120 BPM
    events << "\x00\xC0\x2E"                 # Program Change: Orchestral Harp (Ch 1)

    notes.each do |pitch, vel|
      events << encode_vlq(24) + [0x90, pitch, vel].pack('C*') # Note On (16th note delta)
      events << encode_vlq(48) + [0x80, pitch, 0].pack('C*')   # Note Off (8th note length)
    end

    events << "\x00\xFF\x2F\x00" # End of Track
    track_data = events.join

    header = ["MThd", 6, 0, 1, 480].pack('a4Nnnn')
    track  = ["MTrk", track_data.bytesize].pack('a4N') + track_data
    header + track
  end

  # Extracts [pitch, velocity] note pairs from MIDI binary data
  def self.extract_notes(midi_bytes)
    notes = []
    i = 0
    len = midi_bytes.bytesize
    while i < len - 2
      if midi_bytes.getbyte(i) == 0x90
        pitch = midi_bytes.getbyte(i + 1)
        vel   = midi_bytes.getbyte(i + 2)
        if PENTATONIC.include?(pitch) && vel >= 60 && vel <= 120
          notes << [pitch, vel]
          i += 3
          next
        end
      end
      i += 1
    end
    notes
  end

  # Reverses the musical score in time (retrograde transformation)
  def self.reverse_midi(midi_bytes)
    notes = extract_notes(midi_bytes)
    build_midi(notes.reverse)
  end

  # Decodes a reversed MIDI score back into the exact original executable binary
  def self.decode(reversed_midi_bytes)
    notes = extract_notes(reversed_midi_bytes)
    original_bytes = notes.reverse.map do |pitch, vel|
      high_nibble = PENTATONIC.index(pitch)
      low_nibble  = (vel - 60) / 4
      (high_nibble << 4) | low_nibble
    end
    original_bytes.pack('C*')
  end
end

# Executable self-test & CLI handler
if __FILE__ == $0
  if ARGV.empty?
    # Self-contained validation run on sample binary executable header
    sample_binary = [0x7F, 0x45, 0x4C, 0x46, 0x02, 0x01, 0x01, 0x00].pack('C*') + "Harmonic Binary MIDI"
    puts "--- Harmonious Binary MIDI Converter ---"
    puts "Original Binary (hex):  #{sample_binary.unpack1('H*')}"

    midi = BinaryToMidi.encode(sample_binary)
    puts "Generated MIDI Size:    #{midi.bytesize} bytes"

    reversed_midi = BinaryToMidi.reverse_midi(midi)
    puts "Reversed MIDI Size:     #{reversed_midi.bytesize} bytes"

    reconstructed = BinaryToMidi.decode(reversed_midi)
    puts "Reconstructed (hex):   #{reconstructed.unpack1('H*')}"

    if reconstructed == sample_binary
      puts "SUCCESS: Reconstructed binary perfectly matches original source!"
    else
      puts "ERROR: Mismatch detected during reconstruction."
    end
  else
    mode, input_file, output_file = ARGV
    case mode
    when 'encode'
      data = File.binread(input_file)
      File.binwrite(output_file, BinaryToMidi.encode(data))
      puts "Successfully encoded binary '#{input_file}' into MIDI '#{output_file}'"
    when 'reverse'
      data = File.binread(input_file)
      File.binwrite(output_file, BinaryToMidi.reverse_midi(data))
      puts "Successfully reversed MIDI score '#{input_file}' to '#{output_file}'"
    when 'decode'
      data = File.binread(input_file)
      File.binwrite(output_file, BinaryToMidi.decode(data))
      puts "Successfully reconstructed binary '#{output_file}' from reversed MIDI '#{input_file}'"
    else
      puts "Usage: ruby #{$0} [encode|reverse|decode] <input_file> <output_file>"
    end
  end
end