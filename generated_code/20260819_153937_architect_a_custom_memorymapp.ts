import * as readline from 'readline';

/**
 * Memory-Mapped Cellular Automaton Heap Allocator
 * 
 * Maps heap memory allocations directly into the top chamber of an ASCII hourglass.
 * When pointers are freed, their solid memory blocks physically erode into falling sand
 * grains governed by cellular automaton physics. Resting sand in the bottom chamber is
 * periodically swept by a garbage collector beam, reclaiming raw capacity.
 */

enum CellType {
    EMPTY = 0,
    WALL = 1,
    ALLOCATED = 2,
    SAND = 3,
    SETTLED = 4
}

interface Cell {
    type: CellType;
    allocId: number;
    color: string;
}

interface AllocationBlock {
    id: number;
    ptrIndices: number[];
    size: number;
    ttl: number;
    color: string;
}

class MemoryMappedHourglassHeap {
    private readonly width = 37;
    private readonly height = 23;
    private readonly neckY = 10;
    private readonly midX = 18;

    private grid: Cell[][];
    private topChamberCells: { x: number; y: number }[] = [];
    private heapMap: (number | null)[] = [];

    private allocations: AllocationBlock[] = [];
    private nextAllocId = 1;

    private totalReclaimedBytes = 0;
    private gcRunning = false;
    private gcSweepRow = -1;

    // Palette for distinct allocated memory blocks
    private readonly colors = [
        '\x1b[36m', // Cyan
        '\x1b[32m', // Green
        '\x1b[35m', // Magenta
        '\x1b[34m', // Blue
        '\x1b[93m', // Bright Yellow
        '\x1b[96m', // Bright Cyan
        '\x1b[95m', // Bright Magenta
    ];

    constructor() {
        this.grid = Array.from({ length: this.height }, () =>
            Array.from({ length: this.width }, () => ({
                type: CellType.EMPTY,
                allocId: 0,
                color: ''
            }))
        );

        this.initHourglassGeometry();
    }

    /**
     * Initializes the ASCII hourglass wall boundaries and maps internal top-chamber slots to virtual RAM addresses.
     */
    private initHourglassGeometry(): void {
        for (let y = 0; y < this.height; y++) {
            const radius = this.getRadiusAtY(y);
            const leftWall = this.midX - radius - 1;
            const rightWall = this.midX + radius + 1;

            for (let x = 0; x < this.width; x++) {
                if (x === leftWall || x === rightWall) {
                    this.grid[y][x] = { type: CellType.WALL, allocId: 0, color: '\x1b[90m' };
                } else if (x > leftWall && x < rightWall && y < this.neckY) {
                    this.topChamberCells.push({ x, y });
                }
            }
        }
        this.heapMap = new Array(this.topChamberCells.length).fill(null);
    }

    private getRadiusAtY(y: number): number {
        if (y < this.neckY) {
            return (this.neckY - y) + 1;
        } else if (y === this.neckY) {
            return 1;
        } else {
            return (y - this.neckY) + 1;
        }
    }

    /**
     * Allocates contiguous or fragmented memory slots in the top chamber.
     */
    public malloc(size: number, ttl: number): boolean {
        let freeCount = 0;
        let startIndex = -1;

        // 1. Try contiguous first-fit allocation
        for (let i = 0; i < this.heapMap.length; i++) {
            if (this.heapMap[i] === null) {
                if (freeCount === 0) startIndex = i;
                freeCount++;
                if (freeCount === size) break;
            } else {
                freeCount = 0;
                startIndex = -1;
            }
        }

        const allocatedIndices: number[] = [];
        if (freeCount === size && startIndex !== -1) {
            for (let i = startIndex; i < startIndex + size; i++) {
                allocatedIndices.push(i);
            }
        } else {
            // 2. Fall back to fragmented slot collection if memory is tight
            for (let i = 0; i < this.heapMap.length && allocatedIndices.length < size; i++) {
                if (this.heapMap[i] === null) {
                    allocatedIndices.push(i);
                }
            }
        }

        if (allocatedIndices.length < size) {
            return false; // Out of Memory
        }

        const id = this.nextAllocId++;
        const color = this.colors[id % this.colors.length];

        for (const idx of allocatedIndices) {
            this.heapMap[idx] = id;
            const pos = this.topChamberCells[idx];
            this.grid[pos.y][pos.x] = {
                type: CellType.ALLOCATED,
                allocId: id,
                color
            };
        }

        this.allocations.push({ id, ptrIndices: allocatedIndices, size, ttl, color });
        return true;
    }

    /**
     * Unpins dead pointers, converting static memory blocks into active falling sand particles.
     */
    public free(allocId: number): void {
        const index = this.allocations.findIndex(a => a.id === allocId);
        if (index === -1) return;

        const alloc = this.allocations[index];
        this.allocations.splice(index, 1);

        for (const idx of alloc.ptrIndices) {
            this.heapMap[idx] = null;
            const pos = this.topChamberCells[idx];

            if (this.grid[pos.y][pos.x].type === CellType.ALLOCATED) {
                this.grid[pos.y][pos.x] = {
                    type: CellType.SAND,
                    allocId: 0,
                    color: '\x1b[33m' // Gold sand grain
                };
            }
        }
    }

    /**
     * Triggers a Garbage Collector sweep across the bottom chamber.
     */
    public collectGarbage(): void {
        if (!this.gcRunning) {
            this.gcRunning = true;
            this.gcSweepRow = this.height - 2;
        }
    }

