import * as fs from 'fs';
import * as path from 'path';
import { execSync, spawn } from 'child_process';

// --- CONFIGURATION & TERMINAL ART ---
const SOURCE_DIR = process.cwd(); // Target directory to infect
const MOLD_CHARS = ['░', '▒', '▓', '█', '🍄', '🦠', '🌱', '≈', '𓆣', '∴'];
const PITCH_MAP = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79]; // C Major Scale MIDI Notes

interface InfectedFile {
  filePath: string;
  originalContent: string;
  decayContent: string;
  spores: number;
}

// --- DIGITAL MOLD SIMULATOR CLASS ---
class DigitalMoldSimulation {
  private files: InfectedFile[] = [];
  private isDecaying: boolean = false;

  constructor() {
    this.scanProjectFiles();
  }

  /**
   * Discovers text/code files in the current working directory to decay.
   */
  private scanProjectFiles(): void {
    const entries = fs.readdirSync(SOURCE_DIR, { recursive: true }) as string[];
    const targetFiles = entries.filter((entry) => {
      const fullPath = path.join(SOURCE_DIR, entry);
      return (
        fs.existsSync(fullPath) &&
        fs.statSync(fullPath).isFile() &&
        /\.(ts|js|json|md|txt)$/.test(entry) &&
        !entry.includes('node_modules') &&
        !entry.includes('dist')
      );
    });

    for (const relPath of targetFiles) {
      const fullPath = path.join(SOURCE_DIR, relPath);
      const content = fs.readFileSync(fullPath, 'utf-8');
      this.files.push({
        filePath: fullPath,
        originalContent: content,
        decayContent: content,
        spores: 0,
      });
    }
  }

  /**
   * Physical Decay Logic: Spreads mold characters across target files over time.
   */
  public infectTick(): void {
    if (this.files.length === 0) return;

    // Pick a random target file
    const target = this.files[Math.floor(Math.random() * this.files.length)];
    const contentArr = target.decayContent.split('');

    if (contentArr.length === 0) return;

    // Infect a random non-whitespace character
    let index = Math.floor(Math.random() * contentArr.length);
    for (let i = 0; i < 10; i++) {
      if (!/\s/.test(contentArr[index])) break;
      index = Math.floor(Math.random() * contentArr.length);
    }

    const spore = MOLD_CHARS[Math.floor(Math.random() * MOLD_CHARS.length)];
    contentArr[index] = spore;
    target.decayContent = contentArr.join('');
    target.spores++;

    // Write physical decay back to file system
    fs.writeFileSync(target.filePath, target.decayContent, 'utf-8');

    // Terminal render update
    this.renderMoldUI(target.filePath, spore);
  }

  /**
   * Validates project build/syntax.
   */
  public verifyBuild(): boolean {
    try {
      // Check if TypeScript/JavaScript files compile cleanly
      execSync('npx tsc --noEmit', { stdio: 'ignore' });
      return true;
    } catch {
      return false;
    }
  }

  /**
   * Mutates decaying syntax tree into playable MIDI melodies when build fails.
   */
  public synthesizeFailureMelody(): void {
    console.clear();
    console.log('\x1b[31m%s\x1b[0m', '▓▓▓ BUILD FAILED: CRITICAL MOLD INFESTATION DETECTED ▓▓▓');
    console.log('\x1b[35m%s\x1b[0m', 'Synthesizing syntax decay into MIDI melody...\n');

    // Convert mutated AST/code character frequencies into sound notes
    const notes: number[] = [];
    for (const file of this.files) {
      for (let i = 0; i < file.decayContent.length; i += 8) {
        const charCode = file.decayContent.charCodeAt(i) || 60;
        const note = PITCH_MAP[charCode % PITCH_MAP.length];
        notes.push(note);
        if (notes.length >= 32) break; // Limit melody length
      }
      if (notes.length >= 32) break;
    }

    this.playMIDISequence(notes);
  }

  /**
   * Generates standard binary MIDI file buffer and executes native audio player.
   */
  private playMIDISequence(notes: number[]): void {
    const midiHeader = [
      0x4d, 0x54, 0x68, 0x64, // 'MThd'
      0x00, 0x00, 0x00, 0x06, // Header size
      0x00, 0x00,             // Format 0
      0x00, 0x01,             // 1 Track
      0x00, 0x60              // 96 Ticks per quarter note
    ];

    const trackEvents: number[] = [];
    for (const note of notes) {
      // Note On (Channel 0, Note, Velocity 100)
      trackEvents.push(0x00, 0x90, note, 0x64);
      // Duration (96 ticks delay)
      trackEvents.push(0x60, 0x80, note, 0x00);
    }

    // End of Track event
    trackEvents.push(0x00, 0xff, 0x2f, 0x00);

    const trackLength = trackEvents.length;
    const trackHeader = [
      0x4d, 0x54, 0x72, 0x6b, // 'MTrk'
      (trackLength >> 24) & 0xff,
      (trackLength >> 16) & 0xff,
      (trackLength >> 8) & 0xff,
      trackLength & 0xff,
    ];

    const midiBuffer = Buffer.from([...midiHeader, ...trackHeader, ...trackEvents]);
    const midiPath = path.join(SOURCE_DIR, 'mold_decay.mid');
    fs.writeFileSync(midiPath, midiBuffer);

    console.log(`MIDI exported to: ${midiPath}`);
    console.log('Playing synthesized decay melody...');

    // Attempt native play back (macOS: timidity/afplay, Linux: aplay/timidity, Windows: powershell)
    const platform = process.platform;
    if (platform === 'darwin') {
      spawn('timidity', [midiPath]).on('error', () => {
        console.log('Melody synthesized. (Install "timidity" to play raw MIDI directly in terminal)');
      });
    } else if (platform === 'win32') {
      spawn('powershell', ['-c', `(New-Object Media.SoundPlayer "${midiPath}").PlaySync()`]);
    } else {
      spawn('timidity', [midiPath]).on('error', () => {
        console.log('Melody synthesized to mold_decay.mid');
      });
    }
  }

  /**
   * Terminal visualizer for current mold decay progress.
   */
  private renderMoldUI(file: string, spore: string): void {
    console.clear();
    console.log('\x1b[32m%s\x1b[0m', '════════════════════════════════════════════════════════════');
    console.log('\x1b[33m%s\x1b[0m', '         𓆣 DIGITAL MOLD DECAY SIMULATOR v1.0 𓆣');
    console.log('\x1b[32m%s\x1b[0m', '════════════════════════════════════════════════════════════');
    console.log(`Infecting Target File: ${path.basename(file)}`);
    console.log(`Spores Attached: ${spore}\n`);

    for (const f of this.files) {
      const sporeCount = (f.decayContent.match(/[░▒▓█🍄🦠🌱≈𓆣∴]/g) || []).length;
      console.log(`[${f.spores > 0 ? 'INFECTED' : 'CLEAN'}] ${path.basename(f.filePath)} -> ${sporeCount} spores`);
    }
    console.log('\x1b[36m%s\x1b[0m', '\nPress Ctrl+C to stop simulation.');
  }

  /**
   * Starts the simulation cycle loop.
   */
  public start(): void {
    this.isDecaying = true;
    const interval = setInterval(() => {
      if (!this.isDecaying) return;

      this.infectTick();

      // Check build integrity
      const buildSuccess = this.verifyBuild();
      if (!buildSuccess) {
        clearInterval(interval);
        this.synthesizeFailureMelody();
      }
    }, 1500);
  }
}

// Execute Digital Mold Simulation
const sim = new DigitalMoldSimulation();
sim.start();