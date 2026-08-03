<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Generative Gravitational Semantic Text Editor</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body, html { width: 100%; height: 100%; overflow: hidden; background: #080810; font-family: 'Courier New', monospace; color: #e0e6ed; }
    #canvas { position: absolute; top: 0; left: 0; width: 100%; height: 100%; z-index: 1; }
    #editor-container {
      position: absolute; bottom: 30px; left: 50%; transform: translateX(-50%);
      width: 90%; max-width: 700px; z-index: 10;
      background: rgba(15, 20, 35, 0.85); backdrop-filter: blur(12px);
      border: 1px solid rgba(255, 255, 255, 0.15); border-radius: 12px;
      padding: 16px; box-shadow: 0 20px 50px rgba(0,0,0,0.6);
    }
    textarea {
      width: 100%; height: 80px; background: transparent; border: none; outline: none;
      color: #7dd3fc; font-family: 'Courier New', monospace; font-size: 15px;
      resize: none; line-height: 1.5;
    }
    .hud {
      position: absolute; top: 20px; left: 20px; z-index: 10; pointer-events: none;
      font-size: 12px; color: #64748b; letter-spacing: 1px;
    }
    .hud span { color: #38bdf8; font-weight: bold; }
  </style>
</head>
<body>
  <div class="hud">
    GRAVITY FIELD: <span id="grav-val">1.00</span> G | 
    WORD BODIES: <span id="body-count">0</span> | 
    MERGES: <span id="merge-count">0</span>
  </div>
  <canvas id="canvas"></canvas>
  <div id="editor-container">
    <textarea id="editor" placeholder="Type here... Keystrokes alter word gravity, orbiting semantically similar text..." autofocus></textarea>
  </div>

  <script>
    // System setup
    const canvas = document.getElementById('canvas');
    const ctx = canvas.getContext('2d');
    const editor = document.getElementById('editor');
    const gravHud = document.getElementById('grav-val');
    const countHud = document.getElementById('body-count');
    const mergeHud = document.getElementById('merge-count');

    let width = canvas.width = window.innerWidth;
    let height = canvas.height = window.innerHeight;

    window.addEventListener('resize', () => {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    });

    // Global gravitational constants and metrics
    let baseGravity = 0.5;
    let activeGravity = baseGravity;
    let mergeCounter = 0;
    const words = [];

    // Simple semantic vectorizer using letter n-gram frequency hashing
    function getSemanticVector(text) {
      const vec = new Float32Array(16);
      const clean = text.toLowerCase().replace(/[^a-z0-9]/g, '');
      for (let i = 0; i < clean.length; i++) {
        const code = clean.charCodeAt(i);
        vec[code % 16] += 1;
        if (i < clean.length - 1) {
          vec[(code + clean.charCodeAt(i + 1)) % 16] += 0.5;
        }
      }
      // Normalize vector
      let norm = 0;
      for (let i = 0; i < 16; i++) norm += vec[i] * vec[i];
      norm = Math.sqrt(norm) || 1;
      for (let i = 0; i < 16; i++) vec[i] /= norm;
      return vec;
    }

    // Cosine similarity between two semantic vectors
    function semanticSimilarity(v1, v2) {
      let dot = 0;
      for (let i = 0; i < 16; i++) dot += v1[i] * v2[i];
      return Math.max(0, dot); // 0 to 1 range
    }

    // Word/Paragraph Physics Object
    class WordBody {
      constructor(text, x, y) {
        this.text = text;
        this.x = x;
        this.y = y;
        this.vx = (Math.random() - 0.5) * 3;
        this.vy = (Math.random() - 0.5) * 3;
        this.vector = getSemanticVector(text);
        this.mass = Math.max(1, text.length);
        this.radius = Math.sqrt(this.mass) * 8 + 10;
        this.colorHue = Math.floor(this.vector.reduce((a, b) => a + b, 0) * 180) % 360;
        this.merged = false;
      }

      update() {
        this.x += this.vx;
        this.y += this.vy;
        // Damping force
        this.vx *= 0.985;
        this.vy *= 0.985;

        // Screen boundary reflection
        if (this.x - this.radius < 0) { this.x = this.radius; this.vx *= -0.8; }
        if (this.x + this.radius > width) { this.x = width - this.radius; this.vx *= -0.8; }
        if (this.y - this.radius < 0) { this.y = this.radius; this.vy *= -0.8; }
        if (this.y + this.radius > height - 120) { this.y = height - 120 - this.radius; this.vy *= -0.8; }
      }

      draw() {
        ctx.save();
        ctx.translate(this.x, this.y);

        // Soft aura proportional to mass & semantic hue
        const glowGrad = ctx.createRadialGradient(0, 0, 2, 0, 0, this.radius * 1.8);
        glowGrad.addColorStop(0, `hsla(${this.colorHue}, 80%, 60%, 0.3)`);
        glowGrad.addColorStop(1, `hsla(${this.colorHue}, 80%, 60%, 0)`);
        ctx.fillStyle = glowGrad;
        ctx.beginPath();
        ctx.arc(0, 0, this.radius * 1.8, 0, Math.PI * 2);
        ctx.fill();

        // Core node
        ctx.fillStyle = `hsl(${this.colorHue}, 70%, 15%)`;
        ctx.strokeStyle = `hsl(${this.colorHue}, 90%, 65%)`;
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.arc(0, 0, this.radius, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke();

        // Render text inside node
        ctx.fillStyle = '#f8fafc';
        ctx.font = `${Math.min(14, Math.max(10, this.radius * 0.4))}px monospace`;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        
        // Truncate text if too long for display
        let dispText = this.text;
        if (dispText.length > 20) dispText = dispText.substring(0, 18) + '..';
        ctx.fillText(dispText, 0, 0);

        ctx.restore();
      }
    }

    // Spawn new word bodies from editor input
    function processInputText(fullText) {
      const tokens = fullText.trim().split(/\s+/).filter(t => t.length > 0);
      if (tokens.length === 0) return;

      // Extract last typed word and turn into physical body
      const newText = tokens[tokens.length - 1];
      const spawnX = width / 2 + (Math.random() - 0.5) * 200;
      const spawnY = height / 3 + (Math.random() - 0.5) * 100;

      const newBody = new WordBody(newText, spawnX, spawnY);
      
      // Impart tangential orbital velocity relative to center
      const dx = spawnX - width / 2;
      const dy = spawnY - height / 2;
      const dist = Math.sqrt(dx * dx + dy * dy) || 1;
      newBody.vx = (-dy / dist) * 4;
      newBody.vy = (dx / dist) * 4;

      words.push(newBody);
      countHud.textContent = words.length;
    }

    // Dynamic keystroke handler altering gravity dynamics
    editor.addEventListener('keydown', (e) => {
      // Keystroke spikes local gravity field energy
      activeGravity += 0.35;
      
      // On Space or Enter, create a new semantic gravitational word body
      if (e.key === ' ' || e.key === 'Enter') {
        processInputText(editor.value);
        editor.value = '';
      }
    });

    // Physics Simulation Loop: Gravitational orbital mechanics + Semantic Merging
    function simulatePhysics() {
      // Decay dynamic gravity back towards baseline
      activeGravity += (baseGravity - activeGravity) * 0.05;
      gravHud.textContent = activeGravity.toFixed(2);

      for (let i = 0; i < words.length; i++) {
        const b1 = words[i];
        if (b1.merged) continue;

        for (let j = i + 1; j < words.length; j++) {
          const b2 = words[j];
          if (b2.merged) continue;

          const dx = b2.x - b1.x;
          const dy = b2.y - b1.y;
          const distSq = dx * dx + dy * dy + 100; // Softened distance
          const dist = Math.sqrt(distSq);

          // Calculate semantic affinity (0 to 1)
          const similarity = semanticSimilarity(b1.vector, b2.vector);

          // Gravitational force proportional to semantic similarity & mass
          // High semantic similarity creates intense local attraction field
          const force = (activeGravity * 12 * (b1.mass * b2.mass) * (1 + similarity * 8)) / distSq;
          const fx = (dx / dist) * force;
          const fy = (dy / dist) * force;

          b1.vx += fx / b1.mass;
          b1.vy += fy / b1.mass;
          b2.vx -= fx / b2.mass;
          b2.vy -= fy / b2.mass;

          // Draw semantic attraction web lines
          if (similarity > 0.25) {
            ctx.strokeStyle = `hsla(${(b1.colorHue + b2.colorHue) / 2}, 80%, 60%, ${similarity * 0.4})`;
            ctx.lineWidth = similarity * 2;
            ctx.beginPath();
            ctx.moveTo(b1.x, b1.y);
            ctx.lineTo(b2.x, b2.y);
            ctx.stroke();
          }

          // Collision & Merging logic based on physical proximity & semantic affinity
          if (dist < (b1.radius + b2.radius) * 0.8 && similarity > 0.35) {
            // Merge smaller into larger or combine both
            const primary = b1.mass >= b2.mass ? b1 : b2;
            const secondary = b1.mass >= b2.mass ? b2 : b1;

            // Conservation of momentum
            primary.vx = (primary.vx * primary.mass + secondary.vx * secondary.mass) / (primary.mass + secondary.mass);
            primary.vy = (primary.vy * primary.mass + secondary.vy * secondary.mass) / (primary.mass + secondary.mass);
            
            // Merge text and recalculate mass/vector
            primary.text = `${primary.text} ${secondary.text}`;
            primary.mass += secondary.mass;
            primary.radius = Math.sqrt(primary.mass) * 8 + 10;
            primary.vector = getSemanticVector(primary.text);

            secondary.merged = true;
            mergeCounter++;
            mergeHud.textContent = mergeCounter;
          }
        }
      }

      // Remove merged objects
      for (let i = words.length - 1; i >= 0; i--) {
        if (words[i].merged) {
          words.splice(i, 1);
        }
      }
      countHud.textContent = words.length;
    }

    // Render loop
    function animate() {
      // Background trails
      ctx.fillStyle = 'rgba(8, 8, 16, 0.25)';
      ctx.fillRect(0, 0, width, height);

      // Center force well visualization
      ctx.strokeStyle = `rgba(56, 189, 248, ${Math.min(0.3, activeGravity * 0.05)})`;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(width / 2, height / 2, 100 * activeGravity, 0, Math.PI * 2);
      ctx.stroke();

      simulatePhysics();

      // Update and draw word bodies
      words.forEach(body => {
        body.update();
        body.draw();
      });

      requestAnimationFrame(animate);
    }

    // Seed initial word bodies for immediate interactive feel
    const seedWords = ["Gravity", "Orbits", "Words", "Semantic", "Collision", "Text", "Physics", "Universe"];
    seedWords.forEach((word, idx) => {
      const angle = (idx / seedWords.length) * Math.PI * 2;
      const radius = 180;
      const x = width / 2 + Math.cos(angle) * radius;
      const y = height / 2 + Math.sin(angle) * radius;
      const body = new WordBody(word, x, y);
      body.vx = -Math.sin(angle) * 3;
      body.vy = Math.cos(angle) * 3;
      words.push(body);
    });

    // Start animation loop
    animate();
  </script>
</body>
</html>