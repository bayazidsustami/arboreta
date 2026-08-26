const sampleRate = 44100;
const bufferLength = 1024;

// 1. Audio Context & Real-Time Input Setup
const audioCtx = new (window.AudioContext || window.webkitAudioContext)({ sampleRate });
const analyser = audioCtx.createAnalyser();
analyser.fftSize = bufferLength * 2;
const audioData = new Uint8Array(bufferLength);

// Request microphone input
navigator.mediaDevices.getUserMedia({ audio: true }).then((stream) => {
  const source = audioCtx.createMediaStreamSource(stream);
  source.connect(analyser);
}).catch(() => {
  // Fallback synthetic audio signal if microphone stream is unavailable
  setInterval(() => {
    for (let i = 0; i < bufferLength; i++) {
      audioData[i] = Math.floor(128 + 127 * Math.sin(Date.now() * 0.005 + i * 0.1));
    }
  }, 30);
});

// 2. Machine Code Buffer (Custom Assembly Architecture)
// Opcodes: 0x01: PUSH_FRACTAL_NODE, 0x02: RESONANCE_MUTATE, 0x03: TRANSFORM_MESH, 0xFF: RET
const machineCodeMemory = new Uint8Array([
  0x01, 0x10, 0x20, // Node A initialization
  0x01, 0x30, 0x40, // Node B initialization
  0x02, 0x05,       // Mutate structural resonance
  0x03, 0x12,       // Transform mesh topology
  0xFF              // Terminate iteration cycle
]);

// 3. Self-Modifying Compiler Engine
function executeAndSelfModify(codeBuffer, acousticEnergy) {
  let ip = 0; // Instruction Pointer
  const meshVertices = [];

  while (ip < codeBuffer.length) {
    const opcode = codeBuffer[ip];

    if (opcode === 0x01) {
      // PUSH_FRACTAL_NODE: Generates topological coordinates
      const x = codeBuffer[ip + 1] * (acousticEnergy / 255);
      const y = codeBuffer[ip + 2] * (acousticEnergy / 255);
      meshVertices.push([x, y]);
      ip += 3;
    } else if (opcode === 0x02) {
      // RESONANCE_MUTATE: Machine code modifies itself based on acoustic resonance
      const mutationFactor = Math.floor(acousticEnergy % 16);
      const targetOffset = (ip + codeBuffer[ip + 1]) % codeBuffer.length;
      
      // Direct Bytecode Mutation: Overwriting assembly instructions in real-time
      codeBuffer[targetOffset] = (codeBuffer[targetOffset] ^ mutationFactor) & 0xFF;
      ip += 2;
    } else if (opcode === 0x03) {
      // TRANSFORM_MESH: Apply fractal scale iteration
      const scale = codeBuffer[ip + 1] / 128.0;
      for (let j = 0; j < meshVertices.length; j++) {
        meshVertices[j][0] *= scale;
        meshVertices[j][1] *= scale;
      }
      ip += 2;
    } else if (opcode === 0xFF) {
      // RET: End execution loop
      break;
    } else {
      // Invalid/Mutated instruction fallback handler
      codeBuffer[ip] = 0x01; // Repair corrupted opcode to maintain fractal integrity
      ip++;
    }
  }

  return meshVertices;
}

// 4. Canvas Renderer for Topological Fractal Mesh
const canvas = document.createElement('canvas');
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;
document.body.appendChild(canvas);
const ctx = canvas.getContext('2d');

function renderFrame() {
  requestAnimationFrame(renderFrame);

  if (analyser.getByteTimeDomainData) {
    analyser.getByteTimeDomainData(audioData);
  }

  // Calculate average acoustic resonance
  let sum = 0;
  for (let i = 0; i < audioData.length; i++) {
    sum += Math.abs(audioData[i] - 128);
  }
  const resonance = (sum / audioData.length) * 4;

  // Execute machine code to mutate assembly & construct mesh vertices
  const vertices = executeAndSelfModify(machineCodeMemory, resonance);

  // Clear Canvas
  ctx.fillStyle = 'rgba(10, 10, 20, 0.2)';
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // Render Fractal Mesh
  ctx.save();
  ctx.translate(canvas.width / 2, canvas.height / 2);
  ctx.strokeStyle = `hsl(${resonance * 10 + 180}, 100%, 60%)`;
  ctx.lineWidth = 1.5;

  ctx.beginPath();
  const iterations = 8;
  for (let i = 0; i < iterations; i++) {
    const angle = (Math.PI * 2 / iterations) * i;
    ctx.rotate(angle);
    vertices.forEach(([x, y], idx) => {
      const px = x * Math.cos(resonance * 0.05) - y * Math.sin(resonance * 0.05);
      const py = x * Math.sin(resonance * 0.05) + y * Math.cos(resonance * 0.05);
      if (idx === 0) ctx.moveTo(px, py);
      else ctx.lineTo(px, py);
    });
  }
  ctx.closePath();
  ctx.stroke();
  ctx.restore();
}

renderFrame();