    private stepGC(): void {
        if (!this.gcRunning) return;

        if (this.gcSweepRow > this.neckY) {
            for (let x = 0; x < this.width; x++) {
                const cell = this.grid[this.gcSweepRow][x];
                if (cell.type === CellType.SETTLED || cell.type === CellType.SAND) {
                    this.grid[this.gcSweepRow][x] = { type: CellType.EMPTY, allocId: 0, color: '' };
                    this.totalReclaimedBytes++;
                }
            }
            this.gcSweepRow--;
        } else {
            this.gcRunning = false;
            this.gcSweepRow = -1;
        }
    }

    /**
     * Ticks cellular automaton gravity and pointer lifecycle.
     */
    public physicsTick(): void {
        if (this.gcRunning) {
            this.stepGC();
        }

        // Process grid bottom-to-top to ensure proper sand cascading
        for (let y = this.height - 2; y >= 0; y--) {
            const xIndices = Array.from({ length: this.width }, (_, i) => i).sort(() => Math.random() - 0.5);

            for (const x of xIndices) {
                if (this.grid[y][x].type === CellType.SAND) {
                    this.updateSandCell(x, y);
                }
            }
        }

        // Age live allocation pointers
        for (const alloc of [...this.allocations]) {
            alloc.ttl--;
            if (alloc.ttl <= 0) {
                this.free(alloc.id);
            }
        }
    }

    private updateSandCell(x: number, y: number): void {
        const below = y + 1;
        if (below >= this.height) {
            this.grid[y][x].type = CellType.SETTLED;
            return;
        }

        // Gravity 1: Fall straight down
        if (this.grid[below][x].type === CellType.EMPTY) {
            this.moveCell(x, y, x, below);
            return;
        }

        // Gravity 2: Fall diagonally down-left or down-right
        const dirs = Math.random() < 0.5 ? [-1, 1] : [1, -1];
        for (const dx of dirs) {
            const nx = x + dx;
            if (nx >= 0 && nx < this.width && this.grid[below][nx].type === CellType.EMPTY) {
                this.moveCell(x, y, nx, below);
                return;
            }
        }

        // Settle when trapped in lower chamber
        if (y > this.neckY) {
            this.grid[y][x].type = CellType.SETTLED;
            this.grid[y][x].color = '\x1b[31m'; // Resting garbage color
        }
    }

    private moveCell(fromX: number, fromY: number, toX: number, toY: number): void {
        this.grid[toY][toX] = this.grid[fromY][fromX];
        this.grid[fromY][fromX] = { type: CellType.EMPTY, allocId: 0, color: '' };
    }

    /**
     * Renders live ASCII hourglass frame to stdout.
     */
    public render(): void {
        let output = '\x1b[H'; // Return cursor to top-left
        output += '\x1b[1m=== MEMORY-MAPPED CELLULAR AUTOMATON HEAP ===\x1b[0m\n';

        const usedHeap = this.heapMap.filter(x => x !== null).length;
        const totalHeap = this.heapMap.length;

        output += `Heap: ${usedHeap}/${totalHeap} B | Active Ptrs: ${this.allocations.length} | Reclaimed: ${this.totalReclaimedBytes} B\n`;
        output += `Status: ${this.gcRunning ? '\x1b[42m\x1b[30m SWEEPING GARBAGE \x1b[0m' : '\x1b[32m ALLOCATING \x1b[0m'}\n\n`;

        for (let y = 0; y < this.height; y++) {
            let rowStr = '  ';
            const isGcRow = this.gcRunning && y === this.gcSweepRow;

            for (let x = 0; x < this.width; x++) {
                if (isGcRow && this.grid[y][x].type !== CellType.WALL) {
                    rowStr += '\x1b[42m\x1b[30m~\x1b[0m'; // Laser beam visual
                    continue;
                }

                const cell = this.grid[y][x];
                switch (cell.type) {
                    case CellType.WALL:
                        rowStr += `${cell.color}#\x1b[0m`;
                        break;
                    case CellType.ALLOCATED:
                        rowStr += `${cell.color}█\x1b[0m`;
                        break;
                    case CellType.SAND:
                        rowStr += `${cell.color}•\x1b[0m`;
                        break;
                    case CellType.SETTLED:
                        rowStr += `${cell.color}░\x1b[0m`;
                        break;
                    case CellType.EMPTY:
                        rowStr += ' ';
                        break;
                }
            }
            output += rowStr + '\n';
        }

        output += '\n\x1b[90m[Legend] \x1b[0m█ Allocated Memory | \x1b[33m•\x1b[0m Eroding Pointer | \x1b[31m░\x1b[0m Settled Garbage\n';
        output += '\x1b[90mPress Ctrl+C to stop simulation.\x1b[0m\n';

        process.stdout.write(output);
    }
}

// Interactive Simulation Driver
function startSimulator(): void {
    const heap = new MemoryMappedHourglassHeap();
    process.stdout.write('\x1b[2J\x1b[?25l'); // Clear terminal screen and hide cursor

    let tick = 0;

    const timer = setInterval(() => {
        tick++;

        // Randomly simulate malloc allocation requests
        if (tick % 2 === 0 && Math.random() < 0.7) {
            const allocSize = Math.floor(Math.random() * 5) + 2;
            const ttl = Math.floor(Math.random() * 25) + 10;
            const success = heap.malloc(allocSize, ttl);

            // Automatically trigger GC if OOM
            if (!success) {
                heap.collectGarbage();
            }
        }

        // Periodic maintenance GC sweep
        if (tick % 50 === 0) {
            heap.collectGarbage();
        }

        heap.physicsTick();
        heap.render();
    }, 60);

    process.on('SIGINT', () => {
        clearInterval(timer);
        process.stdout.write('\x1b[?25h\x1b[2J\x1b[H');
        console.log('Heap simulator stopped.');
        process.exit(0);
    });
}

startSimulator();