const fs = require('fs');

class ChromaticAudioCompiler {
    constructor(sampleRate = 44100) {
        this.sampleRate = sampleRate;
        this.baseFreqs = [130.81, 146.83, 164.81, 174.61, 196.00, 220.00, 246.94, 261.63]; // C3 to C4
    }

    // Parses raw 24-bit/32-bit uncompressed BMP files into pixel data
    parseBMP(buffer) {
        const pixelOffset = buffer.readUInt32LE(10);
        const width = buffer.readInt32LE(18);
        const height = Math.abs(buffer.readInt32LE(22));
        const bpp = buffer.readUInt16LE(28);
        const rowSize = Math.floor((bpp * width + 31) / 32) * 4;
        const pixels = [];

        for (let y = 0; y < height; y++) {
            const row = [];
            for (let x = 0; x < width; x++) {
                const idx = pixelOffset + y * rowSize + x * (bpp / 8);
                const b = buffer[idx] / 255;
                const g = buffer[idx + 1] / 255;
                const r = buffer[idx + 2] / 255;
                const brightness = 0.299 * r + 0.587 * g + 0.114 * b;
                row.push({ r, g, b, brightness });
            }
            row.push(row[row.length - 1]); // Pad edge for contrast math
            pixels.push(row);
        }
        return { width, height, pixels };
    }

    // Compiles image pixels to polyphonic audio sample buffer
    compile(imageBuffer) {
        const { width, height, pixels } = this.parseBMP(imageBuffer);
        const audioBuffer = [];
        const secPerCol = 0.08; 
        const samplesPerCol = Math.floor(this.sampleRate * secPerCol);

        let phaseAcc = new Array(height).fill(0);

        for (let x = 0; x < width; x++) {
            // Compute rhythm/duration modifier based on color contrast with neighboring pixel
            let colContrast = 0;
            for (let y = 0; y < height; y++) {
                const curr = pixels[y][x];
                const next = pixels[y][x + 1];
                colContrast += Math.abs(curr.r - next.r) + Math.abs(curr.g - next.g) + Math.abs(curr.b - next.b);
            }
            colContrast /= (height * 3);
            
            // High contrast yields crisp, staccato notes; low contrast stretches the rhythm
            const rhythmFactor = Math.max(0.2, 1.5 - colContrast * 2);
            const currentSamples = Math.floor(samplesPerCol * rhythmFactor);

            for (let s = 0; s < currentSamples; s++) {
                let mixedSample = 0;

                for (let y = 0; y < height; y++) {
                    const { r, g, b, brightness } = pixels[y][x];
                    
                    // Map hue/brightness to frequency spectrum & harmonic resonance
                    const noteIndex = Math.floor((y / height) * this.baseFreqs.length);
                    const baseFreq = this.baseFreqs[noteIndex];
                    const pitchShift = 1 + (r * 0.5 - b * 0.25); 
                    const frequency = baseFreq * pitchShift;

                    // Resonance envelope determined by pixel brightness & hue intensity
                    const resonance = brightness * (0.5 + g * 0.5);
                    
                    // Synthesize oscillator wave
                    phaseAcc[y] += (2 * Math.PI * frequency) / this.sampleRate;
                    const wave = Math.sin(phaseAcc[y]) + 0.25 * Math.sin(2 * phaseAcc[y]); 
                    
                    mixedSample += wave * resonance;
                }

                // Soft clipping to normalize polyphonic mixing
                mixedSample = Math.tanh(mixedSample / (height * 0.2));
                audioBuffer.push(mixedSample);
            }
        }
        return audioBuffer;
    }

    // Encodes raw floating point PCM buffer to 16-bit Mono WAV format
    exportWAV(samples) {
        const buffer = Buffer.alloc(44 + samples.length * 2);
        buffer.write('RIFF', 0);
        buffer.writeUInt32LE(36 + samples.length * 2, 4);
        buffer.write('WAVE', 8);
        buffer.write('fmt ', 12);
        buffer.writeUInt32LE(16, 16);
        buffer.writeUInt16LE(1, 20); // PCM
        buffer.writeUInt16LE(1, 22); // Mono
        buffer.writeUInt32LE(this.sampleRate, 24);
        buffer.writeUInt32LE(this.sampleRate * 2, 28);
        buffer.writeUInt16LE(2, 32);
        buffer.writeUInt16LE(16, 34);
        buffer.write('data', 36);
        buffer.writeUInt32LE(samples.length * 2, 40);

        for (let i = 0; i < samples.length; i++) {
            const s = Math.max(-1, Math.min(1, samples[i]));
            buffer.writeInt16LE(s < 0 ? s * 0x8000 : s * 0x7FFF, 44 + i * 2);
        }
        return buffer;
    }

    // Generates a minimal valid 16x16 RGB BMP buffer for self-contained testing
    createSyntheticBMP() {
        const width = 16, height = 16;
        const rowSize = width * 3;
        const buf = Buffer.alloc(54 + rowSize * height);
        
        // Header
        buf.write('BM', 0);
        buf.writeUInt32LE(54 + rowSize * height, 2);
        buf.writeUInt32LE(54, 10);
        buf.writeUInt32LE(40, 14);
        buf.writeInt32LE(width, 18);
        buf.writeInt32LE(height, 22);
        buf.writeUInt16LE(1, 26);
        buf.writeUInt16LE(24, 28);
        
        // Dynamic color/contrast patterns
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                const idx = 54 + y * rowSize + x * 3;
                buf[idx] = (x * 16) % 255;       // B
                buf[idx + 1] = (y * 16) % 255;   // G
                buf[idx + 2] = ((x + y) * 8) % 255; // R
            }
        }
        return buf;
    }
}

// Execution flow
const compiler = new ChromaticAudioCompiler();
const inputBMP = process.argv[2] ? fs.readFileSync(process.argv[2]) : compiler.createSyntheticBMP();
const audioData = compiler.compile(inputBMP);
const wavBuffer = compiler.exportWAV(audioData);

fs.writeFileSync('output_composition.wav', wavBuffer);
console.log('Compiled image to polyphonic audio: output_composition.wav');