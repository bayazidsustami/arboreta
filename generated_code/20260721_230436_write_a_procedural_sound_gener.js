const fs = require('fs');
const { execSync } = require('child_process');

/**
 * Procedural Git-to-MIDI Symphony Generator
 * Translates Git history into a multi-track MIDI file without external npm dependencies.
 */

// Musical Scales & Key Transpositions
const SCALES = {
  ionian:     [0, 2, 4, 5, 7, 9, 11],
  dorian:     [0, 2, 3, 5, 7, 9, 10],
  phrygian:   [0, 1, 3, 5, 7, 8, 10],
  lydian:     [0, 2, 4, 6, 7, 9, 11],
  mixolydian: [0, 2, 4, 5, 7, 9, 10],
  aeolian:    [0, 2, 3, 5, 7, 8, 10],
  locrian:    [0, 1, 3, 5, 6, 8, 10]
};
const ROOT_NOTES = [60, 62, 64, 65, 67, 69, 71, 72]; // Base MIDI octaves around C4

// Parse local Git commit log
function getGitCommitHistory() {
  try {
    const logOutput = execSync(
      'git log --numstat --pretty=format:"COMMIT|%h|%s" -n 50',
      { encoding: 'utf-8' }
    );
    const commits = [];
    let currentCommit = null;

    for (const line of logOutput.split('\n')) {
      if (line.startsWith('COMMIT|')) {
        const [, hash, subject] = line.split('|');
        currentCommit = {
          hash,
          subject,
          additions: 0,
          deletions: 0,
          isMerge: subject.toLowerCase().includes('merge')
        };
        commits.push(currentCommit);
      } else if (currentCommit && line.trim()) {
        const parts = line.trim().split(/\s+/);
        if (parts.length >= 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
          currentCommit.additions += parseInt(parts[0], 10);
          currentCommit.deletions += parseInt(parts[1], 10);
        }
      }
    }
    return commits.reverse();
  } catch (err) {
    // Fallback mock history if run outside a valid git repo
    return Array.from({ length: 20 }, (_, i) => ({
      hash: Math.random().toString(16).substring(2, 8),
      subject: i % 5 === 0 ? `Merge branch 'feature-${i}'` : `Commit ${i}`,
      additions: Math.floor(Math.random() * 200),
      deletions: Math.floor(Math.random() * 150),
      isMerge: i % 5 === 0
    }));
  }
}

// Low-level binary MIDI File Encoder
class MidiEncoder {
  constructor(ticksPerQuarter = 128) {
    this.tpq = ticksPerQuarter;
    this.tracks = [];
  }

  addTrack() {
    const track = new MidiTrack(this.tpq);
    this.tracks.push(track);
    return track;
  }

  exportBuffer() {
    const header = [
      0x4d, 0x54, 0x68, 0x64, // 'MThd'
      0x00, 0x00, 0x00, 0x06, // length 6
      0x00, 0x01,             // format 1 (multi-track)
      (this.tracks.length >> 8) & 0xff, this.tracks.length & 0xff,
      (this.tpq >> 8) & 0xff, this.tpq & 0xff
    ];

    const trackBuffers = this.tracks.map(t => t.toBuffer());
    return Buffer.concat([Buffer.from(header), ...trackBuffers]);
  }
}

class MidiTrack {
  constructor(tpq) {
    this.tpq = tpq;
    this.events = [];
  }

  // Variable Length Quantity helper for MIDI timing
  writeVLQ(num) {
    const bytes = [];
    let buffer = num & 0x7f;
    while (num >>= 7) {
      buffer <<= 8;
      buffer |= (num & 0x7f) | 0x80;
    }
    while (true) {
      bytes.push(buffer & 0xff);
      if (buffer & 0x80) buffer >>= 8;
      else break;
    }
    return bytes;
  }

  setTempo(ticks, bpm) {
    const microsecondsPerQuarter = Math.round(60000000 / bpm);
    this.events.push({
      ticks,
      bytes: [
        0xff, 0x51, 0x03,
        (microsecondsPerQuarter >> 16) & 0xff,
        (microsecondsPerQuarter >> 8) & 0xff,
        microsecondsPerQuarter & 0xff
      ]
    });
  }

  setInstrument(ticks, channel, program) {
    this.events.push({
      ticks,
      bytes: [0xc0 | (channel & 0x0f), program & 0x7f]
    });
  }

  noteOn(ticks, channel, note, velocity = 90) {
    this.events.push({
      ticks,
      bytes: [0x90 | (channel & 0x0f), note & 0x7f, velocity & 0x7f]
    });
  }

