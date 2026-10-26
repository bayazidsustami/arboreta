// Esoteric Compilation Engine: Melancholy Poetry to Magnetic Typographic Constellations
// This script parses melancholic stanzas, maps each character into a node with mass and charge,
// and simulates real-time magnetic field fluctuations (using harmonic Lorentz-like forces) 
// to render shifting typographic constellations in the terminal.

interface Vector3D {
    x: number;
    y: number;
    z: number;
}

interface ConstellationNode {
    char: string;
    pos: Vector3D;
    velocity: Vector3D;
    mass: number;
    charge: number;
}

class MagneticFieldSimulator {
    private time: number = 0;

    // Simulates geomagnetic solar wind and planetary magnetic fluctuations
    public sample(): Vector3D {
        this.time += 0.15;
        return {
            x: Math.sin(this.time * 0.4) * 12 + Math.cos(this.time * 1.1) * 6,
            y: Math.cos(this.time * 0.3) * 8 + Math.sin(this.time * 0.8) * 5,
            z: Math.sin(this.time * 0.2) * 4
        };
    }
}

class MelancholyCompilationEngine {
    private nodes: ConstellationNode[] = [];
    private field: MagneticFieldSimulator;

    constructor(private poem: string[]) {
        this.field = new MagneticFieldSimulator();
        this.compilePoem();
    }

    // Compiles poetry text into physical node structures
    private compilePoem(): void {
        this.poem.forEach((line, lineIdx) => {
            const chars = line.split('');
            chars.forEach((char, charIdx) => {
                if (char === ' ') return;
                this.nodes.push({
                    char,
                    pos: {
                        x: (charIdx - chars.length / 2) * 2,
                        y: (lineIdx - this.poem.length / 2) * 3,
                        z: (Math.random() - 0.5) * 10
                    },
                    velocity: { x: 0, y: 0, z: 0 },
                    mass: (char.charCodeAt(0) % 5) + 1,
                    charge: (char.charCodeAt(0) % 2 === 0 ? 1 : -1) * (Math.random() * 1.5 + 0.5)
                });
            });
        });
    }

    // Advances the physical state driven by magnetic flux
    public tick(): void {
        const B = this.field.sample();
        
        for (const node of this.nodes) {
            // Lorentz force simulation coupled with viscous damping
            const ax = (B.y * node.charge - node.velocity.x * 0.3) / node.mass;
            const ay = (B.x * node.charge - node.velocity.y * 0.3) / node.mass;
            const az = (B.z * node.charge - node.velocity.z * 0.3) / node.mass;

            node.velocity.x += ax * 0.1;
            node.velocity.y += ay * 0.1;
            node.velocity.z += az * 0.1;

            node.pos.x += node.velocity.x;
            node.pos.y += node.velocity.y;
            node.pos.z += node.velocity.z;

            // Restoring spring anchor to maintain poetic silhouette
            node.velocity.x *= 0.92;
            node.velocity.y *= 0.92;
            node.velocity.z *= 0.92;
        }
    }

    // Projects 3D node constellations onto a 2D ASCII viewport
    public render(): string {
        const width = 70;
        const height = 24;
        const grid: string[][] = Array.from({ length: height }, () => Array(width).fill('.'));

        for (const node of this.nodes) {
            const screenX = Math.floor(width / 2 + node.pos.x);
            const screenY = Math.floor(height / 2 + node.pos.y);

            if (screenX >= 0 && screenX < width && screenY >= 0 && screenY < height) {
                // Depth shading based on Z coordinate
                grid[screenY][screenX] = node.char;
            }
        }

        return grid.map(row => row.join('')).join('\n');
    }
}

// Melancholy Source Stanza
const melancholyStanza = [
    "The cold rain whispers on the glass,",
    "Where silent shadows drift and pass.",
    "A fragile heart, a fading light,",
    "Dissolving softly in the night."
];

const engine = new MelancholyCompilationEngine(melancholyStanza);

let frame = 0;
const simulationInterval = setInterval(() => {
    console.clear();
    console.log(`=== MELANCHOLY TYPOGRAPHIC CONSTELLATIONS [Frame ${frame}] ===`);
    console.log('Engine Status: Compiling emotional wavelengths into magnetic vectors...\n');
    
    engine.tick();
    console.log(engine.render());
    
    console.log('\n[Field Flux: Active | Press Ctrl+C to halt]');
    frame++;

    if (frame > 60) {
        clearInterval(simulationInterval);
        console.log('\nCompilation complete. The poetry has returned to the void.');
    }
}, 150);