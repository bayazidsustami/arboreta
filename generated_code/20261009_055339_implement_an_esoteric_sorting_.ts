import * as fs from 'fs';

/**
 * Flora Sort: An esoteric sorting algorithm visualization.
 * Datasets are represented as recursive Bézier flower petals blooming along a garden bed.
 * Whenever an array swap occurs, the affected flowers instantly "wither" (droop, desaturate, and shrink).
 */

interface SortStep {
    array: number[];
    swapped: boolean;
    swappedIndices: [number, number];
}

function bubbleSortWithHistory(arr: number[]): SortStep[] {
    const history: SortStep[] = [];
    const a = [...arr];
    history.push({ array: [...a], swapped: false, swappedIndices: [-1, -1] });

    let n = a.length;
    let swapped: boolean;
    do {
        swapped = false;
        for (let i = 0; i < n - 1; i++) {
            if (a[i] > a[i + 1]) {
                const temp = a[i];
                a[i] = a[i + 1];
                a[i + 1] = temp;
                swapped = true;
                history.push({ array: [...a], swapped: true, swappedIndices: [i, i + 1] });
            } else {
                history.push({ array: [...a], swapped: false, swappedIndices: [-1, -1] });
            }
        }
        n--;
    } while (swapped);

    return history;
}

function generateHtmlVisualization(): void {
    const initialArray = [45, 12, 88, 34, 23, 67, 19, 90, 52, 30];
    const history = bubbleSortWithHistory(initialArray);

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Flora Sort - Recursive Bézier Garden</title>
    <style>
        body { background: #090d16; color: #f1f5f9; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; overflow: hidden; }
        h1 { font-size: 1.6rem; margin-bottom: 0.2rem; color: #38bdf8; font-weight: 400; letter-spacing: 2px; }
        canvas { background: #0f172a; border-radius: 16px; box-shadow: 0 20px 40px rgba(0,0,0,0.6); border: 1px solid #1e293b; }
        .info { margin-top: 1.2rem; font-size: 0.95rem; color: #94a3b8; letter-spacing: 1px; }
    </style>
</head>
<body>
    <h1>FLORA SORT : RECURSIVE BÉZIER GARDEN</h1>
    <canvas id="canvas" width="900" height="520"></canvas>
    <div class="info" id="status">Initializing ecosystem...</div>
    <script>
        const history = ${JSON.stringify(history)};
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');
        const statusEl = document.getElementById('status');
        
        let currentStep = 0;
        let witherTimer = 0;

        function drawRecursivePetals(x, y, radius, depth, angle, scale, withered) {
            if (depth === 0) return;
            ctx.save();
            ctx.translate(x, y);
            ctx.rotate(angle);
            
            ctx.beginPath();
            const pLength = radius * scale * (withered ? 0.35 : 1.0);
            ctx.moveTo(0, 0);
            ctx.bezierCurveTo(pLength * 0.4, -pLength * 0.9, pLength * 1.6, -pLength * 0.9, pLength, 0);
            ctx.bezierCurveTo(pLength * 1.6, pLength * 0.9, pLength * 0.4, pLength * 0.9, 0, 0);
            
            ctx.fillStyle = withered ? 'rgba(110, 80, 55, 0.5)' : 'rgba(244, 63, 94, 0.65)';
            ctx.strokeStyle = withered ? '#452c1e' : '#fda4af';
            ctx.lineWidth = 1.2;
            ctx.fill();
            ctx.stroke();

            drawRecursivePetals(pLength * 0.65, 0, radius * 0.5, depth - 1, Math.PI / 4, scale, withered);
            drawRecursivePetals(pLength * 0.65, 0, radius * 0.5, depth - 1, -Math.PI / 4, scale, withered);

            ctx.restore();
        }

        function render() {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            const step = history[currentStep];
            const arr = step.array;
            const maxVal = Math.max(...arr);
            const spacing = canvas.width / (arr.length + 1);

            // Soil Bed
            ctx.strokeStyle = '#334155';
            ctx.lineWidth = 6;
            ctx.beginPath();
            ctx.moveTo(40, canvas.height - 90);
            ctx.lineTo(canvas.width - 40, canvas.height - 90);
            ctx.stroke();

            arr.forEach((val, idx) => {
                const x = spacing * (idx + 1);
                const y = canvas.height - 90;
                const isSwapped = step.swapped && (step.swappedIndices[0] === idx || step.swappedIndices[1] === idx);
                
                if (isSwapped) {
                    witherTimer = 25;
                }
                const withered = witherTimer > 0;

                // Stem
                ctx.strokeStyle = withered ? '#475569' : '#10b981';
                ctx.lineWidth = 3;
                ctx.beginPath();
                ctx.moveTo(x, y);
                const stemHeight = (val / maxVal) * 230;
                ctx.lineTo(x, y - stemHeight);
                ctx.stroke();

                // Flower bloom
                const scale = val / maxVal;
                const numPetals = 6;
                for (let p = 0; p < numPetals; p++) {
                    const angle = (p * 2 * Math.PI) / numPetals;
                    drawRecursivePetals(x, y - stemHeight, 22, 3, angle, scale, withered);
                }

                // Center Bulb
                ctx.beginPath();
                ctx.arc(x, y - stemHeight, 5, 0, 2 * Math.PI);
                ctx.fillStyle = withered ? '#5c2c16' : '#fbbf24';
                ctx.fill();

                // Numerical Value Indicator
                ctx.fillStyle = '#94a3b8';
                ctx.font = '13px monospace';
                ctx.textAlign = 'center';
                ctx.fillText(val, x, y + 28);
            });

            if (witherTimer > 0) witherTimer--;

            statusEl.textContent = \`Step \${currentStep + 1} / \${history.length} — \${step.swapped ? '⚠️ SWAP DETECTED: FLORA WITHERING!' : '🌿 GARDEN BLOOMING & STABLE'}\`;

            setTimeout(() => {
                currentStep = (currentStep + 1) % history.length;
                requestAnimationFrame(render);
            }, 750);
        }

        requestAnimationFrame(render);
    </script>
</body>
</html>`;

    fs.writeFileSync('flora_sort.html', html);
    console.log('Flora Sort simulation successfully compiled! Open flora_sort.html in your browser.');
}

generateHtmlVisualization();