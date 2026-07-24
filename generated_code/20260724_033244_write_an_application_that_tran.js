<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>System Log Fluid Dynamics</title>
    <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #050508; font-family: monospace; }
        canvas { display: block; position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
        #ui { position: absolute; top: 20px; left: 20px; color: #808090; pointer-events: none; z-index: 10; text-shadow: 0 0 5px #000; }
        .log-entry { margin-top: 4px; font-size: 11px; opacity: 0.8; transition: opacity 0.5s; }
        .log-error { color: #ff3366; font-weight: bold; }
        .log-warn { color: #33ffaa; font-weight: bold; }
        .log-info { color: #00ccff; }
    </style>
</head>
<body>
    <div id="ui">
        <h3 style="margin:0; color:#fff;">SYSTEM FLUID MONITOR</h3>
        <p style="margin:2px 0 10px 0; font-size: 10px;">[GREEN ALGAE = MEMORY LEAKS | BLACK HOLES = ERROR SPIKES]</p>
        <div id="logs"></div>
    </div>
    <canvas id="canvas"></canvas>

    <script>
    // System Log Interactive Fluid Simulator
    // Translates simulated live log streams into particle fluid dynamics, neon algae growth, and gravitational singularities.

    const canvas = document.getElementById('canvas');
    const ctx = canvas.getContext('2d');
    const logUi = document.getElementById('logs');

    let width, height;
    function resize() {
        width = canvas.width = window.innerWidth;
        height = canvas.height = window.innerHeight;
    }
    window.addEventListener('resize', resize);
    resize();

    // Simulation Entities
    const particles = [];
    const algaeClusters = [];
    const blackHoles = [];
    
    // Grid settings for fluid velocity field
    const gridScale = 20;
    let cols, rows, grid;

    function initGrid() {
        cols = Math.ceil(width / gridScale);
        rows = Math.ceil(height / gridScale);
        grid = new Float32Array(cols * rows * 2); // Velocity vectors (vx, vy) per cell
    }
    initGrid();

    // Utility: Simple 2D Simplex Noise approximation for fluid ambient turbulence
    function getNoise(x, y, t) {
        return Math.sin(x * 0.05 + t) * Math.cos(y * 0.05 + t);
    }

    // --- Particle Class (Fluid Base) ---
    class Particle {
        constructor(x, y, color = '#00ccff') {
            this.x = x;
            this.y = y;
            this.vx = (Math.random() - 0.5) * 2;
            this.vy = (Math.random() - 0.5) * 2;
            this.life = 1.0;
            this.decay = Math.random() * 0.005 + 0.002;
            this.color = color;
            this.radius = Math.random() * 2 + 1;
        }

        update() {
            // Sample fluid grid velocity
            const gx = Math.floor(this.x / gridScale);
            const gy = Math.floor(this.y / gridScale);
            if (gx >= 0 && gx < cols && gy >= 0 && gy < rows) {
                const idx = (gy * cols + gx) * 2;
                this.vx += grid[idx] * 0.1;
                this.vy += grid[idx + 1] * 0.1;
            }

            // Apply dampening
            this.vx *= 0.96;
            this.vy *= 0.96;

            // Apply position
            this.x += this.vx;
            this.y += this.vy;
            this.life -= this.decay;

            // Screen boundaries wrap
            if (this.x < 0) this.x = width;
            if (this.x > width) this.x = 0;
            if (this.y < 0) this.y = height;
            if (this.y > height) this.y = 0;
        }

        draw() {
            ctx.fillStyle = this.color;
            ctx.globalAlpha = Math.max(0, this.life);
            ctx.beginPath();
            ctx.arc(this.x, this.y, this.radius, 0, Math.PI * 2);
            ctx.fill();
        }
    }

    // --- Memory Leak Phenomenon: Spreading Neon Algae ---
    class NeonAlgae {
        constructor(x, y) {
            this.x = x;
            this.y = y;
            this.radius = 5;
            this.maxRadius = Math.random() * 80 + 40;
            this.growthRate = Math.random() * 0.2 + 0.1;
            this.branches = [];
            for (let i = 0; i < 5; i++) {
                this.branches.push({
                    angle: Math.random() * Math.PI * 2,
                    dist: 0,
                    speed: Math.random() * 0.5 + 0.2
                });
            }
        }

        update() {
            if (this.radius < this.maxRadius) {
                this.radius += this.growthRate;
            }
            // Grow branches outward like crystalline algae
            this.branches.forEach(b => {
                if (b.dist < this.radius) {
                    b.dist += b.speed;
                }
            });
        }

        draw() {
            ctx.save();
            ctx.translate(this.x, this.y);
            
            // Core Glow
            const grad = ctx.createRadialGradient(0, 0, 0, 0, 0, this.radius);
            grad.addColorStop(0, 'rgba(51, 255, 170, 0.8)');
            grad.addColorStop(0.5, 'rgba(0, 255, 128, 0.2)');
            grad.addColorStop(1, 'rgba(0, 255, 128, 0)');
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.arc(0, 0, this.radius, 0, Math.PI * 2);
            ctx.fill();

            // Organic Filament Structures
            ctx.strokeStyle = '#33ffaa';
            ctx.shadowColor = '#00ffaa';
            ctx.shadowBlur = 10;
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            this.branches.forEach(b => {
                const bx = Math.cos(b.angle) * b.dist;
                const by = Math.sin(b.angle) * b.dist;
                ctx.moveTo(0, 0);
                ctx.lineTo(bx, by);
                ctx.arc(bx, by, 3, 0, Math.PI * 2);
            });
            ctx.stroke();
            ctx.restore();
        }
    }

    // --- Error Spike Phenomenon: Localized Black Hole ---
    class BlackHole {
        constructor(x, y) {
            this.x = x;
            this.y = y;
            this.mass = 300;
            this.radius = 15;
            this.life = 1.0;
            this.decay = 0.003; // Event duration
        }

        update() {
            this.life -= this.decay;
            if (this.life <= 0) return;

            // Gravitational Pull on Particles
            particles.forEach(p => {
                const dx = this.x - p.x;
                const dy = this.y - p.y;
                const distSq = dx * dx + dy * dy;
                const dist = Math.sqrt(distSq);

                if (dist > 5 && dist < 350) {
                    const force = (this.mass * this.life) / distSq;
                    p.vx += (dx / dist) * force;
                    p.vy += (dy / dist) * force;
                }
            });

            // Consume nearby Algae
            for (let i = algaeClusters.length - 1; i >= 0; i--) {
                const a = algaeClusters[i];
                const dist = Math.hypot(this.x - a.x, this.y - a.y);
                if (dist < this.radius + a.radius) {
                    a.radius *= 0.95; // Shrink/Devour algae
                    if (a.radius < 2) algaeClusters.splice(i, 1);
                }
            }
        }

        draw() {
            if (this.life <= 0) return;

            ctx.save();
            ctx.translate(this.x, this.y);

            // Gravitational Lensing / Accretion Glow
            const grad = ctx.createRadialGradient(0, 0, this.radius * 0.5, 0, 0, this.radius * 3);
            grad.addColorStop(0, 'rgba(0, 0, 0, 1)');
            grad.addColorStop(0.4, 'rgba(255, 50, 100, ' + (0.8 * this.life) + ')');
            grad.addColorStop(0.8, 'rgba(150, 0, 255, ' + (0.3 * this.life) + ')');
            grad.addColorStop(1, 'rgba(0, 0, 0, 0)');

            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.arc(0, 0, this.radius * 3, 0, Math.PI * 2);
            ctx.fill();

            // Singularity Core
            ctx.fillStyle = '#000000';
            ctx.beginPath();
            ctx.arc(0, 0, this.radius * (0.8 + Math.random() * 0.1), 0, Math.PI * 2);
            ctx.fill();
            ctx.strokeStyle = '#ff3366';
            ctx.lineWidth = 2;
            ctx.stroke();

            ctx.restore();
        }
    }

    // --- Log Ingestion & Event Translator ---
    function triggerLogEvent(type, message) {
        const x = Math.random() * (width - 200) + 100;
        const y = Math.random() * (height - 200) + 100;

        // UI Feedback
        const logEl = document.createElement('div');
        logEl.className = `log-entry log-${type}`;
        logEl.innerText = `[${new Date().toLocaleTimeString()}] ${type.toUpperCase()}: ${message}`;
        logUi.prepend(logEl);
        if (logUi.children.length > 8) logUi.removeChild(logUi.lastChild);

        // Map Logs to Physical Dynamics
        if (type === 'info') {
            // Emit normal fluid flow stream
            for (let i = 0; i < 25; i++) {
                particles.push(new Particle(x + (Math.random() - 0.5) * 40, y + (Math.random() - 0.5) * 40));
            }
        } else if (type === 'warn') {
            // Memory Leak Event -> Spawns Algae Growth
            algaeClusters.push(new NeonAlgae(x, y));
            // Add dense fluid particles around leak
            for (let i = 0; i < 15; i++) {
                particles.push(new Particle(x, y, '#33ffaa'));
            }
        } else if (type === 'error') {
            // Fatal Error Event -> Spawns Gravitational Black Hole
            blackHoles.push(new BlackHole(x, y));
        }
    }

    // Simulated Log Generator Pipeline
    const logMessages = {
        info: ['GET /api/v1/stream 200 OK', 'Worker pool heartbeat active', 'GC freed 12MB', 'DB Query executed in 4ms'],
        warn: ['WARN: Unreleased buffer handle detected', 'WARN: Memory consumption threshold > 85%', 'WARN: Potential heap leak in socket context'],
        error: ['CRITICAL: NullPointer in thread main', 'FATAL: Buffer Overflow Spike detected', 'ERROR: Connection pool exhausted']
    };

    function simulateLogs() {
        const rand = Math.random();
        if (rand < 0.6) {
            triggerLogEvent('info', logMessages.info[Math.floor(Math.random() * logMessages.info.length)]);
        } else if (rand < 0.85) {
            triggerLogEvent('warn', logMessages.warn[Math.floor(Math.random() * logMessages.warn.length)]);
        } else {
            triggerLogEvent('error', logMessages.error[Math.floor(Math.random() * logMessages.error.length)]);
        }
        setTimeout(simulateLogs, Math.random() * 1500 + 500);
    }
    simulateLogs();

    // User interaction: Click to force error gravity hole
    window.addEventListener('pointerdown', (e) => {
        blackHoles.push(new BlackHole(e.clientX, e.clientY));
        triggerLogEvent('error', `MANUAL_OVERRIDE_INJECTION at (${e.clientX}, ${e.clientY})`);
    });

    // --- Main Simulation Loop ---
    let time = 0;
    function animate() {
        time += 0.01;

        // Visual trailing effect for fluid motion
        ctx.fillStyle = 'rgba(5, 5, 8, 0.2)';
        ctx.fillRect(0, 0, width, height);

        // Update Velocity Field (Fluid Vector Map)
        for (let r = 0; r < rows; r++) {
            for (let c = 0; c < cols; c++) {
                const idx = (r * cols + c) * 2;
                const angle = getNoise(c, r, time) * Math.PI * 4;
                grid[idx] = Math.cos(angle) * 0.5;      // Force Vector X
                grid[idx + 1] = Math.sin(angle) * 0.5;  // Force Vector Y
            }
        }

        // Render & Update Algae (Memory Leaks)
        algaeClusters.forEach(algae => {
            algae.update();
            algae.draw();
        });

        // Render & Update Black Holes (Error Spikes)
        for (let i = blackHoles.length - 1; i >= 0; i--) {
            const bh = blackHoles[i];
            bh.update();
            bh.draw();
            if (bh.life <= 0) blackHoles.splice(i, 1);
        }

        // Render & Update Particles (Fluid Stream)
        for (let i = particles.length - 1; i >= 0; i--) {
            const p = particles[i];
            p.update();
            p.draw();
            if (p.life <= 0) particles.splice(i, 1);
        }

        requestAnimationFrame(animate);
    }

    animate();
    </script>
</body>
</html>