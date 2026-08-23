```javascript
/**
/*******************************************************************************
 * Git Audio-Visual Tapestry & ASCII Fractal Generator
 * 
 * Takes git commit history (`git log --numstat`) via stdin, parses chronological
 * deltas (insertions/deletions), and creates a microtonal Web Audio composition.
 * Mouse/touch interaction modulates audio pitch/delay and progressively degrades
 * the visual representation into an ASCII Mandelbrot fractal.
 *
 * Usage in Node.js / Browser environment:
 * Pipe `git log --numstat --reverse` output or run directly in Node/Browser.
 ******************************************************************************/

(function () {
  // 1. Setup Audio & Visual Contexts
  const isNode = typeof window === 'undefined';
  
  if (isNode) {
    console.log("Git Tapestry Engine loaded. Run in a browser environment with stdin input for interactive WebAudio & Canvas rendering.");
  }

  const canvas = isNode ? null : document.createElement('canvas');
  const ctx = canvas ? canvas.getContext('2d') : null;
  if (canvas) {
    document.body.appendChild(canvas);
    document.body.style.margin = '0';
    document.body.style.overflow = 'hidden';
    document.body.style.backgroundColor = '#050508';
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  }

  // Audio Setup
  const AudioCtx = !isNode && (window.AudioContext || window.webkitAudioContext);
  const audioCtx = AudioCtx ? new AudioCtx() : null;
  
  // Reverb / Delay feedback loop
  let delayNode, feedbackNode, masterGain;
  if (audioCtx) {
    masterGain = audioCtx.createGain();
    masterGain.gain.setValueAtTime(0.3, audioCtx.currentTime);
    
    delayNode = audioCtx.createDelay();
    delayNode.delayTime.value = 0.25;
    
    feedbackNode = audioCtx.createGain();
    feedbackNode.gain.value = 0.6;
    
    delayNode.connect(feedbackNode);
    feedbackNode.connect(delayNode);
    
    masterGain.connect(audioCtx.destination);
    masterGain.connect(delayNode);
    delayNode.connect(audioCtx.destination);
  }

  // State Management
  let commits = [];
  let interactionIntensity = 0; // 0 = Clean git timeline, 1 = Full ASCII Fractal Decay
  let mouse = { x: 0.5, y: 0.5 };
  let currentStep = 0;

  // 2. Sample Data Generator (Fall-back if stdin is empty)
  const sampleGitLog = `
commit a1b2c3d4e5f67890
12    4    src/index.js
45    2    src/audio.js

commit b2c3d4e5f67890a1
8     15   src/index.js
120   0    src/fractal.js

