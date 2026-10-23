LullabyCompressor {
    // Pentatonic scale frequencies (Hz) for soothing lullaby tones (C Major / A Minor pentatonic)
    private static readonly SCALE = [
        261.63, // C4
        293.66, // D4
        329.63, // E4
        392.00, // G4
        440.00, // A4
        523.25, // C5
        587.33, // D5
        659.25  // E5
    ];

    /**
     * Calculates semantic entropy score for a text segment based on unique-to-total word ratio and length.
     */
    private static calculateEntropy(segment: string): number {
        const words = segment.toLowerCase().match(/\b[a-z]+\b/g) || ['silence'];
        const uniqueWords = new Set(words);
        const lexicalDiversity = uniqueWords.size / words.length;
        // Higher diversity and length imply higher "cognitive load" / semantic entropy
        return lexicalDiversity * Math.log(words.length + 1);
    }

    /**
     * Compresses input text into a procedural lullaby script.
     */
    public static encode(inputText: string): { compressedHash: string; notes: LullabyNote[]; metadata: any } {
        // Split text into semantic sentences/chunks
        const chunks = inputText.split(/(?<=[.!?])\s+/).filter(Boolean);
        const fallbackChunks = chunks.length > 0 ? chunks : [inputText];

        let baseTempoMs = 600; // Starting baseline duration per note in ms
        const notes: LullabyNote[] = [];
        let globalSeed = 42;

        for (let i = 0; i < fallbackChunks.length; i++) {
            const chunk = fallbackChunks[i];
            const entropy = this.calculateEntropy(chunk);

            // Entropy degrades tempo: higher entropy makes the lullaby slower and more drawn out
            baseTempoMs += entropy * 120;

            // Seed RNG with character codes of the chunk for deterministic procedural generation
            for (let charIndex = 0; charIndex < chunk.length; charIndex++) {
                globalSeed += chunk.charCodeAt(charIndex);
            }
            const rng = new SeededRNG(globalSeed);

            // Map chunk characters to procedural notes
            const noteCount = Math.max(2, Math.min(8, chunk.length));
            for (let n = 0; n < noteCount; n++) {
                const scaleIndex = Math.floor(rng.next() * this.SCALE.length);
                const frequency = this.SCALE[scaleIndex];
                
                // Duration stretches as entropy degrades the tempo
                const durationMs = Math.round(baseTempoMs * (0.8 + rng.next() * 0.4));
                const volume = Number((0.3 + (1 / (1 + entropy)) * 0.4).toFixed(2));

                notes.push({
                    frequency,
                    durationMs,
                    volume,
                    annotation: n === 0 ? `[Chunk ${i}: "${chunk.slice(0, 15)}..."]` : ''
                });
            }

            // Rest / pause between sentences
            notes.push({
                frequency: 0,
                durationMs: Math.round(baseTempoMs * 1.5),
                volume: 0,
                annotation: '[Rest]'
            });
        }

        // Generate a compact esoteric hash representation
        const compressedHash = Buffer.from(JSON.stringify(notes)).toString('base64');

        return {
            compressedHash,
            notes,
            metadata: {
                totalChunks: fallbackChunks.length,
                totalNotes: notes.length,
                finalTempoMs: baseTempoMs
            }
        };
    }

    /**
     * Reconstructs pseudo-text outline from the lullaby notes (lossy semantic decompression).
     */
    public static decode(notes: LullabyNote[]): string {
        // Rebuilds an ambient summary of the compressed cadence
        return notes
            .filter(n => n.annotation && n.annotation.includes('Chunk'))
            .map(n => n.annotation)
            .join(' ~ ');
    }
}

// Execution and Verification
const sampleProse = `
    The quick brown fox jumps over the lazy dog. 
    In the quiet twilight, ancient algorithms hum softly to themselves, 
    weaving dreams out of silicon and starlight. Sleep, little process, sleep.
`;

console.log('=== ESOTERIC LULLABY COMPRESSION ALGORITHM ===\n');
console.log('Original Text Length:', sampleProse.length, 'characters\n');

const result = LullabyCompressor.encode(sampleProse);

console.log('--- COMPRESSION METRICS ---');
console.log('Metadata:', JSON.stringify(result.metadata, null, 2));
console.log('Compressed Esoteric Hash (Base64):');
console.log(result.compressedHash.slice(0, 80) + '... [truncated]\n');

console.log('--- SAMPLE PROCEDURAL LULLABY SCORE (First 5 notes) ---');
console.log(result.notes.slice(0, 5));

const reconstructed = LullabyCompressor.decode(result.notes);
console.log('\n--- DECOMPRESSED SEMANTIC OUTLINE ---');
console.log(reconstructed);