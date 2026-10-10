// Orbital Mechanics Bytecode Virtual Machine in TypeScript

interface Vector2D {
    x: number;
    y: number;
}

interface CelestialBody {
    id: number;
    name: string;
    mass: number;
    pos: Vector2D;
    vel: Vector2D;
    radius: number;
}

enum OpCode {
    HALT = 0x00,
    SPAWN = 0x01,
    BURN = 0x02,
    SIM_STEP = 0x03,
    PRINT_STATE = 0x04
}

interface Instruction {
    op: OpCode;
    args: number[];
}

class OrbitalVM {
    private bodies: CelestialBody[] = [];
    private pc: number = 0;
    private halted: boolean = false;
    private G: number = 1.0; // Gravitational constant for our universe

    constructor(private program: Instruction[]) {}

    public run(): void {
        console.log("--- Starting Orbital VM Execution ---");
        while (!this.halted && this.pc < this.program.length) {
            const instr = this.program[this.pc];
            this.execute(instr);
            if (this.halted) break;
            
            // Check for celestial collisions after every instruction cycle
            if (this.checkCollisions()) {
                console.log("\n[CATACLYSM] Celestial collision detected! VM execution halted.");
                this.halted = true;
                break;
            }
            this.pc++;
        }
        console.log("--- VM Execution Terminated ---");
    }

    private execute(instr: Instruction): void {
        switch (instr.op) {
            case OpCode.HALT:
                this.halted = true;
                break;
            case OpCode.SPAWN: {
                // args: [id, mass, posX, posY, velX, velY, radius]
                const [id, mass, px, py, vx, vy, radius] = instr.args;
                this.bodies.push({
                    id,
                    name: `Body_${id}`,
                    mass,
                    pos: { x: px, y: py },
                    vel: { x: vx, y: vy },
                    radius
                });
                break;
            }
            case OpCode.BURN: {
                // args: [id, dVx, dVy] (apply orbital impulse)
                const [id, dvx, dvy] = instr.args;
                const body = this.bodies.find(b => b.id === id);
                if (body) {
                    body.vel.x += dvx;
                    body.vel.y += dvy;
                }
                break;
            }
            case OpCode.SIM_STEP: {
                // args: [steps, dt]
                const steps = instr.args[0] || 1;
                const dt = instr.args[1] || 0.1;
                for (let s = 0; s < steps; s++) {
                    this.stepPhysics(dt);
                    if (this.checkCollisions()) {
                        this.halted = true;
                        return;
                    }
                }
                break;
            }
            case OpCode.PRINT_STATE:
                this.printState();
                break;
            default:
                throw new Error(`Unknown opcode: ${instr.op}`);
        }
    }

    private stepPhysics(dt: number): void {
        const n = this.bodies.length;
        const forces: Vector2D[] = this.bodies.map(() => ({ x: 0, y: 0 }));

        // Calculate N-body gravitational forces
        for (let i = 0; i < n; i++) {
            for (let j = i + 1; j < n; j++) {
                const b1 = this.bodies[i];
                const b2 = this.bodies[j];
                const dx = b2.pos.x - b1.pos.x;
                const dy = b2.pos.y - b1.pos.y;
                const distSq = dx * dx + dy * dy;
                const dist = Math.sqrt(distSq);

                if (dist === 0) continue;

                // F = G * (m1 * m2) / r^2
                const forceMag = (this.G * b1.mass * b2.mass) / distSq;
                const fx = forceMag * (dx / dist);
                const fy = forceMag * (dy / dist);

                forces[i].x += fx;
                forces[i].y += fy;
                forces[j].x -= fx;
                forces[j].y -= fy;
            }
        }

        // Update velocities and positions using Euler integration
        for (let i = 0; i < n; i++) {
            const b = this.bodies[i];
            const ax = forces[i].x / b.mass;
            const ay = forces[i].y / b.mass;

            b.vel.x += ax * dt;
            b.vel.y += ay * dt;
            b.pos.x += b.vel.x * dt;
            b.pos.y += b.vel.y * dt;
        }
    }

    private checkCollisions(): boolean {
        const n = this.bodies.length;
        for (let i = 0; i < n; i++) {
            for (let j = i + 1; j < n; j++) {
                const b1 = this.bodies[i];
                const b2 = this.bodies[j];
                const dx = b2.pos.x - b1.pos.x;
                const dy = b2.pos.y - b1.pos.y;
                const dist = Math.sqrt(dx * dx + dy * dy);

                // Collision condition: distance < sum of radii
                if (dist < (b1.radius + b2.radius)) {
                    console.log(`Collision between ${b1.name} (id: ${b1.id}) and ${b2.name} (id: ${b2.id}) at distance ${dist.toFixed(2)}.`);
                    return true;
                }
            }
        }
        return false;
    }

    private printState(): void {
        console.log(`\n--- VM State (PC: ${this.pc}) ---`);
        for (const b of this.bodies) {
            console.log(`[${b.name}] Pos: (${b.pos.x.toFixed(2)}, ${b.pos.y.toFixed(2)}) Vel: (${b.vel.x.toFixed(2)}, ${b.vel.y.toFixed(2)})`);
        }
    }
}

// --- Sample Program ---
const sampleProgram: Instruction[] = [
    // Spawn Central Star (id: 1)
    { op: OpCode.SPAWN, args: [1, 1000, 0, 0, 0, 0, 5] },
    // Spawn Planet Alpha (id: 2) in circular orbit
    { op: OpCode.SPAWN, args: [2, 10, 50, 0, 0, 4.47, 2] },
    // Print initial system state
    { op: OpCode.PRINT_STATE, args: [] },
    // Simulate normal orbital motion for 20 steps
    { op: OpCode.SIM_STEP, args: [20, 0.1] },
    // Print state after stable orbit segment
    { op: OpCode.PRINT_STATE, args: [] },
    // Spawn a Rogue Asteroid (id: 3) on a direct collision course with Planet Alpha
    { op: OpCode.SPAWN, args: [3, 1, 60, 0, -10, 0, 1] },
    // Simulate steps until collision triggers an automatic hardware-level VM halt
    { op: OpCode.SIM_STEP, args: [100, 0.1] },
    // This unreachable instruction will be skipped due to the catastrophic collision halt
    { op: OpCode.PRINT_STATE, args: [] },
    { op: OpCode.HALT, args: [] }
];

const vm = new OrbitalVM(sampleProgram);
vm.run();