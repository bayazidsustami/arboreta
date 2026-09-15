import { createCanvas, CanvasRenderingContext2D } from 'canvas';
import { WriteStream, createWriteStream } from 'fs';

// --- Types & Definitions ---

type Command = 'NOP' | 'NOTE_ON' | 'NOTE_OFF' | 'SET_PAN' | 'SET_TEMPO' | 'RESET';

interface PixelOpcode {
  command: Command;
  pitch: number;    // MIDI Note Number (0-127)
  velocity: number; // Volume/Gain (0-1)
  duration: number; // In beats
}

interface ToneEvent {
  time: number;     // Absolute time in seconds
  duration: number; // Duration in seconds
  pitch: number;    // MIDI Note Number
  velocity: number; // 0-1
  pan: number;      // -1 (Left) to 1 (Right)
}

// --- Image Compiler (RGB Pixels -> Music Instructions) ---

class PixelToneCompiler {
  private tempo = 120; // BPM

  public compile(ctx: CanvasRenderingContext2D, width: number, height: number): ToneEvent[] {
    const imageData = ctx.getImageData(0, 0, width, height);
    const data = imageData.data;
    const events: ToneEvent[] = [];

    let currentBeat = 0;
    let activePan = 0;

    for (let y = 0; y < height; y++) {
      let rowDuration = 0.25; // Default 16th note step per pixel

      for (let x = 0; x < width; x++) {
        const index = (y * width + x) * 4;
        const r = data[index];
        const g = data[index + 1];
        const b = data[index + 2];
        const a = data[index + 3];

        if (a === 0) continue; // Skip transparent pixels

        const opcode = this.decodePixel(r, g, b);
        
        // Spatial position dictates Panning (-1 Left to +1 Right)
        activePan = (x / (width - 1 || 1)) * 2 - 1;

        // Vertical proximity/grouping controls harmonic layering/polyphony
        // Pixels on the same row play concurrently or offset based on x
        const startTime = (currentBeat * (60 / this.tempo)) + (y * 0.05);

        switch (opcode.command) {
          case 'NOTE_ON':
            events.push({
              time: startTime,
              duration: opcode.duration * (60 / this.tempo),
              pitch: opcode.pitch,
              velocity: opcode.velocity,
              pan: activePan
            });
            break;
          case 'SET_TEMPO':
            this.tempo = Math.max(40, Math.min(240, opcode.pitch * 2));
            break;
          case 'SET_PAN':
            activePan = (opcode.pitch / 127) * 2 - 1;
            break;
        }

        rowDuration = Math.max(rowDuration, opcode.duration);
      }
      currentBeat += rowDuration;
    }

    return events;
  }

  // Red Channel = Opcode/Command
  // Green Channel = Pitch (Scaled to 12-tone chromatic MIDI notes)
  // Blue Channel = Velocity / Duration
  private decodePixel(r: number, g: number, b: number): PixelOpcode {
    const pitch = Math.floor((g / 255) * 60) + 36; // C2 to C7 range
    const velocity = b / 255;
    const duration = 0.25 + (b / 255) * 1.75; // 0.25 to 2 beats

    let command: Command = 'NOP';
    if (r > 200) command = 'NOTE_ON';
    else if (r > 150) command = 'SET_TEMPO';
    else if (r > 100) command = 'SET_PAN';
    else if (r > 50) command = 'NOTE_OFF';

    return { command, pitch, velocity, duration };
  }
}

// --- Audio Synthesizer & Waveform Exporter ---

class SoftwareSynth {
  private sampleRate = 44100;

