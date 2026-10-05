/**
 * Weather-Driven Cellular Automata Font Renderer
 * 
 * This script simulates fetching a local weather report, converts it into a binary stream,
 * evolves it using a 1-dimensional cellular automaton (Rule 30), and maps the resulting 
 * spatial-temporal grid into dynamic glyph kerning values for an ASCII font renderer.
 */

// Simulated weather payload converted to a binary bitstream
const fetchWeatherBinary = (): number[] => {
    const weatherData = { temp: 21, condition: "Sunny", humidity: 45, pressure: 1013 };
    const jsonStr = JSON.stringify(weatherData);
    return jsonStr.split('').flatMap(char => {
        const bin = char.charCodeAt(0).toString(2).padStart(8, '0');
        return bin.split('').map(Number);
    });
};

// 1D Cellular Automaton (Rule 30) simulation engine
const runCellularAutomaton = (initialState: number[], generations: number): number[][] => {
    const grid: number[][] = [initialState];
    let current = [...initialState];

    for (let g = 0; g < generations; g++) {
        const next: number[] = new Array(current.length);
        for (let i = 0; i < current.length; i++) {
            const left = i > 0 ? current[i - 1] : 0;
            const center = current[i];
            const right = i < current.length - 1 ? current[i + 1] : 0;
            // Rule 30 formula: left XOR (center OR right)
            next[i] = left ^ (center | right);
        }
        current = next;
        grid.push([...current]);
    }
    return grid;
};

// Dynamic Kerning & Glyph Manager driven by Weather CA
class WeatherKerningRenderer {
    private caGrid: number[][];
    private font: Record<string, string[]> = {
        'H': ["#   #", "#   #", "#####", "#   #", "#   #"],
        'E': ["#####", "#    ", "#####", "#    ", "#####"],
        'L': ["#    ", "#    ", "#    ", "#    ", "#####"],
        'O': ["#####", "#   #", "#   #", "#   #", "#####"],
        'W': ["#   #", "#   #", "# # #", "### #", "#   #"],
        'R': ["#### ", "#   #", "#### ", "#  # ", "#   #"],
        'D': ["#### ", "#   #", "#   #", "#   #", "#### "],
        ' ': ["     ", "     ", "     ", "     ", "     "]
    };

    constructor() {
        const binaryWeather = fetchWeatherBinary();
        // Evolve the weather binary through 12 cellular automaton generations
        this.caGrid = runCellularAutomaton(binaryWeather, 12);
    }

    // Dynamically compute kerning between two adjacent characters using CA state
    private computeKerning(charA: string, charB: string, positionIndex: number): number {
        const row = positionIndex % this.caGrid.length;
        const col = (charA.charCodeAt(0) + charB.charCodeAt(0)) % this.caGrid[row].length;
        const cellValue = this.caGrid[row][col];
        
        // Map cellular state (0 or 1) to dynamic pixel spacing (kerning offset)
        return cellValue === 1 ? 2 : 0;
    }

    public render(text: string): void {
        const chars = text.toUpperCase().split('');
        const canvasRows: string[] = Array(5).fill('');

        for (let i = 0; i < chars.length; i++) {
            const char = chars[i];
            const glyph = this.font[char] || this.font[' '];
            const nextChar = chars[i + 1] || ' ';
            const kerningSpace = this.computeKerning(char, nextChar, i);

            for (let r = 0; r < 5; r++) {
                canvasRows[r] += glyph[r] + ' '.repeat(kerningSpace);
            }
        }

        console.log("=== WEATHER-DRIVEN KERNING FONT RENDERER ===");
        console.log(canvasRows.join('\n'));
        console.log("============================================");
    }
}

// Execution
const renderer = new WeatherKerningRenderer();
renderer.render("HELLO WORLD");