commit c3d4e5f67890a1b2
3     3    src/audio.js
0     42   src/legacy.js
  `;

  // 3. Parser: Git Log --numstat to Chronological Deltas
  function parseGitLog(rawLog) {
    const lines = rawLog.split('\n');
    const commitData = [];
    let currentCommit = null;

    for (let line of lines) {
      if (line.startsWith('commit ')) {
        if (currentCommit) commitData.push(currentCommit);
        currentCommit = { hash: line.split(' ')[1], insertions: 0, deletions: 0, files: 0 };
      } else if (currentCommit) {
        const match = line.match(/^(\d+)\s+(\d+)\s+(.+)$/);
        if (match) {
          currentCommit.insertions += parseInt(match[1], 10);
          currentCommit.deletions += parseInt(match[2], 10);
          currentCommit.files += 1;
        }
      }
    }
    if (currentCommit) commitData.push(currentCommit);
    return commitData.length ? commitData : parseGitLog(sampleGitLog);
  }

  // 4. Microtonal Audio Synth (43-EDO / Just Intonation Synthesis)
  function playCommitTone(commit, index) {
    if (!audioCtx) return;
    if (audioCtx.state === 'suspended') audioCtx.resume();

    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();

    // Microtonal pitch map using insertions & deletions ratio
    const delta = commit.insertions - commit.deletions;
    const baseFreq = 110; // A2
    
    // Convert git delta into x/43 microtonal octave divisions
    const microInterval = (Math.abs(delta) % 43) / 43;
    const octave = 1 + (commit.files % 3);
    const frequency = baseFreq * Math.pow(2, octave + microInterval + (mouse.y * 0.5));

    // Dynamic wave shape depending on insertions vs deletions
    osc.type = commit.insertions > commit.deletions ? 'sawtooth' : 'sine';
    osc.frequency.setValueAtTime(frequency, audioCtx.currentTime);

    // Filter modulation
    const filter = audioCtx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.value = 200 + (commit.insertions * 10) * (1 - mouse.x);

    // Envelope
    const now = audioCtx.currentTime;
    const duration = 0.2 + (commit.deletions * 0.02);
    gain.gain.setValueAtTime(0.01, now);
    gain.gain.exponentialRampToValueAtTime(0.2, now + 0.05);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + duration);

    osc.connect(filter);
    filter.connect(gain);
    gain.connect(masterGain);

    osc.start(now);
    osc.stop(now + duration);
  }

  // 5. Visual Renderer: Git History visualizer decaying into ASCII Fractal
  const asciiChars = ' .:-=+*#%@';

  function calculateMandelbrotASCII(px, py, maxIter) {
    // Map canvas coordinates to complex plane with mouse distortion
    let x0 = (px / canvas.width - 0.5) * 3.5 - 0.7 + (mouse.x - 0.5);
    let y0 = (py / canvas.height - 0.5) * 2.0 + (mouse.y - 0.5);
    let x = 0, y = 0, iter = 0;

    while (x * x + y * y <= 4 && iter < maxIter) {
      let xTemp = x * x - y * y + x0;
      y = 2 * x * y + y0;
      x = xTemp;
      iter++;
    }

    return asciiChars[Math.floor((iter / maxIter) * (asciiChars.length - 1))];
  }

  function renderFrame() {
    if (!ctx) return;

    ctx.fillStyle = 'rgba(5, 5, 8, 0.2)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    const activeCommit = commits[currentStep] || { insertions: 0, deletions: 0, files: 0 };

    // Progressive visual decay: grid-based ASCII render
    const fontSize = 14;
    ctx.font = `${fontSize}px monospace`;

    const cols = Math.floor(canvas.width / fontSize);
    const rows = Math.floor(canvas.height / fontSize);

    for (let r = 0; r < rows; r += 2) {
      for (let c = 0; c < cols; c += 2) {
        const x = c * fontSize;
        const y = r * fontSize;

        // Blending pure Git timeline UI with ASCII Mandelbrot Fractal based on interaction
        if (Math.random() < interactionIntensity) {
          // Fractal decay layer
          const char = calculateMandelbrotASCII(x, y, 16);
          const green = Math.floor(100 + interactionIntensity * 155);
          ctx.fillStyle = `rgb(40, ${green}, 120)`;
          ctx.fillText(char, x, y);
        } else {
          // Timeline visual representation
          if (c === Math.floor(cols * (currentStep / Math.max(1, commits.length)))) {
            ctx.fillStyle = '#00ffcc';
            ctx.fillText('║', x, y);
          } else if (r === Math.floor(rows / 2)) {
            const h = (activeCommit.insertions - activeCommit.deletions) % 10;
            ctx.fillStyle = h >= 0 ? '#33ff77' : '#ff3366';
            ctx.fillText(h >= 0 ? '+' : '-', x, y);
          }
        }
      }
    }

    // Step audio tapestry forward
    if (commits.length > 0 && Math.random() < 0.1) {
      playCommitTone(activeCommit, currentStep);
      currentStep = (currentStep + 1) % commits.length;
    }

    // Smoothly decay interaction intensity back over time unless driven by mouse
    interactionIntensity = Math.max(0, interactionIntensity - 0.005);

    requestAnimationFrame(renderFrame);
  }

  // 6. Interaction Handlers
  if (canvas) {
    window.addEventListener('mousemove', (e) => {
      mouse.x = e.clientX / window.innerWidth;
      mouse.y = e.clientY / window.innerHeight;
      // Mouse movement triggers visual decay into ASCII fractals
      interactionIntensity = Math.min(1, interactionIntensity + 0.05);
      
      if (delayNode) {
        delayNode.delayTime.value = 0.05 + mouse.x * 0.4;
      }
    });

    window.addEventListener('touchmove', (e) => {
      if (e.touches.length > 0) {
        mouse.x = e.touches[0].clientX / window.innerWidth;
        mouse.y = e.touches[0].clientY / window.innerHeight;
        interactionIntensity = Math.min(1, interactionIntensity + 0.08);
      }
    });

    window.addEventListener('resize', () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    });
  }

  // 7. Process Input Data (stdin in Node/Browser pipe)
  function init(gitRawText) {
    commits = parseGitLog(gitRawText);
    if (!isNode) {
      renderFrame();
    } else {
      console.log(`Parsed ${commits.length} commits into microtonal sequence.`);
      commits.forEach((c, i) => {
        console.log(`[Step ${i}] +${c.insertions} -${c.deletions} (${c.files} files)`);
      });
    }
  }

  // Read stdin if available
  if (typeof process !== 'undefined' && process.stdin) {
    let input = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => input += chunk);
    process.stdin.on('end', () => init(input));
    
    // Timeout fallback if stdin is unpiped
    setTimeout(() => {
      if (!input) init(sampleGitLog);
    }, 500);
  } else {
    init(sampleGitLog);
  }

})();
```