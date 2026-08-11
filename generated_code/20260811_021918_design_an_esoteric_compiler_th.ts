import * as fs from 'fs';

/**
 * Esoteric Compiler: System Crash Logs -> Polyphonic Gregorian Chants
 * 
 * 1. Memory Leak Stack Traces -> Dictate harmonic progressions & modal root shifts (Dorian/Phrygian).
 * 2. HTTP Status Codes -> Control vocal timbres (Formants, harmonics, vibrato, noise).
 * 3. Audio Engine -> Synthesizes multi-voice organum (Vox Principalis & Vox Organalis) into a WAV file.
 */

// --- TYPES & INTERFACES ---

interface StackFrame {
  address: number;      // Hex memory address derived integer
  functionName: string;
  line: number;
  leakSize: number;     // Bytes leaked at frame
}

interface CrashLog {
  timestamp: string;
  httpStatus: number;
  errorMessage: string;
  stackTrace: StackFrame[];
}

interface VocalTimbre {
  formantF1: number;    // First formant frequency (Hz)
  formantF2: number;    // Second formant frequency (Hz)
  sawBlend: number;     // 0.0 (sine/pure) to 1.0 (buzz/grave)
  vibratoRate: number;  // Vibrato frequency in Hz
  vibratoDepth: number; // Vibrato depth
  breathNoise: number;  // White noise mix for monastic aspiration
}

interface VoicePitch {
  cantus: number;       // Lead vocal frequency (Hz)
  organalis: number;   // Parallel fourth/fifth frequency (Hz)
  drone: number;       // Bass drone frequency (Hz)
  durationSec: number; // Duration of chant neume
}

// --- GREGORIAN MODAL CONSTANTS ---

// Dorian Mode frequencies (Hz) based on D3 (146.83 Hz)
const DORIAN_SCALE = [
  146.83, // D3 (Finalis)
  164.81, // E3
  174.61, // F3
  196.00, // G3
  220.00, // A3 (Dominant)
  246.94, // B3
  261.63, // C4
  293.66, // D4
  329.63, // E4
  349.23  // F4
];

// --- HTTP TIMBRE MAPPER ---

function getVocalTimbre(httpStatus: number): VocalTimbre {
  if (httpStatus >= 200 && httpStatus < 300) {
    // Sanctus Vox: Pure, angelic, sine-heavy 'O' vowel
    return { formantF1: 400, formantF2: 800, sawBlend: 0.05, vibratoRate: 4.5, vibratoDepth: 1.5, breathNoise: 0.01 };
  } else if (httpStatus >= 400 && httpStatus < 500) {
    // Kyrie/Penitential Vox: Aspirated, hollow 'E' vowel
    return { formantF1: 300, formantF2: 2200, sawBlend: 0.25, vibratoRate: 5.5, vibratoDepth: 3.0, breathNoise: 0.08 };
  } else {
    // Miserere 5xx Vox: Deep, distorted monastic 'A' vowel with sub-harmonics
    return { formantF1: 700, formantF2: 1100, sawBlend: 0.60, vibratoRate: 3.0, vibratoDepth: 5.0, breathNoise: 0.12 };
  }
}

// --- HARMONIC PROGRESSION COMPILER ---

function compileStackToHarmonies(stackTrace: StackFrame[]): VoicePitch[] {
  const progressions: VoicePitch[] = [];
  let modalIndex = 0; // Start at D3

  for (const frame of stackTrace) {
    // Address dictates pitch movement step within Gregorian Dorian mode
    const stepShift = (frame.address % 5) - 2; // Move -2 to +2 steps
    modalIndex = Math.max(0, Math.min(DORIAN_SCALE.length - 1, modalIndex + stepShift));

    const cantusFreq = DORIAN_SCALE[modalIndex];

    // Memory leak dictates organum harmony type (4th, 5th, or octave)
    let organalisInterval = 3; // Default parallel 4th
    if (frame.leakSize > 1024 * 1024) organalisInterval = 4; // Parallel 5th for large leaks
    if (frame.leakSize > 10 * 1024 * 1024) organalisInterval = 7; // Octave for severe leaks

    const organalisIndex = Math.min(DORIAN_SCALE.length - 1, modalIndex + organalisInterval);
    const organalisFreq = DORIAN_SCALE[organalisIndex];

    // Bass drone locked to Finalis (D2 = 73.41Hz) or Dominant (A2 = 110Hz)
    const droneFreq = (frame.line % 2 === 0) ? 73.41 : 110.00;

    // Leak size dictates duration (1.5s to 4.0s per chant neume)
    const duration = Math.min(4.0, Math.max(1.5, 1.5 + (frame.leakSize / (1024 * 512))));

    progressions.push({
      cantus: cantusFreq,
      organalis: organalisFreq,
      drone: droneFreq,
      durationSec: duration
    });
  }

  return progressions;
}

