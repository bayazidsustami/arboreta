const canvas = document.createElement('canvas');
document.body.appendChild(canvas);
document.body.style.margin = '0';
document.body.style.overflow = 'hidden';
document.body.style.backgroundColor = '#02050e';

const ctx = canvas.getContext('2d');
let width, height;

function resize() {
  width = canvas.width = window.innerWidth;
  height = canvas.height = window.innerHeight;
}
window.addEventListener('resize', resize);
resize();

// Deep-sea bioluminescent organisms bound to runtime heap states
const creatures = [];
let lastHeapUsed = 0;
let heapHistory = [];

// Heap-churn generator: Creates transient object allocations to drive dynamic V8 memory movement
const memoryLeakSink = [];
function simulateHeapActivity() {
  const size = Math.floor(Math.random() * 500) + 100;
  const chunk = new Array(size).fill(0).map(() => ({
    id: Math.random(),
    timestamp: Date.now(),
    payload: new Float64Array(100)
  }));
  
  if (Math.random() < 0.7) {
    memoryLeakSink.push(chunk);
    if (memoryLeakSink.length > 50) memoryLeakSink.shift();
  }
}

class Jellyfish {
  constructor(x, y, memoryWeight) {
    this.x = x;
    this.y = y;
    this.baseRadius = Math.min(Math.max(memoryWeight / 100000, 10), 45);
    this.radius = this.baseRadius;
    this.vx = (Math.random() - 0.5) * 0.8;
    this.vy = -Math.random() * 0.8 - 0.3;
    this.pulse = Math.random() * Math.PI * 2;
    this.hue = 170 + Math.random() * 50; // Deep ocean cyans & blues
    this.life = 1.0;
    this.isGCVictim = false;
  }

  update(gcOccurred) {
    this.pulse += 0.04;
    this.x += this.vx + Math.sin(this.pulse) * 0.5;
    this.y += this.vy + Math.cos(this.pulse * 0.5) * 0.2;

    if (gcOccurred) {
      this.isGCVictim = true;
    }

    if (this.isGCVictim) {
      this.life -= 0.02;
      this.hue = 340; // Shift to bioluminescent shock pink/crimson on sweep
    }

    // Wrap horizontally
    if (this.x < -50) this.x = width + 50;
    if (this.x > width + 50) this.x = -50;
  }

  draw(ctx) {
    ctx.save();
    ctx.globalCompositeOperation = 'screen';
    
    const glowRadius = this.radius * 2.5;
    const gradient = ctx.createRadialGradient(
      this.x, this.y, 0,
      this.x, this.y, glowRadius
    );
    
    const alpha = Math.max(0, this.life);
    gradient.addColorStop(0, `hsla(${this.hue}, 100%, 75%, ${alpha * 0.8})`);
    gradient.addColorStop(0.4, `hsla(${this.hue}, 90%, 40%, ${alpha * 0.3})`);
    gradient.addColorStop(1, `hsla(${this.hue}, 100%, 10%, 0)`);

    // Draw Pulsing Cap
    ctx.fillStyle = gradient;
    ctx.beginPath();
    const currentR = this.radius + Math.sin(this.pulse) * 3;
    ctx.arc(this.x, this.y, currentR, Math.PI, 0, false);
    ctx.quadraticCurveTo(this.x, this.y + currentR * 0.7, this.x - currentR, this.y);
    ctx.fill();

    // Draw Bioluminescent Tentacles
    ctx.strokeStyle = `hsla(${this.hue}, 100%, 80%, ${alpha * 0.5})`;
    ctx.lineWidth = 1.5;
    const tentacles = 5;
    for (let i = 0; i < tentacles; i++) {
      const tx = this.x - currentR + (i * (currentR * 2 / (tentacles - 1)));
      ctx.beginPath();
      ctx.moveTo(tx, this.y);
      ctx.bezierCurveTo(
        tx + Math.sin(this.pulse + i) * 10, this.y + currentR * 1.5,
        tx - Math.cos(this.pulse + i) * 10, this.y + currentR * 2.5,
        tx + Math.sin(this.pulse) * 5, this.y + currentR * 3.5
      );
      ctx.stroke();
    }

    ctx.restore();
  }
}

