<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Git Topography: Codebase Terrain Visualizer</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: #0c0f12; color: #d0d7de; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, monospace; overflow: hidden; height: 100vh; width: 100vw; display: flex; }
    #canvas-container { flex: 1; position: relative; height: 100%; cursor: grab; }
    #canvas-container:active { cursor: grabbing; }
    canvas { display: block; width: 100%; height: 100%; }
    
    /* Control Panel UI */
    #sidebar { width: 340px; background: rgba(18, 22, 28, 0.95); backdrop-filter: blur(10px); border-right: 1px solid #2d333b; padding: 20px; display: flex; flex-direction: column; gap: 18px; z-index: 10; box-shadow: 4px 0 20px rgba(0,0,0,0.5); overflow-y: auto; }
    h1 { font-size: 1.2rem; font-weight: 600; color: #58a6ff; display: flex; align-items: center; gap: 8px; letter-spacing: 0.5px; }
    h1::before { content: "🌋"; font-size: 1.4rem; }
    .section { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 14px; }
    .section-title { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 1px; color: #8b949e; margin-bottom: 10px; font-weight: 700; }
    button { width: 100%; background: #238636; color: #fff; border: none; padding: 10px; border-radius: 6px; font-weight: 600; cursor: pointer; transition: background 0.2s; font-family: inherit; font-size: 0.85rem; }
    button:hover { background: #2ea043; }
    
    .legend-item { display: flex; align-items: center; gap: 10px; margin-bottom: 8px; font-size: 0.82rem; }
    .legend-color { width: 14px; height: 14px; border-radius: 3px; flex-shrink: 0; }
    
    /* Tooltip */
    #tooltip { position: absolute; display: none; background: rgba(13, 17, 23, 0.95); border: 1px solid #30363d; border-radius: 6px; padding: 10px 14px; color: #e6edf3; font-size: 0.8rem; pointer-events: none; z-index: 100; box-shadow: 0 8px 24px rgba(0,0,0,0.6); max-width: 280px; }
    #tooltip .hash { color: #f2cc60; font-family: monospace; font-size: 0.75rem; margin-bottom: 4px; }
    #tooltip .title { font-weight: 600; color: #58a6ff; margin-bottom: 4px; }
    #tooltip .meta { color: #8b949e; font-size: 0.75rem; }
    
    .stat-row { display: flex; justify-content: space-between; font-size: 0.8rem; margin-bottom: 6px; }
    .stat-value { color: #58a6ff; font-weight: 600; }
  </style>
</head>
<body>

  <div id="sidebar">
    <h1>Git Topography</h1>
    <p style="font-size: 0.8rem; color: #8b949e; line-height: 1.4;">Procedural terrain map generated from codebase repository history.</p>
    
    <button id="btn-generate">Regenerate Repository History</button>
    
    <div class="section">
      <div class="section-title">Repository Stats</div>
      <div class="stat-row"><span>Total Commits:</span><span id="stat-commits" class="stat-value">0</span></div>
      <div class="stat-row"><span>Feature Branches:</span><span id="stat-branches" class="stat-value">0</span></div>
      <div class="stat-row"><span>Bug Fix Rivers:</span><span id="stat-fixes" class="stat-value">0</span></div>
      <div class="stat-row"><span>Merge Volcanoes:</span><span id="stat-conflicts" class="stat-value">0</span></div>
    </div>

    <div class="section">
      <div class="section-title">Topographical Key</div>
      <div class="legend-item"><div class="legend-color" style="background: #e63946;"></div> Active Volcano (Merge Conflict)</div>
      <div class="legend-item"><div class="legend-color" style="background: #457b9d;"></div> Mountain Ridge (Long Feature Branch)</div>
      <div class="legend-item"><div class="legend-color" style="background: #61afef;"></div> Winding River (Bug Fix Sequence)</div>
      <div class="legend-item"><div class="legend-color" style="background: #2a9d8f;"></div> Valleys & Plains (Main Baseline)</div>
      <div class="legend-item"><div class="legend-color" style="background: #1d3557;"></div> Ocean (Base Water Level)</div>
    </div>

    <div class="section">
      <div class="section-title">Controls</div>
      <p style="font-size: 0.75rem; color: #8b949e; line-height: 1.4;">
        • <b>Drag</b> to pan terrain map<br>
        • <b>Scroll</b> to zoom in/out<br>
        • <b>Hover</b> features to inspect git history
      </p>
    </div>
  </div>

  <div id="canvas-container">
    <canvas id="mapCanvas"></canvas>
    <div id="tooltip"></div>
  </div>

  <script>
    /**
     * Git Topography Generator
     * Parses simulated/raw Git history into procedural 3D heightmaps & renders isoline topographic maps.
     */

    // --- Simplex / Perlin Noise Generator (Simplified 2D Noise Implementation) ---
    class FastNoise {
      constructor(seed = Math.random()) {
        this.p = new Uint8Array(512);
        const permutation = new Uint8Array(256);
        for (let i = 0; i < 256; i++) permutation[i] = i;
        for (let i = 255; i > 0; i--) {
          const r = Math.floor((seed = (seed * 9301 + 49297) % 233280) / 233280 * (i + 1));
          [permutation[i], permutation[r]] = [permutation[r], permutation[i]];
        }
        for (let i = 0; i < 512; i++) this.p[i] = permutation[i & 255];
      }
      dot(g, x, y) { return g[0] * x + g[1] * y; }
      noise(x, y) {
        const grad2 = [[1,1],[-1,1],[1,-1],[-1,-1],[1,0],[-1,0],[0,1],[0,-1]];
        let X = Math.floor(x) & 255, Y = Math.floor(y) & 255;
        x -= Math.floor(x); y -= Math.floor(y);
        let fx = (3 - 2 * x) * x * x, fy = (3 - 2 * y) * y * y;
        let g00 = grad2[this.p[X + this.p[Y]] % 8];
        let g10 = grad2[this.p[X + 1 + this.p[Y]] % 8];
        let g01 = grad2[this.p[X + this.p[Y + 1]] % 8];
        let g11 = grad2[this.p[X + 1 + this.p[Y + 1]] % 8];
        let n00 = this.dot(g00, x, y), n10 = this.dot(g10, x - 1, y);
        let n01 = this.dot(g01, x, y - 1), n11 = this.dot(g11, x - 1, y - 1);
        let nx0 = n00 + fx * (n10 - n00), nx1 = n01 + fx * (n11 - n01);
        return nx0 + fy * (nx1 - nx0);
      }
      octave(x, y, octaves = 4, persistence = 0.5) {
        let total = 0, frequency = 1, amplitude = 1, maxValue = 0;
        for (let i = 0; i < octaves; i++) {
          total += this.noise(x * frequency, y * frequency) * amplitude;
          maxValue += amplitude;
          amplitude *= persistence;
          frequency *= 2;
        }
        return total / maxValue;
      }
    }

    // --- Git Repository Simulator & Parser ---
    class GitRepoSimulator {
      generateHistory() {
        const authors = ["alex.dev", "sarah.coder", "bot-ci", "mira.refactor", "devin.build"];
        const modules = ["auth", "core/engine", "db/schema", "api/v2", "ui/components", "payment/stripe"];
        
        const commits = [];
        const branches = [];
        const conflicts = [];
        const bugFixes = [];
        
        let totalCommits = 120 + Math.floor(Math.random() * 80);
        
        // Generate Long-lived Feature Branches (Mountain Ranges)
        const branchCount = 3 + Math.floor(Math.random() * 3);
        for (let i = 0; i < branchCount; i++) {
          const name = `feature/${modules[i % modules.length]}-${100 + i}`;
          const commitCount = 15 + Math.floor(Math.random() * 25); // Lifespan length
          branches.push({ name, length: commitCount, author: authors[i % authors.length] });
        }

        // Generate Merge Conflicts (Volcanoes)
        const conflictCount = 3 + Math.floor(Math.random() * 3);
        for (let i = 0; i < conflictCount; i++) {
          conflicts.push({
            hash: Math.random().toString(16).substr(2, 7),
            branch: branches[i % branches.length].name,
            files: [`src/${modules[i]}/index.ts`, `src/${modules[i]}/types.ts`],
            severity: 0.7 + Math.random() * 0.3,
            message: `Merge conflict in ${modules[i]}: Automatic merge failed`
          });
        }

        // Generate Bug Fix Sequences (Rivers)
        const fixCount = 4 + Math.floor(Math.random() * 3);
        for (let i = 0; i < fixCount; i++) {
          const riverLength = 4 + Math.floor(Math.random() * 5);
          const fixCommits = [];
          for (let j = 0; j < riverLength; j++) {
            fixCommits.push({
              hash: Math.random().toString(16).substr(2, 7),
              message: `fix(${modules[j % modules.length]}): patch edge case #${1000 + i * 10 + j}`
            });
          }
          bugFixes.push({ id: `BUG-${4000 + i}`, commits: fixCommits });
        }

        return { totalCommits, branches, conflicts, bugFixes };
      }
    }

    // --- Terrain & Topography Engine ---
    class TopoTerrain {
      constructor(width, height) {
        this.width = width;
        this.height = height;
        this.gridSize = 180; // Grid resolution for heightmap
        this.heightmap = new Float32Array(this.gridSize * this.gridSize);
        this.noise = new FastNoise();
        this.featureNodes = []; // Store interactive POIs (volcanoes, branch peaks, rivers)
        this.particles = [];
      }

      generateFromRepo(repoData) {
        this.noise = new FastNoise(Math.random());
        const N = this.gridSize;
        this.heightmap.fill(0);
        this.featureNodes = [];

        // 1. Base Procedural Landscape (Octave Noise)
        for (let y = 0; y < N; y++) {
          for (let x = 0; x < N; x++) {
            let nx = x / N - 0.5, ny = y / N - 0.5;
            let val = this.noise.octave(nx * 3 + 10, ny * 3 + 10, 5, 0.5);
            // Radial mask for island-like terrain
            let dist = Math.sqrt(nx * nx + ny * ny);
            val = val * (1 - Math.pow(dist * 1.8, 2));
            this.heightmap[y * N + x] = Math.max(0, val);
          }
        }

        // 2. Map Feature Branches into Mountain Ranges
        repoData.branches.forEach((branch, idx) => {
          let angle = (idx / repoData.branches.length) * Math.PI * 2 + Math.random() * 0.5;
          let startX = N * 0.5 + Math.cos(angle) * (N * 0.15);
          let startY = N * 0.5 + Math.sin(angle) * (N * 0.15);
          let len = branch.length;

          let points = [];
          let currX = startX, currY = startY;
          for (let step = 0; step < len; step++) {
            currX += Math.cos(angle + (Math.random() - 0.5) * 0.4) * 1.8;
            currY += Math.sin(angle + (Math.random() - 0.5) * 0.4) * 1.8;
            points.push({ x: currX, y: currY });

            // Raise height around ridge
            let radius = Math.floor(6 + Math.random() * 4);
            for (let ry = -radius; ry <= radius; ry++) {
              for (let rx = -radius; rx <= radius; rx++) {
                let gx = Math.floor(currX + rx), gy = Math.floor(currY + ry);
                if (gx >= 0 && gx < N && gy >= 0 && gy < N) {
                  let d = Math.sqrt(rx * rx + ry * ry) / radius;
                  if (d < 1) {
                    let elevation = (1 - d) * 0.35 * (1 + Math.random() * 0.1);
                    this.heightmap[gy * N + gx] += elevation;
                  }
                }
              }
            }
          }

          // Store mountain peak label
          let midPoint = points[Math.floor(points.length / 2)];
          this.featureNodes.push({
            type: 'mountain',
            gridX: midPoint.x,
            gridY: midPoint.y,
            title: branch.name,
            meta: `Long-lived Feature Branch (${branch.length} commits by ${branch.author})`
          });
        });

        // 3. Map Bug Fixes into Winding Rivers (Erosion Carving)
        repoData.bugFixes.forEach((bug) => {
          // Find high elevation start point
          let rx = Math.floor(N * 0.3 + Math.random() * N * 0.4);
          let ry = Math.floor(N * 0.3 + Math.random() * N * 0.4);
          
          let riverPath = [];
          let currX = rx, currY = ry;

          for (let step = 0; step < bug.commits.length * 6; step++) {
            riverPath.push({ x: currX, y: currY });
            
            // Lower height to carve river channel
            let gx = Math.floor(currX), gy = Math.floor(currY);
            if (gx >= 1 && gx < N - 1 && gy >= 1 && gy < N - 1) {
              this.heightmap[gy * N + gx] *= 0.3; // Deep channel
              this.heightmap[gy * N + (gx + 1)] *= 0.6;
              this.heightmap[(gy + 1) * N + gx] *= 0.6;
            }

            // Flow downwards towards lower terrain
            let lowestX = currX, lowestY = currY, minH = 999;
            for (let dx = -1; dx <= 1; dx++) {
              for (let dy = -1; dy <= 1; dy++) {
                let nx = Math.floor(currX + dx), ny = Math.floor(currY + dy);
                if (nx >= 0 && nx < N && ny >= 0 && ny < N) {
                  let h = this.heightmap[ny * N + nx];
                  if (h < minH) { minH = h; lowestX = nx; lowestY = ny; }
                }
              }
            }
            currX = lowestX + (Math.random() - 0.5) * 0.8;
            currY = lowestY + (Math.random() - 0.5) * 0.8;
          }

          if (riverPath.length > 0) {
            this.featureNodes.push({
              type: 'river',
              gridX: riverPath[0].x,
              gridY: riverPath[0].y,
              title: bug.id,
              meta: `Bug Fix Stream: ${bug.commits.length} fixes carved through terrain`,
              path: riverPath
            });
          }
        });

        // 4. Map Merge Conflicts into Active Volcanoes
        repoData.conflicts.forEach((conflict) => {
          let vx = Math.floor(N * 0.25 + Math.random() * N * 0.5);
          let vy = Math.floor(N * 0.25 + Math.random() * N * 0.5);

          // Raise massive volcanic cone with caldera crater
          let radius = 10;
          for (let ry = -radius; ry <= radius; ry++) {
            for (let rx = -radius; rx <= radius; rx++) {
              let gx = vx + rx, gy = vy + ry;
              if (gx >= 0 && gx < N && gy >= 0 && gy < N) {
                let d = Math.sqrt(rx * rx + ry * ry) / radius;
                if (d < 1) {
                  // Cone profile with depression in center (crater)
                  let h = (1 - d) * 0.7;
                  if (d < 0.25) h *= 0.4; // Caldera hole
                  this.heightmap[gy * N + gx] = Math.max(this.heightmap[gy * N + gx], h + 0.2);
                }
              }
            }
          }

          this.featureNodes.push({
            type: 'volcano',
            gridX: vx,
            gridY: vy,
            hash: conflict.hash,
            title: `Merge Conflict: ${conflict.branch}`,
            meta: `${conflict.message} (${conflict.files.join(', ')})`,
            severity: conflict.severity
          });
        });
      }

      getHeight(x, y) {
        const N = this.gridSize;
        let gx = Math.clamp(Math.floor(x), 0, N - 1);
        let gy = Math.clamp(Math.floor(y), 0, N - 1);
        return this.heightmap[gy * N + gx];
      }
    }

    Math.clamp = (val, min, max) => Math.min(Math.max(val, min), max);

    // --- Main Rendering Engine & Interaction ---
    class TopoRenderer {
      constructor(canvas, terrain) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.terrain = terrain;
        
        // Pan / Zoom Viewport state
        this.zoom = 1.0;
        this.panX = 0;
        this.panY = 0;
        this.isDragging = false;
        this.dragStart = { x: 0, y: 0 };

        this.time = 0;
        this.hoveredNode = null;

        this.setupEvents();
        this.resize();
      }

      resize() {
        this.canvas.width = this.canvas.parentElement.clientWidth;
        this.canvas.height = this.canvas.parentElement.clientHeight;
        this.centerMap();
      }

      centerMap() {
        this.panX = (this.canvas.width - this.terrain.gridSize * 4 * this.zoom) / 2;
        this.panY = (this.canvas.height - this.terrain.gridSize * 4 * this.zoom) / 2;
      }

      setupEvents() {
        window.addEventListener('resize', () => this.resize());

        this.canvas.addEventListener('mousedown', (e) => {
          this.isDragging = true;
          this.dragStart = { x: e.clientX - this.panX, y: e.clientY - this.panY };
        });

        window.addEventListener('mouseup', () => this.isDragging = false);

        this.canvas.addEventListener('mousemove', (e) => {
          if (this.isDragging) {
            this.panX = e.clientX - this.dragStart.x;
            this.panY = e.clientY - this.dragStart.y;
          } else {
            this.checkHover(e.clientX, e.clientY);
          }
        });

        this.canvas.addEventListener('wheel', (e) => {
          e.preventDefault();
          let zoomFactor = e.deltaY < 0 ? 1.15 : 0.85;
          let newZoom = Math.clamp(this.zoom * zoomFactor, 0.4, 4.0);
          
          // Zoom centered around mouse cursor
          let rect = this.canvas.getBoundingClientRect();
          let mouseX = e.clientX - rect.left;
          let mouseY = e.clientY - rect.top;

          this.panX = mouseX - (mouseX - this.panX) * (newZoom / this.zoom);
          this.panY = mouseY - (mouseY - this.panY) * (newZoom / this.zoom);
          this.zoom = newZoom;
        });
      }

      gridToScreen(gx, gy) {
        let scale = 4 * this.zoom;
        return {
          x: this.panX + gx * scale,
          y: this.panY + gy * scale
        };
      }

      screenToGrid(sx, sy) {
        let scale = 4 * this.zoom;
        return {
          x: (sx - this.panX) / scale,
          y: (sy - this.panY) / scale
        };
      }

      checkHover(screenX, screenY) {
        const rect = this.canvas.getBoundingClientRect();
        const mx = screenX - rect.left;
        const my = screenY - rect.top;
        
        let found = null;
        const radiusThreshold = 18;

        for (let node of this.terrain.featureNodes) {
          let pos = this.gridToScreen(node.gridX, node.gridY);
          let dist = Math.hypot(pos.x - mx, pos.y - my);
          if (dist < radiusThreshold) {
            found = node;
            break;
          }
        }

        this.hoveredNode = found;
        const tooltip = document.getElementById('tooltip');
        if (found) {
          tooltip.style.display = 'block';
          tooltip.style.left = `${screenX + 12}px`;
          tooltip.style.top = `${screenY + 12}px`;
          tooltip.innerHTML = `
            ${found.hash ? `<div class="hash">commit ${found.hash}</div>` : ''}
            <div class="title">${found.title}</div>
            <div class="meta">${found.meta}</div>
          `;
        } else {
          tooltip.style.display = 'none';
        }
      }

      getElevationColor(h) {
        // Color bands for topographical terrain
        if (h < 0.08) return '#1d3557'; // Deep water
        if (h < 0.15) return '#457b9d'; // Shallow water
        if (h < 0.22) return '#e9c46a'; // Coastal sand/plains
        if (h < 0.40) return '#2a9d8f'; // Valleys & forests
        if (h < 0.60) return '#8ab17d'; // Low hills
        if (h < 0.75) return '#b08968'; // High mountains
        if (h < 0.88) return '#6c584c'; // Dark rocky peaks
        return '#f8f9fa'; // Snow caps
      }

      render() {
        this.time += 0.03;
        const ctx = this.ctx;
        const N = this.terrain.gridSize;
        const scale = 4 * this.zoom;

        ctx.fillStyle = '#0c0f12';
        ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

        // 1. Draw Base Heightmap Grid Pixels
        for (let y = 0; y < N; y++) {
          for (let x = 0; x < N; x++) {
            let h = this.terrain.heightmap[y * N + x];
            ctx.fillStyle = this.getElevationColor(h);
            let screenPos = this.gridToScreen(x, y);
            ctx.fillRect(screenPos.x, screenPos.y, Math.ceil(scale), Math.ceil(scale));
          }
        }

        // 2. Render Contour Lines (Isolines)
        ctx.strokeStyle = 'rgba(0, 0, 0, 0.25)';
        ctx.lineWidth = 1;
        const contourInterval = 0.08;

        for (let y = 0; y < N - 1; y++) {
          for (let x = 0; x < N - 1; x++) {
            let h = this.terrain.heightmap[y * N + x];
            let hRight = this.terrain.heightmap[y * N + (x + 1)];
            let hDown = this.terrain.heightmap[(y + 1) * N + x];

            let level1 = Math.floor(h / contourInterval);
            let level2 = Math.floor(hRight / contourInterval);
            let level3 = Math.floor(hDown / contourInterval);

            if (level1 !== level2 || level1 !== level3) {
              let p = this.gridToScreen(x, y);
              ctx.beginPath();
              ctx.rect(p.x, p.y, scale, scale);
              ctx.stroke();
            }
          }
        }

        // 3. Draw Winding Bug Fix Rivers
        this.terrain.featureNodes.filter(n => n.type === 'river').forEach(river => {
          if (!river.path || river.path.length < 2) return;
          ctx.beginPath();
          let start = this.gridToScreen(river.path[0].x, river.path[0].y);
          ctx.moveTo(start.x, start.y);

          for (let i = 1; i < river.path.length; i++) {
            let pt = this.gridToScreen(river.path[i].x, river.path[i].y);
            ctx.lineTo(pt.x, pt.y);
          }
          
          ctx.strokeStyle = '#61afef';
          ctx.lineWidth = Math.max(1.5, 2.5 * this.zoom);
          ctx.shadowColor = '#61afef';
          ctx.shadowBlur = 6;
          ctx.stroke();
          ctx.shadowBlur = 0;
        });

        // 4. Render Active Volcanoes (Merge Conflicts) with Animated Smoke & Lava
        this.terrain.featureNodes.filter(n => n.type === 'volcano').forEach(v => {
          let pos = this.gridToScreen(v.gridX, v.gridY);
          
          // Pulsing lava caldera core
          let pulse = Math.sin(this.time * 3 + v.gridX) * 0.3 + 0.7;
          let glowRadius = (12 + v.severity * 10) * this.zoom;

          let grad = ctx.createRadialGradient(pos.x, pos.y, 2, pos.x, pos.y, glowRadius);
          grad.addColorStop(0, '#ff4d4d');
          grad.addColorStop(0.5, 'rgba(230, 57, 70, 0.8)');
          grad.addColorStop(1, 'rgba(230, 57, 70, 0)');

          ctx.fillStyle = grad;
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, glowRadius, 0, Math.PI * 2);
          ctx.fill();

          // Volcanic Peak Icon / Crater Ring
          ctx.strokeStyle = '#e63946';
          ctx.lineWidth = 2 * this.zoom;
          ctx.beginPath();
          ctx.arc(pos.x, pos.y, 6 * this.zoom * pulse, 0, Math.PI * 2);
          ctx.stroke();

          // Smoke Particle Plume Animation
          let smokeY = pos.y - ((this.time * 20 + v.gridX * 10) % 40) * this.zoom;
          let smokeAlpha = 1 - (((this.time * 20 + v.gridX * 10) % 40) / 40);
          ctx.fillStyle = `rgba(180, 180, 180, ${smokeAlpha * 0.6})`;
          ctx.beginPath();
          ctx.arc(pos.x + Math.sin(this.time + v.gridY) * 6, smokeY, (4 + (1 - smokeAlpha) * 8) * this.zoom, 0, Math.PI * 2);
          ctx.fill();
        });

        // 5. Draw Labels for Feature Branches / POIs
        this.terrain.featureNodes.forEach(node => {
          let pos = this.gridToScreen(node.gridX, node.gridY);
          let isHovered = this.hoveredNode === node;

          if (node.type === 'mountain' || isHovered) {
            ctx.font = `${isHovered ? 'bold 12px' : '10px'} monospace`;
            ctx.fillStyle = isHovered ? '#ffffff' : 'rgba(255,255,255,0.7)';
            ctx.textAlign = 'center';
            ctx.fillText(node.title, pos.x, pos.y - 10 * this.zoom);
          }

          // Highlight indicator on hover
          if (isHovered) {
            ctx.strokeStyle = '#f2cc60';
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.arc(pos.x, pos.y, 14 * this.zoom, 0, Math.PI * 2);
            ctx.stroke();
          }
        });

        requestAnimationFrame(() => this.render());
      }
    }

    // --- Application Initialization ---
    window.addEventListener('DOMContentLoaded', () => {
      const canvas = document.getElementById('mapCanvas');
      const repoSim = new GitRepoSimulator();
      const terrain = new TopoTerrain(180, 180);
      const renderer = new TopoRenderer(canvas, terrain);

      function buildNewRepository() {
        const historyData = repoSim.generateHistory();
        
        // Update Sidebar Stats
        document.getElementById('stat-commits').innerText = historyData.totalCommits;
        document.getElementById('stat-branches').innerText = historyData.branches.length;
        document.getElementById('stat-fixes').innerText = historyData.bugFixes.length;
        document.getElementById('stat-conflicts').innerText = historyData.conflicts.length;

        // Build Terrain Map
        terrain.generateFromRepo(historyData);
        renderer.centerMap();
      }

      document.getElementById('btn-generate').addEventListener('click', () => {
        buildNewRepository();
      });

      // Initial Build & Start Animation Loop
      buildNewRepository();
      renderer.render();
    });
  </script>
</body>
</html>