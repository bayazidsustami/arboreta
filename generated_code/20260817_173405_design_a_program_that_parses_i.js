// Interactive Kinetic Assembly: Source-Code Driven Gearbox
const canvas = document.createElement('canvas');
const ctx = canvas.getContext('2d');
document.body.appendChild(canvas);
document.body.style.margin = '0';
document.body.style.overflow = 'hidden';
document.body.style.background = '#0a0d12';

let width, height;
function resize() {
  width = canvas.width = window.innerWidth;
  height = canvas.height = window.innerHeight;
}
window.addEventListener('resize', resize);
resize();

// 1. Source Code Parsing Engine
// Reads the script's own source code to extract numerical parameters & structural nodes
const sourceCode = document.currentScript ? document.currentScript.text : document.scripts[document.scripts.length - 1].text;

function parseSourceToMechanisms(code) {
  // Extract token frequencies to drive physical properties
  const words = code.match(/[a-zA-Z_$][a-zA-Z0-9_$]*/g) || [];
  const numbers = (code.match(/\b\d+\b/g) || [12, 24, 36]).map(Number);
  
  const nodes = [];
  const totalNodes = Math.min(24, Math.max(8, Math.floor(words.length / 15)));
  
  for (let i = 0; i < totalNodes; i++) {
    const word = words[i * 2] || 'gear';
    const charSum = word.split('').reduce((acc, c) => acc + c.charCodeAt(0), 0);
    const teeth = (numbers[i % numbers.length] % 20) + 8; // Tooth count from code numbers
    const radius = teeth * 4.5;
    
    nodes.push({
      id: i,
      label: word,
      teeth: teeth,
      radius: radius,
      x: 0, 
      y: 0,
      angle: 0,
      speed: 0,
      parentIndex: null,
      color: `hsl(${(charSum * 137.5) % 360}, 65%, 60%)`
    });
  }

  // Chain gears together in a kinetic tree branch layout
  const cols = Math.ceil(Math.sqrt(nodes.length * 1.5));
  nodes[0].x = width / 2;
  nodes[0].y = height / 2;
  nodes[0].speed = 0.015;

  for (let i = 1; i < nodes.length; i++) {
    const parent = nodes[Math.floor((i - 1) / 1.8)];
    nodes[i].parentIndex = parent.id;
    
    // Position tangent to parent gear
    const placementAngle = (i * 2.4) + (parent.teeth % 5);
    const dist = parent.radius + nodes[i].radius + 2;
    nodes[i].x = parent.x + Math.cos(placementAngle) * dist;
    nodes[i].y = parent.y + Math.sin(placementAngle) * dist;
    
    // Meshing gear speed and ratio
    const gearRatio = parent.teeth / nodes[i].teeth;
    nodes[i].speed = -parent.speed * gearRatio;
  }
  
  return nodes;
}

const mechanisms = parseSourceToMechanisms(sourceCode);

// 2. Interactive Input Handlers
let mouse = { x: width / 2, y: height / 2, active: false, targetGear: null };

window.addEventListener('mousemove', (e) => {
  mouse.x = e.clientX;
  mouse.y = e.clientY;
});

window.addEventListener('mousedown', (e) => {
  // Find nearest gear to drag or accelerate
  mechanisms.forEach(m => {
    const dx = e.clientX - m.x;
    const dy = e.clientY - m.y;
    if (Math.sqrt(dx * dx + dy * dy) < m.radius) {
      mouse.targetGear = m;
    }
  });
});

window.addEventListener('mouseup', () => { mouse.targetGear = null; });

