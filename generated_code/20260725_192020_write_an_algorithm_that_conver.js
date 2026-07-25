// Dynamic Fluid Simulation from Live Execution Stack Trace
// Creates a Canvas fluid visualization where stack frames, recursion, and variable mutations drive fluid dynamics.

(function() {
    // Setup Canvas DOM setup
    let canvas = document.getElementById('fluid-canvas');
    if (!canvas) {
        canvas = document.createElement('canvas');
        canvas.id = 'fluid-canvas';
        document.body.appendChild(canvas);
        document.body.style.margin = '0';
        document.body.style.overflow = 'hidden';
        document.body.style.backgroundColor = '#050508';
    }
    const ctx = canvas.getContext('2d');

    let width = (canvas.width = window.innerWidth);
    let height = (canvas.height = window.innerHeight);

    window.addEventListener('resize', () => {
        width = canvas.width = window.innerWidth;
        height = canvas.height = window.innerHeight;
    });

    // Particle Fluid Physics Parameters
    const PARTICLE_COUNT = 1200;
    let surfaceTension = 0.5; // Altered by variable mutations
    const particles = [];
    const whirlpools = [];

    class Particle {
        constructor(x, y) {
            this.x = x;
            this.y = y;
            this.vx = (Math.random() - 0.5) * 2;
            this.vy = (Math.random() - 0.5) * 2;
            this.radius = 3 + Math.random() * 3;
            this.baseColor = { r: 60, g: 140, b: 240 };
            this.color = { ...this.baseColor };
            this.depth = 0;
        }

        update() {
            // Apply surface tension cohesiveness (drag & elastic attraction to neighbors)
            this.vx *= 0.96 - surfaceTension * 0.03;
            this.vy *= 0.96 - surfaceTension * 0.03;

            // Fluid Whirlpool / Vorticity forces from recursive calls
            whirlpools.forEach((wp) => {
                const dx = this.x - wp.x;
                const dy = this.y - wp.y;
                const distSq = dx * dx + dy * dy + 100;
                const dist = Math.sqrt(distSq);

                if (dist < wp.radius) {
                    const force = (1 - dist / wp.radius) * wp.strength;
                    // Tangential force (swirl)
                    const angle = Math.atan2(dy, dx) + (wp.clockwise ? Math.PI / 2 : -Math.PI / 2);
                    this.vx += Math.cos(angle) * force * 1.5;
                    this.vy += Math.sin(angle) * force * 1.5;

                    // Inward suction (self-similar whirlpool sink)
                    this.vx -= (dx / dist) * force * 0.5;
                    this.vy -= (dy / dist) * force * 0.5;
                }
            });

            this.x += this.vx;
            this.y += this.vy;

            // Screen boundary fluid bouncing
            if (this.x < 0 || this.x > width) this.vx *= -1;
            if (this.y < 0 || this.y > height) this.vy *= -1;
            this.x = Math.max(0, Math.min(width, this.x));
            this.y = Math.max(0, Math.min(height, this.y));
        }

        draw() {
            ctx.beginPath();
            ctx.arc(this.x, this.y, this.radius, 0, Math.PI * 2);
            ctx.fillStyle = `rgba(${this.color.r}, ${this.color.g}, ${this.color.b}, 0.8)`;
            ctx.shadowBlur = 10;
            ctx.shadowColor = `rgb(${this.color.r}, ${this.color.g}, ${this.color.b})`;
            ctx.fill();
            ctx.shadowBlur = 0;
        }
    }

    // Initialize fluid particle grid
    for (let i = 0; i < PARTICLE_COUNT; i++) {
        particles.push(new Particle(Math.random() * width, Math.random() * height));
    }

    // Program Execution Tracer & Fluid Controller
    class ExecutionTracer {
        constructor() {
            this.stack = [];
            this.mutationCount = 0;
        }

        // Trace function call (pushed to stack)
        pushFrame(functionName, args) {
            const depth = this.stack.length;
            const frame = { functionName, args, depth, id: Math.random() };
            this.stack.push(frame);

            // Recursive call detected -> spawn self-similar vortex whirlpool
            const isRecursive = this.stack.filter(f => f.functionName === functionName).length > 1;
            if (isRecursive) {
                const cx = width / 2 + Math.cos(depth) * (depth * 25);
                const cy = height / 2 + Math.sin(depth) * (depth * 25);
                whirlpools.push({
                    x: cx,
                    y: cy,
                    radius: 120 + depth * 30,
                    strength: 0.8 + depth * 0.2,
                    clockwise: depth % 2 === 0,
                    life: 180, // frames
                    depth: depth
                });
            }
        }

        // Trace variable mutation -> alters surface tension
        mutateVariable(varName, value) {
            this.mutationCount++;
            // Dynamic surface tension oscillates based on variable state change frequency
            surfaceTension = 0.1 + Math.abs(Math.sin(this.mutationCount * 0.4)) * 0.8;

            // Shockwave displacement in fluid
            particles.forEach(p => {
                if (Math.random() < 0.15) {
                    p.color = {
                        r: 255,
                        g: Math.floor(100 + surfaceTension * 155),
                        b: 80
                    };
                }
            });
        }

        popFrame() {
            this.stack.pop();
        }
    }

    const tracer = new ExecutionTracer();

    // Simulated Recursive Function for Stack Trace Generation
    function simulatedRecursiveCall(depth, maxDepth) {
        tracer.pushFrame('recursiveTraceFn', { depth });
        tracer.mutateVariable('accumulator', depth * 42);

        if (depth < maxDepth) {
            setTimeout(() => {
                simulatedRecursiveCall(depth + 1, maxDepth);
            }, 150);
        } else {
            setTimeout(() => unwindStack(), 200);
        }
    }

    function unwindStack() {
        if (tracer.stack.length > 0) {
            tracer.popFrame();
            setTimeout(unwindStack, 100);
        } else {
            // Restart execution loop
            setTimeout(() => simulatedRecursiveCall(1, 8 + Math.floor(Math.random() * 5)), 1000);
        }
    }

    // Start program execution trace
    simulatedRecursiveCall(1, 10);

    // Render loop
    function animate() {
        // Semi-transparent background clear for fluid trail motion blur
        ctx.fillStyle = 'rgba(5, 5, 8, 0.25)';
        ctx.fillRect(0, 0, width, height);

        // Update whirlpool decay
        for (let i = whirlpools.length - 1; i >= 0; i--) {
            const wp = whirlpools[i];
            wp.life--;
            wp.strength *= 0.99;
            if (wp.life <= 0) {
                whirlpools.splice(i, 1);
            }
        }

        // Update and draw fluid particles
        particles.forEach(p => {
            p.update();
            p.draw();
        });

        // Overlay status info
        ctx.fillStyle = '#00ffcc';
        ctx.font = '14px monospace';
        ctx.fillText(`Stack Depth: ${tracer.stack.length}`, 20, 30);
        ctx.fillText(`Surface Tension: ${surfaceTension.toFixed(3)}`, 20, 50);
        ctx.fillText(`Active Whirlpools (Recursions): ${whirlpools.length}`, 20, 70);

        requestAnimationFrame(animate);
    }

    animate();
})();