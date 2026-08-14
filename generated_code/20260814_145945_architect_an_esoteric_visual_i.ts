// Atmospheric Quantum Mandala Visual Interpreter
// Continuously simulates a 6-qubit quantum circuit and renders its Hilbert state space 
// as an atmospheric mandala. Symmetrical petals implode upon qubit measurement events.

interface Complex { re: number; im: number; }
interface Particle { x: number; y: number; vx: number; vy: number; life: number; color: string; size: number; }

class QuantumCircuit {
  readonly numQubits: number;
  readonly dim: number;
  state: Complex[];

  constructor(numQubits: number = 6) {
    this.numQubits = numQubits;
    this.dim = 1 << numQubits;
    this.state = Array.from({ length: this.dim }, (_, i) => ({ re: i === 0 ? 1 : 0, im: 0 }));
  }

  apply1QubitGate(target: number, matrix: [[Complex, Complex], [Complex, Complex]]): void {
    const nextState = Array.from({ length: this.dim }, () => ({ re: 0, im: 0 }));
    for (let i = 0; i < this.dim; i++) {
      if (((i >> target) & 1) === 0) {
        const j = i | (1 << target);
        const a = this.state[i], b = this.state[j];
        nextState[i] = {
          re: matrix[0][0].re * a.re - matrix[0][0].im * a.im + matrix[0][1].re * b.re - matrix[0][1].im * b.im,
          im: matrix[0][0].re * a.im + matrix[0][0].im * a.re + matrix[0][1].re * b.im + matrix[0][1].im * b.re
        };
        nextState[j] = {
          re: matrix[1][0].re * a.re - matrix[1][0].im * a.im + matrix[1][1].re * b.re - matrix[1][1].im * b.im,
          im: matrix[1][0].re * a.im + matrix[1][0].im * a.re + matrix[1][1].re * b.im + matrix[1][1].im * b.re
        };
      }
    }
    this.state = nextState;
  }

  hadamard(target: number): void {
    const invSqrt2 = 1 / Math.SQRT2;
    this.apply1QubitGate(target, [
      [{ re: invSqrt2, im: 0 }, { re: invSqrt2, im: 0 }],
      [{ re: invSqrt2, im: 0 }, { re: -invSqrt2, im: 0 }]
    ]);
  }

  phaseShift(target: number, theta: number): void {
    this.apply1QubitGate(target, [
      [{ re: 1, im: 0 }, { re: 0, im: 0 }],
      [{ re: 0, im: 0 }, { re: Math.cos(theta), im: Math.sin(theta) }]
    ]);
  }

  measure(target: number): { result: number; prob: number } {
    let zeroProb = 0;
    for (let i = 0; i < this.dim; i++) {
      if (((i >> target) & 1) === 0) {
        zeroProb += this.state[i].re ** 2 + this.state[i].im ** 2;
      }
    }
    const result = Math.random() < zeroProb ? 0 : 1;
    const norm = Math.sqrt(result === 0 ? zeroProb : 1 - zeroProb) || 1;

    for (let i = 0; i < this.dim; i++) {
      if (((i >> target) & 1) === result) {
        this.state[i].re /= norm;
        this.state[i].im /= norm;
      } else {
        this.state[i] = { re: 0, im: 0 };
      }
    }
    return { result, prob: result === 0 ? zeroProb : 1 - zeroProb };
  }
}

class MandalaInterpreter {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private circuit: QuantumCircuit;
  private collapseFactor: number = 0;
  private collapseOrigin: { x: number; y: number } = { x: 0, y: 0 };
  private particles: Particle[] = [];
  private frameCount: number = 0;

  constructor() {
    this.canvas = document.createElement('canvas');
    document.body.appendChild(this.canvas);
    document.body.style.margin = '0';
    document.body.style.overflow = 'hidden';
    document.body.style.backgroundColor = '#030308';
    
    this.ctx = this.canvas.getContext('2d')!;
    this.circuit = new QuantumCircuit(6);
    this.resize();
    window.addEventListener('resize', () => this.resize());

    // Initialize initial state superposition
    for (let q = 0; q < 6; q++) this.circuit.hadamard(q);

    this.loop();
  }

  private resize(): void {
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
  }

