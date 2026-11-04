// Heap Memory Manager & Subway Map Simulator
// Visualizes heap allocations as subway stations and pointers as tracks, 
// where freeing memory while pointers exist triggers real-time train derailments.

class Station {
    constructor(id, size) {
        this.id = id;
        this.size = size;
        this.active = true;
    }
}

class Track {
    constructor(fromStation, toStation, trainName) {
        this.from = fromStation;
        this.to = toStation;
        this.trainName = trainName;
        this.position = 0;
        this.derailed = false;
    }

    update() {
        if (!this.to.active && !this.derailed) {
            this.derailed = true;
            return `💥 CATASTROPHIC DERAILMENT! Train '${this.trainName}' plunged into unmapped void at freed Station #${this.to.id} (Dangling Pointer)!`;
        }
        if (!this.derailed) {
            this.position = (this.position + 33) % 100;
            return `🚆 Train '${this.trainName}' cruising: Station #${this.from.id} ──> Station #${this.to.id} [Progress: ${this.position}%]`;
        }
        return `🔥 WRECKAGE: Train '${this.trainName}' rests in the heap abyss.`;
    }
}

class HeapSubwayManager {
    constructor() {
        this.stations = new Map();
        this.tracks = [];
        this.nextId = 1;
    }

    alloc(size) {
        const id = this.nextId++;
        const station = new Station(id, size);
        this.stations.set(id, station);
        console.log(`🗺️ [ALLOC] Station #${id} constructed (${size} bytes allocated).`);
        return station;
    }

    link(from, to, trainName) {
        const track = new Track(from, to, trainName);
        this.tracks.push(track);
        console.log(`🛤️ [POINTER] Track laid: Station #${from.id} ══> Station #${to.id} [Train: ${trainName}]`);
        return track;
    }

    free(station) {
        station.active = false;
        console.log(`⚠️ [FREE] Station #${station.id} demolished! Pointers pointing here are now DANGLING.`);
    }

    runSimulationSteps(steps = 4) {
        for (let i = 1; i <= steps; i++) {
            console.log(`\n--- Time Tick ${i} ---`);
            for (const track of this.tracks) {
                console.log(track.update());
            }
        }
    }
}

// Execution
const heap = new HeapSubwayManager();

const coreStation = heap.alloc(128);
const cacheStation = heap.alloc(64);
const dbStation = heap.alloc(256);

heap.link(coreStation, cacheStation, "Metro-Express");
heap.link(cacheStation, dbStation, "Freight-Line");

heap.runSimulationSteps(2);

console.log("\n[!] Deallocating cacheStation while Freight-Line still points to it...");
heap.free(cacheStation);

heap.runSimulationSteps(3);