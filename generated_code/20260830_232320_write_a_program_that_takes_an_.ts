// Self-contained TypeScript program: Text-to-Topographical-SVG Converter
// Runs via Node.js or browser. Reads text input, performs natural language & layout analysis,
// and projects word frequencies, semantic tone, and spatial structure into a 2D topographic SVG map.

interface WordNode {
  text: string;
  lineIndex: number;
  indentation: number;
  frequency: number;
  sentiment: number; // -1 (negative) to +1 (positive)
  x: number;
  y: number;
}

interface MapOptions {
  width: number;
  height: number;
  gridSize: number;
  contourLevels: number;
}

// Sentiment lexicon mapping core words to emotional valence
const SENTIMENT_LEXICON: Record<string, number> = {
  good: 0.8, great: 1.0, happy: 0.9, love: 0.9, joy: 0.9, light: 0.6, hope: 0.7,
  peace: 0.8, truth: 0.6, peak: 0.7, high: 0.5, beauty: 0.8, life: 0.7,
  bad: -0.7, dark: -0.8, death: -0.9, pain: -0.8, fear: -0.8, loss: -0.7,
  cold: -0.5, abyss: -1.0, shadow: -0.6, fall: -0.5, stress: -0.6, doubt: -0.5
};

class TextTopographyMapGenerator {
  private options: MapOptions;

  constructor(options: Partial<MapOptions> = {}) {
    this.options = {
      width: 1000,
      height: 800,
      gridSize: 80,
      contourLevels: 12,
      ...options
    };
  }

