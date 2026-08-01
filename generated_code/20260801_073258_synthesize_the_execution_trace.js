// ASCII Topographical Map Synthesizer for Self-Modifying Execution Traces
// Maps call stack depth to terrain elevation and simulates catastrophic erosion on stack overflow.

(function synthesizeExecutionTrace() {
  const WIDTH = 64;
  const HEIGHT = 16;
  const ELEVATION_CHARS = [' ', '.', ':', '-', '=', '+', '*', '%', '@', '#'];
  const EROSION_CHARS = ['~', '≈', '░', '▒', '.'];

  // Initialize elevation grid
  const grid = Array.from({ length: HEIGHT }, () => Array(WIDTH).fill(0));
  let pc = 0; // Program counter / horizontal coordinate
  
  // Self-modifying instruction routine
  const program = [
    { op: 'BUILD', weight: 1 },
    { op: 'MUTATE', target: 0 },
    { op: 'SPLIT', branch: 2 },
    { op: 'RECURSE' }
  ];

  // Render current topographical grid state to console
  function render(statusMessage) {
    let output = `\n=== TOPOGRAPHICAL MAP EXECUTION TRACE ===\nSTATUS: ${statusMessage}\n`;
    output += '┌' + '─'.repeat(WIDTH) + '┐\n';
    
    for (let y = HEIGHT - 1; y >= 0; y--) {
      let line = '│';
      for (let x = 0; x < WIDTH; x++) {
        const cell = grid[y][x];
        if (typeof cell === 'string') {
          line += cell; // Eroded cell
        } else {
          const idx = Math.min(Math.floor(cell), ELEVATION_CHARS.length - 1);
          line += ELEVATION_CHARS[idx];
        }
      }
      output += line + '│\n';
    }
    output += '└' + '─'.repeat(WIDTH) + '┘\n';
    console.log(output);
  }

  // Recursive self-modifying engine
  function executeTrace(depth) {
    const x = pc % WIDTH;
    const y = Math.min(depth, HEIGHT - 1);

    // Dynamic self-modification: modify program weights based on stack depth
    program[0].weight = (program[0].weight + depth) % 5;
    program[1].target = (depth * 3) % program.length;

    // Record terrain elevation based on call stack depth
    grid[y][x] = Math.min(ELEVATION_CHARS.length - 1, grid[y][x] + depth * 0.8);
    pc++;

    // Artificial stack limit trigger to guarantee overflow scenario
    if (depth >= 18) {
      throw new RangeError("Maximum call stack size exceeded (Stack Overflow)");
    }

    // Branching recursive call simulating self-modifying expansion
    executeTrace(depth + 1);
    if (program[0].weight > 2) {
      executeTrace(depth + 1);
    }
  }

  // Trigger catastrophic erosion on stack overflow exception
  function triggerCatastrophicErosion() {
    for (let y = HEIGHT - 1; y >= 0; y--) {
      for (let x = 0; x < WIDTH; x++) {
        if (grid[y][x] > 0) {
          // Structural integrity failure increases with elevation
          const vulnerability = (y / HEIGHT) + (Math.random() * 0.4);
          if (vulnerability > 0.35) {
            const eIdx = Math.floor(Math.random() * EROSION_CHARS.length);
            grid[y][x] = EROSION_CHARS[eIdx]; // Collapse peak into debris/erosion symbol
          }
        }
      }
    }
  }

  // Execution runner with exception handling
  try {
    executeTrace(1);
  } catch (error) {
    if (error instanceof RangeError) {
      triggerCatastrophicErosion();
      render("CRITICAL EXCEPTION: STACK OVERFLOW -> CATASTROPHIC EROSION DETECTED");
      return;
    }
    throw error;
  }

  render("EXECUTION COMPLETED NORMALLY");
})();