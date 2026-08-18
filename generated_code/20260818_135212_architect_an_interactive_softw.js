// BioSystem Digital Twin: Living Generative Cellular Automaton
// Translates simulated CPU, Memory, and Network telemetry into dynamic CA rules and graphics.

(function() {
  // Setup HTML canvas and layout
  const container = document.createElement('div');
  container.style.cssText = 'position:fixed;top:0;left:0;width:100vw;height:100vh;background:#05070a;color:#a0b0c0;font-family:monospace;overflow:hidden;margin:0;padding:0;user-select:none;';
  
  const canvas = document.createElement('canvas');
  canvas.style.cssText = 'width:100%;height:100%;display:block;filter:contrast(1.2) brightness(1.1);';
  container.appendChild(canvas);

  const hud = document.createElement('div');
  hud.style.cssText = 'position:absolute;top:20px;left:20px;background:rgba(10,15,25,0.75);padding:15px 20px;border-radius:8px;border:1px solid rgba(255,255,255,0.1);backdrop-filter:blur(5px);pointer-events:none;box-shadow:0 8px 32px rgba(0,0,0,0.5);';
  hud.innerHTML = `
    <div style="font-size:14px;font-weight:bold;letter-spacing:2px;margin-bottom:8px;color:#61afef;">SYSTEM SYNTHESIS</div>
    <div style="display:grid;grid-template-columns:auto 1fr;gap:6px 15px;font-size:12px;">
      <span>CPU Load:</span><span id="val-cpu" style="color:#e06c75;">0%</span>
      <span>Mem Alloc:</span><span id="val-mem" style="color:#98c379;">0%</span>
      <span>Net Traffic:</span><span id="val-net" style="color:#d19a66;">0 KB/s</span>
      <span>CA Mutation:</span><span id="val-rule" style="color:#e5c07b;">0x00</span>
    </div>
  `;
  container.appendChild(hud);
  document.body.appendChild(container);

  const ctx = canvas.getContext('2d');
  let width, height, cols, rows, grid, nextGrid;
  const cellSize = 4; // Scale factor for resolution vs performance

  // Telemetry state variables (simulated micro-fluctuations)
  let cpu = 0.5, mem = 0.5, net = 0.5;
  let targetCpu = 0.5, targetMem = 0.5, targetNet = 0.5;
  let phase = 0;

  function resize() {
    width = canvas.width = window.innerWidth;
    height = canvas.height = window.innerHeight;
    cols = Math.floor(width / cellSize);
    rows = Math.floor(height / cellSize);
    grid = new Uint8Array(cols * rows);
    nextGrid = new Uint8Array(cols * rows);
    seedGrid();
  }

  function seedGrid() {
    for (let i = 0; i < grid.length; i++) {
      grid[i] = Math.random() < 0.2 ? Math.floor(Math.random() * 255) : 0;
    }
  }

  // Simulate real-time micro-fluctuations in system telemetry
  function updateTelemetry() {
    phase += 0.02;
    if (Math.random() < 0.05) targetCpu = Math.random();
    if (Math.random() < 0.03) targetMem = Math.min(1, Math.max(0.1, targetMem + (Math.random() - 0.5) * 0.4));
    if (Math.random() < 0.08) targetNet = Math.random();

    // Smooth transition towards targets (micro-fluctuations overlay)
    cpu += (targetCpu - cpu) * 0.05 + (Math.sin(phase * 3) * 0.02);
    mem += (targetMem - mem) * 0.02 + (Math.cos(phase * 1.5) * 0.01);
    net += (targetNet - net) * 0.08 + ((Math.random() - 0.5) * 0.05);

    cpu = Math.min(1, Math.max(0, cpu));
    mem = Math.min(1, Math.max(0, mem));
    net = Math.min(1, Math.max(0, net));

    // Update UI HUD
    document.getElementById('val-cpu').innerText = `${(cpu * 100).toFixed(1)}%`;
    document.getElementById('val-mem').innerText = `${(mem * 100).toFixed(1)}%`;
    document.getElementById('val-net').innerText = `${(net * 1024).toFixed(0)} KB/s`;
    document.getElementById('val-rule').innerText = `0x${Math.floor(net * 255).toString(16).toUpperCase()}`;
  }

  // Generative Automaton Engine driven by Telemetry
  function stepAutomaton() {
    // Net traffic dynamically alters neighbor weighting & survival mutation thresholds
    const ruleShift = Math.floor(net * 8);
    const birthThreshold = 3 + Math.floor(cpu * 2);  // High CPU creates stricter birth rules
    const memoryDecay = Math.max(1, Math.floor((1 - mem) * 15)); // High Mem allows long cell trail lifespans

    for (let y = 0; y < rows; y++) {
      for (let x = 0; x < cols; x++) {
        const idx = x + y * cols;

        // Count active neighbors in 8-connected Moore neighborhood
        let neighbors = 0;
        let sumState = 0;
        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            if (dx === 0 && dy === 0) continue;
            const nx = (x + dx + cols) % cols;
            const ny = (y + dy + rows) % rows;
            const val = grid[nx + ny * cols];
            if (val > 0) {
              neighbors++;
              sumState += val;
            }
          }
        }

        const currentState = grid[idx];
        
        // Dynamic Cellular Rules Mutation
        let nextState = 0;
        if (currentState > 0) {
          // Survival rule mutated by Network traffic
          const surviveCondition = (neighbors === 2 || neighbors === 3 || ((neighbors << ruleShift) & 4));
          nextState = surviveCondition ? Math.max(1, currentState - memoryDecay) : 0;
        } else {
          // Reproduction rule mutated by CPU load
          if (neighbors === birthThreshold || (neighbors === 2 && cpu > 0.75)) {
            const avgColor = neighbors > 0 ? Math.floor(sumState / neighbors) : 255;
            nextState = (avgColor + Math.floor(net * 50)) % 255 || 1;
          }
        }

        // Random micro-sparks triggered by memory pressure
        if (nextState === 0 && Math.random() < (mem * 0.0005)) {
          nextState = Math.floor(cpu * 255);
        }

        nextGrid[idx] = nextState;
      }
    }

    // Swap buffers
    const temp = grid;
    grid = nextGrid;
    nextGrid = temp;
  }

  // Render CA state with fluid color palettes tied to metrics
  function render() {
    const imgData = ctx.createImageData(width, height);
    const data = imgData.data;

    // Palette shifting based on CPU (reds/warm), Memory (greens/blues), Net (vibrant accents)
    const rFactor = cpu * 2.0;
    const gFactor = mem * 2.0;
    const bFactor = net * 2.5 + 0.5;

    for (let y = 0; y < rows; y++) {
      for (let x = 0; x < cols; x++) {
        const cellVal = grid[x + y * cols];
        
        if (cellVal > 0) {
          // Map grid coordinates to Canvas pixel blocks
          const baseColor = cellVal / 255;
          const r = Math.min(255, Math.floor(baseColor * 255 * rFactor));
          const g = Math.min(255, Math.floor((1 - baseColor) * 200 * gFactor));
          const b = Math.min(255, Math.floor(Math.sin(baseColor * Math.PI) * 255 * bFactor));

          for (let py = 0; py < cellSize; py++) {
            for (let px = 0; px < cellSize; px++) {
              const screenX = x * cellSize + px;
              const screenY = y * cellSize + py;
              if (screenX < width && screenY < height) {
                const pIdx = (screenX + screenY * width) * 4;
                data[pIdx] = r;
                data[pIdx + 1] = g;
                data[pIdx + 2] = b;
                data[pIdx + 3] = 255;
              }
            }
          }
        }
      }
    }

    ctx.putImageData(imgData, 0, 0);
  }

  // Main Loop
  function loop() {
    updateTelemetry();
    stepAutomaton();
    render();
    requestAnimationFrame(loop);
  }

  window.addEventListener('resize', resize);
  resize();
  loop();
})();