  private triggerMeasurement(): void {
    const targetQubit = Math.floor(Math.random() * this.circuit.numQubits);
    this.circuit.measure(targetQubit);
    this.collapseFactor = 1.0;
    
    // Spawn collapse impact shockwave particles
    const cx = this.canvas.width / 2;
    const cy = this.canvas.height / 2;
    for (let i = 0; i < 150; i++) {
      const angle = Math.random() * Math.PI * 2;
      const speed = Math.random() * 8 + 2;
      this.particles.push({
        x: cx,
        y: cy,
        vx: Math.cos(angle) * speed,
        vy: Math.sin(angle) * speed,
        life: 1.0,
        color: `hsl(${280 + Math.random() * 60}, 100%, 75%)`,
        size: Math.random() * 3 + 1
      });
    }
  }

  private stepQuantumDynamics(): void {
    this.frameCount++;
    const q = this.frameCount % 6;
    this.circuit.phaseShift(q, 0.05 * (q + 1));

    if (this.frameCount % 120 === 0) {
      this.circuit.hadamard(Math.floor(Math.random() * 6));
    }
    if (this.frameCount % 180 === 0) {
      this.triggerMeasurement();
    }
  }

  private drawMandalaPetals(cx: number, cy: number, maxRadius: number): void {
    const state = this.circuit.state;
    const totalPetals = state.length;
    const angleStep = (Math.PI * 2) / totalPetals;
    
    // Decay measurement collapse shockwave effect
    this.collapseFactor *= 0.94;

    for (let i = 0; i < totalPetals; i++) {
      const amp = Math.sqrt(state[i].re ** 2 + state[i].im ** 2);
      const phase = Math.atan2(state[i].im, state[i].re);
      if (amp < 0.001) continue;

      const baseAngle = i * angleStep + this.frameCount * 0.002;
      const petalLen = amp * maxRadius * (1 - this.collapseFactor * 0.7);
      const hue = (phase * (180 / Math.PI) + 360 + this.frameCount) % 360;

      this.ctx.save();
      this.ctx.translate(cx, cy);
      this.ctx.rotate(baseAngle);

      // Atmospheric glow gradient for quantum state amplitude
      const grad = this.ctx.createRadialGradient(0, 0, 2, 0, petalLen, petalLen * 0.4);
      grad.addColorStop(0, `hsla(${hue}, 90%, 65%, ${amp * 0.8})`);
      grad.addColorStop(0.6, `hsla(${(hue + 40) % 360}, 80%, 45%, ${amp * 0.4})`);
      grad.addColorStop(1, `hsla(${hue}, 100%, 10%, 0)`);

      // Symmetrical petal geometry
      this.ctx.beginPath();
      this.ctx.moveTo(0, 0);
      this.ctx.quadraticCurveTo(petalLen * 0.3, petalLen * 0.5, 0, petalLen);
      this.ctx.quadraticCurveTo(-petalLen * 0.3, petalLen * 0.5, 0, 0);
      this.ctx.fillStyle = grad;
      this.ctx.fill();

      // Intricate interference overlay lines
      this.ctx.strokeStyle = `hsla(${hue}, 100%, 85%, ${amp * 0.6})`;
      this.ctx.lineWidth = 1;
      this.ctx.stroke();

      this.ctx.restore();
    }
  }

  private updateParticles(): void {
    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.vx *= 0.96;
      p.vy *= 0.96;
      p.life -= 0.02;

      if (p.life <= 0) {
        this.particles.splice(i, 1);
        continue;
      }

      this.ctx.beginPath();
      this.ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      this.ctx.fillStyle = p.color;
      this.ctx.globalAlpha = p.life;
      this.ctx.fill();
      this.ctx.globalAlpha = 1.0;
    }
  }

  private loop = (): void => {
    this.stepQuantumDynamics();

    // Fade background to create ethereal motion trails
    this.ctx.fillStyle = 'rgba(3, 3, 8, 0.15)';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    const cx = this.canvas.width / 2;
    const cy = this.canvas.height / 2;
    const maxRadius = Math.min(cx, cy) * 0.8;

    this.drawMandalaPetals(cx, cy, maxRadius);
    this.updateParticles();

    requestAnimationFrame(this.loop);
  };
}

// Instantiate interpreter on load
if (typeof window !== 'undefined') {
  window.addEventListener('DOMContentLoaded', () => new MandalaInterpreter());
}