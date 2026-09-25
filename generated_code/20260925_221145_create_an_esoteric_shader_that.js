const fs = require('fs');
const path = require('path');

// Recursively scan directory to gather file stats (size & mtime)
function scanDirectory(dir) {
    let nodes = [];
    try {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
            // Skip hidden files/directories for aesthetic clarity
            if (entry.name.startsWith('.')) continue;
            
            const fullPath = path.join(dir, entry.name);
            const stats = fs.statSync(fullPath);
            
            nodes.push({
                name: entry.name,
                size: stats.size, // Dictates root growth velocity
                mtime: stats.mtimeMs, // Dictates bioluminescent pulse frequency
                isDirectory: entry.isDirectory(),
                children: entry.isDirectory() ? scanDirectory(fullPath) : []
            });
        }
    } catch (err) {
        // Handle permission or access errors silently
    }
    return nodes;
}

// Flatten and map file tree nodes into geometric mycelial hyphae coordinates
function buildMycelialNetwork(nodes, depth = 0, cx = 40, cy = 12) {
    let hyphae = [];
    const angleStep = (Math.PI * 2) / Math.max(nodes.length, 1);
    
    nodes.forEach((node, index) => {
        const angle = angleStep * index + (depth * 0.4);
        // File size scales growth velocity/radius extension
        const radius = Math.min(Math.max(node.size / 15000, 2), 25) + (depth * 4);
        const x = cx + Math.cos(angle) * radius;
        const y = cy + Math.sin(angle) * (radius * 0.5); // Aspect ratio correction for terminals
        
        // Timestamp controls bioluminescent pulse frequency
        const ageFactor = Math.abs(Date.now() - node.mtime) / 100000000;
        const pulseFreq = 0.05 + (1.0 / (ageFactor + 0.1));

        hyphae.push({
            x: Math.floor(x),
            y: Math.floor(y),
            velocity: Math.min(node.size / 50000 + 0.2, 3.0),
            pulseFreq: pulseFreq,
            name: node.name
        });

        if (node.children && node.children.length > 0) {
            hyphae = hyphae.push ? hyphae.concat(buildMycelialNetwork(node.children, depth + 1, x, y)) : hyphae;
        }
    });

    return hyphae;
}

// Terminal Shader Loop simulating organic spore diffusion and bioluminescence
const targetDir = process.argv[2] || process.cwd();
const fileTree = scanDirectory(targetDir);
const network = buildMycelialNetwork(fileTree);

let frame = 0;
const width = 80;
const height = 24;

function renderShaderFrame() {
    let grid = Array(height).fill(0).map(() => Array(width).fill(' '));
    
    // Draw mycelial strands and spore nodes
    network.forEach(node => {
        // Esoteric shader wave function combining position, size velocity, and timestamp frequency
        const wave = Math.sin(frame * node.pulseFreq * 0.2 + (node.x * 0.1)) * 0.5 + 0.5;
        const intensity = Math.floor(wave * 5);
        const palette = ['·', ':', '*', 'o', 'O', '@'];
        const char = palette[Math.min(intensity, palette.length - 1)];

        const px = (node.x % width + width) % width;
        const py = (node.y % height + height) % height;
        
        grid[py][px] = char;
    });

    // Output frame to console with ANSI clear screen
    console.clear();
    console.log(`\x1b[32m=== BIO-MYCELIAL FILESYSTEM SHADER: ${path.basename(targetDir)} ===\x1b[0m`);
    console.log(grid.map(row => row.join('')).join('\n'));
    console.log(`\x1b[2m[Nodes: ${network.length} | Press Ctrl+C to exit]\x1b[0m`);
    
    frame++;
}

// Run render loop at ~20fps
setInterval(renderShaderFrame, 50);