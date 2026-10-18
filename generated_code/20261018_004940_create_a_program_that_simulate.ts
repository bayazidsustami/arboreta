// Virtual Clockwork Universe driven by Traffic Velocity
// Renders a mesmerizing, non-repeating geometric kaleidoscope via SVG paths.

class ClockworkUniverse {
    private svg: SVGSVGElement;
    private width: number = window.innerWidth;
    private height: number = window.innerHeight;
    private trafficVelocity: number = 50; // km/h baseline
    private accumulatedTime: number = 0;
    private lastFrameTime: number = performance.now();
    private symmetry: number = 8;
    private pathGroup: SVGGElement;

    constructor() {
        // Setup full-screen SVG container
        this.svg = document.createElementNS("[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)", "svg");
        this.svg.setAttribute("width", "100%");
        this.svg.setAttribute("height", "100%");
        this.svg.style.position = "fixed";
        this.svg.style.top = "0";
        this.svg.style.left = "0";
        this.svg.style.background = "#050508";
        document.body.appendChild(this.svg);

        // Center group for kaleidoscope transformation
        this.pathGroup = document.createElementNS("[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)", "g");
        this.pathGroup.setAttribute("transform", `translate(${this.width / 2}, ${this.height / 2})`);
        this.svg.appendChild(this.pathGroup);

        window.addEventListener("resize", () => this.onResize());
        this.initTrafficSimulation();
        this.animate();
    }

    private onResize(): void {
        this.width = window.innerWidth;
        this.height = window.innerHeight;
        this.pathGroup.setAttribute("transform", `translate(${this.width / 2}, ${this.height / 2})`);
    }

    // Simulate fluctuating local traffic velocity (e.g., rush hour swells)
    private initTrafficSimulation(): void {
        setInterval(() => {
            const hour = new Date().getHours();
            const rushHourFactor = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19) ? 20 : 60;
            this.trafficVelocity = Math.max(5, Math.min(120, this.trafficVelocity + (Math.random() - 0.5) * 15 + (rushHourFactor - this.trafficVelocity) * 0.05));
        }, 2000);
    }

    // Generate non-repeating geometric path data based on accumulated temporal flux
    private generatePathData(time: number, depth: number): string {
        let d = "";
        let radius = Math.min(this.width, this.height) * 0.35;
        for (let i = 0; i < depth; i++) {
            const angle = (i / depth) * Math.PI * 2 + time * 0.0002;
            const r = radius * (0.3 + 0.7 * Math.abs(Math.sin(time * 0.0005 + i)));
            const x = Math.cos(angle) * r;
            const y = Math.sin(angle) * r;
            
            if (i === 0) {
                d += `M ${x.toFixed(2)} ${y.toFixed(2)}`;
            } else {
                const cx1 = Math.cos(angle - 0.5) * (r * 1.2);
                const cy1 = Math.sin(angle - 0.5) * (r * 1.2);
                d += ` Q ${cx1.toFixed(2)} ${cy1.toFixed(2)}, ${x.toFixed(2)} ${y.toFixed(2)}`;
            }
        }
        return d + " Z";
    }

    private renderKaleidoscope(time: number): void {
        while (this.pathGroup.firstChild) {
            this.pathGroup.removeChild(this.pathGroup.firstChild);
        }

        // Time dilation factor based on traffic velocity
        const dilation = this.trafficVelocity / 50.0;
        const primaryPath = this.generatePathData(this.accumulatedTime * dilation, 12);

        // Render symmetric petals for kaleidoscope effect
        for (let s = 0; s < this.symmetry; s++) {
            const angle = (s / this.symmetry) * 360;
            const pathElem = document.createElementNS("[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)", "path");
            pathElem.setAttribute("d", primaryPath);
            pathElem.setAttribute("transform", `rotate(${angle}) scale(${1 + 0.1 * Math.sin(this.accumulatedTime * 0.001 + s)})`);
            
            const hue = (this.accumulatedTime * 0.05 + s * (360 / this.symmetry) + this.trafficVelocity * 2) % 360;
            pathElem.setAttribute("stroke", `hsla(${hue}, 80%, 65%, 0.8)`);
            pathElem.setAttribute("stroke-width", "1.5");
            pathElem.setAttribute("fill", `hsla(${hue}, 70%, 50%, 0.03)`);
            pathElem.style.mixBlendMode = "screen";

            this.pathGroup.appendChild(pathElem);
        }
    }

    private animate = (): void => {
        const now = performance.now();
        const delta = now - this.lastFrameTime;
        this.lastFrameTime = now;

        this.accumulatedTime += delta * (this.trafficVelocity / 60);

        this.renderKaleidoscope(this.accumulatedTime);
        requestAnimationFrame(this.animate);
    }
}

if (typeof window !== "undefined") {
    window.addEventListener("DOMContentLoaded", () => {
        new ClockworkUniverse();
    });
}