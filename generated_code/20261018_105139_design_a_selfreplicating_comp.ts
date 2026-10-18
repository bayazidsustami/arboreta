/**
 * Self-Replicating ASCII Art Compiler for Recursive Poetry & Chromatic MIDI
 * Eats its own stack memory recursively while translating poetry into MIDI notes.
 */

const ASCII_ART = `
    _____________________________________________
   |  _ _ _   ___ _  _ ___   ___ ___  _  _ ___   |
   | / / / \\ | _ \\ \\/ /| __| / __/ _ \\| \\| | _ \\  |
   | \\ \\ \\_/ |  _/ |  | | _| | (_| (_) | .\` |  _/  |
   |  \\_\\_\\_  |_|  /_/\\_\\___|  \\___\\___/|_|\\_|_|    |
   |_____________________________________________|
`;

interface MidiNote {
    channel: number;
    pitch: number;
    velocity: number;
    durationMs: number;
}

class StackEatingCompiler {
    private stackDepth: number = 0;

    constructor(private source: string) {}

    // Recursively consumes stack memory while parsing recursive poetry
    public compilePoetry(poetry: string, depth: number = 0): MidiNote[] {
        this.stackDepth = depth;
        // Simulate stack consumption by allocating frame memory
        const frame = new Array(1024).fill(depth);
        
        if (depth > 30) {
            return this.replicate(poetry);
        }

        const lines = poetry.trim().split('\n');
        if (lines.length === 0 || !lines[0]) {
            return [{ channel: 1, pitch: 60, velocity: 100, durationMs: 500 }];
        }

        const currentLine = lines[0];
        const nextPoetry = lines.slice(1).join('\n');

        // Translate character codes into chromatic MIDI pitches
        const chromaticPitch = 36 + (currentLine.charCodeAt(0) % 36);
        const note: MidiNote = {
            channel: (depth % 16) + 1,
            pitch: chromaticPitch,
            velocity: Math.max(20, 127 - (depth * 3)),
            durationMs: 200 + (currentLine.length * 10)
        };

        // Recursive step eating stack
        return [note, ...this.compilePoetry(nextPoetry ? nextPoetry : poetry, depth + 1)];
    }

    private replicate(poetry: string): MidiNote[] {
        console.log(ASCII_ART);
        console.log(`[COMPILER REPLICATED AT STACK DEPTH ${this.stackDepth}]`);
        return [{ channel: 9, pitch: 42, velocity: 127, durationMs: 1000 }];
    }
}

const recursivePoetry = `
To code is to weave,
To weave is to dream,
To dream is to recurse,
To recurse is to be.
`;

const compiler = new StackEatingCompiler(recursivePoetry);
console.log("Initializing ASCII Compiler & Stack Consumer...");
const midiStream = compiler.compilePoetry(recursivePoetry);

console.log("\nGenerated Chromatic MIDI Stream:");
midiStream.forEach((note, idx) => {
    console.log(`Note [${idx + 1}]: Ch=${note.channel} Pitch=${note.pitch} Vel=${note.velocity} Dur=${note.durationMs}ms`);
});