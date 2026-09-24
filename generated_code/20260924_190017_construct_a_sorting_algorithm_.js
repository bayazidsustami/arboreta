// Constellation Sorter & Ambient Audio Engine
// Maps dataset values to gravitational masses, simulates orbital physics, 
// renders an ASCII starfield, and synthesizes generative audio on collision.

(function() {
    // 1. Setup Environment & DOM
    const style = document.createElement('style');
    style.innerHTML = `
        body { background: #05050a; color: #00ffcc; font-family: monospace; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; overflow: hidden; }
        #constellation { font-size: 14px; line-height: 14px; white-space: pre; text-shadow: 0 0 8px rgba(0,255,204,0.6); }
    `;
    document.head.appendChild(style);

    const pre = document.createElement('pre');
    pre.id = 'constellation';
    document.body.appendChild(pre);

    // 2. Initialize Audio Context
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    let audioCtx = null;

    function playCollisionTone(freq) {
        if (!audioCtx) return;
        try {
            const osc = audioCtx.createOscillator();
            const gain = audioCtx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
            gain.gain.setValueAtTime(0.05, audioCtx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.5);
            osc.connect(gain);
            gain.connect(audioCtx.destination);
            osc.start();
            osc.stop(audioCtx.currentTime + 0.5);
        } catch(e) {}
    }

    // Enable audio on first user interaction
    window.addEventListener('click', () => {
        if (!audioCtx) audioCtx = new AudioContext();
    }, { once: true });

    // 3. Dataset & Physics Setup (Sorting via Gravity)
    const rawData = [42, 15, 88, 23, 67, 91, 34, 5, 76, 50];
    const sortedData = [...rawData].sort((a, b) => a - b);
    
    const width = 60;
    const height = 25;
    const particles = sortedData.map((val, i) => ({
        id: i,
        value: val,
        mass: val / 10,
        x: Math.random() * width,
        y: Math.random() * height,
        vx: (Math.random() - 0.5) * 0.4,
        vy: (Math.random() - 0.5) * 0.4,
        char: String.fromCharCode(33 + (val % 90))
    }));

    // 4. Main Simulation Loop
    function updatePhysics() {
        const cx = width / 2;
        const cy = height / 2;

        for (let i = 0; i < particles.length; i++) {
            let p = particles[i];
            
            let dx = cx - p.x;
            let dy = cy - p.y;
            let dist = Math.sqrt(dx * dx + dy * dy) || 1;
            
            p.vx += (dx / dist) * 0.02 * (p.mass * 0.1);
            p.vy += (dy / dist) * 0.02 * (p.mass * 0.1);

            p.vx *= 0.98;
            p.vy *= 0.98;

            p.x += p.vx;
            p.y += p.vy;

            if (p.x < 0 || p.x >= width || p.y < 0 || p.y >= height) {
                playCollisionTone(200 + p.value * 5);
                p.vx *= -1;
                p.x = Math.max(0, Math.min(width - 1, p.x));
                p.y = Math.max(0, Math.min(height - 1, p.y));
            }
        }
    }

    function renderAscii() {
        let grid = Array(height).fill(0).map(() => Array(width).fill(' '));

        particles.forEach(p => {
            let gx = Math.floor(p.x);
            let gy = Math.floor(p.y);
            if (gx >= 0 && gx < width && gy >= 0 && gy < height) {
                grid[gy][gx] = p.char;
            }
        });

        for (let i = 0; i < particles.length - 1; i++) {
            let p1 = particles[i];
            let p2 = particles[i+1];
            let x1 = Math.floor(p1.x), y1 = Math.floor(p1.y);
            let x2 = Math.floor(p2.x), y2 = Math.floor(p2.y);
            
            let steps = Math.max(Math.abs(x2 - x1), Math.abs(y2 - y1));
            for (let s = 1; s < steps; s++) {
                let lx = Math.floor(x1 + (x2 - x1) * (s / steps));
                let ly = Math.floor(y1 + (y2 - y1) * (s / steps));
                if (lx >= 0 && lx < width && ly >= 0 && ly < height && grid[ly][lx] === ' ') {
                    grid[ly][lx] = '.';
                }
            }
        }

        pre.textContent = grid.map(row => row.join('')).join('\n') + '\n\n[Click anywhere to initialize ambient audio constellation]';
    }

    function loop() {
        updatePhysics();
        renderAscii();
        requestAnimationFrame(loop);
    }

    loop();
})();