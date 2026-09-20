// Bonsai Script Interpreter: A programming language where variables are living bonsai trees that wither if test coverage drops below 90%.

class BonsaiTree {
    constructor(name, value) {
        this.name = name;
        this.value = value;
        this.health = 100;
        this.blooms = 4;
        this.alive = true;
    }

    // Renders the visual state of the bonsai variable
    render() {
        if (!this.alive) {
            return `[${this.name}] 🪵 (Dead Stump - Test coverage fell below 90%)`;
        }
        const foliage = '🌿'.repeat(Math.max(0, this.blooms));
        return `[${this.name}] 🪴 Value: ${this.value} | Health: ${this.health}% | ${foliage}`;
    }
}

class BonsaiInterpreter {
    constructor() {
        this.variables = new Map();
        this.testCoverage = 100;
    }

    // Updates test coverage and triggers the wither condition if below 90%
    setCoverage(percentage) {
        this.testCoverage = percentage;
        console.log(`📊 Test Coverage set to ${this.testCoverage}%`);
        if (this.testCoverage < 90) {
            console.log(`⚠️ CRITICAL: Coverage dropped below 90%! The bonsai garden withers into lifeless stumps...`);
            for (let tree of this.variables.values()) {
                tree.alive = false;
                tree.health = 0;
                tree.blooms = 0;
            }
        }
    }

    // Evaluates a script written in Bonsai Script
    eval(script) {
        const lines = script.split('\n');
        for (let rawLine of lines) {
            const line = rawLine.trim();
            if (!line || line.startsWith('//')) continue;

            if (line.startsWith('COVERAGE')) {
                const match = line.match(/COVERAGE\s+(\d+)/);
                if (match) this.setCoverage(parseInt(match[1], 10));
            } 
            else if (line.startsWith('PLANT')) {
                if (this.testCoverage < 90) {
                    console.log(`❌ Soil is barren! Cannot plant variables while coverage is under 90%.`);
                    continue;
                }
                const match = line.match(/PLANT\s+(\w+)\s*=\s*(.+)/);
                if (match) {
                    const [, name, valExpr] = match;
                    const value = Function(`return ${valExpr}`)();
                    this.variables.set(name, new BonsaiTree(name, value));
                    console.log(`🌱 Planted bonsai variable '${name}' successfully.`);
                }
            } 
            else if (line.startsWith('WATER')) {
                const match = line.match(/WATER\s+(\w+)/);
                if (match) {
                    const name = match[1];
                    const tree = this.variables.get(name);
                    if (tree && tree.alive) {
                        tree.blooms += 2;
                        console.log(`💧 Watered '${name}'. Its leaves flourish!`);
                    } else {
                        console.log(`❌ Failed to water '${name}': It is dead or non-existent.`);
                    }
                }
            } 
            else if (line.startsWith('INSPECT')) {
                const match = line.match(/INSPECT\s+(\w+)/);
                if (match) {
                    const name = match[1];
                    const tree = this.variables.get(name);
                    if (tree) {
                        console.log(tree.render());
                    } else {
                        console.log(`❌ Bonsai variable '${name}' not found.`);
                    }
                }
            }
        }
    }
}

// Running a sample program
const program = `
    COVERAGE 95
    PLANT harmony = 100 + 23
    WATER harmony
    INSPECT harmony
    COVERAGE 85
    INSPECT harmony
    PLANT failureTree = 50
`;

const interpreter = new BonsaiInterpreter();
interpreter.eval(program);