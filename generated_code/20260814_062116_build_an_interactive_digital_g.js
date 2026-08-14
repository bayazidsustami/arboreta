// Interactive Digital Garden: Procedural Git Flora Generator
// Paste and run this script directly in any browser console or HTML document.

(function () {
  // 1. Setup Canvas and CSS Overlay
  const style = document.createElement('style');
  style.textContent = `
    body, html { margin: 0; padding: 0; overflow: hidden; background: #0a0c10; font-family: monospace; color: #8b949e; }
    #garden-canvas { display: block; width: 100vw; height: 100vh; }
    #ui-panel {
      position: absolute; top: 15px; left: 15px; background: rgba(13, 17, 23, 0.85);
      backdrop-filter: blur(8px); border: 1px solid #30363d; border-radius: 8px;
      padding: 16px; width: 320px; box-shadow: 0 8px 24px rgba(0,0,0,0.5); z-index: 10;
    }
    h3 { margin: 0 0 12px 0; color: #58a6ff; font-size: 14px; text-transform: uppercase; letter-spacing: 1px; }
    .control-group { margin-bottom: 12px; }
    label { display: flex; justify-content: space-between; font-size: 12px; margin-bottom: 4px; }
    input, select, button {
      width: 100%; background: #21262d; border: 1px solid #30363d; color: #c9d1d9;
      padding: 6px 10px; border-radius: 4px; box-sizing: border-box; font-family: monospace;
    }
    button { background: #238636; color: #fff; border: none; font-weight: bold; cursor: pointer; transition: 0.2s; margin-top: 8px;}
    button:hover { background: #2ea043; }
    #log-stream { height: 100px; overflow-y: auto; font-size: 11px; background: #010409; padding: 6px; border-radius: 4px; border: 1px solid #21262d; margin-top: 10px; }
    .log-entry { margin-bottom: 4px; border-bottom: 1px solid #161b22; padding-bottom: 2px; }
    .log-branch { color: #d2a8ff; }
  `;
  document.head.appendChild(style);

  const canvas = document.createElement('canvas');
  canvas.id = 'garden-canvas';
  document.body.appendChild(canvas);
  const ctx = canvas.getContext('2d');

  const ui = document.createElement('div');
  ui.id = 'ui-panel';
  ui.innerHTML = `
    <h3>Git Digital Garden</h3>
    <div class="control-group">
      <label>Target Branch: <span id="branch-val">main</span></label>
      <select id="branch-select">
        <option value="main">main</option>
        <option value="feature/auth">feature/auth</option>
        <option value="fix/parser">fix/parser</option>
        <option value="experimental">experimental</option>
      </select>
    </div>
    <div class="control-group">
      <label>Test Coverage (%): <span id="cov-val">85%</span></label>
      <input type="range" id="cov-slider" min="0" max="100" value="85">
    </div>
    <div class="control-group">
      <label>Code Complexity (Chaos): <span id="comp-val">3</span></label>
      <input type="range" id="comp-slider" min="1" max="10" value="3">
    </div>
    <button id="commit-btn">⚡ Push Live Commit</button>
    <div id="log-stream"></div>
  `;
  document.body.appendChild(ui);

  // Resize canvas
  function resize() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  }
  window.addEventListener('resize', resize);
  resize();

  // 2. Data Models & State
  const branches = {};
  let particles = [];
  let globalTime = 0;

  class BranchNode {
    constructor(parent, x, y, angle, length, depth, branchName) {
      this.parent = parent;
      this.x = x;
      this.y = y;
      this.angle = angle;
      this.length = length;
      this.currentLength = 0;
      this.depth = depth;
      this.branchName = branchName;
      this.children = [];
      this.bloom = null;
      this.complexity = 3;
      this.coverage = 85;
      this.mutationOffset = (Math.random() - 0.5) * 0.2;
    }

    grow() {
      if (this.currentLength < this.length) {
        this.currentLength += (this.length - this.currentLength) * 0.05 + 0.1;
      }
      this.children.forEach(child => child.grow());
      if (this.bloom) this.bloom.grow();
    }

    render(ctx, parentX, parentY, accumulatedWind) {
      // Complexity causes chaotic, wind-like mutations
      const chaosFactor = this.complexity * 0.08;
      const wind = Math.sin(globalTime * 0.002 + this.depth) * chaosFactor + this.mutationOffset;
      const currentAngle = this.angle + accumulatedWind + wind;

      const endX = parentX + Math.cos(currentAngle) * this.currentLength;
      const endY = parentY + Math.sin(currentAngle) * this.currentLength;

      // Draw Stem/Root
      ctx.beginPath();
      ctx.moveTo(parentX, parentY);
      ctx.lineTo(endX, endY);
      ctx.lineWidth = Math.max(1, 8 - this.depth * 1.2);
      
      // Branch color based on branch identity
      const hue = getBranchHue(this.branchName);
      ctx.strokeStyle = `hsl(${hue}, 60%, ${Math.min(70, 30 + this.depth * 8)}%)`;
      ctx.lineCap = 'round';
      ctx.stroke();

      // Render children
      this.children.forEach(child => child.render(ctx, endX, endY, accumulatedWind + wind * 0.5));

      // Render Bloom if terminal node and high test coverage
      if (this.bloom) {
        this.bloom.render(ctx, endX, endY);
      }
    }
  }

  class Bloom {
    constructor(coverage) {
      this.coverage = coverage; // High test coverage = bigger, vibrant bloom
      this.scale = 0;
      this.targetScale = Math.max(0.2, (coverage / 100));
      this.petals = Math.floor(5 + (coverage / 100) * 7);
      this.colorHue = 120 + (coverage / 100) * 200; // Shift color with coverage quality
    }

    grow() {
      if (this.scale < this.targetScale) {
        this.scale += (this.targetScale - this.scale) * 0.03;
      }
    }

    render(ctx, x, y) {
      if (this.scale <= 0.01) return;
      ctx.save();
      ctx.translate(x, y);
      ctx.scale(this.scale, this.scale);

      // Floral bloom center
      ctx.beginPath();
      ctx.arc(0, 0, 8, 0, Math.PI * 2);
      ctx.fillStyle = '#ffd700';
      ctx.fill();

      // Petals
      for (let i = 0; i < this.petals; i++) {
        const angle = (i * Math.PI * 2) / this.petals;
        ctx.save();
        ctx.rotate(angle);
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.quadraticCurveTo(12, -20, 0, -35);
        ctx.quadraticCurveTo(-12, -20, 0, 0);
        ctx.fillStyle = `hsla(${this.colorHue}, 80%, 65%, 0.8)`;
        ctx.fill();
        ctx.restore();
      }

      ctx.restore();

      // Pollen particles emission for high coverage
      if (this.coverage > 75 && Math.random() < 0.1) {
        particles.push({
          x: x + (Math.random() - 0.5) * 10,
          y: y + (Math.random() - 0.5) * 10,
          vx: (Math.random() - 0.5) * 0.5,
          vy: -Math.random() * 0.8 - 0.2,
          life: 1,
          hue: this.colorHue
        });
      }
    }
  }

  function getBranchHue(name) {
    let hash = 0;
    for (let i = 0; i < name.length; i++) hash = name.charCodeAt(i) + ((hash << 5) - hash);
    return Math.abs(hash) % 360;
  }

  // 3. Core Git Parser & Flora Generator Engine
  function initGarden() {
    // Create base trunk for main
    const startX = window.innerWidth / 2;
    const startY = window.innerHeight - 40;
    branches['main'] = new BranchNode(null, startX, startY, -Math.PI / 2, 70, 0, 'main');
  }

  function parseCommit(commit) {
    let root = branches[commit.branch];

    // If branch doesn't exist, sprout from main or existing node
    if (!root) {
      const parentBranch = branches['main'];
      const sproutOrigin = findDeepestNode(parentBranch);
      const angleOffset = (Math.random() - 0.5) * 0.8;
      
      root = new BranchNode(
        sproutOrigin,
        0, 0,
        sproutOrigin.angle + angleOffset,
        50 + Math.random() * 30,
        sproutOrigin.depth + 1,
        commit.branch
      );
      sproutOrigin.children.push(root);
      branches[commit.branch] = root;
    }

    // Add new growth node to branch
    const targetNode = findDeepestNode(root);
    const branchAngle = targetNode.angle + (Math.random() - 0.5) * (commit.complexity * 0.1);
    const newNode = new BranchNode(
      targetNode,
      0, 0,
      branchAngle,
      40 + Math.random() * 40,
      targetNode.depth + 1,
      commit.branch
    );

    newNode.complexity = commit.complexity;
    newNode.coverage = commit.coverage;

    // High coverage causes floral blooms
    if (commit.coverage >= 50) {
      newNode.bloom = new Bloom(commit.coverage);
    }

    targetNode.children.push(newNode);

    // Log UI update
    const logBox = document.getElementById('log-stream');
    const entry = document.createElement('div');
    entry.className = 'log-entry';
    entry.innerHTML = `<span class="log-branch">[${commit.branch}]</span> ${commit.hash} - Cov: ${commit.coverage}% | Comp: ${commit.complexity}`;
    logBox.insertBefore(entry, logBox.firstChild);
  }

  function findDeepestNode(node) {
    if (node.children.length === 0) return node;
    // Pick random child branch to expand organically
    const child = node.children[Math.floor(Math.random() * node.children.length)];
    return findDeepestNode(child);
  }

  // 4. Interaction & UI Listeners
  const branchSelect = document.getElementById('branch-select');
  const covSlider = document.getElementById('cov-slider');
  const compSlider = document.getElementById('comp-slider');
  const commitBtn = document.getElementById('commit-btn');

  branchSelect.addEventListener('change', e => document.getElementById('branch-val').textContent = e.target.value);
  covSlider.addEventListener('input', e => document.getElementById('cov-val').textContent = e.target.value + '%');
  compSlider.addEventListener('input', e => document.getElementById('comp-val').textContent = e.target.value);

  function pushCommit() {
    const hash = Math.random().toString(16).substr(2, 7);
    parseCommit({
      hash: hash,
      branch: branchSelect.value,
      coverage: parseInt(covSlider.value, 10),
      complexity: parseInt(compSlider.value, 10),
      timestamp: Date.now()
    });
  }

  commitBtn.addEventListener('click', pushCommit);

  // 5. Main Render Loop
  initGarden();

  // Seed initial commit logs
  parseCommit({ hash: 'a1b2c3d', branch: 'main', coverage: 90, complexity: 2 });
  parseCommit({ hash: 'e4f5g6h', branch: 'main', coverage: 85, complexity: 3 });
  parseCommit({ hash: 'f9d8s7a', branch: 'feature/auth', coverage: 60, complexity: 6 });

  function animate(timestamp) {
    globalTime = timestamp;

    // Clear frame with glowing trail effect
    ctx.fillStyle = 'rgba(10, 12, 16, 0.25)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Render soil line
    ctx.beginPath();
    ctx.moveTo(0, canvas.height - 40);
    ctx.lineTo(canvas.width, canvas.height - 40);
    ctx.strokeStyle = '#21262d';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Grow & Render All Flora Trees
    if (branches['main']) {
      branches['main'].grow();
      branches['main'].render(ctx, branches['main'].x, branches['main'].y, 0);
    }

    // Render Pollen Particles
    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.01;

      ctx.beginPath();
      ctx.arc(p.x, p.y, 1.5, 0, Math.PI * 2);
      ctx.fillStyle = `hsla(${p.hue}, 100%, 75%, ${p.life})`;
      ctx.fill();

      if (p.life <= 0) particles.splice(i, 1);
    }

    requestAnimationFrame(animate);
  }

  requestAnimationFrame(animate);
})();