const readline = require('readline');

// Simulated Martian atmospheric pressure logs and wind speeds over a sol cycle
const marsLogs = [
    { sol: 1, pressure: 712, windSpeed: 2.1, text: "SOL 001: THE RED DUST SETTLES ACROSS THE CRATER RIM." },
    { sol: 2, pressure: 708, windSpeed: 4.5, text: "SOL 002: FAint WHISPERS OF GALE FORCE CURRENTS RISING." },
    { sol: 3, pressure: 695, windSpeed: 8.2, text: "SOL 003: PRESSURE DROPS AS A DUST DEVIL STIRS THE PLAINS." },
    { sol: 4, pressure: 680, windSpeed: 12.6, text: "SOL 004: ATMOSPHERIC THINNING ACCELERATES EROSION." },
    { sol: 5, pressure: 672, windSpeed: 18.4, text: "SOL 005: FIERCE WINDS TEAR THROUGH THE OLYMPUS MONS VALLEYS." },
    { sol: 6, pressure: 660, windSpeed: 24.1, text: "SOL 006: MAXIMUM VELOCITY: TYPOGRAPHY DECAYS INTO THE STORM." }
];

// Glitch characters used to simulate wind erosion/decay on typography
const glitchChars = ['░', '▒', '▓', '~', 'x', '*', '#', '>', '<', '-', '.', 'ø'];

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Applies wind decay: higher wind speed means higher probability of character mutation/erasure
function applyWindDecay(line, windSpeed) {
    const decayFactor = Math.min(windSpeed / 25.0, 1.0);
    return line.split('').map(char => {
        if (char === ' ') return ' ';
        if (Math.random() < decayFactor * 0.7) {
            // Pick a random glitch character to represent dust/erosion
            return glitchChars[Math.floor(Math.random() * glitchChars.length)];
        }
        return char;
    }).join('');
}

// Generates an ASCII landscape profile scaled by atmospheric pressure
function generateLandscape(pressure) {
    const height = 8;
    const width = 60;
    // Base height fluctuation derived from pressure values
    const baseline = Math.floor((720 - pressure) / 4) + 2;
    
    let landscape = [];
    for (let y = 0; y < height; y++) {
        let row = "";
        for (let x = 0; x < width; x++) {
            // Create a pseudo-random wave representing Martian dunes/hills
            const hillHeight = Math.floor(Math.sin(x * 0.15 + pressure * 0.01) * 2 + baseline);
            if (y >= height - hillHeight) {
                row += (y === height - hillHeight) ? '_' : 'A';
            } else {
                row += ' ';
            }
        }
        landscape.push(row);
    }
    return landscape;
}

async function runSimulation() {
    // Clear screen and hide cursor for a smooth interactive terminal loop
    process.stdout.write('\x1b[2J\x1b[3J\x1b[H');
    process.stdout.write('\x1b[?25l');

    for (let log of marsLogs) {
        // Move cursor to top-left to redraw frame
        process.stdout.write('\x1b[H');
        
        console.log("=== PROJECT: MARS ATMOSPHERIC TELEMETRY & EROSION ===");
        console.log(`TELEMETRY -> SOL: ${log.sol} | PRESSURE: ${log.pressure} Pa | WIND: ${log.windSpeed} m/s\n`);

        // Render dynamic ASCII landscape based on pressure
        const landscape = generateLandscape(log.pressure);
        landscape.forEach(row => console.log(row));
        console.log("".padEnd(60, '='));

        // Render typography text with progressive wind decay frames
        for (let frame = 0; frame < 5; frame++) {
            process.stdout.write('\x1b[s'); // Save cursor position
            // Move down to text area and print decayed text
            const decayedText = applyWindDecay(log.text, log.windSpeed);
            process.stdout.write(`\n[TYPOGRAPHY DECAY STREAM]: ${decayedText}\x1b[K\n`);
            process.stdout.write('\x1b[u'); // Restore cursor
            await sleep(300);
        }

        await sleep(1200); // Pause before transitioning to the next Sol
    }

    // Restore cursor visibility on exit
    process.stdout.write('\x1b[?25h');
    console.log("\n[SIMULATION COMPLETE: ATMOSPHERE STABILIZED]");
}

runSimulation();