# Git History MIDI Synthesizer
# Parses the current Git repository's commit history and converts it into 
# a polyphonic MIDI composition where authors dictate instruments and merges
# generate harmonic dissonance.

class GitMidiComposer
  # Author-to-Instrument map (General MIDI Program numbers 0-127)
  INSTRUMENTS = [0, 11, 19, 24, 40, 52, 73, 80, 89, 105]

  # Scales: Consonant (Pentatonic/Major) vs Dissonant (Tritones/Diminished)
  CONSONANT_INTERVALS = [0, 4, 7, 11, 12, 14, 16]
  DISSONANT_INTERVALS = [0, 1, 6, 8, 13, 15, 18]

  def initialize(output_file = "git_composition.mid")
    @output_file = output_file
    @authors = {}
    @tracks = {}
  end

  def run
    commits = parse_git_log
    return puts "No git commits found." if commits.empty?

    process_commits(commits)
    write_midi_file
    puts "Composition saved to #{@output_file} (#{commits.size} commits processed)"
  end

  private

  # Extract commit metadata: hash, parent hashes, author, timestamp, message
  def parse_git_log
    log_data = `git log --pretty=format:"%H|%P|%an|%at|%s"`
    return [] if log_data.empty?

    log_data.lines.map do |line|
      parts = line.strip.split('|')
      hash, parents, author, timestamp, subject = parts[0], parts[1].to_s.split(' '), parts[2], parts[3].to_i, parts[4].to_s
      {
        hash: hash,
        is_merge: parents.size > 1,
        author: author,
        timestamp: timestamp,
        subject: subject,
        diff_conflict: subject.downcase.include?("conflict") || subject.downcase.include?("merge")
      }
    end.reverse # Chronological order
  end

  def process_commits(commits)
    base_time = commits.first[:timestamp]
    last_tick = 0

    commits.each do |c|
      author_id = get_author_channel(c[:author])
      channel = author_id % 16
      
      # Calculate musical timing (tick delta relative to commit intervals)
      time_delta = [(c[:timestamp] - base_time) / 10, 0].max
      ticks = time_delta % 480
      base_time = c[:timestamp]

      # Determine harmonic pitch and interval structure
      root_note = 48 + (c[:hash][0..3].hex % 24) # Key range C3-C5
      is_dissonant = c[:is_merge] || c[:diff_conflict]
      intervals = is_dissonant ? DISSONANT_INTERVALS : CONSONANT_INTERVALS
      
      # Select notes based on commit hash segments
      velocity = is_dissonant ? 110 : 80
      duration = is_dissonant ? 960 : 480
      
      chord = [0, 2, 4].map do |i|
        idx = (c[:hash][i..i+1].hex) % intervals.size
        root_note + intervals[idx]
      end

      # Add MIDI events to track
      @tracks[channel] ||= []
      
      # Set instrument at start if channel is new
      if @tracks[channel].empty?
        inst = INSTRUMENTS[author_id % INSTRUMENTS.size]
        @tracks[channel] << { delta: 0, bytes: [0xC0 | channel, inst] }
      end

      # Note On
      chord.each_with_index do |note, idx|
        delta = (idx == 0) ? ticks : 0
        @tracks[channel] << { delta: delta, bytes: [0x90 | channel, note, velocity] }
      end

      # Note Off
      chord.each_with_index do |note, idx|
        delta = (idx == 0) ? duration : 0
        @tracks[channel] << { delta: delta, bytes: [0x80 | channel, note, 0] }
      end
    end
  end

  def get_author_channel(author)
    @authors[author] ||= @authors.size
  end

  # Helpers for standard MIDI binary generation
  def encode_vlv(val)
    bytes = []
    bytes << (val & 0x7F)
    val >>= 7
    while val > 0
      bytes << ((val & 0x7F) | 0x80)
      val >>= 7
    end
    bytes.reverse.pack('C*')
  end

  def write_midi_file
    file_bytes = []
    
    # MIDI Header Chunk (Format 1, Tracks count, 480 Ticks Per Quarter Note)
    track_count = @tracks.keys.size
    file_bytes << "MThd"
    file_bytes << [6, 1, track_count, 480].pack("Nnnn")

    # Generate each track chunk
    @tracks.each do |channel, events|
      track_data = String.new
      events.each do |event|
        track_data << encode_vlv(event[:delta])
        track_data << event[:bytes].pack('C*')
      end
      # End of Track event
      track_data << encode_vlv(0) << "\xFF\x2F\x00".b

      file_bytes << "MTrk"
      file_bytes << [track_data.bytesize].pack("N")
      file_bytes << track_data
    end

    File.open(@output_file, "wb") { |f| f.write(file_bytes.join) }
  end
end

GitMidiComposer.new.run