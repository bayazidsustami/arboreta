require 'json'

# Ruby Git-to-MIDI Compiler
# Maps Git history (commits, merges, force pushes) into a multi-track MIDI file.

class GitToMidiCompiler
  attr_reader :repo_path, :output_file

  # MIDI Scale mapping: Base scale (C Major / A Minor context)
  BASE_SCALE = [60, 62, 64, 65, 67, 69, 71, 72] # C4 to C5
  
  def initialize(repo_path = '.', output_file = 'git_history.mid')
    @repo_path = repo_path
    @output_file = output_file
  end

  def run
    commits = extract_git_history
    return puts("No git commits found in #{repo_path}") if commits.empty?

    midi_events = compile_commits_to_midi(commits)
    write_midi_file(midi_events)
    puts "Compiled #{commits.size} commits into MIDI score: #{output_file}"
  end

  private

  # Extract commit logs, parent info, and reflogs to detect force pushes & merges
  def extract_git_history
    Dir.chdir(repo_path) do
      # Fetch commit hash, parents, author timestamp, and commit subject
      raw_log = `git log --pretty=format:"%H|%P|%at|%s" --all --reverse`
      reflog = `git reflog show --format="%h %gs"` # Detect force updates

      force_push_hashes = reflog.scan(/forced-update|force-push/i).map { |m| true }

      raw_log.lines.each_with_index.map do |line, idx|
        parts = line.strip.split('|')
        hash = parts[0]
        parents = parts[1] ? parts[1].split(' ') : []
        timestamp = parts[2].to_i
        subject = parts[3] || ''

        {
          hash: hash,
          is_merge: parents.size > 1,
          is_force_push: force_push_hashes[idx] || subject.downcase.include?('force'),
          hash_val: hash[0..5].to_i(16),
          timestamp: timestamp
        }
      end
    end
  rescue StandardError => e
    puts "Error reading git repository: #{e.message}"
    []
  end

  # Map git events to MIDI events across multiple tracks
  def compile_commits_to_midi(commits)
    tracks = {
      melodic: [],     # Track 0: Main commit pulse
      harmonic: [],    # Track 1: Branch merges (chords)
      microtonal: []   # Track 2: Force pushes (dissonant pitch-bends)
    }

    ticks_per_beat = 480
    current_time = 0

    commits.each do |c|
      delta_ticks = 240 # Half-note steps

      # Track 0: Standard commit -> Melodic note
      note_index = c[:hash_val] % BASE_SCALE.size
      pitch = BASE_SCALE[note_index]
      tracks[:melodic] << { time: current_time, type: :note_on, note: pitch, vel: 90, channel: 0 }
      tracks[:melodic] << { time: current_time + 200, type: :note_off, note: pitch, vel: 0, channel: 0 }

      # Track 1: Branch Merge -> Harmonic Progression (Triad Chord)
      if c[:is_merge]
        chord = [pitch, pitch + 4, pitch + 7] # Major triad harmonic progression
        chord.each do |p|
          tracks[:harmonic] << { time: current_time, type: :note_on, note: p, vel: 110, channel: 1 }
          tracks[:harmonic] << { time: current_time + 400, type: :note_off, note: p, vel: 0, channel: 1 }
        end
      end

      # Track 2: Force Push -> Microtonal Dissonance
      if c[:is_force_push]
        # Pitch bend event creating quarter-tone dissonance (+2048 / -2048)
        bend_val = (c[:hash_val] % 2 == 0) ? 2048 : 14000
        tritonus_note = pitch + 6 # Diminished 5th (Tritone dissonance)

        tracks[:microtonal] << { time: current_time, type: :pitch_bend, value: bend_val, channel: 2 }
        tracks[:microtonal] << { time: current_time, type: :note_on, note: tritonus_note, vel: 120, channel: 2 }
        tracks[:microtonal] << { time: current_time + 350, type: :note_off, note: tritonus_note, vel: 0, channel: 2 }
        tracks[:microtonal] << { time: current_time + 360, type: :pitch_bend, value: 8192, channel: 2 } # Reset bend
      end

      current_time += delta_ticks
    end

    tracks
  end

  # Binary MIDI file format writer (Standard MIDI File Type 1)
  def write_midi_file(tracks)
    division = 480 # ticks per quarter note
    all_track_bytes = []

    tracks.each do |name, events|
      next if events.empty?
      all_track_bytes << build_track_chunk(events)
    end

    header_chunk = [
      'MThd',
      6,                     # Header length
      1,                     # Format 1 (multi-track)
      all_track_bytes.size,  # Number of tracks
      division
    ].pack('A4Nnnn')

    File.binwrite(output_file, header_chunk + all_track_bytes.join)
  end

  def build_track_chunk(events)
    # Sort events chronologically
    sorted_events = events.sort_by { |e| e[:time] }
    
    stream = []
    last_time = 0

    sorted_events.each do |e|
      delta = e[:time] - last_time
      last_time = e[:time]

      stream << encode_var_length(delta)

      case e[:type]
      when :note_on
        stream << [0x90 | e[:channel], e[:note], e[:vel]].pack('C*')
      when :note_off
        stream << [0x80 | e[:channel], e[:note], e[:vel]].pack('C*')
      when :pitch_bend
        lsb = e[:value] & 0x7F
        msb = (e[:value] >> 7) & 0x7F
        stream << [0xE0 | e[:channel], lsb, msb].pack('C*')
      end
    end

    # End of Track meta-event
    stream << encode_var_length(0)
    stream << [0xFF, 0x2F, 0x00].pack('C*')

    track_data = stream.join
    ['MTrk', track_data.bytesize].pack('A4N') + track_data
  end

  # MIDI variable-length quantity encoder
  def encode_var_length(val)
    bytes = []
    bytes << (val & 0x7F)
    while (val >>= 7) > 0
      bytes << ((val & 0x7F) | 0x80)
    end
    bytes.reverse.pack('C*')
  end
end

# Run the compiler
GitToMidiCompiler.new.run