// Particle system representing freed memory energy sweeps
const gcParticles = [];
function triggerGCSweepEffect(freedAmount) {
  const particleCount = Math.min(Math.floor(freedAmount / 50000) + 20, 200);
  for (let i = 0; i < particleCount; i++) {
    gcParticles.push({
      x: Math.random() * width,
      y: height + 20,
      vx: (Math.random() - 0.5) * 4,
      vy: -Math.random() * 8 - 3,
      size: Math.random() * 3 + 1,
      hue: 280 + Math.random() * 60, // Electric violet sweep
      life: 1.0
    });
  }
}

function render() {
  simulateHeapActivity();

  // Read browser process heap memory (Performance API)
  const memory = window.performance && window.performance.memory ? 
    window.performance.memory : 
    { usedJSHeapSize: 20000000 + Math.sin(Date.now() * 0.001) * 5000000, totalJSHeapSize: 50000000 };

  const usedHeap = memory.usedJSHeapSize;
  const heapDelta = usedHeap - lastHeapUsed;
  const isGC = heapDelta < -50000; // Sharp drop indicates garbage collection sweep

  if (isGC) {
    triggerGCSweepEffect(Math.abs(heapDelta));
  }

  // Spawn bioluminescent entity on memory allocation
  if (heapDelta > 0 && Math.random() < 0.6) {
    creatures.push(new Jellyfish(
      Math.random() * width,
      height + 50,
      heapDelta
    ));
  }

  // Deep ocean background clearing with subtle motion blur trail
  ctx.fillStyle = 'rgba(2, 5, 14, 0.25)';
  ctx.fillRect(0, 0, width, height);

  // Update and render organisms
  for (let i = creatures.length - 1; i >= 0; i--) {
    const c = creatures[i];
    c.update(isGC);
    c.draw(ctx);

    if (c.y < -100 || c.life <= 0) {
      creatures.splice(i, 1);
    }
  }

  // Update and render GC energy sweep particles
  ctx.save();
  ctx.globalCompositeOperation = 'screen';
  for (let i = gcParticles.length - 1; i >= 0; i--) {
    const p = gcParticles[i];
    p.x += p.vx;
    p.y += p.vy;
    p.life -= 0.015;

    ctx.fillStyle = `hsla(${p.hue}, 100%, 75%, ${Math.max(0, p.life)})`;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
    ctx.fill();

    if (p.life <= 0) gcParticles.splice(i, 1);
  }
  ctx.restore();

  // Render Live Heap Dashboard HUD
  heapHistory.push(usedHeap);
  if (heapHistory.length > 100) heapHistory.shift();

  ctx.fillStyle = 'rgba(10, 255, 200, 0.75)';
  ctx.font = '12px monospace';
  ctx.fillText(`LIVE HEAP: ${(usedHeap / 1048576).toFixed(2)} MB`, 20, 30);
  ctx.fillText(`ORGANISMS (ALLOCS): ${creatures.length}`, 20, 48);
  if (isGC) {
    ctx.fillStyle = 'rgba(255, 50, 150, 0.9)';
    ctx.fillText(`[GC SWEEP DETECTED: ${(Math.abs(heapDelta) / 1048576).toFixed(2)} MB FREED]`, 20, 66);
  }

  // Draw miniature heap topology wave
  ctx.beginPath();
  ctx.strokeStyle = 'rgba(10, 255, 200, 0.3)';
  ctx.lineWidth = 1.5;
  const graphWidth = 150;
  const graphHeight = 30;
  const graphX = 20;
  const graphY = 110;

  const minHeap = Math.min(...heapHistory);
  const maxHeap = Math.max(...heapHistory) || 1;

  for (let i = 0; i < heapHistory.length; i++) {
    const normY = (heapHistory[i] - minHeap) / (maxHeap - minHeap || 1);
    const x = graphX + (i / 100) * graphWidth;
    const y = graphY - normY * graphHeight;
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.stroke();

  lastHeapUsed = usedHeap;
  requestAnimationFrame(render);
}

render();