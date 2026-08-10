#!/usr/bin/env node

/**
 * Shell Constellation Map Generator
 * Converts local shell history into a generative ASCII night sky.
 * Frequent commands become bright star clusters; syntax errors bleed ink.
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// Configuration & Dimensions
const WIDTH = process.stdout.columns || 80;
const HEIGHT = process.stdout.rows ? Math.min(process.stdout.rows - 2, 40) : 30;

// ANSI Color Palette
const RESET = '\x1b[0m';
const DIM = '\x1b[2m';
const BRIGHT = '\x1b[1m';
const STAR_BRIGHT = '\x1b[97m'; // White
const STAR_CLUSTER = '\x1b[93m'; // Bright Yellow
const INK_BLEED = '\x1b[31m';   // Reddish/Crimson for errors
const NEBULA = '\x1b[35m';      // Magenta

/**
 * Detects the user's shell history file path.
 */
function getHistoryFilePath() {
    const home = os.homedir();
    const shell = process.env.SHELL || '';
    
    if (shell.includes('zsh')) {
        return path.join(home, '.zsh_history');
    } else if (shell.includes('bash')) {
        return path.join(home, '.bash_history');
    }
    
    // Fallback checks
    const zshPath = path.join(home, '.zsh_history');
    if (fs.existsSync(zshPath)) return zshPath;
    
    const bashPath = path.join(home, '.bash_history');
    if (fs.existsSync(bashPath)) return bashPath;
    
    return null;
}

/**
 * Parses raw history lines into clean commands.
 */
function parseHistory(rawContent) {
    const lines = rawContent.split('\n');
    const commands = [];

    for (let line of lines) {
        if (!line.trim()) continue;

        // Handle ZSH extended history format: ": 1600000000:0;command"
        if (line.startsWith(': ')) {
            const parts = line.split(';');
            if (parts.length > 1) {
                commands.push(parts.slice(1).join(';').trim());
                continue;
            }
        }

        // Standard Bash history line
        commands.push(line.trim());
    }

    return commands;
}

/**
 * Heuristic check to see if a command looks like a syntax error or failed execution.
 */
function isSyntaxError(cmd) {
    const errorPatterns = [
        /syntax error/,
        /command not found/,
        /no such file or directory/,
        /permission denied/,
        /fatal:/,
        /error:/,
        /^git\s+[^a-z]/
    ];
    
    const lower = cmd.toLowerCase();
    // Also consider short gibberish or repeated accidental keystrokes as "ink bleeds"
    if (cmd.length < 2 && !['ls', 'cd', 'vi', 'rm'].includes(cmd)) return true;
    
    return errorPatterns.some(pattern => pattern.test(lower));
}

/**
 * Main execution routine.
 */
function main() {
    const histPath = getHistoryFilePath();
    let rawCommands = [];

    if (histPath && fs.existsSync(histPath)) {
        try {
            const content = fs.readFileSync(histPath, 'utf8');
            rawCommands = parseHistory(content);
        } catch (e) {
            // Fallback if read fails
        }
    }

    // Fallback dummy data if history is unavailable or empty
    if (rawCommands.length === 0) {
        rawCommands = [
            'git status', 'git commit -m "fix"', 'npm test', 'ls -la',
            'cd src', 'syntax error near unexpected token', 'node index.js',
            'git push origin main', 'vim app.js', 'command not found: sl'
        ];
    }

    // Tally command frequencies for cluster weighting
    const freqMap = new Map();
    for (const cmd of rawCommands) {
        const baseCmd = cmd.split(' ')[0]; // Group by base utility
        freqMap.set(baseCmd, (freqMap.get(baseCmd) || 0) + 1);
    }

    // Initialize 2D grid representing the night sky space
    const grid = Array.from({ length: HEIGHT }, () => Array(WIDTH).fill({ char: ' ', color: DIM }));

    // Seed background ambient starlight (sparse field)
    for (let y = 0; y < HEIGHT; y++) {
        for (let x = 0; x < WIDTH; x++) {
            const rand = Math.sin(x * 12.9898 + y * 78.233) * 43758.5453;
            const val = rand - Math.floor(rand);
            if (val > 0.92) {
                grid[y][x] = { char: '.', color: DIM };
            } else if (val > 0.985) {
                grid[y][x] = { char: '*', color: STAR_BRIGHT };
            }
        }
    }

    // Plot commands as celestial coordinates
    let index = 0;
    for (const cmd of rawCommands) {
        index++;
        const baseCmd = cmd.split(' ')[0];
        const freq = freqMap.get(baseCmd) || 1;
        const isError = isSyntaxError(cmd);

        // Pseudo-deterministic spatial mapping based on command string entropy
        let hash = 0;
        for (let i = 0; i < cmd.length; i++) {
            hash = (hash << 5) - hash + cmd.charCodeAt(i);
            hash |= 0;
        }

        const x = Math.abs(hash) % (WIDTH - 4) + 2;
        const y = Math.abs(Math.floor(hash / 31)) % (HEIGHT - 2) + 1;

        if (isError) {
            // Syntax errors bleed ink across surrounding spatial coordinates
            const bleedChars = ['~', 'x', '%', ':', ';', '\\', '/'];
            for (let bx = -1; bx <= 1; bx++) {
                for (let by = -1; by <= 1; by++) {
                    const nx = x + bx;
                    const ny = y + by;
                    if (nx >= 0 && nx < WIDTH && ny >= 0 && ny < HEIGHT) {
                        const bChar = bleedChars[Math.abs(hash + bx + by) % bleedChars.length];
                        grid[ny][nx] = { char: bChar, color: INK_BLEED };
                    }
                }
            }
        } else if (freq > 3) {
            // Frequent commands form bright star clusters (Constellations)
            const clusterChars = ['*', 'O', 'o', '+', '¤'];
            const cChar = clusterChars[freq % clusterChars.length];
            grid[y][x] = { char: cChar, color: STAR_CLUSTER };

            // Add orbital companion stars for high frequency nodes
            if (x + 1 < WIDTH) grid[y][x + 1] = { char: '`', color: NEBULA };
            if (x - 1 >= 0) grid[y][x - 1] = { char: ',', color: NEBULA };
        } else {
            // Standard single star node
            const normalChars = ['.', '·', '°', ''];
            const nChar = normalChars[Math.abs(hash) % normalChars.length];
            if (nChar) {
                grid[y][x] = { char: nChar, color: BRIGHT };
            }
        }
    }

    // Render Constellation Map Output
    console.clear();
    console.log(`${BRIGHT}${STAR_CLUSTER} 🌌 SHELL CONSTELLATION MAP 🌌 ${RESET} ${DIM}(Parsed ${rawCommands.length} history nodes)${RESET}\n`);

    for (let y = 0; y < HEIGHT; y++) {
        let rowStr = '';
        for (let x = 0; x < WIDTH; x++) {
            const cell = grid[y][x];
            rowStr += `${cell.color}${cell.char}${RESET}`;
        }
        process.stdout.write(rowStr + '\n');
    }

    console.log(`\n${DIM}Legend: ${STAR_CLUSTER}* Frequent Cluster${RESET} | ${BRIGHT}· Single Star${RESET} | ${INK_BLEED}~ Syntax Ink Bleed${RESET}`);
}

main();