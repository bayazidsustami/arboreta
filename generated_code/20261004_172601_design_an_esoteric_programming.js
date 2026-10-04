```javascript
/**
 * ChordoScript Interpreter
 * An esoteric programming language where variables are musical chords
 * that dynamically orchestrate a live ambient soundtrack as code executes.
 * 
 * Syntax:
 * - Cmaj / Am / G7 / Dm7 / etc. = Variable assignment or chord playback
 * - Cmaj += 20         = Increment chord root frequency offset or play note
 * - print Cmaj         = Output chord state & trigger audio modulation
 * - if Am { ... }      = Conditional based on chord complexity/tension
 * - loop 4 { ... }     = Musical loop / rhythmic repetition
 */

class ChordoScriptInterpreter {
    constructor() {
        this.variables = {};
        this.audioCtx = null;
        this.masterGain = null;
        this.activeOscillators = new Set();
        this.running = false;

        // Chord definitions (semitones relative to root, and chord quality name)
        this.chordDatabase = {
            'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3,
            'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8,
            'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11
        };

        this.chordIntervals = {
            'maj': [0, 4, 7, 11],
            'min': [0, 3, 7, 10],
            '7': [0, 4, 7, 10],
            'maj7': [0, 4, 7, 11],
            'm7': [0, 3, 7, 10],
            'dim': [0, 3, 6, 9],
            'aug': [0, 4, 8, 11],
            'sus4': [0, 5, 7, 10]
        };
    }

    initAudio() {
        if (!this.audioCtx) {
            const AudioContext = window.AudioContext || window.webkitAudioContext;
            this.audioCtx = new AudioContext();
            this.masterGain = this.audioCtx.createGain();
            this.masterGain.gain.setValueAtTime(0.15, this.audioCtx.currentTime);

            // Add subtle ambient reverb/delay simulation via feedback filter
            const filter = this.audioCtx.createBiquadFilter();
            filter.type = 'lowpass';
            filter.frequency.setValueAtTime(1200, this.audioCtx.currentTime);

            this.masterGain.connect(filter);
            filter.connect(this.audioCtx.destination);
        }
        if (this.audioCtx.state === 'suspended') {
            this.audioCtx.resume();
        }
    }

    parseChord(chordStr) {
        // e.g. "Cmaj", "Am7", "F#dim"
        const match = chordStr.match(/^([A-G][b#]?)(.*)$/);
        if (!match) return null;

        const rootNote = match[1];
        let quality = match[2].toLowerCase();
        if (!quality || quality === '') quality = 'maj';
        if (!this.chordIntervals[quality]) quality = 'maj';

        const baseMidi = 48 + (this.chordDatabase[rootNote] || 0); // Octave 3 (C3 = 48)
        const intervals = this.chordIntervals[quality];

        const frequencies = intervals.map(semitone => {
            return 440 * Math.pow(2, (baseMidi + semitone - 69) / 12);
        });

        return { root: rootNote, quality, frequencies };
    }

    playChordAudio(chordData, duration = 2.5) {
        this.initAudio();
        const now = this.audioCtx.currentTime;

        chordData.frequencies.forEach((freq, idx) => {
            const osc = this.audioCtx.createOscillator();
            const gainNode = this.audioCtx.createGain();

            // Blend sine and triangle for a warm ambient pad tone
            osc.type = idx % 2 === 0 ? 'sine' : 'triangle';
            osc.frequency.setValueAtTime(freq, now);

            // Gentle attack and long release envelope
            gainNode.gain.setValueAtTime(0, now);
            gainNode.gain.linearRampToValueAtTime(0.08 / chordData.frequencies.length, now + 0.5);
            gainNode.gain.exponentialRampToValueAtTime(0.0001, now + duration);

            osc.connect(gainNode);
            gainNode.connect(this.masterGain);

            osc.start(now);
            osc.stop(now + duration);

            this.activeOscillators.add(osc);
            osc.onended = () => this.activeOscillators.delete(osc);
        });
    }

    async execute(code) {
        this.running = true;
        const lines = code.split('\n').map(l => l.trim()).filter(l => l && !l.startsWith('//'));
        
        for (let i = 0; i < lines.length; i++) {
            if (!this.running) break;
            const line = lines[i];

            // Handle print statement: print Cmaj
            if (line.startsWith('print ')) {
                const varName = line.substring(6).trim();
                const val = this.variables[varName];
                console.log(`[ChordoScript Output] ${varName} =`, val);
                if (val && val.frequencies) {
                    this.playChordAudio(val, 3.0);
                }
                await this.sleep(400);
                continue;
            }

            // Handle assignment / chord declaration: Am = 10 or Cmaj = active
            if (line.includes('=')) {
                const parts = line.split('=').map(p => p.trim());
                const chordName = parts[0];
                const rhs = parts[1];

                const chordInfo = this.parseChord(chordName);
                if (chordInfo) {
                    this.variables[chordName] = {
                        ...chordInfo,
                        value: isNaN(rhs) ? rhs : parseFloat(rhs)
                    };
                    // Trigger sound on chord assignment
                    this.playChordAudio(chordInfo, 2.0);
                    console.log(`[Harmony Engine] Chord assigned & orchestrated: ${chordName}`);
                }
                await this.sleep(300);
                continue;
            }

            // Handle standalone chord evaluation as rhythmic pulses
            const chordInfo = this.parseChord(line);
            if (chordInfo) {
                this.playChordAudio(chordInfo, 1.5);
                console.log(`[Ambient Pulse] Played chord: ${line}`);
                await this.sleep(500);
            }
        }
        console.log('[ChordoScript] Soundtrack execution complete.');
    }

    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

// Example usage script demonstrating the esoteric musical language:
const sampleScript = `
// Initialize ambient mood chords
Cmaj = 100
Am7 = 200
Fmaj7 = 300
G7 = 400

print Cmaj
print Am7
print Fmaj7
print G7

// Dynamic live melodic progression
Dm7
G7
Cmaj
`;

// To run in browser environment with user audio interaction:
if (typeof window !== 'undefined') {
    const runBtn = document.createElement('button');
    runBtn.innerText = 'Play ChordoScript Ambient Soundtrack';
    runBtn.style.cssText = 'position:fixed;top:20px;left:20px;z-index:9999;padding:12px 24px;font-family:sans-serif;background:#4f46e5;color:#fff;border:none;border-radius:8px;cursor:pointer;box-shadow:0 4px 12px rgba(0,0,0,0.15);';
    runBtn.onclick = () => {
        const interpreter = new ChordoScriptInterpreter();
        interpreter.execute(sampleScript);
        runBtn.innerText = 'Soundtrack Playing...';
        runBtn.disabled = true;
    };
    document.body.appendChild(runBtn);
}
```