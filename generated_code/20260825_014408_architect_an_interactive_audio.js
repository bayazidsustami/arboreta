const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Git Commit Fractal Galaxy & Music Synthesizer</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { background: #050508; color: #e0e6ed; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; overflow: hidden; height: 100vh; display: flex; flex-direction: column; }
        canvas { flex: 1; width: 100%; height: 100%; display: block; }
        #ui { position: absolute; top: 20px; left: 20px; z-index: 10; background: rgba(15, 18, 28, 0.75); backdrop-filter: blur(12px); border: 1px solid rgba(255, 255, 255, 0.1); padding: 20px; border-radius: 12px; width: 320px; box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.37); }
        h1 { font-size: 1.1rem; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 15px; color: #a5b4fc; }
        .input-group { margin-bottom: 12px; }
        label { display: block; font-size: 0.75rem; text-transform: uppercase; color: #94a3b8; margin-bottom: 4px; }
        input, select { width: 100%; padding: 8px 12px; background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.15); border-radius: 6px; color: #fff; font-size: 0.85rem; outline: none; }
        input:focus, select:focus { border-color: #6366f1; }
        button { width: 100%; padding: 10px; background: linear-gradient(135deg, #6366f1, #4f46e5); border: none; border-radius: 6px; color: #fff; font-weight: bold; cursor: pointer; transition: all 0.2s; margin-top: 5px; }
        button:hover { opacity: 0.9; transform: translateY(-1px); }
        #status { margin-top: 10px; font-size: 0.75rem; color: #38bdf8; min-height: 18px; }
        #info { position: absolute; bottom: 20px; left: 20px; font-size: 0.8rem; color: #64748b; pointer-events: none; }
    </style>
</head>
<body>
    <div id="ui">
        <h1>Git Synthesizer</h1>
        <div class="input-group">
            <label>GitHub Repository</label>
            <input type="text" id="repoInput" value="facebook/react" placeholder="owner/repo">
        </div>
        <div class="input-group">
            <label>Scale Preset</label>
            <select id="scaleSelect">
                <option value="pentatonic">Pentatonic Minor</option>
                <option value="dorian">Dorian Mode</option>
                <option value="chromatic">Chromatic</option>
                <option value="japanese">Insen (Japanese)</option>
            </select>
        </div>
        <button id="startBtn">Fetch & Synthesize</button>
        <div id="status">Ready</div>
    </div>
    <div id="info">Visualizing commit hash entropy as fractal galaxy orbits & generative web audio notes.</div>
    <canvas id="canvas"></canvas>

    <script>
        // Scales mapped to semitone ratios
        const SCALES = {
            pentatonic: [0, 3, 5, 7, 10, 12, 15, 17],
            dorian: [0, 2, 3, 5, 7, 9, 10, 12],
            chromatic: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
            japanese: [0, 1, 5, 7, 8, 12, 13, 17]
        };

        // Web Audio Context setup
        let audioCtx = null;
        let masterGain = null;

        function initAudio() {
            if (!audioCtx) {
                audioCtx = new (window.AudioContext || window.webkitAudioContext)();
                masterGain = audioCtx.createGain();
                masterGain.gain.setValueAtTime(0.15, audioCtx.currentTime);
                
                // Add ambient reverb / delay buffer
                const delay = audioCtx.createDelay();
                delay.delayTime.value = 0.35;
                const feedback = audioCtx.createGain();
                feedback.gain.value = 0.4;
                
                delay.connect(feedback);
                feedback.connect(delay);
                masterGain.connect(delay);
                delay.connect(audioCtx.destination);
                masterGain.connect(audioCtx.destination);
            }
            if (audioCtx.state === 'suspended') {
                audioCtx.resume();
            }
        }

        // Play synth note based on commit parameters
        function playCommitTone(hashVal, lengthVal, timeOffset) {
            if (!audioCtx) return;

            const scale = SCALES[document.getElementById('scaleSelect').value];
            const baseFreq = 130.81; // C3
            const noteIndex = hashVal % scale.length;
            const octave = (hashVal % 3);
            const freq = baseFreq * Math.pow(2, (scale[noteIndex] + octave * 12) / 12);

            const osc = audioCtx.createOscillator();
            const noteGain = audioCtx.createGain();
            const filter = audioCtx.createBiquadFilter();

            // Modulate oscillator waveform based on commit character
            const types = ['sine', 'triangle', 'sawtooth', 'square'];
            osc.type = types[hashVal % types.length];
            osc.frequency.setValueAtTime(freq, audioCtx.currentTime + timeOffset);

            // Filter cutoff driven by commit length
            filter.type = 'lowpass';
            filter.frequency.setValueAtTime(200 + (lengthVal * 10), audioCtx.currentTime + timeOffset);
            filter.Q.value = 5;

            // Envelope
            const now = audioCtx.currentTime + timeOffset;
            const duration = 0.2 + (lengthVal % 5) * 0.1;
            noteGain.gain.setValueAtTime(0, now);
            noteGain.gain.linearRampToValueAtTime(0.3, now + 0.02);
            noteGain.gain.exponentialRampToValueAtTime(0.0001, now + duration);

            osc.connect(filter);
            filter.connect(noteGain);
            noteGain.connect(masterGain);

            osc.start(now);
            osc.stop(now + duration);
        }

        // Canvas setup
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');
        let width, height;

        function resize() {
            width = canvas.width = window.innerWidth;
            height = canvas.height = window.innerHeight;
        }
        window.addEventListener('resize', resize);
        resize();

        // Galaxy / Fractal particle system
        let particles = [];
        let rotationAngle = 0;

        class CommitParticle {
            constructor(commit, index, total) {
                this.hash = commit.sha;
                this.val = parseInt(this.hash.substring(0, 8), 16);
                this.messageLength = commit.commit.message.length;
                
                // Spiral arms distribution based on commit index & entropy
                const armAngle = (index / total) * Math.PI * 8;
                const distance = 50 + (this.val % (Math.min(width, height) * 0.4));
                
                this.baseX = Math.cos(armAngle) * distance;
                this.baseY = Math.sin(armAngle) * distance;
                this.x = this.baseX;
                this.y = this.baseY;
                
                // Chromatic values mapped from SHA hash chunks
                this.r = parseInt(this.hash.substring(0, 2), 16);
                this.g = parseInt(this.hash.substring(2, 4), 16);
                this.b = parseInt(this.hash.substring(4, 6), 16);
                this.size = 2 + (this.messageLength % 6);
                this.pulseSpeed = 0.02 + (this.val % 50) / 1000;
                this.phase = Math.random() * Math.PI * 2;
                
                // Audio trigger timing
                this.audioTriggered = false;
                this.triggerAngle = (index / total) * Math.PI * 2;
            }

            update(angle) {
                this.phase += this.pulseSpeed;
                
                // Fractal orbital deformation
                const k = 3;
                const fractalMod = Math.sin(k * angle + this.phase) * 15;
                const currentDist = Math.hypot(this.baseX, this.baseY) + fractalMod;
                const baseAngle = Math.atan2(this.baseY, this.baseX) + angle;

                this.x = Math.cos(baseAngle) * currentDist;
                this.y = Math.sin(baseAngle) * currentDist;

                // Check for sweep line trigger to play sound
                const normalizedAngle = (baseAngle % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2);
                if (Math.abs(normalizedAngle - Math.PI) < 0.03 && !this.audioTriggered) {
                    playCommitTone(this.val, this.messageLength, 0);
                    this.audioTriggered = true;
                    this.size = 8 + (this.messageLength % 6); // Visual pulse trigger
                } else if (Math.abs(normalizedAngle - Math.PI) > 0.1) {
                    this.audioTriggered = false;
                    this.size = Math.max(2 + (this.messageLength % 6), this.size * 0.95);
                }
            }

            draw(ctx) {
                ctx.save();
                ctx.beginPath();
                ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
                
                const alpha = 0.6 + Math.sin(this.phase) * 0.4;
                ctx.fillStyle = \`rgba(\${this.r}, \${this.g}, \${this.b}, \${alpha})\`;
                ctx.shadowColor = \`rgb(\${this.r}, \${this.g}, \${this.b})\`;
                ctx.shadowBlur = this.audioTriggered ? 20 : 5;
                
                ctx.fill();
                ctx.restore();
            }
        }

        // Fetch repository commits from GitHub API
        async function fetchCommits(repo) {
            const statusEl = document.getElementById('status');
            statusEl.textContent = 'Fetching commits...';
            try {
                const response = await fetch(\`[https://api.github.com/repos/](https://api.github.com/repos/)\${repo}/commits?per_page=100\`);
                if (!response.ok) throw new Error('Repo not found or rate limited');
                const commits = await response.json();
                statusEl.textContent = \`Loaded \${commits.length} commits.\`;
                
                // Convert commits to particles
                particles = commits.map((c, i) => new CommitParticle(c, i, commits.length));
            } catch (err) {
                statusEl.textContent = \`Error: \${err.message}\`;
            }
        }

        // Animation Loop
        function animate() {
            // Trail effect (fade background slightly)
            ctx.fillStyle = 'rgba(5, 5, 8, 0.25)';
            ctx.fillRect(0, 0, width, height);

            ctx.save();
            ctx.translate(width / 2, height / 2);

            rotationAngle += 0.005;

            // Draw connecting fractal lines between adjacent particles
            ctx.beginPath();
            ctx.strokeStyle = 'rgba(99, 102, 241, 0.15)';
            ctx.lineWidth = 0.5;
            for (let i = 0; i < particles.length; i++) {
                const p1 = particles[i];
                const p2 = particles[(i + 1) % particles.length];
                ctx.moveTo(p1.x, p1.y);
                ctx.lineTo(p2.x, p2.y);
            }
            ctx.stroke();

            // Render and update individual particles
            particles.forEach(p => {
                p.update(rotationAngle);
                p.draw(ctx);
            });

            // Draw resonant center core
            ctx.beginPath();
            ctx.arc(0, 0, 15 + Math.sin(rotationAngle * 4) * 5, 0, Math.PI * 2);
            ctx.fillStyle = '#6366f1';
            ctx.shadowColor = '#818cf8';
            ctx.shadowBlur = 30;
            ctx.fill();

            ctx.restore();
            requestAnimationFrame(animate);
        }

        // UI Event Listeners
        document.getElementById('startBtn').addEventListener('click', () => {
            initAudio();
            const repo = document.getElementById('repoInput').value.trim();
            if (repo) fetchCommits(repo);
        });

        // Initialize with default repo
        animate();
    </script>
</body>
</html>`;

console.log(html);