// Generative Fractal Forest Generator in TypeScript
// Runs in any standard browser environment with an HTML document.

interface TreeBranch {
    x: number;
    y: number;
    length: number;
    angle: number;
    depth: number;
    maxDepth: number;
    color: string;
    progress: number;
    swayOffset: number;
}

class FractalForest {
    private canvas: HTMLCanvasElement;
    private ctx: CanvasRenderingContext2D;
    private branches: TreeBranch[] = [];
    private palette: string[] = ['#2d6a4f', '#52b788', '#b7e4c7', '#d8f3dc'];
    private lastKeyTime: number = Date.now();
    private currentSpeed: number = 1;

    constructor() {
        this.canvas = document.createElement('canvas');
        this.canvas.style.position = 'fixed';
        this.canvas.style.top = '0';
        this.canvas.style.left = '0';
        this.canvas.style.width = '100vw';
        this.canvas.style.height = '100vh';
        this.canvas.style.zIndex = '-1';
        this.canvas.style.background = '#0b090a';
        document.body.appendChild(this.canvas);

        const context = this.canvas.getContext('2d');
        if (!context) throw new Error('Could not get 2D context');
        this.ctx = context;

        this.resize();
        window.addEventListener('resize', () => this.resize());
        window.addEventListener('keydown', (e) => this.handleKeydown(e));

        this.initWeatherPalette();
        this.animate();
    }

    private resize(): void {
        this.canvas.width = window.innerWidth;
        this.canvas.height = window.innerHeight;
    }

    private async initWeatherPalette(): void {
        try {
            // Fetch local weather to dynamically adjust forest ecosystem colors
            const res = await fetch('[https://api.open-meteo.com/v1/forecast?latitude=37.7749&longitude=-122.4194&current_weather=true](https://api.open-meteo.com/v1/forecast?latitude=37.7749&longitude=-122.4194&current_weather=true)');
            const data = await res.json();
            const weatherCode = data.current_weather?.weathercode ?? 0;
            const temp = data.current_weather?.temperature ?? 20;

            if (weatherCode >= 51) {
                // Rainy weather: Deep blues and aqua tones
                this.palette = ['#1d3557', '#457b9d', '#a8dadc', '#f1faee'];
            } else if (weatherCode >= 1 && weatherCode <= 3) {
                // Cloudy weather: Muted sage and slate
                this.palette = ['#4a5759', '#70798c', '#dad2bc', '#f5ebe0'];
            } else if (temp > 25) {
                // Warm weather: Vibrant autumn/sunset hues
                this.palette = ['#bc6c25', '#dda15e', '#fefae0', '#606c38'];
            }
        } catch {
            // Fallback palette remains default lush green
        }
    }

    private handleKeydown(e: KeyboardEvent): void {
        const now = Date.now();
        const delta = now - this.lastKeyTime;
        this.lastKeyTime = now;

        // Calculate typing speed factor: faster typing yields higher multipliers
        this.currentSpeed = Math.max(0.5, Math.min(4.0, 1000 / Math.max(delta, 60)));

        // Spawn a new procedural fractal tree at a random horizontal position
        const startX = Math.random() * this.canvas.width;
        const startY = this.canvas.height;
        const baseLength = 40 + this.currentSpeed * 25;

        this.createBranch(startX, startY, baseLength, -Math.PI / 2, 0, 5 + Math.floor(this.currentSpeed));
    }

    private createBranch(x: number, y: number, length: number, angle: number, depth: number, maxDepth: number): void {
        const colorIndex = Math.min(depth, this.palette.length - 1);
        const branch: TreeBranch = {
            x,
            y,
            length,
            angle,
            depth,
            maxDepth,
            color: this.palette[colorIndex],
            progress: 0,
            swayOffset: Math.random() * Math.PI * 2
        };

        this.branches.push(branch);

        if (depth < maxDepth) {
            const nextLength = length * 0.75;
            const angleSpread = 0.4 + Math.random() * 0.2;

            // Schedule recursive child branches to bloom sequentially
            setTimeout(() => {
                const endX = x + Math.cos(angle) * length;
                const endY = y + Math.sin(angle) * length;
                this.createBranch(endX, endY, nextLength, angle - angleSpread, depth + 1, maxDepth);
                this.createBranch(endX, endY, nextLength, angle + angleSpread, depth + 1, maxDepth);
            }, 150 * (depth + 1));
        }
    }

    private animate = (): void => {
        this.ctx.fillStyle = 'rgba(11, 9, 10, 0.15)';
        this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

        const time = Date.now() * 0.002;

        for (let i = this.branches.length - 1; i >= 0; i--) {
            const b = this.branches[i];
            if (b.progress < 1) {
                b.progress += 0.03 + (this.currentSpeed * 0.01);
                if (b.progress > 1) b.progress = 1;
            }

            const sway = Math.sin(time + b.swayOffset) * 0.03 * (b.depth + 1);
            const currentAngle = b.angle + sway;
            const currentLength = b.length * b.progress;

            const endX = b.x + Math.cos(currentAngle) * currentLength;
            const endY = b.y + Math.sin(currentAngle) * currentLength;

            this.ctx.beginPath();
            this.ctx.moveTo(b.x, b.y);
            this.ctx.lineTo(endX, endY);
            this.ctx.strokeStyle = b.color;
            this.ctx.lineWidth = Math.max(1, (b.maxDepth - b.depth) * 1.2);
            this.ctx.lineCap = 'round';
            this.ctx.stroke();
        }

        requestAnimationFrame(this.animate);
    }
}

new FractalForest();