// Cat Neural Waveform to ASCII Nebula Compiler & Simulator
// Simulates a sleeping cat's brainwaves (purrs, REM, slow-wave sleep) 
// and compiles them into a collapsing nebula particle simulation.

interface Particle {
    x: number;
    y: number;
    vx: number;
    vy: number;
    char: string;
    mass: number;
}

class CatNeuralCompiler {
    private frequency: number;
    private amplitude: number;
    private phase: number;

    constructor(seed: number = 42) {
        this.frequency = seed * 0.1;
        this.amplitude = 5.0;
        this.phase = 0;
    }

    // Generates a mock neural waveform sample (representing purr/REM spikes)
    public nextWaveformSample(): number {
        this.phase += 0.2;
        // Combines low-frequency delta waves with high-frequency REM spikes
        return Math.sin(this.phase * this.frequency) * this.amplitude + 
               (Math.random() > 0.85 ? (Math.random() * 10 - 5) : 0);
    }

    // Compiles waveform data into nebula particles
    public compileToNebula(count: number, width: number, height: number): Particle[] {
        const particles: Particle[] = [];
        const chars = ['.', ':', '*', 'o', 'O', '#', '@', '≈', '•'];
        const centerX = width / 2;
        const centerY = height / 2;

        for (let i = 0; i < count; i++) {
            const waveValue = this.nextWaveformSample();
            // Distance from center influenced by neural waveform amplitude
            const angle = Math.random() * Math.PI * 2;
            const distance = (Math.random() * 0.4 + 0.1) * Math.min(width, height) + waveValue;
            
            const x = centerX + Math.cos(angle) * distance;
            const y = centerY + Math.sin(angle) * (distance * 0.5); // Aspect ratio fix for terminal fonts
            
            // Initial velocities pointing toward the center (collapsing nebula)
            const speed = 0.05 + Math.abs(waveValue) * 0.02;
            const vx = (centerX - x) * speed * 0.05;
            const vy = (centerY - y) * speed * 0.05;

            const charIndex = Math.floor(Math.abs(waveValue) * 0.5) % chars.length;

            particles.push({
                x,
                y,
                vx,
                vy,
                char: chars[charIndex] || '*',
                mass: Math.abs(waveValue) + 1
            });
        }

        return particles;
    }
}

class NebulaSimulator {
    private width: number;
    private height: number;
    private particles: Particle[];
    private compiler: CatNeuralCompiler;

    constructor(width: number = 60, height: number = 25) {
        this.width = width;
        this.height = height;
        this.compiler = new CatNeuralCompiler(Math.random() * 100);
        this.particles = this.compiler.compileToNebula(150, width, height);
    }

    public update(): void {
        const centerX = this.width / 2;
        const centerY = this.height / 2;

        for (let p of this.particles) {
            // Gravitational pull towards center
            const dx = centerX - p.x;
            const dy = centerY - p.y;
            const distSq = dx * dx + dy * dy + 1;
            
            const force = (0.5 * p.mass) / distSq;
            p.vx += dx * force * 0.02;
            p.vy += dy * force * 0.02;

            // Apply friction/damping
            p.vx *= 0.98;
            p.vy *= 0.98;

            p.x += p.vx;
            p.y += p.vy;

            // Recycle particles that collapse into the center
            if (Math.abs(dx) < 1 && Math.abs(dy) < 1) {
                const angle = Math.random() * Math.PI * 2;
                const distance = Math.min(this.width, this.height) * 0.4;
                p.x = centerX + Math.cos(angle) * distance;
                p.y = centerY + Math.sin(angle) * (distance * 0.5);
                p.vx = (Math.random() - 0.5) * 0.2;
                p.vy = (Math.random() - 0.5) * 0.2;
            }
        }
    }

    public render(): string {
        // Initialize grid with blank spaces
        const grid: string[][] = Array.from({ length: this.height }, () => 
            Array.from({ length: this.width }, () => ' ')
        );

        // Place particles
        for (let p of this.particles) {
            const ix = Math.round(p.x);
            const iy = Math.round(p.y);
            if (ix >= 0 && ix < this.width && iy >= 0 && iy < this.height) {
                grid[iy][ix] = p.char;
            }
        }

        // Add center singularity core
        const coreX = Math.floor(this.width / 2);
        const coreY = Math.floor(this.height / 2);
        if (coreY >= 0 && coreY < this.height && coreX >= 0 && coreX < this.width) {
            grid[coreY][coreX] = '◎';
        }

        return grid.map(row => row.join('')).join('\n');
    }

    public run(frames: number = 100): void {
        let frameCount = 0;
        const interval = setInterval(() => {
            console.clear();
            console.log("=== SLEEPING CAT NEURAL NEBULA COMPILER ===");
            console.log(`Frame: ${frameCount}/${frames} | Translating Purr/REM Waveforms...`);
            console.log(this.render());
            
            this.update();
            frameCount++;

            if (frameCount >= frames) {
                clearInterval(interval);
                console.log("\n[Compilation Complete]: Nebula successfully collapsed into cat dreamscape singularity.");
            }
        }, 100);
    }
}

// Execute simulation
const simulator = new NebulaSimulator(60, 24);
simulator.run(150);