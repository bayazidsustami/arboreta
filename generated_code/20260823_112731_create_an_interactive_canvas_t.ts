// Interactive Code-Garden: Generates flora based on TypeScript/JavaScript source code structure.
// Setup: Create an HTML file with `<canvas id="canvas"></canvas>` and run this compiled TypeScript script.

interface Node {
    type: 'class' | 'function' | 'variable' | 'control' | 'leaf';
    depth: number;
    complexity: number;
    children: Node[];
}

class CodeParser {
    // Light AST-like parser to analyze code syntax structure
    static parse(code: string): Node[] {
        const lines = code.split('\n');
        const rootNodes: Node[] = [];
        const stack: { node: Node; indent: number }[] = [];

        lines.forEach(line => {
            const trimmed = line.trim();
            if (!trimmed || trimmed.startsWith('//') || trimmed.startsWith('/*')) return;

            const indent = line.search(/\S/);
            let type: Node['type'] = 'leaf';
            
            if (/\b(class|interface)\b/.test(trimmed)) type = 'class';
            else if (/\b(function|const\s+\w+\s*=\s*\(|=>)\b/.test(trimmed)) type = 'function';
            else if (/\b(if|for|while|switch|try)\b/.test(trimmed)) type = 'control';
            else if (/\b(let|const|var)\b/.test(trimmed)) type = 'variable';

            const complexity = (trimmed.match(/[{}()[\];,]/g) || []).length + 1;
            const node: Node = { type, depth: 0, complexity, children: [] };

            while (stack.length > 0 && stack[stack.length - 1].indent >= indent) {
                stack.pop();
            }

            if (stack.length === 0) {
                node.depth = 0;
                rootNodes.push(node);
            } else {
                const parent = stack[stack.length - 1].node;
                node.depth = parent.depth + 1;
                parent.children.push(node);
            }

            stack.push({ node, indent });
        });

        return rootNodes;
    }
}

class Plant {
    x: number;
    y: number;
    node: Node;
    growth: number = 0;
    maxGrowth: number = 1;
    colorHue: number;

    constructor(x: number, y: number, node: Node) {
        this.x = x;
        this.y = y;
        this.node = node;
        
        // Color themes based on structural design pattern hints
        switch (node.type) {
            case 'class': this.colorHue = 120; break;     // Deep Emerald / Trees
            case 'function': this.colorHue = 280; break;  // Purple Blossom
            case 'control': this.colorHue = 35; break;    // Golden Vines
            case 'variable': this.colorHue = 190; break;   // Cyan Stems
            default: this.colorHue = 90;
        }
    }

    grow() {
        if (this.growth < this.maxGrowth) {
            this.growth += 0.01;
        }
    }

    draw(ctx: CanvasRenderingContext2D) {
        ctx.save();
        ctx.translate(this.x, this.y);
        this.renderBranch(ctx, this.node, 0, -Math.PI / 2, 50 * this.growth, 8);
        ctx.restore();
    }

    private renderBranch(
        ctx: CanvasRenderingContext2D, 
        node: Node, 
        depth: number, 
        angle: number, 
        length: number, 
        thickness: number
    ) {
        if (length < 2) return;

        const endX = Math.cos(angle) * length * this.growth;
        const endY = Math.sin(angle) * length * this.growth;

        // Draw Branch Stem
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.quadraticCurveTo(
            Math.cos(angle + 0.2) * (length / 2), 
            Math.sin(angle + 0.2) * (length / 2), 
            endX, 
            endY
        );
        ctx.strokeStyle = `hsl(${this.colorHue + depth * 15}, 65%, ${Math.max(20, 50 - depth * 8)}%)`;
        ctx.lineWidth = Math.max(1, thickness);
        ctx.lineCap = 'round';
        ctx.stroke();

        ctx.save();
        ctx.translate(endX, endY);

        // Render Leaves / Flowers at Terminals
        if (node.children.length === 0 || depth > 4) {
            this.renderFlora(ctx, node);
        } else {
            const childCount = node.children.length;
            const spread = Math.PI / (childCount === 1 ? 3 : 2);
            const startAngle = angle - (spread * (childCount - 1)) / 2;

            node.children.forEach((child, index) => {
                const childAngle = childCount === 1 
                    ? angle + (Math.random() - 0.5) * 0.4 
                    : startAngle + index * spread;
                
                const childLength = length * (0.65 + (child.complexity % 3) * 0.1);
                this.renderBranch(ctx, child, depth + 1, childAngle, childLength, thickness * 0.7);
            });
        }

        ctx.restore();
    }

