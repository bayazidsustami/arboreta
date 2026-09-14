#!/usr/bin/env node

/**
 * Constellation History Mapper
 * Parses shell history (~/.bash_history or ~/.zsh_history) into a dynamic graph,
 * groups sequential command workflows into star clusters/nebulae, and renders
 * a high-resolution, printable SVG constellation map.
 * 
 * Usage: node constellation.js [history_file] [output_file.svg]
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// Configuration
const CONFIG = {
  width: 2400,
  height: 2400,
  maxCommands: 1500,
  clusterThreshold: 0.15,
  palette: ['#E2F1FF', '#8AB4F8', '#C58AF9', '#F28B82', '#FDE293', '#78D9EC']
};

// 1. Locate and parse shell history
function getHistoryFilePath() {
  const home = os.homedir();
  const candidates = ['.zsh_history', '.bash_history', '.history'];
  for (const file of candidates) {
    const p = path.join(home, file);
    if (fs.existsSync(p)) return p;
  }
  return null;
}

function parseHistory(filePath) {
  if (!filePath || !fs.existsSync(filePath)) {
    console.error('History file not found.');
    process.exit(1);
  }
  const raw = fs.readFileSync(filePath, 'utf8');
  return raw
    .split('\n')
    .map(line => {
      // Clean Zsh extended format timestamp prefix if present
      let clean = line.replace(/^:\s*\d+:\d+;/, '').trim();
      // Extract main executable command
      const cmd = clean.split(/\s+/)[0];
      return { raw: clean, base: cmd };
    })
    .filter(item => item.base && item.base.length > 0 && !item.base.includes('='))
    .slice(-CONFIG.maxCommands);
}

// 2. Build graph & calculate transition frequencies (Workflow Nebulae)
function buildGraph(history) {
  const nodes = new Map();
  const edges = new Map();

  history.forEach((item, i) => {
    // Register/update node frequency (brightness/star magnitude)
    if (!nodes.has(item.base)) {
      nodes.set(item.base, { id: item.base, count: 0, x: 0, y: 0, vx: 0, vy: 0 });
    }
    nodes.get(item.base).count += 1;

    // Register transition to next command
    if (i < history.length - 1) {
      const nextItem = history[i + 1];
      if (item.base !== nextItem.base) {
        const edgeKey = [item.base, nextItem.base].sort().join('->');
        if (!edges.has(edgeKey)) {
          edges.set(edgeKey, { source: item.base, target: nextItem.base, weight: 0 });
        }
        edges.get(edgeKey).weight += 1;
      }
    }
  });

  return { nodes: Array.from(nodes.values()), edges: Array.from(edges.values()) };
}

// 3. Force-directed graph layout simulation
function simulateLayout(nodes, edges, iterations = 300) {
  const nodeMap = new Map(nodes.map(n => [n.id, n]));
  
  // Initialize random circular positions
  nodes.forEach((node, i) => {
    const angle = (i / nodes.length) * 2 * Math.PI;
    const radius = 400 + Math.random() * 300;
    node.x = CONFIG.width / 2 + Math.cos(angle) * radius;
    node.y = CONFIG.height / 2 + Math.sin(angle) * radius;
  });

  const k = Math.sqrt((CONFIG.width * CONFIG.height) / nodes.length) * 0.8;

  for (let iter = 0; iter < iterations; iter++) {
    // Repulsion between all nodes
    for (let i = 0; i < nodes.length; i++) {
      for (let j = i + 1; j < nodes.length; j++) {
        const n1 = nodes[i];
        const n2 = nodes[j];
        const dx = n2.x - n1.x || 1;
        const dy = n2.y - n1.y || 1;
        const dist = Math.sqrt(dx * dx + dy * dy) || 1;
        const force = (k * k) / dist;
        const fx = (dx / dist) * force;
        const fy = (dy / dist) * force;

        n1.vx -= fx;
        n1.vy -= fy;
        n2.vx += fx;
        n2.vy += fy;
      }
    }

    // Attraction along workflow edges
    edges.forEach(edge => {
      const source = nodeMap.get(edge.source);
      const target = nodeMap.get(edge.target);
      if (!source || !target) return;

      const dx = target.x - source.x || 1;
      const dy = target.y - source.y || 1;
      const dist = Math.sqrt(dx * dx + dy * dy) || 1;
      const force = (dist * dist) / k * Math.log(edge.weight + 1) * 0.15;
      const fx = (dx / dist) * force;
      const fy = (dy / dist) * force;

      source.vx += fx;
      source.vy += fy;
      target.vx -= fx;
      target.vy -= fy;
    });

    // Gravity pulling towards center & update positions
    const damping = 0.85;
    nodes.forEach(node => {
      const dx = CONFIG.width / 2 - node.x;
      const dy = CONFIG.height / 2 - node.y;
      node.vx += dx * 0.005;
      node.vy += dy * 0.005;

      node.x += node.vx * 0.1;
      node.y += node.vy * 0.1;
      node.vx *= damping;
      node.vy *= damping;
    });
  }
}

// 4. Render printable SVG Constellation Map
function renderSVG(nodes, edges) {
  const nodeMap = new Map(nodes.map(n => [n.id, n]));
  const maxCount = Math.max(...nodes.map(n => n.count), 1);
  const maxWeight = Math.max(...edges.map(e => e.weight), 1);

  // Background star field generator
  let ambientStars = '';
  for (let i = 0; i < 400; i++) {
    const sx = Math.random() * CONFIG.width;
    const sy = Math.random() * CONFIG.height;
    const r = Math.random() * 1.5;
    const opacity = Math.random() * 0.7 + 0.1;
    ambientStars += `<circle cx="${sx.toFixed(1)}" cy="${sy.toFixed(1)}" r="${r.toFixed(1)}" fill="#ffffff" opacity="${opacity.toFixed(2)}" />`;
  }

  // Draw Nebulae (Glow behind connected workflow clusters)
  let nebulae = '';
  nodes.forEach((node, idx) => {
    if (node.count > maxCount * 0.05) {
      const color = CONFIG.palette[idx % CONFIG.palette.length];
      const radius = Math.min(node.count / maxCount * 180 + 40, 250);
      nebulae += `<circle cx="${node.x.toFixed(1)}" cy="${node.y.toFixed(1)}" r="${radius.toFixed(1)}" fill="${color}" opacity="0.04" filter="blur(40px)" />`;
    }
  });

  // Draw Constellation Lines (Edges)
  let lines = '';
  edges.forEach(edge => {
    const s = nodeMap.get(edge.source);
    const t = nodeMap.get(edge.target);
    if (!s || !t) return;

    const opacity = Math.min((edge.weight / maxWeight) * 0.8 + 0.15, 0.9).toFixed(2);
    const strokeWidth = (Math.log(edge.weight + 1) * 1.5 + 0.5).toFixed(1);
    lines += `<line x1="${s.x.toFixed(1)}" y1="${s.y.toFixed(1)}" x2="${t.x.toFixed(1)}" y2="${t.y.toFixed(1)}" stroke="#8AB4F8" stroke-opacity="${opacity}" stroke-width="${strokeWidth}" stroke-dasharray="${edge.weight < 2 ? '4,4' : 'none'}" />`;
  });

  // Draw Stars (Nodes) and Command Labels
  let stars = '';
  nodes.forEach((node, idx) => {
    const color = CONFIG.palette[idx % CONFIG.palette.length];
    const radius = Math.max(Math.sqrt(node.count / maxCount) * 16, 3).toFixed(1);
    
    // Star core & outer glow
    stars += `<g transform="translate(${node.x.toFixed(1)}, ${node.y.toFixed(1)})">`;
    stars += `<circle r="${(radius * 2.5).toFixed(1)}" fill="${color}" opacity="0.15" filter="blur(4px)" />`;
    stars += `<circle r="${radius}" fill="${color}" stroke="#FFFFFF" stroke-width="0.8" />`;
    
    // Label for significant commands
    if (node.count / maxCount > 0.02 || nodes.length < 30) {
      const fontSize = Math.max(Math.log(node.count + 1) * 4 + 10, 12).toFixed(1);
      stars += `<text x="${(parseFloat(radius) + 6).toFixed(1)}" y="4" fill="#E2F1FF" font-family="'Courier New', monospace" font-size="${fontSize}" font-weight="600" opacity="0.9" letter-spacing="1">${node.id}</text>`;
    }
    stars += `</g>`;
  });

  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 ${CONFIG.width} ${CONFIG.height}" width="100%" height="100%" style="background-color: #05070F;">
  <defs>
    <style>
      text { text-shadow: 0 0 4px rgba(0,0,0,0.8); }
    </style>
  </defs>
  <!-- Background Ambient Stars -->
  <g id="ambient-stars">${ambientStars}</g>
  <!-- Workflow Nebulae -->
  <g id="nebulae">${nebulae}</g>
  <!-- Constellation Connections -->
  <g id="constellation-lines">${lines}</g>
  <!-- Star Nodes & Labels -->
  <g id="stars">${stars}</g>
  <!-- Map Legend Header -->
  <text x="80" y="100" fill="#8AB4F8" font-family="'Courier New', monospace" font-size="32" font-weight="bold" letter-spacing="4">SHELL HISTORY CONSTELLATION MAP</text>
  <text x="80" y="135" fill="#E2F1FF" font-family="'Courier New', monospace" font-size="16" opacity="0.6" letter-spacing="2">GENERATED FROM ${nodes.length} COMMAND NODES</text>
</svg>`;
}

// Execute Workflow
(function main() {
  const args = process.argv.slice(2);
  const inputPath = args[0] || getHistoryFilePath();
  const outputPath = args[1] || path.join(process.cwd(), 'constellation_map.svg');

  console.log(`Parsing history from: ${inputPath}...`);
  const history = parseHistory(inputPath);
  
  console.log(`Analyzing ${history.length} commands...`);
  const { nodes, edges } = buildGraph(history);
  
  console.log(`Simulating dynamic constellation graph layout...`);
  simulateLayout(nodes, edges);

  console.log(`Rendering high-resolution vector SVG...`);
  const svg = renderSVG(nodes, edges);
  
  fs.writeFileSync(outputPath, svg, 'utf8');
  console.log(`✨ Constellation map successfully saved to: ${outputPath}`);
})();