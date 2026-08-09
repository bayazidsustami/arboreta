import os
import subprocess
import threading
import time
import json
import random
import math
import numpy as np
from http.server import HTTPServer, BaseHTTPRequestHandler
import socketserver

def get_git_commits(max_count=30):
    """Parses local git log into a structured timeline for audio synthesis."""
    cmd = [
        "git", "log", f"-n{max_count}",
        "--pretty=format:%H|%an|%s|%P"
    ]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines = res.stdout.strip().split("\n")
    except Exception:
        # Fallback simulated git history if run outside a valid git repo
        lines = [
            "a1b2c3d|Dev|Initial commit|",
            "e4f5g6h|Dev|Add feature core|a1b2c3d",
            "i7j8k9l|Dev|Fix bug in synthesis|e4f5g6h",
            "m0n1o2p|Dev|Merge branch 'feature/audio'|i7j8k9l q3r4s5t",
            "q3r4s5t|Dev|Refactor spatial sound|e4f5g6h",
            "u6v7w8x|Dev|Cleanup deleted lines|m0n1o2p"
        ]

    commits = []
    for line in lines:
        if not line.strip():
            continue
        parts = line.split("|")
        commit_hash = parts[0]
        author = parts[1] if len(parts) > 1 else "Unknown"
        msg = parts[2] if len(parts) > 2 else ""
        parents = parts[3].split() if len(parts) > 3 else []
        
        # Determine stats or mock if not readable
        deletions = random.randint(0, 50)
        additions = random.randint(5, 120)
        
        # Check if merge commit
        is_merge = len(parents) > 1 or "merge" in msg.lower()

        commits.append({
            "hash": commit_hash[:7],
            "author": author,
            "message": msg,
            "is_merge": is_merge,
            "deletions": deletions,
            "additions": additions,
            # Assign 2D spatial coordinate based on hash
            "x": (int(commit_hash[:4], 16) % 800) - 400 if len(commit_hash) >= 4 else random.randint(-400, 400),
            "y": (int(commit_hash[4:8], 16) % 600) - 300 if len(commit_hash) >= 8 else random.randint(-300, 300)
        })
    return commits

# Global state to track live HTTP traffic for real-time tempo modulation
TRAFFIC_COUNTER = 0
LAST_REQUEST_TIME = time.time()
TEMPO_BPM = 120

def register_traffic():
    global TRAFFIC_COUNTER, LAST_REQUEST_TIME, TEMPO_BPM
    now = time.time()
    dt = max(0.001, now - LAST_REQUEST_TIME)
    LAST_REQUEST_TIME = now
    TRAFFIC_COUNTER += 1
    
    # Live traffic modulates tempo: faster traffic = higher BPM
    target_bpm = min(240, max(60, 120 + int(1.0 / dt * 15)))
    TEMPO_BPM = int(TEMPO_BPM * 0.7 + target_bpm * 0.3)

class GitSoundscapeHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Suppress default HTTP logging for clean console

    def do_GET(self):
        register_traffic()
        if self.path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(HTML_CLIENT.encode("utf-8"))
        elif self.path == "/api/data":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            commits = get_git_commits()
            data = {
                "commits": commits,
                "bpm": TEMPO_BPM,
                "traffic": TRAFFIC_COUNTER
            }
            self.send_byte_data(json.dumps(data).encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    def send_byte_data(self, data):
        self.wfile.write(data)

HTML_CLIENT = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Git History 2D Soundscape</title>
    <style>
        body {
            margin: 0;
            background: #0d0e15;
            color: #00ffcc;
            font-family: 'Courier New', Courier, monospace;
            overflow: hidden;
            display: flex;
            flex-direction: column;
            align-items: center;
        }
        #canvas {
            background: #12131c;
            box-shadow: 0 0 20px rgba(0, 255, 204, 0.2);
            border-radius: 8px;
            margin-top: 10px;
        }
        #ui {
            margin-top: 15px;
            display: flex;
            gap: 20px;
            align-items: center;
        }
        button {
            background: #00ffcc;
            color: #0d0e15;
            border: none;
            padding: 10px 20px;
            font-weight: bold;
            cursor: pointer;
            border-radius: 4px;
            box-shadow: 0 0 10px #00ffcc;
        }
        button:hover { background: #ffffff; }
        .stat { font-size: 14px; }
    </style>
</head>
<body>
    <div id="ui">
        <button id="startBtn">START SOUNDSCAPE</button>
        <div class="stat">TEMPO: <span id="bpmVal">120</span> BPM</div>
        <div class="stat">TRAFFIC PULSES: <span id="trafficVal">0</span></div>
    </div>
    <canvas id="canvas" width="900" height="600"></canvas>

    <script>
        let audioCtx, isPlaying = false;
        let commits = [];
        let currentIdx = 0;
        let nextBeatTime = 0;
        let bpm = 120;
        
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');
        const centerX = canvas.width / 2;
        const centerY = canvas.height / 2;

        async function fetchData() {
            try {
                const res = await fetch('/api/data');
                const data = await res.json();
                commits = data.commits;
                bpm = data.bpm;
                document.getElementById('bpmVal').innerText = bpm;
                document.getElementById('trafficVal').innerText = data.traffic;
            } catch (e) {
                console.error(e);
            }
        }

        // Web Audio API Synthesis Engine
        function initAudio() {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        }

        // Generate 2D Panner for Spatial Positioning
        function createSpatialNode(x, y) {
            if (!audioCtx) return null;
            const panner = audioCtx.createPanner();
            panner.panningModel = 'HRTF';
            panner.distanceModel = 'inverse';
            panner.setPosition(x / 200, y / 200, -0.5);
            panner.connect(audioCtx.destination);
            return panner;
        }

        // Play Harmonic Chord for Merge Commits
        function playHarmonicChord(x, y) {
            const frequencies = [261.63, 329.63, 392.00, 523.25]; // C Major Chord
            const panner = createSpatialNode(x, y);
            
            frequencies.forEach((freq, idx) => {
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                
                osc.type = 'sine';
                osc.frequency.setValueAtTime(freq * (1 + idx * 0.01), audioCtx.currentTime);
                
                gain.gain.setValueAtTime(0.15, audioCtx.currentTime);
                gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 1.2);
                
                osc.connect(gain);
                gain.connect(panner);
                
                osc.start();
                osc.stop(audioCtx.currentTime + 1.2);
            });
        }

        // Play White Noise Burst for Deleted Lines
        function playWhiteNoise(deletions, x, y) {
            if (deletions <= 0) return;
            
            const bufferSize = audioCtx.sampleRate * Math.min(0.5, deletions * 0.01);
            const buffer = audioCtx.createBuffer(1, bufferSize, audioCtx.sampleRate);
            const output = buffer.getChannelData(0);
            
            for (let i = 0; i < bufferSize; i++) {
                output[i] = Math.random() * 2 - 1;
            }

            const whiteNoise = audioCtx.createBufferSource();
            whiteNoise.buffer = buffer;

            const filter = audioCtx.createBiquadFilter();
            filter.type = 'bandpass';
            filter.frequency.value = 1000 + deletions * 20;

            const gain = audioCtx.createGain();
            const duration = Math.min(0.4, deletions * 0.008);
            gain.gain.setValueAtTime(0.2, audioCtx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration);

            const panner = createSpatialNode(x, y);

            whiteNoise.connect(filter);
            filter.connect(gain);
            gain.connect(panner);

            whiteNoise.start();
        }

        // Single Beat Scheduler
        function playStep() {
            if (commits.length === 0) return;
            const commit = commits[currentIdx];

            if (commit.is_merge) {
                playHarmonicChord(commit.x, commit.y);
            } else {
                // Pitch based on additions
                const panner = createSpatialNode(commit.x, commit.y);
                const osc = audioCtx.createOscillator();
                const gain = audioCtx.createGain();
                osc.frequency.setValueAtTime(150 + commit.additions * 3, audioCtx.currentTime);
                gain.gain.setValueAtTime(0.1, audioCtx.currentTime);
                gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.3);
                osc.connect(gain);
                gain.connect(panner);
                osc.start();
                osc.stop(audioCtx.currentTime + 0.3);
            }

            playWhiteNoise(commit.deletions, commit.x, commit.y);

            // Trigger visual pulse
            commit.active = 1.0;

            currentIdx = (currentIdx + 1) % commits.length;
        }

        // Audio Loop Engine
        function scheduler() {
            while (nextBeatTime < audioCtx.currentTime + 0.1) {
                playStep();
                const secondsPerBeat = 60.0 / bpm;
                nextBeatTime += secondsPerBeat;
            }
            if (isPlaying) {
                setTimeout(scheduler, 25);
            }
        }

        // 2D Canvas Renderer
        function render() {
            ctx.fillStyle = 'rgba(18, 19, 28, 0.2)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            // Draw center listener node
            ctx.beginPath();
            ctx.arc(centerX, centerY, 8, 0, Math.PI * 2);
            ctx.fillStyle = '#00ffcc';
            ctx.fill();
            ctx.shadowBlur = 10;
            ctx.shadowColor = '#00ffcc';

            // Draw commits as spatial sound points
            commits.forEach((c, idx) => {
                const px = centerX + c.x;
                const py = centerY + c.y;

                ctx.beginPath();
                ctx.arc(px, py, c.is_merge ? 10 : 5, 0, Math.PI * 2);
                
                if (c.active && c.active > 0) {
                    ctx.fillStyle = c.is_merge ? '#ff00ff' : '#ffffff';
                    ctx.shadowBlur = 20;
                    ctx.shadowColor = c.is_merge ? '#ff00ff' : '#00ffcc';
                    c.active -= 0.05;
                } else {
                    ctx.fillStyle = c.is_merge ? 'rgba(255, 0, 255, 0.5)' : 'rgba(0, 255, 204, 0.4)';
                    ctx.shadowBlur = 0;
                }
                ctx.fill();

                // Draw line connection to center listener
                ctx.beginPath();
                ctx.moveTo(centerX, centerY);
                ctx.lineTo(px, py);
                ctx.strokeStyle = 'rgba(255, 255, 255, 0.03)';
                ctx.stroke();
            });

            requestAnimationFrame(render);
        }

        document.getElementById('startBtn').addEventListener('click', () => {
            if (!isPlaying) {
                initAudio();
                audioCtx.resume();
                isPlaying = true;
                nextBeatTime = audioCtx.currentTime;
                scheduler();
                setInterval(fetchData, 1000);
                document.getElementById('startBtn').innerText = "SOUNDSCAPE ACTIVE";
            }
        });

        fetchData();
        render();
    </script>
</body>
</html>
"""

def run_server(port=8000):
    """Starts the interactive soundscape HTTP server."""
    server_address = ("", port)
    httpd = HTTPServer(server_address, GitSoundscapeHandler)
    print(f"[*] Git Soundscape active at http://localhost:{port}")
    print("[*] Open browser and click START. Refresh/interact to modulate tempo live.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[*] Shutting down soundscape server.")

if __name__ == "__main__":
    run_server()