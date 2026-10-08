// Whale Net-Song: Hexadecimal ASCII Art Score Generator for Three Synthesized Whales
// Simulates a network traffic stream, maps packet attributes to whale harmonics,
// and renders a live collaborative ASCII hex score.

const whales = [
    { name: 'Baleen', hexBase: 0x1A4, symbol: '🐋', buffer: [] },
    { name: 'Sperm',  hexBase: 0x3F9, symbol: '🐳', buffer: [] },
    { name: 'Blue',   hexBase: 0x7C2, symbol: '🌊', buffer: [] }
];

// Generates a mock network traffic packet with random payload and timestamp
function createPacket() {
    const payloadLength = Math.floor(Math.random() * 256);
    let hexStr = '';
    for (let i = 0; i < 8; i++) {
        hexStr += Math.floor(Math.random() * 16).toString(16);
    }
    return {
        size: payloadLength,
        hex: hexStr.toUpperCase(),
        timestamp: Date.now()
    };
}

// Transforms a hex chunk into structured ASCII art notation for a specific whale
function renderHexGlyph(hex, whaleIndex) {
    const prefixes = ['0xA1', '0xB2', '0xC3'];
    return `${prefixes[whaleIndex]}:${hex.slice(0, 4)}:${hex.slice(4)}`;
}

// Stream processing loop simulating real-time packet intake
let tick = 0;
const maxTicks = 25;

const streamInterval = setInterval(() => {
    const packet = createPacket();
    
    // Distribute network energy across the three whale voices
    whales.forEach((whale, idx) => {
        const modulation = (packet.size + idx * 43) % 0xFFFF;
        const computedHex = (whale.hexBase ^ modulation).toString(16).toUpperCase().padStart(4, '0');
        whale.buffer.push(computedHex);
        if (whale.buffer.length > 4) whale.buffer.shift();
    });

    // Render the collaborative hexadecimal ASCII art score frame
    console.clear();
    console.log('=====================================================');
    console.log('   DEEP SEA NETWORK SYMPHONY (HEXADECIMAL SCORE)     ');
    console.log('=====================================================\n');
    
    whales.forEach((whale, idx) => {
        const scoreLine = whale.buffer.map(h => `[${renderHexGlyph(h, idx)}]`).join(' ~~~ ');
        console.log(`${whale.symbol} ${whale.name.padEnd(6, ' ')} | ${scoreLine}`);
    });

    console.log('\n-----------------------------------------------------');
    console.log(`Packet #${tick + 1} | Length: ${packet.size}B | Hash: 0x${packet.hex}`);
    console.log('=====================================================');

    tick++;
    if (tick >= maxTicks) {
        clearInterval(streamInterval);
        console.log('\n[Transmission complete. The pod submerges into silence.]');
    }
}, 350);