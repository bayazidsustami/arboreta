import * as fs from 'fs';
import * as http from 'http';
import * as os from 'os';

/**
 * Real-Time Digital Ecosystem: Dynamic SVG Calligraphic Brushstrokes
 * Ingests system CPU temperature fluctuations or electromagnetic/system noise
 * to drive thread mutation, reproduction, decay, and SVG brushstroke rendering.
 */

interface Point {
  x: number;
  y: number;
}

class ThreadEntity {
  public id: string;
  public energy: number;
  public path: Point[];
  public angle: number;
  public speed: number;
  public strokeWidth: number;
  public hue: number;
  public curvature: number;

  constructor(x: number, y: number, hue?: number) {
    this.id = Math.random().toString(36).substring(2, 9);
    this.energy = 1.0; // Life energy from 1.0 down to 0.0
    this.path = [{ x, y }];
    this.angle = Math.random() * Math.PI * 2;
    this.speed = 2 + Math.random() * 3;
    this.strokeWidth = 10 + Math.random() * 15;
    this.hue = hue ?? Math.floor(Math.random() * 360);
    this.curvature = (Math.random() - 0.5) * 0.2;
  }

  // Mutate organism based on environmental temperature/noise inputs
  public mutate(entropySignal: number, width: number, height: number): void {
    const lastPoint = this.path[this.path.length - 1];

    // System noise alters trajectory, stroke width, and curvature
    this.angle += this.curvature + (entropySignal - 0.5) * 0.5;
    this.speed = Math.max(1, this.speed + (entropySignal - 0.5) * 1.5);
    this.strokeWidth = Math.max(2, this.strokeWidth + (entropySignal - 0.5) * 2);
    this.hue = (this.hue + entropySignal * 10) % 360;

    // Calculate next calligraphic position
    let nextX = lastPoint.x + Math.cos(this.angle) * this.speed;
    let nextY = lastPoint.y + Math.sin(this.angle) * this.speed;

    // Toroidal wrap around canvas boundaries
    if (nextX < 0) nextX = width;
    if (nextX > width) nextX = 0;
    if (nextY < 0) nextY = height;
    if (nextY > height) nextY = 0;

    this.path.push({ x: nextX, y: nextY });

    // Organic decay
    this.energy -= 0.015 + (1 - entropySignal) * 0.01;
  }

  // Reproduce offspring thread when energy and environmental noise permit
  public reproduce(entropySignal: number): ThreadEntity | null {
    if (this.energy > 0.6 && entropySignal > 0.65 && Math.random() < 0.2) {
      this.energy -= 0.3;
      const lastPoint = this.path[this.path.length - 1];
      const child = new ThreadEntity(lastPoint.x, lastPoint.y, (this.hue + 20) % 360);
      child.angle = this.angle + (Math.random() - 0.5);
      return child;
    }
    return null;
  }

  // Express thread trajectory as a smooth SVG calligraphic path
  public toSVGPath(): string {
    if (this.path.length < 2) return '';

    let d = `M ${this.path[0].x.toFixed(1)} ${this.path[0].y.toFixed(1)}`;
    for (let i = 1; i < this.path.length - 1; i++) {
      const xc = (this.path[i].x + this.path[i + 1].x) / 2;
      const yc = (this.path[i].y + this.path[i + 1].y) / 2;
      d += ` Q ${this.path[i].x.toFixed(1)} ${this.path[i].y.toFixed(1)}, ${xc.toFixed(1)} ${yc.toFixed(1)}`;
    }

    const opacity = Math.max(0, this.energy).toFixed(2);
    const color = `hsla(${Math.floor(this.hue)}, 70%, 50%, ${opacity})`;
    
    return `<path d="${d}" fill="none" stroke="${color}" stroke-width="${this.strokeWidth.toFixed(1)}" stroke-linecap="round" stroke-linejoin="round" />`;
  }
}

class SystemNoiseIngestor {
  // Reads physical CPU core temp or falls back to microsecond system noise
  public async getEntropySignal(): Promise<number> {
    try {
      if (process.platform === 'linux') {
        const thermalData = fs.readFileSync('/sys/class/thermal/thermal_zone0/temp', 'utf8');
        const milliC = parseInt(thermalData.trim(), 10);
        const celsius = milliC / 1000;
        // Normalize 30C - 80C to [0.0, 1.0]
        return Math.min(1, Math.max(0, (celsius - 30) / 50));
      }
    } catch {
      // Fallback: capture CPU load fluctuations across cores
    }

    const cpus = os.cpus();
    let totalIdle = 0;
    let totalTick = 0;
    for (const cpu of cpus) {
      for (const type in cpu.times) {
        totalTick += (cpu.times as Record<string, number>)[type];
      }
      totalIdle += cpu.times.idle;
    }
    const noise = (Math.sin(totalTick * 0.0001) + 1) / 2;
    return noise;
  }
}

class EcosystemServer {
  private threads: ThreadEntity[] = [];
  private ingestor = new SystemNoiseIngestor();
  private width = 1200;
  private height = 800;

  constructor() {
    this.seed();
  }

  private seed(): void {
    for (let i = 0; i < 8; i++) {
      this.threads.push(new ThreadEntity(Math.random() * this.width, Math.random() * this.height));
    }
  }

  public async step(): Promise<string> {
    const entropy = await this.ingestor.getEntropySignal();
    const newThreads: ThreadEntity[] = [];

    // Evolve living threads
    for (const thread of this.threads) {
      thread.mutate(entropy, this.width, this.height);
      const child = thread.reproduce(entropy);
      if (child) newThreads.push(child);
    }

    this.threads.push(...newThreads);

    // Filter out decayed threads
    this.threads = this.threads.filter((t) => t.energy > 0);

    // Re-seed if ecosystem faces extinction
    if (this.threads.length === 0) {
      this.seed();
    }

    // Render ecosystem into live SVG
    const pathsSVG = this.threads.map((t) => t.toSVGPath()).join('\n');
    return `<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 ${this.width} ${this.height}" style="background:#0a0a10; width:100%; height:100vh;">
      <defs>
        <filter id="glow">
          <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
          <feMerge>
            <feMergeNode in="coloredBlur"/>
            <feMergeNode in="SourceGraphic"/>
          </feMerge>
        </filter>
      </defs>
      <g filter="url(#glow)">
        ${pathsSVG}
      </g>
    </svg>`;
  }

  public startServer(port = 3000): void {
    http.createServer(async (req, res) => {
      if (req.url === '/stream') {
        res.writeHead(200, {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        });

        const interval = setInterval(async () => {
          const svg = await this.step();
          const payload = svg.replace(/\n/g, '');
          res.write(`data: ${payload}\n\n`);
        }, 50);

        req.on('close', () => clearInterval(interval));
      } else {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(`
          <!Timeline html>
          <html>
            <head>
              <title>Decaying Digital Ecosystem</title>
              <style>body { margin: 0; background: #0a0a10; overflow: hidden; }</style>
            </head>
            <body>
              <div id="canvas"></div>
              <script>
                const evtSource = new EventSource('/stream');
                const container = document.getElementById('canvas');
                evtSource.onmessage = (e) => {
                  container.innerHTML = e.data;
                };
              </script>
            </body>
          </html>
        `);
      }
    }).listen(port, () => {
      console.log(`Live Calligraphic Ecosystem running at http://localhost:${port}`);
    });
  }
}

new EcosystemServer().startServer(3000);