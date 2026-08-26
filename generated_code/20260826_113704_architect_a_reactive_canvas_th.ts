import { WebSocketServer, WebSocket } from 'ws';
import { createCanvas, CanvasRenderingContext2D } from 'canvas';
import * as fs from 'fs';
import * as path from 'path';

interface LatencySample {
  timestamp: number;
  ms: number;
  normalized: number; // 0 (fast/stable) to 1 (high latency/jitter)
}

interface Node {
  x: number;
  y: number;
  angle: number;
  length: number;
  thickness: number;
  depth: number;
  maxDepth: number;
  energy: number;
  hue: number;
  children: Node[];
  pulseOffset: number;
}

class ReactiveBioluminescentFlora {
  private width = 1280;
  private height = 720;
  private canvas = createCanvas(this.width, this.height);
  private ctx: CanvasRenderingContext2D = this.canvas.getContext('2d');
  
  private currentLatency = 40;
  private latencyHistory: LatencySample[] = [];
  private roots: Node[] = [];
  private frameCount = 0;

  constructor() {
    this.initRoots();
  }

  private initRoots(): void {
    const rootCount = 5;
    for (let i = 0; i < rootCount; i++) {
      const x = (this.width / (rootCount + 1)) * (i + 1);
      this.roots.push(this.createNode(x, this.height, -Math.PI / 2, 80, 14, 0, 6));
    }
  }

  private createNode(
    x: number, 
    y: number, 
    angle: number, 
    length: number, 
    thickness: number, 
    depth: number, 
    maxDepth: number
  ): Node {
    return {
      x,
      y,
      angle,
      length,
      thickness,
      depth,
      maxDepth,
      energy: Math.random() * 0.5 + 0.5,
      hue: 170 + Math.random() * 50, // Cyan to deep bioluminescent blue/violet
      children: [],
      pulseOffset: Math.random() * Math.PI * 2,
    };
  }

  public updateLatency(ms: number): void {
    this.currentLatency = ms;
    // Normalize latency: 20ms baseline (0.0), 300ms+ high latency (1.0)
    const normalized = Math.min(Math.max((ms - 20) / 280, 0), 1);
    this.latencyHistory.push({ timestamp: Date.now(), ms, normalized });
    if (this.latencyHistory.length > 50) this.latencyHistory.shift();

    // High latency sparks morphogenetic growth
    this.mutateFlora(normalized);
  }

  private mutateFlora(stressFactor: number): void {
    const traverseAndGrow = (node: Node) => {
      // Latency stress increases branching probability and alters angles
      if (node.depth < node.maxDepth && node.children.length === 0) {
        if (Math.random() < 0.2 + stressFactor * 0.5) {
          const branchAngle = 0.3 + stressFactor * 0.4;
          const childLength = node.length * (0.75 - stressFactor * 0.2);
          
          node.children.push(
            this.createNode(
              node.x + Math.cos(node.angle) * node.length,
              node.y + Math.sin(node.angle) * node.length,
              node.angle - branchAngle + (Math.random() - 0.5) * 0.2,
              childLength,
              node.thickness * 0.7,
              node.depth + 1,
              node.maxDepth
            ),
            this.createNode(
              node.x + Math.cos(node.angle) * node.length,
              node.y + Math.sin(node.angle) * node.length,
              node.angle + branchAngle + (Math.random() - 0.5) * 0.2,
              childLength,
              node.thickness * 0.7,
              node.depth + 1,
              node.maxDepth
            )
          );
        }
      }

      // High latency shifts color spectrum towards intense crimson/violet stress hues
      node.hue = (170 + stressFactor * 140) % 360;
      node.children.forEach(traverseAndGrow);
    };

    this.roots.forEach(traverseAndGrow);
  }

  public render(): void {
    this.frameCount++;
    
    // Deep ocean dark translucent wipe for trailing glow effects
    this.ctx.fillStyle = 'rgba(3, 8, 16, 0.25)';
    this.ctx.fillRect(0, 0, this.width, this.height);

    // Draw organically pulsing flora structures
    this.roots.forEach(root => this.renderNode(root));
  }

