// Self-modifying audio opcode dancer// Simulates a live audio stream by emitting pseudo‑audio bytes.
// Each byte serves as an opcode that commands terminal characters to dance,
// change color, move, or even rewrite the interpreter itself.
//
// Run with Node:  node dancer.js
(async () => {
  const CLEAR = '\x1b[2J\x1b[0;0H';
  const COLORS = [
    '\x1b[31m','\x1b[32m','\x1b[33m','\x1b[34m','\x1b[35m','\x1b[36m','\x1b[90m','\x1b[0m'
  ];
  let colorIdx = 0;
  let direction = 1;
  let opcodeMap = 0b101010; // seed for self‑modification

  // Dispatcher for a single opcode byte
  const dispatch = (b) => {
    switch (b) {
      case 0: case 1: case 2: case 3: case 4:
        // Print a row of dot glyphs of length = opcode
        process.stdout.write(CLEAR);
        process.stdout.write('·'.repeat(b));
        break;
      case 5: case 6: case 7:
        // Switch color palette
        colorIdx = b - 5;
        process.stdout.write(COLORS[colorIdx]);
        break;
      case 8:
        // Move cursor down one line        process.stdout.write('\x1b[B');
        break;
      case 9:
        // Move cursor right one column
        process.stdout.write('\x1b[C');
        break;
      case 10:
        // Reverse movement direction
        direction *= -1;
        break;
      case 11:
        // Self‑modify: flip a pattern bit in the opcode map seed
        opcodeMap ^= 0b101010;
        break;
      case 97: case 98: case 99: // 'a','b','c' → reset state        process.stdout.write(CLEAR);
        colorIdx = 0;
        direction = 1;
        delete opcodeMap;
        break;
      default:
        // Generic step: emit a capital letter based on low nibble
        process.stdout.write(String.fromCharCode(65 + (b & 0xF)));
    }
  };

  // Pseudo‑live audio generator (noise + sinusoidal wave)
  async function* audioBytes() {
    while (true) {
      const noise = Math.floor(Math.random() * 128);
      const wave = Math.sin(Date.now() * 0.001) * 64;
      const byte = (noise + wave) & 0x7F;
      yield byte;
      await new Promise(r => setTimeout(r, 30));
    }
  }

  // Initialize screen
  process.stdout.write(CLEAR);

  // Main loop: consume audio bytes and execute opcodes
  for await (const b of audioBytes()) {
    dispatch(b);
    // Simple rhythmic modulation of direction for extra flair    direction = ((direction + 1) % 3) - 1;
    // Optionally, incorporate direction into future moves (here just stored)
    // The interpreter state (colorIdx, opcodeMap, direction) is mutable and can be
    // altered by opcodes such as 11 (self‑modification), enabling a live‑changing compiler.
  }
})();