  public renderToWav(events: ToneEvent[], outputPath: string): Promise<void> {
    const totalDuration = Math.max(...events.map(e => e.time + e.duration), 1) + 1.0;
    const totalSamples = Math.floor(totalDuration * this.sampleRate);
    
    // Stereo audio buffers
    const leftBuffer = new Float32Array(totalSamples);
    const rightBuffer = new Float32Array(totalSamples);

    // Synthesize each tone event using additive synthesis (Fundamental + Harmonics)
    for (const event of events) {
      const startSample = Math.floor(event.time * this.sampleRate);
      const numSamples = Math.floor(event.duration * this.sampleRate);
      const freq = 440 * Math.pow(2, (event.pitch - 69) / 12);

      // Panning calculations (Constant Power)
      const panRad = ((event.pan + 1) * Math.PI) / 4;
      const leftGain = Math.cos(panRad) * event.velocity;
      const rightGain = Math.sin(panRad) * event.velocity;

      for (let i = 0; i < numSamples; i++) {
        const idx = startSample + i;
        if (idx >= totalSamples) break;

        const t = i / this.sampleRate;
        
        // ADSR Envelope (Fast attack, linear decay)
        const env = Math.sin((i / numSamples) * Math.PI); 

        // Rich Warm Synth Tone: Sine fundamental + Soft Triangle Harmonic
        const sampleVal = (Math.sin(2 * Math.PI * freq * t) * 0.7 +
                           Math.asin(Math.sin(2 * Math.PI * freq * 2 * t)) * 0.3) * env * 0.3;

        leftBuffer[idx] += sampleVal * leftGain;
        rightBuffer[idx] += sampleVal * rightGain;
      }
    }

    return this.writeWavFile(outputPath, leftBuffer, rightBuffer);
  }

  private writeWavFile(filepath: string, left: Float32Array, right: Float32Array): Promise<void> {
    return new Promise((resolve, reject) => {
      const stream = createWriteStream(filepath);
      const numSamples = left.length;
      const buffer = Buffer.alloc(44 + numSamples * 4);

      // RIFF header
      buffer.write('RIFF', 0);
      buffer.writeUInt32LE(36 + numSamples * 4, 4);
      buffer.write('WAVE', 8);
      buffer.write('fmt ', 12);
      buffer.writeUInt32LE(16, 16);          // Subchunk1Size (16 for PCM)
      buffer.writeUInt16LE(1, 20);           // AudioFormat (1 = PCM)
      buffer.writeUInt16LE(2, 22);           // NumChannels (2 = Stereo)
      buffer.writeUInt32LE(this.sampleRate, 24); 
      buffer.writeUInt32LE(this.sampleRate * 4, 28); // ByteRate
      buffer.writeUInt16LE(4, 32);           // BlockAlign
      buffer.writeUInt16LE(16, 34);          // BitsPerSample

      // Data header
      buffer.write('data', 36);
      buffer.writeUInt32LE(numSamples * 4, 40);

      // Interleave samples
      let offset = 44;
      for (let i = 0; i < numSamples; i++) {
        const sL = Math.max(-1, Math.min(1, left[i]));
        const sR = Math.max(-1, Math.min(1, right[i]));
        buffer.writeInt16LE(sL < 0 ? sL * 0x8000 : sL * 0x7FFF, offset);
        buffer.writeInt16LE(sR < 0 ? sR * 0x8000 : sR * 0x7FFF, offset + 2);
        offset += 4;
      }

      stream.write(buffer);
      stream.end();
      stream.on('finish', resolve);
      stream.on('error', reject);
    });
  }
}

// --- Main Execution Script ---

async function main() {
  const width = 16;
  const height = 16;
  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext('2d');

  // Generate an example Pixel Program (Source Code Image)
  // Creates a colorful visual pattern that translates into a harmonic progression
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const red = 210; // NOTE_ON command
      const green = ((x * 4 + y * 7) % 48) + 40; // Pentatonic/Harmonic pitch variations
      const blue = 100 + Math.floor(Math.sin(x + y) * 100); // Dynamics and durations
      
      ctx.fillStyle = `rgba(${red}, ${green}, ${blue}, 1.0)`;
      ctx.fillRect(x, y, 1, 1);
    }
  }

  console.log('Compiling Pixel Source Code into Music Events...');
  const compiler = new PixelToneCompiler();
  const toneEvents = compiler.compile(ctx, width, height);

  console.log(`Compiled ${toneEvents.length} musical instructions.`);
  console.log('Rendering audio waveform to output.wav...');
  
  const synth = new SoftwareSynth();
  await synth.renderToWav(toneEvents, 'output.wav');

  console.log('Done! Output saved to output.wav');
}

main().catch(console.error);