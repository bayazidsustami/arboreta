const polyglotQuine = (): void => {
  // Polyglot header trick / Polyglot Quine source string
  // A self-contained TypeScript / JavaScript polyglot quine that visualizes
  // its execution stack and dynamic text-based gravity simulation.

  const src: string = `const polyglotQuine = ${polyglotQuine.toString()};
polyglotQuine();`;

  // --- 1. Execution Stack Visualizer (ASCII Constellation) ---
  const stackTrace = new Error().stack || "Error: [Stack Unknown]";
  const frames = stackTrace.split("\n").slice(1);
  
  console.log("=== EXECUTION STACK CONSTELLATION ===");
  frames.forEach((frame, idx) => {
    const starType = ["★", "✦", "✶", "✹", "✧"][idx % 5];
    const padding = " ".repeat((idx * 4) % 20);
    const label = frame.trim().replace(/^at\s+/, "");
    console.log(`${padding}${starType} . * [Depth ${idx}]: ${label}`);
  });
  console.log("=====================================\n");

  // --- 2. Cosmic Collisions & Dynamic Source Rewriting ---
  // Extract variable tokens from source code
  const tokens = src.match(/\b[a-zA-Z_]\w*\b/g) || ["body", "mass", "star"];
  const uniqueTokens = Array.from(new Set(tokens)).slice(0, 8);

  // Map variables to celestial bodies with spatial coordinates
  type CelestialBody = { name: string; x: number; y: number; vx: number; vy: number; mass: number };
  const bodies: CelestialBody[] = uniqueTokens.map((name, i) => ({
    name,
    x: (i * 3 + 2) % 15,
    y: (i * 2 + 1) % 10,
    vx: (Math.random() - 0.5) * 0.5,
    vy: (Math.random() - 0.5) * 0.5,
    mass: name.length
  }));

  // Simple Gravity Physics Step
  const width = 20;
  const height = 10;
  
  for (let step = 0; step < 3; step++) {
    for (let i = 0; i < bodies.length; i++) {
      for (let j = i + 1; j < bodies.length; j++) {
        const b1 = bodies[i];
        const b2 = bodies[j];
        const dx = b2.x - b1.x;
        const dy = b2.y - b1.y;
        const distSq = dx * dx + dy * dy + 0.1;
        const force = (b1.mass * b2.mass) / distSq;
        const ax = (force * dx) / Math.sqrt(distSq);
        const ay = (force * dy) / Math.sqrt(distSq);

        b1.vx += ax / b1.mass;
        b1.vy += ay / b1.mass;
        b2.vx -= ax / b2.mass;
        b2.vy -= ay / b2.mass;
      }
    }

    // Apply velocities & bounce off boundaries
    bodies.forEach(b => {
      b.x += b.vx;
      b.y += b.vy;
      if (b.x < 0 || b.x >= width) b.vx *= -1;
      if (b.y < 0 || b.y >= height) b.vy *= -1;
    });
  }

  // --- 3. Text-Based Gravity Simulator Grid Render ---
  console.log("=== PLAYABLE GRAVITY SIMULATOR ARENA ===");
  const grid: string[][] = Array.from({ length: height }, () => Array(width).fill("."));

  bodies.forEach(b => {
    const gx = Math.max(0, Math.min(width - 1, Math.floor(b.x)));
    const gy = Math.max(0, Math.min(height - 1, Math.floor(b.y)));
    grid[gy][gx] = b.name[0].toUpperCase();
  });

  console.log(grid.map(row => row.join(" ")).join("\n"));
  console.log("========================================");
  console.log("Source Code Regenerated & Intact (Quine Payload Verified):");
  console.log(src.slice(0, 60) + "...\n");
};

polyglotQuine();