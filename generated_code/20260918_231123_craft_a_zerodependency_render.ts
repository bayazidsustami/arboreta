// Zero-Dependency Non-Euclidean Baroque Kernel Panic Wallpaper Renderer
// This script simulates a rendering engine that continuously sorts raw kernel panic 
// logs using a hyperbolic non-Euclidean distance metric, weaving a shifting baroque 
// ANSI art wallpaper in the terminal.

const WIDTH = 60;
const HEIGHT = 20;

interface LogEntry {
    id: string;
    message: string;
    x: number;
    y: number;
    weight: number;
}

const MOCK_LOGS: string[] = [
    "KERN_EMERG: Fatal exception in interrupt context",
    "BUG: unable to handle kernel NULL pointer dereference at 0000000000000008",
    "IP: [<ffffffff810392a4>] native_safe_halt+0x14/0x20",
    "Call Trace: [<ffffffff81012345>] ? schedule+0x42/0x90",
    "CR2: 0000000000000008, RAX: ffff880123456789",
    "Kernel panic - not syncing: VFS: Unable to mount root fs",
    "SMP alternatives: switching to UP architecture",
    "Hardware error corrected: bank 0 = ffffe80000000000",
    "CPU: 3 PID: 1 Comm: swapper/0 Not tainted 4.15.0-generic",
    "Oops: 0002 [#1] SMP NOPTI"
];

// Initialize logs with pseudo-spatial coordinates for the non-Euclidean plane
function generateLogs(): LogEntry[] {
    return MOCK_LOGS.map((msg, idx) => ({
        id: `PANIC_${idx}`,
        message: msg,
        x: (idx * 3.7) % 10 - 5,
        y: (idx * 2.1) % 10 - 5,
        weight: msg.length
    }));
}

// Non-Euclidean metric (Poincaré disk model approximation)
// Computes curved space distance from a shifting origin (cx, cy)
function nonEuclideanDistance(entry: LogEntry, cx: number, cy: number): number {
    const dx = entry.x - cx;
    const dy = entry.y - cy;
    const r2 = dx * dx + dy * dy;
    const curvatureFactor = Math.max(0.01, 1 - (r2 / 50));
    return Math.sqrt(r2) / curvatureFactor;
}

// Custom non-Euclidean sorting algorithm based on hyperbolic metric warping
function nonEuclideanSort(logs: LogEntry[], time: number): LogEntry[] {
    const cx = Math.sin(time * 0.5) * 3;
    const cy = Math.cos(time * 0.3) * 3;
    
    return [...logs].sort((a, b) => {
        const distA = nonEuclideanDistance(a, cx, cy);
        const distB = nonEuclideanDistance(b, cx, cy);
        return distA - distB;
    });
}

// Render baroque wallpaper grid driven by the sorted kernel logs
function renderWallpaper(sortedLogs: LogEntry[], frame: number): string {
    let output = "\x1b[H\x1b[2J"; // ANSI escape sequence to clear screen and reset cursor
    output += `=== BAROQUE KERNEL PANIC WALLPAPER (Frame ${frame}) ===\n`;
    
    const baroqueChars = ['█', '▓', '▒', '░', '◆', '◇', '╳', '╬', '═', '║', '·', ' '];
    const ansiColors = [
        "\x1b[31m", // Red
        "\x1b[33m", // Yellow
        "\x1b[35m", // Magenta
        "\x1b[36m", // Cyan
        "\x1b[37m"  // White
    ];

    for (let y = 0; y < HEIGHT; y++) {
        let row = "";
        for (let x = 0; x < WIDTH; x++) {
            const logIndex = (x + y + frame) % sortedLogs.length;
            const log = sortedLogs[logIndex];
            
            // Baroque symmetry calculation (mandala folding pattern)
            const symX = Math.abs(x - WIDTH / 2);
            const symY = Math.abs(y - HEIGHT / 2);
            const patternVal = Math.floor(Math.abs(Math.sin((symX * symY + frame + log.weight) * 0.1)) * baroqueChars.length);
            
            const char = baroqueChars[Math.min(patternVal, baroqueChars.length - 1)];
            const color = ansiColors[(x + y + frame + log.weight) % ansiColors.length];
            row += `${color}${char}\x1b[0m`;
        }
        output += row + "\n";
    }

    output += "\nActive Non-Euclidean Top Sorted Logs:\n";
    for (let i = 0; i < Math.min(2, sortedLogs.length); i++) {
        output += ` ⟡ [${sortedLogs[i].id}] ${sortedLogs[i].message.slice(0, 55)}\n`;
    }

    return output;
}

// Main execution loop
function runEngine() {
    let frame = 0;
    let logs = generateLogs();

    const interval = setInterval(() => {
        frame++;
        
        // Continually shift log coordinates in the non-Euclidean space
        logs = logs.map((l, i) => ({
            ...l,
            x: l.x + Math.sin(frame * 0.15 + i) * 0.25,
            y: l.y + Math.cos(frame * 0.15 + i) * 0.25
        }));

        const sortedLogs = nonEuclideanSort(logs, frame * 0.1);
        process.stdout.write(renderWallpaper(sortedLogs, frame));

        if (frame > 120) {
            clearInterval(interval);
            console.log("\nWallpaper rendering sequence completed successfully.");
        }
    }, 100);
}

if (require.main === module) {
    runEngine();
}