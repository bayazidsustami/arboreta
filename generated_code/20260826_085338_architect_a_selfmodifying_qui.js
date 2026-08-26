/*
 Self-Modifying Quine -> Interactive ASCII Fluid Dynamics -> Genetic Algorithm Mutation
 
 1. Reads its own source code via function stringification.
 2. Simulates Navier-Stokes fluid dynamics (density & velocity grids) in an ASCII canvas.
 3. ASCII ripples act as a cellular automaton that mutates seed values in its own source code.
 4. Renders interactive ASCII fluid simulation where mouse movement or keypresses create ripples.
 5. Periodically re-compiles and re-evaluates its mutated source code dynamically.
*/

(function quineFluidSim(mutationSeed = 104) {
  const WIDTH = 60;
  const HEIGHT = 24;
  const N = WIDTH * HEIGHT;

  // Fluid simulation buffers
  const density = new Float32Array(N);
  const vx = new Float32Array(N);
  const vy = new Float32Array(N);
  const vx0 = new Float32Array(N);
  const vy0 = new Float32Array(N);

  const asciiRamp = " .:-=+*#%@";

  // Create UI overlay
  if (typeof document !== 'undefined') {
    let container = document.getElementById('quine-fluid-app');
    if (!container) {
      document.body.style.backgroundColor = '#0d1117';
      document.body.style.color = '#58a6ff';
      document.body.style.fontFamily = 'monospace';
      document.body.style.display = 'flex';
      document.body.style.flexDirection = 'column';
      document.body.style.alignItems = 'center';
      document.body.style.justifyContent = 'center';
      document.body.style.height = '100vh';
      document.body.style.margin = '0';

      container = document.createElement('div');
      container.id = 'quine-fluid-app';
      
      const screen = document.createElement('pre');
      screen.id = 'screen';
      screen.style.fontSize = '12px';
      screen.style.lineHeight = '12px';
      screen.style.userSelect = 'none';
      screen.style.cursor = 'crosshair';
      
      const meta = document.createElement('div');
      meta.id = 'meta';
      meta.style.marginTop = '10px';
      meta.style.color = '#8b949e';

      container.appendChild(screen);
      container.appendChild(meta);
      document.body.appendChild(container);

      // Interactive ripple creation on mouse drag
      window.addEventListener('mousemove', (e) => {
        const rect = screen.getBoundingClientRect();
        const x = Math.floor(((e.clientX - rect.left) / rect.width) * WIDTH);
        const y = Math.floor(((e.clientY - rect.top) / rect.height) * HEIGHT);
        if (x >= 1 && x < WIDTH - 1 && y >= 1 && y < HEIGHT - 1) {
          const idx = x + y * WIDTH;
          density[idx] += 255;
          vx[idx] += (Math.random() - 0.5) * 10;
          vy[idx] += (Math.random() - 0.5) * 10;
        }
      });
    }
  }

  // Fluid step primitives
  function addSource(x, s, dt) {
    for (let i = 0; i < N; i++) x[i] += dt * s[i];
  }

  function diffuse(b, x, x0, diff, dt) {
    const a = dt * diff * WIDTH * HEIGHT;
    for (let k = 0; k < 4; k++) {
      for (let j = 1; j < HEIGHT - 1; j++) {
        for (let i = 1; i < WIDTH - 1; i++) {
          const idx = i + j * WIDTH;
          x[idx] = (x0[idx] + a * (x[idx - 1] + x[idx + 1] + x[idx - WIDTH] + x[idx + WIDTH])) / (1 + 4 * a);
        }
      }
    }
  }

  function advect(b, d, d0, u, v, dt) {
    const dt0 = dt * WIDTH;
    for (let j = 1; j < HEIGHT - 1; j++) {
      for (let i = 1; i < WIDTH - 1; i++) {
        let x = i - dt0 * u[i + j * WIDTH];
        let y = j - dt0 * v[i + j * WIDTH];
        if (x < 0.5) x = 0.5; if (x > WIDTH - 1.5) x = WIDTH - 1.5;
        if (y < 0.5) y = 0.5; if (y > HEIGHT - 1.5) y = HEIGHT - 1.5;
        const i0 = Math.floor(x), i1 = i0 + 1;
        const j0 = Math.floor(y), j1 = j0 + 1;
        const s1 = x - i0, s0 = 1 - s1;
        const t1 = y - j0, t0 = 1 - t1;
        d[i + j * WIDTH] = s0 * (t0 * d0[i0 + j0 * WIDTH] + t1 * d0[i0 + j1 * WIDTH]) +
                          s1 * (t0 * d0[i1 + j0 * WIDTH] + t1 * d0[i1 + j1 * WIDTH]);
      }
    }
  }

  function stepFluid() {
    diffuse(1, vx0, vx, 0.0001, 0.1);
    diffuse(2, vy0, vy, 0.0001, 0.1);
    advect(1, vx, vx0, vx0, vy0, 0.1);
    advect(2, vy, vy0, vx0, vy0, 0.1);
    diffuse(0, vx0, density, 0.0001, 0.1);
    advect(0, density, vx0, vx, vy, 0.1);

    // Random energy injection guided by current mutation seed
    const randIdx = Math.floor((Math.sin(mutationSeed) * 0.5 + 0.5) * N);
    density[randIdx] += Math.random() * 50;
  }

  let frame = 0;
  function loop() {
    stepFluid();
    
    let asciiFrame = "";
    let totalDensity = 0;

    for (let j = 0; j < HEIGHT; j++) {
      for (let i = 0; i < WIDTH; i++) {
        const val = density[i + j * WIDTH];
        totalDensity += val;
        const charIdx = Math.min(asciiRamp.length - 1, Math.floor((val / 100) * asciiRamp.length));
        asciiFrame += asciiRamp[charIdx] || " ";
      }
      asciiFrame += "\n";
    }

    // Render output
    const screenEl = document.getElementById('screen');
    const metaEl = document.getElementById('meta');
    if (screenEl) screenEl.textContent = asciiFrame;

    frame++;

    // Mutate and Re-compile step
    if (frame % 120 === 0) {
      // Fluid density pattern determines algorithmic mutation
      const rippleHash = Math.floor(totalDensity) % 256;
      const nextMutationSeed = (mutationSeed + rippleHash) % 10000;

      // Quine step: Extract exact function source
      const currentSource = quineFluidSim.toString();
      
      // Self-modifying string mutation: replace seed initialization
      const mutatedSource = currentSource.replace(
        /function quineFluidSim\(mutationSeed = \d+\)/,
        `function quineFluidSim(mutationSeed = ${nextMutationSeed})`
      );

      if (metaEl) {
        metaEl.textContent = `[Gen: ${frame / 120}] Seed: ${mutationSeed} -> Ripple Hash: ${rippleHash} -> Mutated Seed: ${nextMutationSeed}`;
      }

      // Dynamic re-execution of mutated self
      const nextIteration = new Function(`return (${mutatedSource})`)();
      setTimeout(() => nextIteration(nextMutationSeed), 50);
      return;
    }

    requestAnimationFrame(loop);
  }

  loop();
})();