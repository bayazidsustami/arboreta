/**
 * Self-Sorting Typographic Kaleidoscope
 * 
 * Ingests live system memory metrics (Node.js process memory) and renders them as 
 * animated, harmonically colliding ASCII mandalas using floating-point dithering.
 * Automatically sorts typographic density based on metric fluctuations.
 */

const isNode = typeof process !== 'undefined' && process.versions && process.versions.node;

// Dynamic ASCII Density Ramp (Sorted dynamically by character weight)
let densityChars = [' ', '.', ':', '-', '=', '+', '*', '#', '%', '@', '&', '$', 'W', 'M', '8', '#', '█'];

// Configuration
const WIDTH = 80;
const HEIGHT = 40;
const ASPECT_RATIO = 2.0; // Correction for terminal character height vs width
let time = 0;

/**
 * Custom Floating-Point Dithering Function
 * Maps a continuous [0, 1] scalar value to an ASCII character with spatial dithering noise.
 */
function floatDither(val, x, y, t) {
  // Bayer-like matrix offset using floating-point arithmetic
  const ditherPattern = (Math.sin(x * 12.9898 + y * 78.233 + t) * 43758.5453) % 1;
  const ditheredVal = val + (ditherPattern - 0.5) * 0.15;
  const clamped = Math.max(0, Math.min(1, ditheredVal));
  const index = Math.floor(clamped * (densityChars.length - 1));
  return densityChars[index];
}

/**
 * Self-sorting mechanism for typographic density spectrum.
 * Dynamically re-orders density characters based on memory metric pressure.
 */
function sortDensityRamp(metricFactor) {
  // Sort characters by a combination of original position and metric weight
  densityChars.sort((a, b) => {
    const wA = a.charCodeAt(0) * (1 + metricFactor * 0.1);
    const wB = b.charCodeAt(0) * (1 + metricFactor * 0.1);
    return (wA % 17) - (wB % 17);
  });
}

/**
 * Ingests live system memory metrics.
 */
function getMemoryMetrics() {
  if (isNode) {
    const mem = process.memoryUsage();
    return {
      heapRatio: mem.heapUsed / mem.heapTotal,
      totalUsage: mem.rss / (1024 * 1024), // MB
      external: (mem.external || 0) / (1024 * 1024)
    };
  }
  // Fallback simulated metrics for standard JS environments
  const now = Date.now() / 1000;
  return {
    heapRatio: 0.5 + 0.3 * Math.sin(now * 0.5),
    totalUsage: 128 + 64 * Math.cos(now * 0.3),
    external: 16 + 8 * Math.sin(now * 0.8)
  };
}

/**
 * Renders a single frame of harmonically colliding mandalas.
 */
function renderFrame() {
  const metrics = getMemoryMetrics();
  
  // Re-sort typographic spectrum based on heap consumption metrics
  sortDensityRamp(metrics.heapRatio);

  const buffer = [];
  const centerX = WIDTH / 2;
  const centerY = HEIGHT / 2;
  
  // Harmonic frequencies modulated by live memory usage
  const freq1 = 3 + metrics.heapRatio * 5;
  const freq2 = 2 + (metrics.totalUsage % 10);
  const rotSpeed = 0.05 + (metrics.external % 5) * 0.01;

  time += rotSpeed;

  for (let y = 0; y < HEIGHT; y++) {
    let line = '';
    for (let x = 0; x < WIDTH; x++) {
      // Map screen space to polar coordinates
      const nx = (x - centerX) / (WIDTH / 2) * ASPECT_RATIO;
      const ny = (y - centerY) / (HEIGHT / 2);
      
      let radius = Math.sqrt(nx * nx + ny * ny);
      let angle = Math.atan2(ny, nx);

      // Apply Kaleidoscope symmetry (8-fold symmetry)
      const symmetrySegments = 8;
      angle = Math.abs((angle % (Math.PI * 2 / symmetrySegments)) - (Math.PI / symmetrySegments));

      // Harmonic Mandala Collision Math
      const mandala1 = Math.sin(radius * freq1 - time * 2) * Math.cos(angle * symmetrySegments + time);
      const mandala2 = Math.cos(radius * freq2 + time * 1.5) * Math.sin(angle * (symmetrySegments / 2) - time * 0.8);
      
      // Merge mandalas into scalar field [0, 1]
      let scalarVal = (mandala1 + mandala2 + 2) / 4;
      scalarVal = Math.pow(scalarVal, 1.5); // Enhance contrast

      // Render pixel with floating-point dithering
      line += floatDither(scalarVal, x, y, time);
    }
    buffer.push(line);
  }

  // Clear screen and render ASCII buffer
  const output = (isNode ? '\x1Bc' : '') + buffer.join('\n') + 
                 `\n[Memory Metrics] Heap: ${(metrics.heapRatio * 100).toFixed(1)}% | RSS: ${metrics.totalUsage.toFixed(1)} MB`;
  
  if (isNode) {
    process.stdout.write(output);
  } else {
    console.clear();
    console.log(output);
  }
}

// Main Loop Execution
const FPS = 30;
setInterval(renderFrame, 1000 / FPS);