    private renderFlora(ctx: CanvasRenderingContext2D, node: Node) {
        const radius = Math.min(12, Math.max(3, node.complexity * 2)) * this.growth;
        ctx.fillStyle = `hsl(${this.colorHue + 40}, 80%, 60%)`;

        if (node.type === 'class' || node.type === 'function') {
            // Petal Flower Execution
            const petals = node.type === 'class' ? 8 : 5;
            for (let i = 0; i < petals; i++) {
                const petalAngle = (i * Math.PI * 2) / petals;
                ctx.beginPath();
                ctx.arc(
                    Math.cos(petalAngle) * radius, 
                    Math.sin(petalAngle) * radius, 
                    radius / 2, 
                    0, 
                    Math.PI * 2
                );
                ctx.fill();
            }
            ctx.beginPath();
            ctx.arc(0, 0, radius / 3, 0, Math.PI * 2);
            ctx.fillStyle = '#FFF';
            ctx.fill();
        } else {
            // Leaf Formation
            ctx.beginPath();
            ctx.ellipse(0, 0, radius * 1.5, radius * 0.6, Math.PI / 4, 0, Math.PI * 2);
            ctx.fill();
        }
    }
}

class GardenCanvas {
    private canvas: HTMLCanvasElement;
    private ctx: CanvasRenderingContext2D;
    private plants: Plant[] = [];

    constructor(canvasId: string) {
        this.canvas = document.getElementById(canvasId) as HTMLCanvasElement;
        this.ctx = this.canvas.getContext('2d')!;
        this.resize();
        window.addEventListener('resize', () => this.resize());
        this.setupInteractiveInput();
        this.animate();
    }

    private resize() {
        this.canvas.width = window.innerWidth;
        this.canvas.height = window.innerHeight;
    }

    public plantCode(code: string) {
        this.plants = [];
        const astRoots = CodeParser.parse(code);
        const margin = this.canvas.width / (astRoots.length + 1);

        astRoots.forEach((rootNode, i) => {
            const x = margin * (i + 1);
            const y = this.canvas.height - 40;
            this.plants.push(new Plant(x, y, rootNode));
        });
    }

    private setupInteractiveInput() {
        // Create an overlay text area to feed code directly into the garden
        const textArea = document.createElement('textarea');
        textArea.style.position = 'absolute';
        textArea.style.top = '20px';
        textArea.style.left = '20px';
        textArea.style.width = '320px';
        textArea.style.height = '180px';
        textArea.style.background = 'rgba(20, 20, 30, 0.75)';
        textArea.style.color = '#7df9ff';
        textArea.style.border = '1px solid #446655';
        textArea.style.borderRadius = '8px';
        textArea.style.padding = '10px';
        textArea.style.fontFamily = 'monospace';
        textArea.style.backdropFilter = 'blur(5px)';
        textArea.placeholder = '// Paste TS/JS code here to cultivate visual flora...';

        // Default Code Seed (Decorator/Factory Pattern Sample)
        textArea.value = `class ComponentFactory {\n  createWidget(type) {\n    if (type === 'button') {\n      const btn = new Button();\n      return btn;\n    }\n    return null;\n  }\n}\n\nfunction renderGarden() {\n  const garden = [];\n  let seed = 0;\n  while (seed < 10) {\n    garden.push(seed);\n    seed++;\n  }\n}`;

        document.body.appendChild(textArea);

        textArea.addEventListener('input', () => {
            this.plantCode(textArea.value);
        });

        // Seed initial garden state
        this.plantCode(textArea.value);
    }

    private drawGround() {
        const gradient = this.ctx.createLinearGradient(0, this.canvas.height - 50, 0, this.canvas.height);
        gradient.addColorStop(0, '#111d13');
        gradient.addColorStop(1, '#050a06');
        this.ctx.fillStyle = gradient;
        this.ctx.fillRect(0, this.canvas.height - 50, this.canvas.width, 50);
    }

    private animate = () => {
        // Dark soil background clear step
        this.ctx.fillStyle = '#080c0a';
        this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

        this.drawGround();

        this.plants.forEach(plant => {
            plant.grow();
            plant.draw(this.ctx);
        });

        requestAnimationFrame(this.animate);
    };
}

// Instantiate Garden environment when DOM is ready
window.addEventListener('DOMContentLoaded', () => {
    new GardenCanvas('canvas');
});