  private renderNode(node: Node): void {
    const endX = node.x + Math.cos(node.angle) * node.length;
    const endY = node.y + Math.sin(node.angle) * node.length;

    // Organic sway driven by network pulse
    const sway = Math.sin(this.frameCount * 0.03 + node.depth) * (1 + this.currentLatency * 0.01);
    const curvedEndX = endX + sway;

    // Bioluminescent glow pulse calculation
    const pulse = Math.sin(this.frameCount * 0.08 + node.pulseOffset) * 0.5 + 0.5;
    const brightness = 40 + pulse * 40;
    const alpha = 0.6 + pulse * 0.4;

    this.ctx.save();
    this.ctx.beginPath();
    this.ctx.moveTo(node.x, node.y);
    this.ctx.quadraticCurveTo(node.x, node.y - node.length * 0.5, curvedEndX, endY);

    // Outer bioluminescent aura
    this.ctx.strokeStyle = `hsla(${node.hue}, 100%, ${brightness}%, ${alpha * 0.3})`;
    this.ctx.lineWidth = node.thickness * 2.5;
    this.ctx.lineCap = 'round';
    this.ctx.stroke();

    // Inner glowing core
    this.ctx.strokeStyle = `hsla(${node.hue}, 90%, ${brightness + 20}%, ${alpha})`;
    this.ctx.lineWidth = node.thickness;
    this.ctx.stroke();
    this.ctx.restore();

    // Render luminous spores/blooms at terminal tips
    if (node.children.length === 0) {
      const bloomRadius = (3 + pulse * 4) * (1 + (this.currentLatency / 100));
      this.ctx.save();
      this.ctx.beginPath();
      this.ctx.arc(curvedEndX, endY, bloomRadius, 0, Math.PI * 2);
      this.ctx.fillStyle = `hsla(${node.hue + 30}, 100%, 75%, ${alpha})`;
      this.ctx.shadowColor = `hsla(${node.hue}, 100%, 50%, 1)`;
      this.ctx.shadowBlur = 15;
      this.ctx.fill();
      this.ctx.restore();
    }

    // Recursively render branches
    node.children.forEach(child => {
      child.x = curvedEndX;
      child.y = endY;
      this.renderNode(child);
    });
  }

  public exportFrame(filePath: string): void {
    const buffer = this.canvas.toBuffer('image/png');
    fs.writeFileSync(filePath, buffer);
  }
}

// Setup real-time WebSocket telemetry server and client simulator
const PORT = 8080;
const wss = new WebSocketServer({ port: PORT });
const flora = new ReactiveBioluminescentFlora();

wss.on('connection', (ws: WebSocket) => {
  console.log('[Network] Client connected. Streaming latency pulses...');

  // Ping-pong latency sampler
  const interval = setInterval(() => {
    const start = Date.now();
    ws.ping(() => {
      const rtt = Date.now() - start;
      // Inject simulated spikes to mirror chaotic network conditions
      const jitter = Math.random() > 0.85 ? Math.random() * 250 : 0;
      const effectiveLatency = rtt + jitter;
      
      flora.updateLatency(effectiveLatency);
      flora.render();
      
      console.log(`[Ping] RTT: ${effectiveLatency.toFixed(1)}ms | Organism Mutated`);
    });
  }, 200);

  ws.on('close', () => clearInterval(interval));
});

// Self-connecting client simulator to drive the reactive canvas immediately
const client = new WebSocket(`ws://localhost:${PORT}`);
client.on('open', () => {
  client.on('ping', () => client.pong());
  
  // Render loop outputting snapshot after simulation warms up
  let frames = 0;
  const outputDir = path.join(__dirname, 'output');
  if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir);

  const renderInterval = setInterval(() => {
    frames++;
    flora.render();
    if (frames === 30) {
      const outputPath = path.join(outputDir, 'bioluminescent_flora.png');
      flora.exportFrame(outputPath);
      console.log(`\n[Canvas Render Complete] Organic snapshot saved to: ${outputPath}`);
      client.close();
      wss.close();
      clearInterval(renderInterval);
      process.exit(0);
    }
  }, 100);
});