// --- AUDIO SYNTHESIZER ENGINE ---

class ChantAudioSynthesizer {
  private sampleRate = 44100;

  // Formant Filter simulation (Simple 2-pole resonant filter approximation)
  private applyFormant(sample: number, f1: number, f2: number, t: number): number {
    const formant1 = Math.sin(2 * Math.PI * f1 * t) * 0.5;
    const formant2 = Math.sin(2 * Math.PI * f2 * t) * 0.3;
    return sample * (1.0 + formant1 + formant2);
  }

  // Synthesizes a single vocal tone with timbral dynamics
  private generateVoiceSample(freq: number, timbre: VocalTimbre, t: number): number {
    const vibrato = Math.sin(2 * Math.PI * timbre.vibratoRate * t) * timbre.vibratoDepth;
    const modulatedFreq = freq + vibrato;

    // Harmonic blend: Pure Sine + Sawtooth rich body
    const sineWave = Math.sin(2 * Math.PI * modulatedFreq * t);
    const sawWave = 2 * ((modulatedFreq * t) % 1) - 1;
    const rawVoice = (sineWave * (1 - timbre.sawBlend)) + (sawWave * timbre.sawBlend);

    // Add monastic breath / room resonance
    const noise = (Math.random() * 2 - 1) * timbre.breathNoise;

    // Apply formant shaping
    return this.applyFormant(rawVoice + noise, timbre.formantF1, timbre.formantF2, t);
  }

  public synthesizeChant(progressions: VoicePitch[], timbre: VocalTimbre): Float32Array {
    let totalSamples = 0;
    for (const p of progressions) {
      totalSamples += Math.floor(p.durationSec * this.sampleRate);
    }

    const audioBuffer = new Float32Array(totalSamples);
    let currentSampleOffset = 0;

    for (const chord of progressions) {
      const numSamples = Math.floor(chord.durationSec * this.sampleRate);

      for (let i = 0; i < numSamples; i++) {
        const t = i / this.sampleRate;

        // Envelope: Smooth Gregorian attack and long decay
        const attack = Math.min(1.0, i / (this.sampleRate * 0.3));
        const decay = Math.min(1.0, (numSamples - i) / (this.sampleRate * 0.5));
        const envelope = attack * decay;

        // Polyphonic blend: Cantus + Organalis + Bass Drone
        const cantusSample = this.generateVoiceSample(chord.cantus, timbre, t);
        const organalisSample = this.generateVoiceSample(chord.organalis, timbre, t);
        const droneSample = this.generateVoiceSample(chord.drone, timbre, t) * 0.8;

        const polyphonicMix = (cantusSample * 0.4) + (organalisSample * 0.35) + (droneSample * 0.25);
        
        audioBuffer[currentSampleOffset + i] = polyphonicMix * envelope * 0.5; // Master gain
      }

      currentSampleOffset += numSamples;
    }

    return audioBuffer;
  }

  // Encodes PCM Float32 data into a valid WAV file Buffer
  public createWavBuffer(samples: Float32Array): Buffer {
    const buffer = Buffer.alloc(44 + samples.length * 2);

    // RIFF chunk descriptor
    buffer.write('RIFF', 0);
    buffer.writeUInt32LE(36 + samples.length * 2, 4);
    buffer.write('WAVE', 8);

    // fmt sub-chunk
    buffer.write('fmt ', 12);
    buffer.writeUInt32LE(16, 16);          // Subchunk1Size
    buffer.writeUInt16LE(1, 20);           // AudioFormat (PCM)
    buffer.writeUInt16LE(1, 22);           // NumChannels (Mono)
    buffer.writeUInt32LE(this.sampleRate, 24); // SampleRate
    buffer.writeUInt32LE(this.sampleRate * 2, 28); // ByteRate
    buffer.writeUInt16LE(2, 32);           // BlockAlign
    buffer.writeUInt16LE(16, 34);          // BitsPerSample

    // data sub-chunk
    buffer.write('data', 36);
    buffer.writeUInt32LE(samples.length * 2, 40);

    // Write PCM 16-bit audio samples
    for (let i = 0; i < samples.length; i++) {
      const s = Math.max(-1, Math.min(1, samples[i]));
      buffer.writeInt16LE(s < 0 ? s * 0x8000 : s * 0x7FFF, 44 + i * 2);
    }

    return buffer;
  }
}