  // Parse text into structured semantic nodes based on layout and tone
  private parseText(rawText: string): { nodes: WordNode[]; textLength: number } {
    const lines = rawText.split(/\r?\n/);
    const words = rawText.toLowerCase().match(/\b[a-z']+\b/g) || [];
    
    // Calculate word frequencies
    const freqMap = new Map<string, number>();
    words.forEach(w => freqMap.set(w, (freqMap.get(w) || 0) + 1));

    const nodes: WordNode[] = [];
    const lineCount = lines.length || 1;

    lines.forEach((line, lineIndex) => {
      const trimmed = line.trim();
      if (!trimmed) return;

      // Count leading spaces/tabs for structural indentation layout
      const indentMatch = line.match(/^[\t ]*/);
      const indentation = indentMatch ? indentMatch[0].replace(/\t/g, '  ').length : 0;
      
      const lineWords = trimmed.match(/\b[a-z']+\b/gi) || [];
      const lineY = ((lineIndex + 1) / (lineCount + 1)) * this.options.height;

      lineWords.forEach((word, wordIndex) => {
        const cleanWord = word.toLowerCase();
        const freq = freqMap.get(cleanWord) || 1;
        const sentiment = SENTIMENT_LEXICON[cleanWord] || 0.05;

        // X coordinate reflects indentation layout plus word position along the line
        const xNormalized = (wordIndex + 1) / (lineWords.length + 1);
        const indentOffset = (indentation / 40) * (this.options.width * 0.3);
        const lineX = (indentOffset + xNormalized * (this.options.width - indentOffset - 100));

        nodes.push({
          text: word,
          lineIndex,
          indentation,
          frequency: freq,
          sentiment,
          x: lineX,
          y: lineY
        });
      });
    });

    return { nodes, textLength: words.length };
  }

  // Calculate terrain elevation z(x,y) using radial basis potential from text nodes
  private calculateElevation(x: number, y: number, nodes: WordNode[]): number {
    let elevation = 0;
    for (const node of nodes) {
      const dx = x - node.x;
      const dy = y - node.y;
      const distSq = dx * dx + dy * dy;
      
      // Tone (sentiment) drives height direction, frequency drives magnitude/spread
      const amplitude = (node.sentiment !== 0 ? node.sentiment : 0.2) * (1 + Math.log(node.frequency));
      const sigmaSq = 8000 + node.indentation * 500;
      
      elevation += amplitude * Math.exp(-distSq / sigmaSq);
    }
    return elevation;
  }

  // Generate 2D height grid
  private createHeightField(nodes: WordNode[]): number[][] {
    const cols = this.options.gridSize;
    const rows = this.options.gridSize;
    const grid: number[][] = Array.from({ length: rows }, () => new Array(cols).fill(0));

    for (let r = 0; r < rows; r++) {
      const y = (r / (rows - 1)) * this.options.height;
      for (let c = 0; c < cols; c++) {
        const x = (c / (cols - 1)) * this.options.width;
        grid[r][c] = this.calculateElevation(x, y, nodes);
      }
    }

    return grid;
  }

  // Simple Marching Squares algorithm to extract topographic elevation contours
  private generateContourPaths(grid: number[][]): string[] {
    const rows = grid.length;
    const cols = grid[0].length;
    const paths: string[] = [];

    // Find min and max height across terrain grid
    let minH = Infinity, maxH = -Infinity;
    grid.forEach(row => row.forEach(h => {
      if (h < minH) minH = h;
      if (h > maxH) maxH = h;
    }));

    const levels = this.options.contourLevels;
    const step = (maxH - minH) / (levels + 1);

    for (let i = 1; i <= levels; i++) {
      const threshold = minH + i * step;
      let pathData = '';

      for (let r = 0; r < rows - 1; r++) {
        for (let c = 0; c < cols - 1; c++) {
          const x0 = (c / (cols - 1)) * this.options.width;
          const x1 = ((c + 1) / (cols - 1)) * this.options.width;
          const y0 = (r / (rows - 1)) * this.options.height;
          const y1 = ((r + 1) / (rows - 1)) * this.options.height;

          const v0 = grid[r][c] >= threshold ? 1 : 0;
          const v1 = grid[r][c + 1] >= threshold ? 1 : 0;
          const v2 = grid[r + 1][c + 1] >= threshold ? 1 : 0;
          const v3 = grid[r + 1][c] >= threshold ? 1 : 0;

          const caseIndex = (v0 << 3) | (v1 << 2) | (v2 << 1) | v3;
          if (caseIndex === 0 || caseIndex === 15) continue;

          // Midpoint edge interpolation
          const top = `${(x0 + x1) / 2},${y0}`;
          const right = `${x1},${(y0 + y1) / 2}`;
          const bottom = `${(x0 + x1) / 2},${y1}`;
          const left = `${x0},${(y0 + y1) / 2}`;

          if (caseIndex === 1 || caseIndex === 14) pathData += `M ${left} L ${bottom} `;
          else if (caseIndex === 2 || caseIndex === 13) pathData += `M ${bottom} L ${right} `;
          else if (caseIndex === 3 || caseIndex === 12) pathData += `M ${left} L ${right} `;
          else if (caseIndex === 4 || caseIndex === 11) pathData += `M ${top} L ${right} `;
          else if (caseIndex === 5) pathData += `M ${left} L ${top} M ${bottom} L ${right} `;
          else if (caseIndex === 6 || caseIndex === 9) pathData += `M ${top} L ${bottom} `;
          else if (caseIndex === 7 || caseIndex === 8) pathData += `M ${left} L ${top} `;
          else if (caseIndex === 10) pathData += `M ${top} L ${right} M ${left} L ${bottom} `;
        }
      }

      if (pathData) {
        paths.push(`<path d="${pathData}" stroke="#3b5249" stroke-width="0.8" fill="none" opacity="0.65" />`);
      }
    }

    return paths;
  }

  // Render vegetation overlay where font size & density act as natural forest canopy
  private renderVegetation(nodes: WordNode[]): string {
    return nodes.map(node => {
      const fontSize = Math.min(28, 8 + node.frequency * 3.5);
      const opacity = Math.min(0.9, 0.35 + node.frequency * 0.12);
      
      // Vegetation color shifts based on sentiment tone: high positive = lush green, negative = autumn flora
      const color = node.sentiment > 0.2 ? '#2a5a3b' : (node.sentiment < -0.2 ? '#7a4220' : '#4a6042');
      
      return `<text x="${node.x.toFixed(2)}" y="${node.y.toFixed(2)}" 
                    font-size="${fontSize.toFixed(1)}px" 
                    font-family="Georgia, serif" 
                    fill="${color}" 
                    fill-opacity="${opacity.toFixed(2)}" 
                    text-anchor="middle" 
                    class="tree-node"
                    data-word="${node.text}"
                    data-freq="${node.frequency}">
                ${node.text}
              </text>`;
    }).join('\n    ');
  }

  // Public method to convert text input into complete printable/interactive SVG
  public convertTextToSvgMap(text: string): string {
    const { nodes } = this.parseText(text);
    const grid = this.createHeightField(nodes);
    const contourPaths = this.generateContourPaths(grid);
    const vegetationElements = this.renderVegetation(nodes);

    return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" 
     viewBox="0 0 ${this.options.width} ${this.options.height}" 
     width="100%" height="100%">
  <style>
    .bg { fill: #f2efe9; }
    .contour-line { transition: stroke 0.3s; }
    .tree-node { cursor: pointer; user-select: none; transition: transform 0.2s, fill-opacity 0.2s; }
    .tree-node:hover { fill-opacity: 1.0; fill: #111111; font-weight: bold; }
    .map-title { font-family: 'Courier New', monospace; font-size: 14px; fill: #666; letter-spacing: 2px; }
    @media print {
      .bg { fill: #ffffff; }
      .tree-node { fill: #000000 !important; }
    }
  </style>
  <rect width="100%" height="100%" class="bg"/>
  
  <!-- Map Grid Overlay -->
  <g stroke="#d5cfc4" stroke-width="0.5" stroke-dasharray="4,4">
    ${Array.from({ length: 10 }).map((_, i) => `<line x1="${i * 100}" y1="0" x2="${i * 100}" y2="${this.options.height}" />`).join('')}
    ${Array.from({ length: 8 }).map((_, i) => `<line x1="0" y1="${i * 100}" x2="${this.options.width}" y2="${i * 100}" />`).join('')}
  </g>

  <!-- Elevation Contour Map Lines -->
  <g class="contour-layer">
    ${contourPaths.join('\n    ')}
  </g>

  <!-- Natural Vegetation Layer (Word Density Forest) -->
  <g class="vegetation-layer">
    ${vegetationElements}
  </g>

  <!-- Legend & Header -->
  <g transform="translate(30, 40)">
    <text class="map-title" x="0" y="0">TOPOGRAPHIC TEXT MAP</text>
    <text class="map-title" x="0" y="16" font-size="10px">ELEVATION = SEMANTIC TONE | VEGETATION = WORD DENSITY</text>
  </g>
</svg>`;
  }
}

// Example Usage & Runner:
const sampleText = `
Topography of Thought
  High peaks bring clarity and great joy
  Rising above the low valley of doubt and deep pain
    Nested structures map directly into high elevation ridges
      Where ideas blossom like dense natural forest trees
  Dark shadows fall into abyssal ravines
Light and hope prevail on the crest
`;

const mapper = new TextTopographyMapGenerator({ width: 1000, height: 700 });
const svgMapOutput = mapper.convertTextToSvgMap(sampleText);

// Print or write result to file system / browser document
console.log(svgMapOutput);