// 3. Rendering Helpers for Gears, Levers & Piston Links
function drawGear(gear) {
  ctx.save();
  ctx.translate(gear.x, gear.y);
  ctx.rotate(gear.angle);

  // Outer gear rim and teeth
  ctx.fillStyle = gear.color;
  ctx.strokeStyle = '#1e2638';
  ctx.lineWidth = 2;
  
  ctx.beginPath();
  const numTeeth = gear.teeth;
  const outerR = gear.radius;
  const innerR = gear.radius - 8;
  const step = (Math.PI * 2) / numTeeth;

  for (let i = 0; i < numTeeth; i++) {
    const a = i * step;
    ctx.lineTo(Math.cos(a) * innerR, Math.sin(a) * innerR);
    ctx.lineTo(Math.cos(a + step * 0.25) * outerR, Math.sin(a + step * 0.25) * outerR);
    ctx.lineTo(Math.cos(a + step * 0.5) * outerR, Math.sin(a + step * 0.5) * outerR);
    ctx.lineTo(Math.cos(a + step * 0.75) * innerR, Math.sin(a + step * 0.75) * innerR);
  }
  ctx.closePath();
  ctx.fill();
  ctx.stroke();

  // Spoke patterns and code label branding
  ctx.beginPath();
  ctx.arc(0, 0, innerR - 6, 0, Math.PI * 2);
  ctx.fillStyle = '#0f141d';
  ctx.fill();
  ctx.stroke();

  // Spokes
  ctx.strokeStyle = gear.color;
  ctx.lineWidth = 3;
  for (let i = 0; i < 4; i++) {
    const sa = (Math.PI / 2) * i;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(Math.cos(sa) * (innerR - 6), Math.sin(sa) * (innerR - 6));
    ctx.stroke();
  }

  // Label showing the parsed code identifier
  ctx.rotate(-gear.angle); // Keep text horizontal
  ctx.fillStyle = '#a0b0d0';
  ctx.font = '10px monospace';
  ctx.textAlign = 'center';
  ctx.fillText(gear.label, 0, 3);

  ctx.restore();
}

function drawLeverMechanism(p1, p2) {
  // Connect two gears via mechanical linkage arm
  const dx = p2.x - p1.x;
  const dy = p2.y - p1.y;
  const dist = Math.sqrt(dx * dx + dy * dy);

  // Pin anchors on gears
  const pin1 = {
    x: p1.x + Math.cos(p1.angle) * (p1.radius * 0.6),
    y: p1.y + Math.sin(p1.angle) * (p1.radius * 0.6)
  };
  const pin2 = {
    x: p2.x + Math.cos(p2.angle + Math.PI) * (p2.radius * 0.6),
    y: p2.y + Math.sin(p2.angle + Math.PI) * (p2.radius * 0.6)
  };

  // Connecting metallic rod
  ctx.beginPath();
  ctx.moveTo(pin1.x, pin1.y);
  ctx.lineTo(pin2.x, pin2.y);
  ctx.strokeStyle = 'rgba(180, 200, 230, 0.4)';
  ctx.lineWidth = 6;
  ctx.lineCap = 'round';
  ctx.stroke();

  // Pin heads
  ctx.fillStyle = '#e0e6f0';
  [pin1, pin2].forEach(p => {
    ctx.beginPath();
    ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
    ctx.fill();
  });
}

// 4. Main Kinematic Loop
function animate() {
  ctx.clearRect(0, 0, width, height);

  // Background Source Code Watermark Matrix
  ctx.fillStyle = 'rgba(30, 40, 60, 0.15)';
  ctx.font = '12px monospace';
  const lines = sourceCode.split('\n');
  for (let i = 0; i < lines.length && i < 50; i++) {
    ctx.fillText(lines[i].substring(0, 80), 20, 25 + i * 16);
  }

  // Drag interaction physics update
  if (mouse.targetGear) {
    mouse.targetGear.x += (mouse.x - mouse.targetGear.x) * 0.1;
    mouse.targetGear.y += (mouse.y - mouse.targetGear.y) * 0.1;
  }

  // Update angles and gear locations
  mechanisms.forEach(m => {
    m.angle += m.speed;
  });

  // Render mechanical linkages (levers)
  for (let i = 1; i < mechanisms.length; i++) {
    if (i % 2 === 0) {
      const parent = mechanisms[mechanisms[i].parentIndex];
      drawLeverMechanism(parent, mechanisms[i]);
    }
  }

  // Render all gear nodes
  mechanisms.forEach(drawGear);

  requestAnimationFrame(animate);
}

animate();