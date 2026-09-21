const WIDTH = process.stdout.columns || 80;
const HEIGHT = process.stdout.rows ? process.stdout.rows - 3 : 22;

let basePressure = 1013.25;
let time = 0;

function getAtmosphericPressure(): number {
    time += 0.08;
    return basePressure + Math.sin(time * 0.4) * 18 + Math.cos(time * 0.15) * 12 + (Math.random() - 0.5) * 3;
}

interface GlassNode {
    x: number;
    y: number;
    vx: number;
    vy: number;
    r: number;
    g: number;
    b: number;
}

const numPanels = 14;
const panels: GlassNode[] = [];

for (let i = 0; i < numPanels; i++) {
    panels.push({
        x: Math.random() * WIDTH,
        y: Math.random() * HEIGHT,
        vx: (Math.random() - 0.5) * 0.6,
        vy: (Math.random() - 0.5) * 0.6,
        r: Math.floor(40 + Math.random() * 215),
        g: Math.floor(40 + Math.random() * 215),
        b: Math.floor(80 + Math.random() * 175)
    });
}

function renderStainedGlass(pressure: number) {
    const pressureDelta = pressure - 1013.25;

    panels.forEach(panel => {
        panel.x += panel.vx * (1 + pressureDelta * 0.04);
        panel.y += panel.vy * (1 + pressureDelta * 0.04);
        if (panel.x < 0 || panel.x >= WIDTH) panel.vx *= -1;
        if (panel.y < 0 || panel.y >= HEIGHT) panel.vy *= -1;
    });

    let frame = '\x1b[H\x1b[J';
    frame += `\x1b[1;36m STAINED GLASS BAROMETER | Pressure: \x1b[33m${pressure.toFixed(2)} hPa\x1b[0m\n`;

    for (let y = 0; y < HEIGHT; y++) {
        let row = '';
        for (let x = 0; x < WIDTH; x++) {
            let minDist1 = Infinity;
            let minDist2 = Infinity;
            let activePanel = panels[0];

            for (const panel of panels) {
                const dx = (panel.x - x) * 2.1; 
                const dy = panel.y - y;
                const dist = Math.sqrt(dx * dx + dy * dy);

                if (dist < minDist1) {
                    minDist2 = minDist1;
                    minDist1 = dist;
                    activePanel = panel;
                } else if (dist < minDist2) {
                    minDist2 = dist;
                }
            }

            const borderThickness = minDist2 - minDist1;

            if (borderThickness < 1.6) {
                row += '\x1b[48;2;15;15;15m \x1b[0m';
            } else {
                const gradientShade = Math.min(1, Math.max(0, minDist1 / 25));
                const red = Math.min(255, Math.max(10, Math.floor(activePanel.r * (1 - gradientShade * 0.35) + pressureDelta * 2.5)));
                const green = Math.min(255, Math.max(10, Math.floor(activePanel.g * (1 - gradientShade * 0.35))));
                const blue = Math.min(255, Math.max(10, Math.floor(activePanel.b * (1 - gradientShade * 0.35) - pressureDelta * 2.5)));

                row += `\x1b[48;2;${red};${green};${blue} \x1b[0m`;
            }
        }
        frame += row + '\n';
    }

    process.stdout.write(frame);
}

console.clear();
const loop = setInterval(() => {
    const livePressure = getAtmosphericPressure();
    renderStainedGlass(livePressure);
}, 90);

process.on('SIGINT', () => {
    clearInterval(loop);
    console.log('\x1b[0m\nWindow simulation closed.');
    process.exit(0);
});