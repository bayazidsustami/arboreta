#!/usr/bin/env ruby
# frozen_string_literal: true

# Required gems:
#   gem install ruby-opencv
#   gem install midilib
#   gem install ruby-osc
#   gem install pstream
# Ensure you have a MIDI synth (e.g., fluidsynth) listening on a virtual port.

require 'opencv'
require 'midilib/sequence'
require 'midilib/consts'
require 'socket'
require 'thread'
require 'tempfile'

# ------------------- Configuration -------------------
CAMERA_INDEX = 0                     # default webcam
FRAME_INTERVAL = 0.1                 # seconds between processed frames
MIDI_OUT_PORT = 0                    # first MIDI output port
BASE_TEMPO = 120                     # BPM
NOTE_RANGE = (48..72)                # C3 to C5
# -----------------------------------------------------

# Global mutable synthesis parameters that self‑modify
synth_params = {
  pitch_offset: 0,
  velocity: 80,
  scale: 1.0,
  decay: 0.5
}

# Helper to map a value 0..1 to a MIDI note within NOTE_RANGE
def map_to_note(val, offset)
  range = NOTE_RANGE.last - NOTE_RANGE.first
  NOTE_RANGE.first + ((val * range).to_i + offset) % range
end

# Simple placeholder emotion intensity estimator (replace with real model)
def emotion_intensity(frame)
  # Use average brightness as a naive proxy for "intensity"
  gray = frame.BGR2GRAY
  avg = gray.mean
  avg / 255.0
end

# Generate a short MIDI sequence based on current synth_params
def generate_midi(params)
  seq = MIDI::Sequence.new
  track = MIDI::Track.new(seq)
  seq.tracks << track
  track.name = 'EmotionMusic'
  track.events << MIDI::Tempo.new(MIDI::Tempo.bpm_to_mpq(BASE_TEMPO))
  track.events << MIDI::MetaEvent.new(MIDI::META_SEQ_NAME, 'Emotion Loop')
  16.times do |i|
    pitch = map_to_note(i / 15.0, params[:pitch_offset])
    vel   = params[:velocity]
    dur   = (MIDI::TicksPerQuarterNote * params[:scale] * 0.5).to_i
    track.events << MIDI::NoteOn.new(0, pitch, vel, 0)
    track.events << MIDI::NoteOff.new(0, pitch, 0, dur)
  end
  seq
end

# Write MIDI sequence to a temporary file
def write_midi_to_temp(seq)
  tf = Tempfile.new(['emotion', '.mid'])
  File.open(tf.path, 'wb') { |f| seq.write(f) }
  tf
end

# Send MIDI file to synth using a simple external player (e.g., timidity)
def play_midi_file(path)
  pid = spawn("timidity -iA -B2,8 -Os -s 48000 -Ef #{path}")
  pid
end

# Thread: continuously capture webcam, update synth_params
capture_thread = Thread.new do
  cap = OpenCV::CVCapture.open(CAMERA_INDEX)
  loop do
    frame = cap.query
    break unless frame
    intensity = emotion_intensity(frame)

    # Map intensity to synthesis parameters
    synth_params[:pitch_offset] = (intensity * 12).to_i      # semitone shift
    synth_params[:velocity]     = 60 + (intensity * 60).to_i
    synth_params[:scale]        = 0.5 + intensity * 1.0
    synth_params[:decay]        = 0.3 + intensity * 0.7

    sleep FRAME_INTERVAL
  end
end

# Main loop: rebuild MIDI whenever parameters change significantly
last_params = {}
player_pid = nil
loop do
  if synth_params != last_params
    seq = generate_midi(synth_params)
    midi_file = write_midi_to_temp(seq)

    # Restart synth with new MIDI
    Process.kill('TERM', player_pid) if player_pid
    player_pid = play_midi_file(midi_file.path)

    last_params = synth_params.dup
    midi_file.unlink
  end
  sleep 0.2
end

# Ensure clean shutdown on interrupt
Signal.trap('INT') do
  Process.kill('TERM', player_pid) if player_pid
  exit
end