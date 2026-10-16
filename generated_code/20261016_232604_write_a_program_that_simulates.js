// Prime-Driven Meteorological Ecosystem & Ambient Drone Simulator
// Run with: node script.js

const readline = require('readline');

// Computes prime factorizations to drive the ecosystem state
function getPrimeFactors(n) {
    const factors = [];
    let d = 2;
    let temp = n;
    while (temp > 1) {
        while (temp % d === 0) {
            factors.push(d);
            temp /= d;
        }
        d++;
        if (d * d > temp) {
            if (temp > 1) {
                factors.push(temp);
                break;
            }
        }
    }
    return factors.length ? factors : [1];
}

let tick = 2;
const width = 64;
const height = 16;

function renderEcosystem() {
    tick++;
    const factors = getPrimeFactors(tick);
    
    // Derive meteorological parameters from prime factor characteristics
    const sumFactors = factors.reduce((a, b) => a + b, 0);
    const maxFactor = Math.max(...factors);
    const uniqueFactors = new Set(factors).size;

    const barometricPressure = 950 + (sumFactors % 120) + (maxFactor % 30); // hPa
    const temperature = 10 + ((sumFactors * 2) % 30) - (uniqueFactors * 3); // °C
    const humidity = Math.min(100, (maxFactor * 7) % 100); // %
    const droneFrequency = (barometricPressure * 1.25).toFixed(2); // Hz mirror

    // Construct ASCII weather canvas
    let grid = Array(height).fill(0).map(() => Array(width).fill(' '));

    for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
            const wave = Math.sin(x * 0.15 + tick * 0.1) * Math.cos(y * 0.25 + maxFactor * 0.05);
            const pressureThreshold = (barometricPressure - 950) / 120;
            
            if (wave > 0.4 - pressureThreshold * 0.4) {
                grid[y][x] = humidity > 65 ? (y > height / 2 ? '|' : '▓') : '▒';
            } else if (y === height - 1) {
                grid[y][x] = '_';
            }
        }
    }

    // Render to terminal
    console.clear();
    console.log(`================================================================`);
    console.log(` 🌀 PRIME METEOROLOGICAL ECOSYSTEM (Tick: ${tick})`);
    console.log(`================================================================`);
    console.log(` Factors : [${factors.join(', ')}]`);
    console.log(` Pressure: ${barometricPressure} hPa  | Temp: ${temperature}°C | Humidity: ${humidity}%`);
    console.log(`----------------------------------------------------------------`);
    console.log(grid.map(row => row.join('')).join('\n'));
    console.log(`----------------------------------------------------------------`);
    console.log(` [AUDIO DRONE] Continuous Oscillator Frequency: ${droneFrequency} Hz`);
    console.log(`================================================================`);
}

// Run simulation loop at 10 fps
setInterval(renderEcosystem, 100);