  noteOff(ticks, channel, note) {
    this.events.push({
      ticks,
      bytes: [0x80 | (channel & 0x0f), note & 0x7f, 0]
    });
  }

  toBuffer() {
    // Sort events chronologically
    this.events.sort((a, b) => a.ticks - b.ticks);

    const body = [];
    let lastTicks = 0;

    for (const ev of this.events) {
      const delta = ev.ticks - lastTicks;
      lastTicks = ev.ticks;
      body.push(...this.writeVLQ(delta), ...ev.bytes);
    }
    // End of Track meta-event
    body.push(0x00, 0xff, 0x2f, 0x00);

    const len = body.length;
    const header = [
      0x4d, 0x54, 0x72, 0x6b, // 'MTrk'
      (len >> 24) & 0xff, (len >> 16) & 0xff, (len >> 8) & 0xff, len & 0xff
    ];

    return Buffer.from([...header, ...body]);
  }
}

// Core Composition Engine
function buildSymphony(commits) {
  const midi = new MidiEncoder(128);
  const tempoTrack = midi.addTrack();
  const leadTrack = midi.addTrack();    // Acoustic/Electric Lead (Channel 0)
  const padTrack = midi.addTrack();     // Harmonic Pad (Channel 1)
  const bassTrack = midi.addTrack();    // Sub Bass (Channel 2)

  leadTrack.setInstrument(0, 0, 0);     // Acoustic Grand
  padTrack.setInstrument(0, 1, 89);    // Warm Pad
  bassTrack.setInstrument(0, 2, 32);    // Acoustic Bass

  let currentTicks = 0;
  let keyIndex = 0;                     // Initial scale transposition
  const scaleKeys = Object.keys(SCALES);

  commits.forEach((commit) => {
    // 1. Merge Commits Trigger Structural Key Changes
    if (commit.isMerge) {
      keyIndex = (keyIndex + 1) % scaleKeys.length;
    }
    const currentScale = SCALES[scaleKeys[keyIndex]];
    const baseRoot = ROOT_NOTES[keyIndex % ROOT_NOTES.length];

    // 2. Deletions Control Tempo (More deletions = faster tempo)
    const bpm = Math.min(220, Math.max(60, 80 + Math.floor(commit.deletions * 1.5)));
    tempoTrack.setTempo(currentTicks, bpm);

    // 3. Line Insertions Determine Harmonic Dissonance
    // High additions shift notes outside scale intervals, creating dissonance
    const dissonanceLevel = Math.min(1.0, commit.additions / 300);

    const measureTicks = 512; // 4 quarter notes per commit step
    const noteSteps = 8;
    const stepDuration = measureTicks / noteSteps;

    for (let step = 0; step < noteSteps; step++) {
      const stepTime = currentTicks + step * stepDuration;

      // Calculate pitch given dissonance
      const scaleDegree = (step + commit.additions) % currentScale.length;
      let pitchOffset = currentScale[scaleDegree];
      
      if (Math.random() < dissonanceLevel) {
        pitchOffset += (Math.random() > 0.5 ? 1 : -1); // Introduce sharp/flat chromaticism
      }

      const note = baseRoot + pitchOffset;

      // Play Lead Arpeggio
      leadTrack.noteOn(stepTime, 0, note, 85);
      leadTrack.noteOff(stepTime + stepDuration - 10, 0, note);

      // Play Bass on beat 1 and 5
      if (step === 0 || step === 4) {
        bassTrack.noteOn(stepTime, 2, baseRoot - 24, 100);
        bassTrack.noteOff(stepTime + stepDuration * 3, 2, baseRoot - 24);
      }
    }

    // Play Sustained Harmonic Pad Chord per Commit
    const chordPitches = [0, 2, 4].map(idx => {
      const degree = currentScale[(idx + (commit.additions % 3)) % currentScale.length];
      return baseRoot - 12 + degree;
    });

    chordPitches.forEach(pitch => {
      padTrack.noteOn(currentTicks, 1, pitch, 65);
      padTrack.noteOff(currentTicks + measureTicks - 20, 1, pitch);
    });

    currentTicks += measureTicks;
  });

  return midi.exportBuffer();
}

// Execution
const commits = getGitCommitHistory();
const midiBuffer = buildSymphony(commits);
const outputFile = 'git_symphony.mid';

fs.writeFileSync(outputFile, midiBuffer);
console.log(`Successfully generated "${outputFile}" from ${commits.length} commits.`);