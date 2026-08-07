<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Self-Cannibalizing CA Clock</title>
  <style>
    body, html {
      margin: 0;
      padding: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
      background-color: #050508;
      font-family: 'Courier New', Courier, monospace;
    }
    canvas {
      display: block;
      width: 100%;
      height: 100%;
    }
    #time-display {
      position: absolute;
      bottom: 20px;
      left: 20px;
      color: rgba(255, 255, 255, 0.85);
      font-size: 1.8rem;
      letter-spacing: 3px;
      pointer-events: none;
      text-shadow: 0 0 10px rgba(0,255,200,0.5);
      z-index: 10;
    }
    #species-info {
      position: absolute;
      top: 20px;
      left: 20px;
      color: rgba(255, 255, 255, 0.6);
      font-size: 0.85rem;
      pointer-events: none;
      z-index: 10;
      line-height: 1.4;
    }
  </style>
</head>
<body>
  <div id="species-info">ACTIVE SPECIES: <span id="addr">0x00000000</span><br>GENOME: <span id="genome">000000</span></div>
  <div id="time-display">00:00:00</div>
  <canvas id="canvas"></canvas>

  <script>
    // Configuration & Setup
    const canvas = document.getElementById('canvas');
    const ctx = canvas.getContext('2d');
    const timeDisplay = document.getElementById('time-display');
    const addrDisplay = document.getElementById('addr');
    const genomeDisplay = document.getElementById('genome');

    const CELL_SIZE = 4;
    let cols, rows, grid, nextGrid;
    let lastSecond = -1;
    let currentSpecies = null;
    let mouseX = -1, mouseY = -1;

    // Resize canvas to fill viewport
    function resize() {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
      cols = Math.floor(canvas.width / CELL_SIZE);
      rows = Math.floor(canvas.height / CELL_SIZE);
      
      // Initialize grids (0 = empty, object = cell data)
      grid = new Array(cols * rows).fill(null);
      nextGrid = new Array(cols * rows).fill(null);
    }

    // Pseudo-memory address generator based on execution timestamp & time parameters
    function generateProcessMemoryAddress(now) {
      const timeSeed = now.getTime() ^ (now.getMilliseconds() << 12);
      const randomOffset = Math.floor(Math.random() * 0xFFFFFF);
      const addr = ((timeSeed ^ randomOffset) >>> 0).toString(16).padStart(8, '0').toUpperCase();
      return `0x${addr}`;
    }

    // Convert hex memory address to species rules & traits
    function createSpeciesFromAddress(memAddr, second) {
      const hash = parseInt(memAddr.slice(2), 16);
      
      // Extract genetic traits from memory bit-shifts
      const r = (hash & 0xFF0000) >> 16;
      const g = (hash & 0x00FF00) >> 8;
      const b = (hash & 0x0000FF);
      
      // Dominance/Predation trait determines which species cannibalizes another
      const dominance = (hash >> 4) % 100;
      
      // Cellular Automaton survival/birth rules (derived from bitmask)
      const birthRule = [ (hash & 1) ? 3 : 2, (hash & 2) ? 3 : 4 ];
      const preyDominanceOffset = (hash % 30) - 15;

      return {
        id: memAddr,
        second: second,
        color: `rgb(${r},${g},${b})`,
        rgb: [r, g, b],
        dominance: dominance,
        birthRule: birthRule,
        preyThreshold: preyDominanceOffset,
        age: 0
      };
    }

    // Seed a new species into the cellular ecosystem
    function spawnSpecies(species) {
      // Spawn in center or at mouse position
      const centerX = mouseX >= 0 ? Math.floor(mouseX / CELL_SIZE) : Math.floor(cols / 2);
      const centerY = mouseY >= 0 ? Math.floor(mouseY / CELL_SIZE) : Math.floor(rows / 2);
      
      const radius = 8;
      for (let dx = -radius; dx <= radius; dx++) {
        for (let dy = -radius; dy <= radius; dy++) {
          if (dx * dx + dy * dy <= radius * radius && Math.random() > 0.3) {
            const x = (centerX + dx + cols) % cols;
            const y = (centerY + dy + rows) % rows;
            const idx = x + y * cols;
            grid[idx] = { ...species, energy: 1.0 };
          }
        }
      }
    }

    // Cellular Automaton Simulation Cycle
    function updateEcosystem() {
      for (let y = 0; y < rows; y++) {
        for (let x = 0; x < cols; x++) {
          const idx = x + y * cols;
          const currentCell = grid[idx];
          
          // Neighbor scanning & predation logic
          let neighborCount = 0;
          let dominantNeighbor = null;
          let highestDominance = -1;

          for (let dy = -1; dy <= 1; dy++) {
            for (let dx = -1; dx <= 1; dx++) {
              if (dx === 0 && dy === 0) continue;
              
              const nx = (x + dx + cols) % cols;
              const ny = (y + dy + rows) % rows;
              const nCell = grid[nx + ny * cols];

              if (nCell) {
                neighborCount++;
                // Cannibalization metric: higher dominance prey on weaker species
                if (nCell.dominance > highestDominance) {
                  highestDominance = nCell.dominance;
                  dominantNeighbor = nCell;
                }
              }
            }
          }

          // Rule Execution
          if (currentCell) {
            // Check if current cell is cannibalized by an aggressive neighboring species
            if (dominantNeighbor && 
                dominantNeighbor.id !== currentCell.id && 
                dominantNeighbor.dominance > currentCell.dominance + currentCell.preyThreshold) {
              // Cell is eaten and converted into the dominant predator species
              nextGrid[idx] = { ...dominantNeighbor, energy: 1.0 };
            } else if (neighborCount < 2 || neighborCount > 4) {
              // Starvation or overcrowding
              nextGrid[idx] = null;
            } else {
              // Survival with energy decay
              nextGrid[idx] = { 
                ...currentCell, 
                energy: Math.max(0.1, currentCell.energy - 0.005) 
              };
            }
          } else {
            // Reproduction into empty space
            if (dominantNeighbor && dominantNeighbor.birthRule.includes(neighborCount)) {
              nextGrid[idx] = { ...dominantNeighbor, energy: 1.0 };
            } else {
              nextGrid[idx] = null;
            }
          }
        }
      }

      // Swap buffer grids
      const temp = grid;
      grid = nextGrid;
      nextGrid = temp;
    }

    // Render Canvas Frame
    function draw() {
      // Semi-transparent background sweep creates light trail effects
      ctx.fillStyle = 'rgba(5, 5, 8, 0.25)';
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      for (let y = 0; y < rows; y++) {
        for (let x = 0; x < cols; x++) {
          const cell = grid[x + y * cols];
          if (cell) {
            const [r, g, b] = cell.rgb;
            ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${cell.energy})`;
            ctx.fillRect(x * CELL_SIZE, y * CELL_SIZE, CELL_SIZE - 0.5, CELL_SIZE - 0.5);
          }
        }
      }
    }

    // Master Animation & Clock Loop
    function tick() {
      const now = new Date();
      const seconds = now.getSeconds();

      // Trigger every new second
      if (seconds !== lastSecond) {
        lastSecond = seconds;
        
        // Format time display
        const pad = n => String(n).padStart(2, '0');
        timeDisplay.textContent = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(seconds)}`;

        // Spawn new species defined by the unique process memory address
        const memAddr = generateProcessMemoryAddress(now);
        currentSpecies = createSpeciesFromAddress(memAddr, seconds);
        
        // Update UI info
        addrDisplay.textContent = currentSpecies.id;
        genomeDisplay.textContent = `DOM:${currentSpecies.dominance} | R:${currentSpecies.rgb[0]} G:${currentSpecies.rgb[1]} B:${currentSpecies.rgb[2]}`;

        spawnSpecies(currentSpecies);
      }

      updateEcosystem();
      draw();
      requestAnimationFrame(tick);
    }

    // Interactive cursor seeding
    window.addEventListener('mousemove', (e) => {
      mouseX = e.clientX;
      mouseY = e.clientY;
    });

    window.addEventListener('mouseleave', () => {
      mouseX = -1;
      mouseY = -1;
    });

    window.addEventListener('resize', resize);

    // Start Clock
    resize();
    tick();
  </script>
</body>
</html>