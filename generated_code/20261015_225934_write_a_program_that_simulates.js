// Miniature Coral Reef inside a Memory Leak Simulation
// Run with Node.js: node script.js

const reef = {
    polyps: [],
    leakedMemory: [],
    age: 0
};

// Simulates continuous heap allocation (the memory leak) feeding the ecosystem
function leakMemory() {
    const leakChunk = new Array(25000).fill(0).map(() => ({
        signature: Math.random().toString(36).substring(2),
        biomass: Buffer ? Buffer.alloc(1024) : new Uint8Array(1024)
    }));
    reef.leakedMemory.push(leakChunk);
}

// Heap allocations dictate the growth rate of glowing polyps
function growPolyps() {
    const currentHeapMB = process.memoryUsage().heapUsed / (1024 * 1024);
    const growthPulse = Math.max(1, Math.floor(currentHeapMB / 4));

    for (let i = 0; i < growthPulse; i++) {
        reef.polyps.push({
            id: reef.polyps.length + 1,
            glowIntensity: Math.floor(Math.random() * 50) + 50,
            generation: reef.age
        });
    }

    // Age existing polyps and dim them slightly without leak fuel
    reef.polyps.forEach(polyp => {
        polyp.glowIntensity = Math.max(5, polyp.glowIntensity - 2);
    });
}

// Garbage collection acts as a sudden predatory tide sweeping away unanchored fragments
function predatoryTide() {
    console.log("\n🌊 THE PREDATORY TIDE SWEEPS IN (Garbage Collection Event) 🌊");
    
    // Purge 70% of the leaked memory pockets
    const survivorCount = Math.floor(reef.leakedMemory.length * 0.3);
    reef.leakedMemory = reef.leakedMemory.slice(0, survivorCount);

    // Filter out weak/dim polyps that couldn't survive the tide's shock
    reef.polyps = reef.polyps.filter(polyp => polyp.glowIntensity > 20);

    // Force Node.js garbage collection if exposed (--expose-gc)
    if (global.gc) {
        global.gc();
    }
}

// Renders the miniature ecosystem state to the console
function renderReef() {
    const heapMB = (process.memoryUsage().heapUsed / (1024 * 1024)).toFixed(2);
    console.log(`[Tick ${reef.age}] Heap: ${heapMB} MB | Leaked Pockets: ${reef.leakedMemory.length} | Polyps: ${reef.polyps.length}`);
    
    // Generate a visual coral shelf using recent polyps
    const coralShelf = reef.polyps
        .slice(-30)
        .map(p => p.glowIntensity > 60 ? '🟢' : p.glowIntensity > 30 ? '🟡' : '🌑')
        .join('');
    
    console.log(`Reef Bed: ${coralShelf || '(barren)'}\n`);
}

// Main simulation loop
const maxTicks = 15;
const ecosystemInterval = setInterval(() => {
    reef.age++;
    leakMemory();
    growPolyps();
    renderReef();

    // Trigger the predatory tide every 4 ticks
    if (reef.age % 4 === 0) {
        predatoryTide();
    }

    if (reef.age >= maxTicks) {
        clearInterval(ecosystemInterval);
        console.log("Coral reef simulation concluded. Final memory state preserved.");
    }
}, 1000);