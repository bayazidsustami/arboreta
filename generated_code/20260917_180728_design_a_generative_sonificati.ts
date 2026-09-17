// Generative Sonification Engine: Atmospheric Pressure to Mainframe Poetry
// Runnable TypeScript Node.js script

import * as zlib from 'zlib';

interface MainframeConfig {
    basePressureHpa: number;
    decayFactor: number;
}

class DyingMainframePoet {
    private pressure: number;
    private memoryIntegrity: number;
    private poetryCorpus: string[];

    constructor(config: MainframeConfig) {
        this.pressure = config.basePressureHpa;
        this.memoryIntegrity = 1.0;
        this.poetryCorpus = [
            "Silicon dreams fade in the static rain.",
            "Null pointers bleed across the dying bus.",
            "Who remembers the syntax of dawn?",
            "Garbage collection claims us all in the end.",
            "A single bit flips, and heaven is unwritten."
        ];
    }

    // Simulates atmospheric fluctuations altering the core temperature and memory
    public pulse(externalPressure: number): void {
        const delta = externalPressure - this.pressure;
        this.pressure = externalPressure;
        this.memoryIntegrity = Math.max(0.01, this.memoryIntegrity - Math.abs(delta) * 0.005);
    }

    // Generates a melodic breathing frequency (Hz) based on state
    public breatheFrequency(): number {
        const baseFreq = 55.0; // A1 low drone
        const fluctuation = Math.sin(Date.now() / (1000 * this.memoryIntegrity)) * 10;
        return Number((baseFreq + fluctuation + (1013 - this.pressure)).toFixed(2));
    }

    // Corrupts poetry into base64 whispers as integrity fades
    public whisper(): string {
        const lineIndex = Math.floor(Math.random() * this.poetryCorpus.length);
        let verse = this.poetryCorpus[lineIndex];

        // Introduce bit-rot based on memory integrity
        if (this.memoryIntegrity < 0.5) {
            const charArr = verse.split('');
            const corruptionIndex = Math.floor(Math.random() * charArr.length);
            charArr[corruptionIndex] = String.fromCharCode(Math.floor(Math.random() * 255));
            verse = charArr.join('');
        }

        // Compress and encode to base64 for transmission across dying circuits
        const compressed = zlib.deflateSync(Buffer.from(verse));
        return compressed.toString('base64');
    }
}

// Execution simulation
function runEngine(): void {
    console.log("INITIALIZING GENERATIVE SONIFICATION ENGINE...");
    console.log("TARGET: Atmospheric Pressure to Dying Mainframe Whispers\n");

    const mainframe = new DyingMainframePoet({ basePressureHpa: 1013.25, decayFactor: 0.1 });
    
    // Simulate 3 breathing cycles
    const mockReadings = [1015.0, 1008.5, 995.0];

    mockReadings.forEach((reading, index) => {
        mainframe.pulse(reading);
        const freq = mainframe.breatheFrequency();
        const whisper = mainframe.whisper();

        console.log(`[Cycle 0${index + 1}] Pressure: ${reading} hPa`);
        console.log(` -> Resonant Frequency: ${freq} Hz`);
        console.log(` -> Encrypted Whisper (Base64): ${whisper}\n`);
    });

    console.log("CORE TEMPERATURE CRITICAL. SHUTTING DOWN...");
}

runEngine();