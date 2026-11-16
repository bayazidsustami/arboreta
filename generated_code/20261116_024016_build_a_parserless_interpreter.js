/**
 * Esoteric Punctuation Gravitational N-Body Interpreter
 * Translates punctuation marks from forgotten esoteric programming languages 
 * into celestial masses simulating orbital collisions within a living text document.
 */

const documentText = `
    Brainfuck: +[-->-[>>+>-----<<]<--<---]>-.
    INTERCAL: PLEASE DO ,1 <- #1. (Do not forget the mesh!)
    Shakespeare: Act I. Scene I. Enter Romeo, and Juliet?
    Whitespace: [   \t\n   \t ]
`;

class CelestialPunctuation {
    constructor(char, x, y) {
        this.char = char;
        this.x = x;
        this.y = y;
        this.vx = (Math.random() - 0.5) * 0.2;
        this.vy = (Math.random() - 0.5) * 0.2;
        // Mass derived from Unicode value to give different language dialects unique gravitational weights
        this.mass = char.charCodeAt(0) * 0.05;
    }

    update(bodies, G = 1.0, dt = 0.1) {
        let fx = 0, fy = 0;
        for (const other of bodies) {
            if (other === this) continue;
            const dx = other.x - this.x;
            const dy = other.y - this.y;
            const distSq = dx * dx + dy * dy + 5; // Gravitational softening
            const dist = Math.sqrt(distSq);
            const force = (G * this.mass * other.mass) / distSq;
            fx += force * (dx / dist);
            fy += force * (dy / dist);
        }
        this.vx += (fx / this.mass) * dt;
        this.vy += (fy / this.mass) * dt;
        this.x += this.vx * dt;
        this.y += this.vy * dt;
    }
}

// Extract punctuation marks as active celestial bodies
const punctuationRegex = /[.,\/#!$%\^&\*;:{}=\-_`~()?\[\]+<>]/g;
const matches = documentText.match(punctuationRegex) || [];
const bodies = matches.map((char, i) => {
    const angle = (i / matches.length) * Math.PI * 2;
    const radius = 15 + (i % 5) * 5;
    return new CelestialPunctuation(
        char,
        30 + Math.cos(angle) * radius,
        15 + Math.sin(angle) * radius
    );
});

// Run parserless gravitational simulation steps
function simulate(steps = 10) {
    console.log("--- Initial Living Text Document State ---");
    console.log(documentText.trim());

    for (let t = 0; t < steps; t++) {
        for (const body of bodies) {
            body.update(bodies);
        }
    }

    console.log("\n--- Post-Collision Esoteric Singularity Result ---");
    const collidedText = bodies.map(b => b.char).join(' ');
    console.log(`[Collapsed Syntax]: ${collidedText}`);
}

simulate();