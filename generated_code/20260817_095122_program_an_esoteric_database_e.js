class EsotericEmbroideryDB {
    constructor() {
        this.canvasWidth = 40;
        this.tables = {};
    }

    createTable(tableName, schema) {
        this.tables[tableName] = {
            schema, 
            rows: [],
            grid: Array(12).fill(null).map(() => Array(this.canvasWidth).fill(' '))
        };
    }

    insert(tableName, row) {
        const table = this.tables[tableName];
        if (!table) throw new Error(`Table ${tableName} not found.`);

        for (const [col, constraint] of Object.entries(table.schema)) {
            if (constraint.unique && table.rows.some(r => r[col] === row[col])) {
                this.unravelFabric(table, `Unique constraint violation on '${col}': ${row[col]}`);
                return false;
            }
        }

        table.rows.push(row);
        this.embroiderRow(table, row, table.rows.length - 1);
        return true;
    }

    embroiderRow(table, row, rowIndex) {
        const rowStr = Object.values(row).join(':');
        const startX = (rowIndex * 8) % (this.canvasWidth - 6);
        const y = Math.floor((rowIndex * 8) / (this.canvasWidth - 6)) * 3;

        for (let i = 0; i < rowStr.length; i++) {
            const charCode = rowStr.charCodeAt(i);
            const x = (startX + i) % this.canvasWidth;
            const stitchY = y + (i % 2);
            
            if (stitchY < table.grid.length) {
                const stitches = ['/\\', 'X', '::', '++'];
                table.grid[stitchY][x] = stitches[charCode % stitches.length][0];
            }
        }
    }

    join(tableA, tableB, keyA, keyB) {
        const tA = this.tables[tableA];
        const tB = this.tables[tableB];
        const result = [];
        
        console.log(`\n--- Weaving Thread Dynamics: JOIN ${tableA} & ${tableB} ---`);
        
        for (let rA of tA.rows) {
            for (let rB of tB.rows) {
                if (rA[keyA] === rB[keyB]) {
                    console.log(`[Thread Weave Pass] Matching needle '${rA[keyA]}' -> Interlocking loops X~~X`);
                    result.push({ ...rA, ...rB });
                } else {
                    console.log(`[Thread Weave Skip] Misaligned tension between '${rA[keyA]}' and '${rB[keyB]}'`);
                }
            }
        }
        return result;
    }

    unravelFabric(table, reason) {
        console.log(`\n!!! CONSTRAINT VIOLATION: ${reason} !!!`);
        console.log(`Fabric tension snapped! Unraveling pattern...`);
        
        for (let y = 0; y < table.grid.length; y++) {
            for (let x = 0; x < table.grid[y].length; x++) {
                if (table.grid[y][x] !== ' ') {
                    table.grid[y][x] = '~'; // Frayed thread
                }
            }
        }
        this.renderPattern(table);
        table.rows = []; 
        console.log(`Fabric completely unraveled. Table reset.\n`);
    }

    renderPattern(table) {
        console.log(`+${'-'.repeat(this.canvasWidth)}+`);
        for (let row of table.grid) {
            console.log(`|${row.join('')}|`);
        }
        console.log(`+${'-'.repeat(this.canvasWidth)}+`);
    }
}

// === Demonstration Run ===
const db = new EsotericEmbroideryDB();

console.log("Creating embroidered table 'users'...");
db.createTable('users', { id: { unique: true }, name: {} });
db.insert('users', { id: 1, name: 'Alice' });
db.insert('users', { id: 2, name: 'Bob' });

console.log("\nUsers Fabric Pattern:");
db.renderPattern(db.tables['users']);

console.log("\nCreating embroidered table 'orders'...");
db.createTable('orders', { id: { unique: true }, userId: {}, item: {} });
db.insert('orders', { id: 101, userId: 1, item: 'Silk Thread' });
db.insert('orders', { id: 102, userId: 2, item: 'Needle Set' });

console.log("\nOrders Fabric Pattern:");
db.renderPattern(db.tables['orders']);

// Perform relational JOIN via weaving simulation
const joined = db.join('users', 'orders', 'id', 'userId');
console.log("\nJOIN Results:", JSON.stringify(joined, null, 2));

// Trigger constraint violation to unravel fabric
console.log("\nAttempting duplicate entry insertion...");
db.insert('users', { id: 1, name: 'Eve' });