// --- LOG PARSER & COMPILER ENTRY POINT ---

function parseSystemCrashLog(rawLog: string): CrashLog {
  const lines = rawLog.trim().split('\n');
  const header = lines[0];
  
  // Extract HTTP status code
  const statusMatch = header.match(/HTTP\s+(\d{3})/i) || header.match(/Status:\s*(\d{3})/i);
  const httpStatus = statusMatch ? parseInt(statusMatch[1], 10) : 500;

  const stackTrace: StackFrame[] = [];

  for (let i = 1; i < lines.length; i++) {
    const line = lines[i];
    if (!line.includes('at ')) continue;

    // Parse hex memory addresses and leak descriptors
    const addrMatch = line.match(/0x[0-9a-fA-F]+/);
    const lineNumMatch = line.match(/:(\d+)\)?$/);
    const leakMatch = line.match(/\[leaked\s+(\d+)B\]/i);

    const address = addrMatch ? parseInt(addrMatch[0], 16) : Math.floor(Math.random() * 0xFFFFFF);
    const lineNum = lineNumMatch ? parseInt(lineNumMatch[1], 10) : 42;
    const leakSize = leakMatch ? parseInt(leakMatch[1], 10) : 1024 * (i * 256);

    stackTrace.push({
      address,
      functionName: line.trim(),
      line: lineNum,
      leakSize
    });
  }

  return {
    timestamp: new Date().toISOString(),
    httpStatus,
    errorMessage: header,
    stackTrace
  };
}

// --- VISUALIZATION HELPER ---

function renderAsciiNeumes(progressions: VoicePitch[], status: number): void {
  console.log(`\n======================================================`);
  console.log(`   ESOTERIC COMPILER: SYSTEM CRASH TO GREGORIAN CHANT  `);
  console.log(`======================================================`);
  console.log(` HTTP Status Code : ${status}`);
  console.log(` Polyphonic Modes : Dorian / Parallel Organum`);
  console.log(` Neume Score Notation:`);
  console.log(`------------------------------------------------------`);

  for (let i = 0; i < progressions.length; i++) {
    const p = progressions[i];
    const cantusNote = Math.round(p.cantus);
    const organalisNote = Math.round(p.organalis);
    const padding = " ".repeat((cantusNote % 12));
    
    console.log(` Frame #${i + 1} | ${cantusNote}Hz ♫ ${padding}𝄀𝄁 █▓▒░ (Organum: ${organalisNote}Hz, Drone: ${Math.round(p.drone)}Hz)`);
  }
  console.log(`------------------------------------------------------\n`);
}

// --- RUNNABLE DEMONSTRATION ---

const MOCK_CRASH_LOG = `
FATAL ERROR: MemoryLeakException - HTTP 500 Internal Server Error
  at HeavyBufferPool.allocate (0x7fff5fbff080) :104 [leaked 204800B]
  at RequestHandler.processPipeline (0x7fff5fbff1c4) :210 [leaked 1048576B]
  at QueryBuilder.executeLeak (0x7fff5fbff400) :85 [leaked 5242880B]
  at GarbageCollector.failGracefully (0x7fff5fbff8e0) :512 [leaked 12582912B]
  at MonasticProcess.exit (0x7fff5fbffc10) :12 [leaked 512B]
`.trim();

// 1. Parse Crash Log
const crashData = parseSystemCrashLog(MOCK_CRASH_LOG);

// 2. Map Memory Leaks -> Harmonic Progressions
const harmonicChords = compileStackToHarmonies(crashData.stackTrace);

// 3. Map HTTP Status -> Vocal Timbre
const vocalTimbre = getVocalTimbre(crashData.httpStatus);

// 4. Render ASCII Chant Score
renderAsciiNeumes(harmonicChords, crashData.httpStatus);

// 5. Synthesize Chant Audio -> WAV Buffer
const synth = new ChantAudioSynthesizer();
const floatAudioSamples = synth.synthesizeChant(harmonicChords, vocalTimbre);
const wavBuffer = synth.createWavBuffer(floatAudioSamples);

// 6. Write to Output WAV File
const outputFile = 'gregorian_crash_chant.wav';
fs.writeFileSync(outputFile, wavBuffer);

console.log(`✓ Polyphonic Gregorian Chant compiled successfully!`);
console.log(`  Audio saved to: ${outputFile} (${wavBuffer.length} bytes)\n`);