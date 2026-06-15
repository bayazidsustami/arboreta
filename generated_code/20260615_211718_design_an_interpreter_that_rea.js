// Cellular‑Verse Mandala – self‑contained demo
(() => {
  const canvas = document.createElement('canvas');
  document.body.style.margin = 0;
  document.body.style.overflow = 'hidden';
  document.body.appendChild(canvas);
  const ctx = canvas.getContext('2d');

  // resize
  const resize = () => {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  };
  window.addEventListener('resize', resize);
  resize();

  // ---- Poem → rule parser -------------------------------------------------
  // Example poem: each stanza separated by blank line, first line holds rule like "B3/S23"
  const poem = `
B3/S23
Life dances.
B2/S
Lonely cells.
B36/S125
Fire bursts.
`;

  // split into stanzas, ignore empty lines
  const stanzas = poem.trim().split('\n\n').map(s => s.trim().split('\n'));
  // each stanza yields {birth:Set, survive:Set, color:string}
  const layers = stanzas.map((lines, i) => {
    const ruleLine = lines[0].trim().toUpperCase();
    const m = ruleLine.match(/B(\d*)\/S(\d*)/);
    const birth = new Set((m?.[1]||'').split('').map(Number));
    const survive = new Set((m?.[2]||'').split('').map(Number));
    // assign a hue based on index
    const hue = (i * 137) % 360; // golden angle
    const color = `hsla(${hue},80%,60%,0.6)`;
    return {birth, survive, color, grid: null, next: null};
  });

  // ---- Grid init ---------------------------------------------------------
  const size = 200; // cells per side
  const cellSize = Math.min(canvas.width, canvas.height) / size;

  // create random initial grid for each layer
  layers.forEach(layer => {
    layer.grid = new Uint8Array(size * size);
    layer.next = new Uint8Array(size * size);
    for (let i = 0; i < layer.grid.length; i++) {
      layer.grid[i] = Math.random() < 0.15 ? 1 : 0;
    }
  });

  // ---- Simulation step ----------------------------------------------------
  const step = () => {
    layers.forEach(layer => {
      const {birth, survive, grid, next} = layer;
      for (let y = 0; y < size; y++) {
        for (let x = 0; x < size; x++) {
          const idx = y * size + x;
          let cnt = 0;
          // Moore neighbourhood
          for (let dy = -1; dy <= 1; dy++) {
            const ny = (y + dy + size) % size;
            for (let dx = -1; dx <= 1; dx++) {
              if (dx === 0 && dy === 0) continue;
              const nx = (x + dx + size) % size;
              cnt += grid[ny * size + nx];
            }
          }
          const alive = grid[idx] === 1;
          next[idx] = (alive && survive.has(cnt)) || (!alive && birth.has(cnt)) ? 1 : 0;
        }
      }
      // swap buffers
      layer.grid.set(next);
    });
  };

  // ---- Draw mandala -------------------------------------------------------
  const draw = () => {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    const cx = canvas.width / 2;
    const cy = canvas.height / 2;
    const radius = Math.min(cx, cy) * 0.9;

    layers.forEach((layer, li) => {
      const angle = (li / layers.length) * Math.PI * 2;
      const offsetX = Math.cos(angle) * radius * 0.2;
      const offsetY = Math.sin(angle) * radius * 0.2;

      ctx.save();
      ctx.translate(cx + offsetX, cy + offsetY);
      ctx.rotate(angle);
      for (let y = 0; y < size; y++) {
        for (let x = 0; x < size; x++) {
          if (layer.grid[y * size + x]) {
            ctx.fillStyle = layer.color;
            ctx.fillRect(
              (x - size / 2) * cellSize,
              (y - size / 2) * cellSize,
              cellSize,
              cellSize
            );
          }
        }
      }
      ctx.restore();
    });
  };

  // ---- Animation loop -----------------------------------------------------
  const fps = 12;
  let last = 0;
  const loop = t => {
    if (t - last > 1000 / fps) {
      step();
      draw();
      last = t;
    }
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
})();