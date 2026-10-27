const fs = require('fs');

/**
 * Stained Glass Text Compressor & Trauma Simulator
 * Encodes text into a colorful SVG mosaic window, permanently shattering random panes for typos.
 */
class StainedGlassCompressor {
    constructor(options = {}) {
        this.paneSize = options.paneSize || 24;
    }

    /**
     * Encodes text into an SVG stained glass representation.
     * @param {string} text - The text to compress/encode.
     * @param {number} typoCount - Number of spelling mistakes that cause structural damage.
     * @returns {string} SVG markup string.
     */
    encode(text, typoCount = 0) {
        const bytes = Buffer.from(text, 'utf-8');
        const cols = Math.ceil(Math.sqrt(bytes.length));
        const rows = Math.ceil(bytes.length / cols);
        
        const svgWidth = cols * this.paneSize;
        const svgHeight = rows * this.paneSize;

        let svg = `<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 ${svgWidth} ${svgHeight}" width="100%" height="100%">\n`;
        svg += `<style>
            .pane { stroke: #111111; stroke-width: 2.5px; }
            .shattered-line { stroke: #ffffff; stroke-width: 1.2px; opacity: 0.85; stroke-dasharray: 2 1; }
            .shard { fill: rgba(255, 255, 255, 0.15); }
        </style>\n`;
        svg += `<rect width="100%" height="100%" fill="#0a0a0a"/>\n`;

        let byteIndex = 0;
        let shatteredPanes = new Set();

        // Determine which panes get shattered by spelling mistakes
        const totalPanes = cols * rows;
        const actualTypos = Math.min(typoCount, totalPanes);
        while (shatteredPanes.size < actualTypos) {
            shatteredPanes.add(Math.floor(Math.random() * totalPanes));
        }

        for (let r = 0; r < rows; r++) {
            for (let c = 0; c < cols; c++) {
                const x = c * this.paneSize;
                const y = r * this.paneSize;
                const paneIndex = r * cols + c;

                if (byteIndex < bytes.length) {
                    const charCode = bytes[byteIndex++];
                    // Map character byte to jewel-toned HSL color space
                    const hue = (charCode * 17) % 360;
                    const saturation = 75 + (charCode % 20);
                    const lightness = 40 + (charCode % 25);
                    const fillColor = `hsl(${hue}, ${saturation}%, ${lightness}%)`;

                    // Draw the glass pane
                    svg += `<rect class="pane" x="${x}" y="${y}" width="${this.paneSize}" height="${this.paneSize}" fill="${fillColor}" rx="4" ry="4" />\n`;

                    // Apply the fracture effect if a spelling mistake hit this coordinate
                    if (shatteredPanes.has(paneIndex)) {
                        const midX = x + this.paneSize / 2;
                        const midY = y + this.paneSize / 2;
                        svg += `<rect class="shard" x="${x+2}" y="${y+2}" width="${this.paneSize-4}" height="${this.paneSize-4}" rx="2" />\n`;
                        svg += `<path class="shattered-line" d="M ${x+3} ${y+3} L ${midX} ${midY} L ${x+this.paneSize-3} ${y+this.paneSize-3} M ${x+this.paneSize-3} ${y+3} L ${midX} ${midY} L ${x+3} ${y+this.paneSize-3}" />\n`;
                        svg += `<circle cx="${midX}" cy="${midY}" r="2" fill="#ffffff" />\n`;
                    }
                }
            }
        }

        svg += `</svg>`;
        return svg;
    }
}

// Execution demonstration
const compressor = new StainedGlassCompressor();
const sampleText = "Compression algorithms transform raw data into elegant visual tapestries.";
const simulatedTypos = 4; // Each typo shatters a random pane of glass

const svgOutput = compressor.encode(sampleText, simulatedTypos);
fs.writeFileSync('stained_glass_window.svg', svgOutput);
console.log(`Successfully compressed text and rendered stained glass with ${simulatedTypos} shattered panes to 'stained_glass_window.svg'.`);