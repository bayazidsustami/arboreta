const fs = require('fs');
const { PNG } = require('pngjs');
const { createWriteStream } = require('fs');
const { createCanvas } = require('canvas');

// --- tiny stack‑based VM ----------------------------------------------------
const OPCODES = {
  0x00: (st) => st.ip++,                      // NOP
  0x01: (st) => { st.stack.push(st.ip & 255); st.ip++; }, // PUSH ip low byte
  0x02: (st) => { const a = st.stack.pop()||0; const b = st.stack.pop()||0; st.stack.push((a+b)&255); st.ip++; }, // ADD
  0x03: (st) => { const a = st.stack.pop()||0; const b = st.stack.pop()||0; st.stack.push((a-b)&255); st.ip++; }, // SUB
  0x04: (st) => { const a = st.stack.pop()||0; const b = st.stack.pop()||0; st.stack.push((a*b)&255); st.ip++; }, // MUL
  0x05: (st) => { const a = st.stack.pop()||0; st.ip = a; }, // JMP
  0x06: (st) => { const a = st.stack.pop()||0; if (st.stack[st.stack.length-1]===0) st.ip = a; else st.ip++; }, // JZ
  0x07: (st) => { // WRITE back to image (self‑modifying)
    const val = st.stack.pop()||0;
    const addr = st.stack.pop()||0;
    if (addr < st.program.length) st.program[addr] = val;
    st.ip++;
  },
  0x08: (st) => { // READ from image onto stack
    const addr = st.stack.pop()||0;
    const val = addr < st.program.length ? st.program[addr] : 0;
    st.stack.push(val);
    st.ip++;
  },
  0xFF: (st) => { st.halt = true; }          // HALT
};

function run(program) {
  const st = { ip:0, stack:[], program, halt:false };
  while (!st.halt && st.ip < program.length) {
    const op = program[st.ip];
    const fn = OPCODES[op];
    if (fn) fn(st); else st.ip++; // unknown = NOP
  }
  return st.stack;
}

// --- SVG fractal spiral generator -------------------------------------------
function spiralSVG(iterations, hue) {
  const size = 512;
  const canvas = createCanvas(size, size);
  const ctx = canvas.getContext('2d');
  ctx.translate(size/2, size/2);
  for (let i=0;i<iterations;i++) {
    const r = i*2;
    const angle = i*0.15;
    const x = r*Math.cos(angle);
    const y = r*Math.sin(angle);
    ctx.beginPath();
    ctx.arc(x, y, 3, 0, Math.PI*2);
    ctx.fillStyle = `hsl(${(hue+i*5)%360},80%,60%)`;
    ctx.fill();
  }
  return canvas.toBuffer('image/svg+xml');
}

// --- Main --------------------------------------------------------------------
if (process.argv.length<3) {
  console.error('Usage: node selfmod.js <grayscale.png>');
  process.exit(1);
}
const inputPath = process.argv[2];
fs.createReadStream(inputPath)
  .pipe(new PNG({ filterType: 4 }))
  .on('parsed', function() {
    // treat each pixel (R===G===B) as a bytecode instruction
    const program = new Uint8Array(this.width * this.height);
    for (let i=0;i<program.length;i++) program[i]=this.data[i*4]; // R channel

    // run interpreter, produce a stack of results
    const stack = run(program);

    // use top of stack (or 0) to drive fractal parameters
    const iter = (stack.pop()||64) % 200 + 50;
    const hue = (stack.pop()||0) % 360;

    // generate SVG and embed as a pixel‑wise visual trace (optional)
    const svgBuf = spiralSVG(iter, hue);
    // write SVG to file
    fs.writeFileSync('output.svg', svgBuf);

    // write back execution trace: overlay each executed opcode with its final value
    for (let i=0;i<program.length;i++) {
      const val = program[i];
      const idx = i*4;
      this.data[idx]=val;          // R
      this.data[idx+1]=val;        // G
      this.data[idx+2]=val;        // B
      this.data[idx+3]=255;        // A
    }

    // save altered image
    this.pack().pipe(fs.createWriteStream('trace.png'));
  });