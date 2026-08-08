import http.server
import socketserver
import json
import threading
import time
import webbrowser
import os
import random

# Try importing psutil for real hardware metrics; fall back gracefully if unavailable
try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False

# Global state to track telemetry over time for rate calculations
state_lock = threading.Lock()
telemetry_data = {
    "cpu_temp": 45.0,
    "battery_drain": 15.0,
    "cpu_usage": 10.0,
    "battery_percent": 100.0,
    "is_plugged": True
}

def monitor_system():
    """Continuously monitors CPU temperature, CPU usage, and battery status."""
    global telemetry_data
    last_battery_pct = None
    last_time = time.time()
    drain_rate = 10.0  # baseline estimated milliwatts/percent per min

    while True:
        temp = 45.0
        cpu_use = 10.0
        bat_pct = 100.0
        plugged = True

        if HAS_PSUTIL:
            # CPU Usage
            cpu_use = psutil.cpu_percent(interval=None)
            
            # CPU Temperature (OS dependent support in psutil)
            try:
                temps = psutil.sensors_temperatures()
                if temps:
                    for name, entries in temps.items():
                        if entries:
                            temp = entries[0].current
                            break
                else:
                    temp = 40.0 + (cpu_use * 0.4)  # Dynamic estimate if direct sensor unreadable
            except Exception:
                temp = 40.0 + (cpu_use * 0.4)

            # Battery Status & Drain Rate
            try:
                bat = psutil.sensors_battery()
                if bat:
                    bat_pct = bat.percent
                    plugged = bat.power_plugged
                    now = time.time()
                    
                    if last_battery_pct is not None and not plugged:
                        dt = (now - last_time) / 3600.0  # hours
                        dp = last_battery_pct - bat_pct
                        if dt > 0 and dp >= 0:
                            # Calculate estimated drain (% drop per hour)
                            calculated_drain = dp / dt
                            drain_rate = max(5.0, min(calculated_drain, 100.0))
                    elif plugged:
                        drain_rate = 2.0  # Minimal effective stress when charging
                    
                    last_battery_pct = bat_pct
                    last_time = now
            except Exception:
                pass
        else:
            # Synthetic variation if psutil isn't installed
            t = time.time()
            cpu_use = 20.0 + 15.0 * (1.0 + (t % 10) / 10.0)
            temp = 42.0 + (cpu_use * 0.35) + random.uniform(-1, 1)
            drain_rate = 12.0 + random.uniform(-2, 2)

        with state_lock:
            telemetry_data["cpu_temp"] = round(temp, 1)
            telemetry_data["battery_drain"] = round(drain_rate, 1)
            telemetry_data["cpu_usage"] = round(cpu_use, 1)
            telemetry_data["battery_percent"] = round(bat_pct, 1)
            telemetry_data["is_plugged"] = plugged

        time.sleep(1.0)

HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Generative Digital Necrosis - System Stress Canvas</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body, html { width: 100%; height: 100%; overflow: hidden; background: #050508; font-family: 'Courier New', monospace; }
        canvas { display: block; width: 100vw; height: 100vh; }
        #hud {
            position: absolute;
            top: 20px;
            left: 20px;
            color: rgba(255, 255, 255, 0.75);
            background: rgba(10, 10, 15, 0.7);
            padding: 15px 20px;
            border-radius: 8px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            pointer-events: none;
            box-shadow: 0 10px 30px rgba(0,0,0,0.5);
        }
        h1 { font-size: 14px; text-transform: uppercase; letter-spacing: 2px; margin-bottom: 8px; color: #8a9ba8; }
        .metric { font-size: 12px; margin: 4px 0; }
        .value { font-weight: bold; color: #61afef; }
        .stress-bar-bg { width: 100%; height: 6px; background: rgba(255,255,255,0.1); border-radius: 3px; margin-top: 8px; overflow: hidden; }
        .stress-bar-fill { height: 100%; width: 0%; background: linear-gradient(90deg, #98c379, #e5c07b, #e06c75); transition: width 0.5s ease; }
    </style>
</head>
<body>
    <div id="hud">
        <h1>System Biomarker Sync</h1>
        <div class="metric">CPU Temp: <span id="tempVal" class="value">--</span> °C</div>
        <div class="metric">Drain Rate: <span id="drainVal" class="value">--</span> %/hr</div>
        <div class="metric">CPU Load: <span id="loadVal" class="value">--</span> %</div>
        <div class="metric">Status: <span id="statusVal" class="value">Thriving</span></div>
        <div class="stress-bar-bg"><div id="stressBar" class="stress-bar-fill"></div></div>
    </div>
    <canvas id="canvas"></canvas>

    <script>
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');

        let width, height;
        function resize() {
            width = canvas.width = window.innerWidth;
            height = canvas.height = window.innerHeight;
        }
        window.addEventListener('resize', resize);
        resize();

        // System state smoothed over time
        let metrics = { cpu_temp: 45, battery_drain: 10, cpu_usage: 10, stress: 0 };
        let smoothedStress = 0;

        // Generative Organism Branch Class
        class Branch {
            constructor(x, y, angle, length, depth, maxDepth) {
                this.x = x;
                this.y = y;
                this.angle = angle;
                this.length = length;
                this.depth = depth;
                this.maxDepth = maxDepth;
                this.children = [];
                this.growth = 0;
                this.rotProgress = 0;
                
                if (depth < maxDepth) {
                    const numBranches = 2 + Math.floor(Math.random() * 2);
                    for (let i = 0; i < numBranches; i++) {
                        const newAngle = angle + (Math.random() - 0.5) * 0.8;
                        const newLength = length * (0.65 + Math.random() * 0.2);
                        this.children.push(new Branch(0, 0, newAngle, newLength, depth + 1, maxDepth));
                    }
                }
            }

            draw(parentX, parentY, stress) {
                this.growth = Math.min(1, this.growth + 0.02);
                
                // Stress alters angle (wilting downwards due to high stress/gravity)
                const gravityDroop = stress * 0.015 * (this.depth + 1);
                const effectiveAngle = this.angle + (this.angle > -Math.PI / 2 ? gravityDroop : -gravityDroop);

                const currentLen = this.length * this.growth;
                const endX = parentX + Math.cos(effectiveAngle) * currentLen;
                const endY = parentY + Math.sin(effectiveAngle) * currentLen + (stress * 2.0 * (this.depth / this.maxDepth));

                // Color shifts from vibrant teal/emerald to rotting brown/charcoal under stress
                const healthRatio = 1 - Math.min(1, stress);
                const r = Math.floor(20 + stress * 180);
                const g = Math.floor(180 * healthRatio + stress * 40);
                const b = Math.floor(120 * healthRatio + stress * 20);
                const alpha = Math.max(0.15, 0.9 - stress * 0.5);

                ctx.save();
                ctx.beginPath();
                ctx.moveTo(parentX, parentY);
                ctx.lineTo(endX, endY);
                ctx.strokeStyle = `rgba(${r}, ${g}, ${b}, ${alpha})`;
                ctx.lineWidth = Math.max(1, (this.maxDepth - this.depth + 1) * (1 - stress * 0.4));
                ctx.lineCap = 'round';
                ctx.stroke();

                // Draw decaying bloom/spore clusters at terminals
                if (this.depth === this.maxDepth) {
                    this.drawBloom(endX, endY, stress);
                }

                // Recursively render children
                if (this.growth > 0.5) {
                    for (let child of this.children) {
                        child.draw(endX, endY, stress);
                    }
                }
                ctx.restore();
            }

            drawBloom(x, y, stress) {
                const bloomRadius = (12 - this.depth) * (1 - stress * 0.6);
                if (bloomRadius <= 0) return;

                const r = Math.floor(220 * stress + 80 * (1 - stress));
                const g = Math.floor(100 * (1 - stress));
                const b = Math.floor(150 * (1 - stress) + 50 * stress);

                ctx.beginPath();
                ctx.arc(x, y, Math.max(1, bloomRadius), 0, Math.PI * 2);
                ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${0.7 - stress * 0.4})`;
                ctx.fill();

                // Generate falling ash/spore particles when wilting
                if (stress > 0.35 && Math.random() < stress * 0.3) {
                    spores.push(new Spore(x, y, stress));
                }
            }
        }

        // Particle System for Decomposition
        class Spore {
            constructor(x, y, stress) {
                this.x = x;
                this.y = y;
                this.vx = (Math.random() - 0.5) * (1 + stress * 3);
                this.vy = Math.random() * (1 + stress * 4) + 0.5; // Flakes fall downward
                this.life = 1.0;
                this.decay = 0.005 + Math.random() * 0.02 * stress;
                this.size = Math.random() * 3 + 1;
            }

            update() {
                this.x += this.vx;
                this.y += this.vy;
                this.life -= this.decay;
            }

            draw() {
                ctx.fillStyle = `rgba(180, 80, 50, ${this.life * 0.6})`;
                ctx.beginPath();
                ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        let roots = [];
        let spores = [];

        function initOrganism() {
            roots = [];
            const mainBranches = 5;
            for (let i = 0; i < mainBranches; i++) {
                const angle = -Math.PI / 2 + (i - (mainBranches - 1) / 2) * 0.35;
                roots.push(new Branch(width / 2, height - 80, angle, 110, 0, 5));
            }
        }
        initOrganism();

        // Fetch metrics from backend
        async function fetchTelemetry() {
            try {
                const res = await fetch('/api/telemetry');
                const data = await res.json();
                metrics = data;

                // Calculate composite stress score (0.0 = baseline, 1.0 = critical stress)
                const tempStress = Math.max(0, (metrics.cpu_temp - 40) / 45.0); // 40C-85C scale
                const drainStress = Math.min(1.0, metrics.battery_drain / 35.0); // 0-35%/hr scale
                const loadStress = metrics.cpu_usage / 100.0;

                metrics.stress = Math.min(1.0, Math.max(0.0, (tempStress * 0.5 + drainStress * 0.3 + loadStress * 0.2)));

                // Update HUD
                document.getElementById('tempVal').innerText = metrics.cpu_temp;
                document.getElementById('drainVal').innerText = metrics.battery_drain;
                document.getElementById('loadVal').innerText = metrics.cpu_usage;
                
                const statusEl = document.getElementById('statusVal');
                const stressBar = document.getElementById('stressBar');
                
                stressBar.style.width = `${(metrics.stress * 100).toFixed(0)}%`;

                if (metrics.stress < 0.3) {
                    statusEl.innerText = "Thriving";
                    statusEl.style.color = "#98c379";
                } else if (metrics.stress < 0.65) {
                    statusEl.innerText = "Wilting";
                    statusEl.style.color = "#e5c07b";
                } else {
                    statusEl.innerText = "Decomposing";
                    statusEl.style.color = "#e06c75";
                }
            } catch (e) {
                console.error("Telemetry error:", e);
            }
        }

        setInterval(fetchTelemetry, 1000);
        fetchTelemetry();

        // Main Animation Loop
        function animate() {
            // Smoothly interpolate stress value to create continuous fluid motion
            smoothedStress += (metrics.stress - smoothedStress) * 0.05;

            // Canvas background clears with trail persistence proportional to stress/rot
            const bgAlpha = 0.15 + smoothedStress * 0.25;
            ctx.fillStyle = `rgba(5, 5, 8, ${bgAlpha})`;
            ctx.fillRect(0, 0, width, height);

            // Draw organic base pediment
            ctx.beginPath();
            ctx.arc(width / 2, height + 100, 180, 0, Math.PI * 2);
            ctx.fillStyle = `rgba(${Math.floor(40 + smoothedStress * 100)}, 25, 30, 0.8)`;
            ctx.fill();

            // Render branches
            for (let root of roots) {
                root.draw(width / 2, height - 70, smoothedStress);
            }

            // Render and decay particles
            for (let i = spores.length - 1; i >= 0; i--) {
                spores[i].update();
                spores[i].draw();
                if (spores[i].life <= 0) {
                    spores.splice(i, 1);
                }
            }

            requestAnimationFrame(animate);
        }

        animate();
    </script>
</body>
</html>
"""

class TelemetryHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/telemetry':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            with state_lock:
                data = json.dumps(telemetry_data)
            self.wfile.write(data.encode('utf-8'))
        else:
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode('utf-8'))

    def log_message(self, format, *args):
        # Suppress standard HTTP request logging in terminal for clean execution
        return

def run_server(port=8080):
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", port), TelemetryHandler) as httpd:
        print(f"[*] Generative Canvas server active at http://localhost:{port}")
        httpd.serve_forever()

if __name__ == "__main__":
    # Start system monitor loop in daemon thread
    monitor_thread = threading.Thread(target=monitor_system, daemon=True)
    monitor_thread.start()

    PORT = 8080
    # Launch browser automatically
    threading.Thread(target=lambda: (time.sleep(1), webbrowser.open(f"http://localhost:{PORT}")), daemon=True).start()

    try:
        run_server(PORT)
    except KeyboardInterrupt:
        print("\n[*] Server shut down.")