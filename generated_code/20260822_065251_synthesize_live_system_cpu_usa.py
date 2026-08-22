import http.server
import socketserver
import threading
import webbrowser
import json
import time
import psutil

# HTML + WebGL Fluid Simulation Front-End
HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>System Stress Fluid Dynamics</title>
    <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #000; font-family: sans-serif; }
        canvas { width: 100%; height: 100%; display: block; }
        #overlay {
            position: absolute; top: 20px; left: 20px; color: rgba(255, 255, 255, 0.8);
            pointer-events: none; text-shadow: 0 0 10px rgba(0,0,0,0.8);
        }
        h1 { margin: 0 0 5px 0; font-size: 1.2rem; text-transform: uppercase; letter-spacing: 2px; }
        p { margin: 2px 0; font-size: 0.85rem; font-family: monospace; }
    </style>
</head>
<body>
    <div id="overlay">
        <h1>System Turbulence Field</h1>
        <p>CPU Load (Turbulence): <span id="cpu-val">0</span>%</p>
        <p>Memory Paging Rate (Injection): <span id="page-val">0</span> pages/s</p>
    </div>
    <canvas id="glcanvas"></canvas>

    <script>
        const canvas = document.getElementById('glcanvas');
        const gl = canvas.getContext('webgl');

        if (!gl) alert('WebGL not supported');

        // Shader helper
        function createShader(gl, type, source) {
            const shader = gl.createShader(type);
            gl.shaderSource(shader, source);
            gl.compileShader(shader);
            return shader;
        }

        // Fullscreen Quad Shaders
        const vsSource = `
            attribute vec2 a_position;
            void main() {
                gl_Position = vec4(a_position, 0.0, 1.0);
            }
        `;

        // Fragment Shader: Simulates fluid dynamics using noise, advection, and stress inputs
        const fsSource = `
            precision highp float;
            uniform vec2 u_resolution;
            uniform float u_time;
            uniform float u_cpu;   // Driven by CPU usage (0.0 to 1.0)
            uniform float u_page;  // Driven by Memory Paging Rate

            // Simplex Noise Generator
            vec3 permute(vec3 x) { return mod(((x*34.0)+1.0)*x, 289.0); }
            float snoise(vec2 v){
                const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                                 -0.577350269189626, 0.024390243902439);
                vec2 i  = floor(v + dot(v, C.yy) );
                vec2 x0 = v -   i + dot(i, C.xx);
                vec2 i1;
                i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
                vec4 x12 = x0.xyxy + C.xxzz;
                x12.xy -= i1;
                i = mod(i, 289.0);
                vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
                + i.x + vec3(0.0, i1.x, 1.0 ));
                vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
                m = m*m ;
                m = m*m ;
                vec3 x = 2.0 * fract(p * C.www) - 1.0;
                vec3 h = abs(x) - 0.5;
                vec3 ox = floor(x + 0.5);
                vec3 a0 = x - ox;
                m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
                vec3 g;
                g.x  = a0.x  * x0.x  + h.x  * x0.y;
                g.yz = a0.yz * x12.xz + h.yz * x12.yw;
                return 130.0 * dot(m, g);
            }

            // Turbulence Curl function
            vec2 curl(vec2 p) {
                float eps = 0.1;
                float n1 = snoise(p + vec2(0.0, eps));
                float n2 = snoise(p - vec2(0.0, eps));
                float n3 = snoise(p + vec2(eps, 0.0));
                float n4 = snoise(p - vec2(eps, 0.0));
                return vec2((n1 - n2) / (2.0 * eps), (n4 - n3) / (2.0 * eps));
            }

            void main() {
                vec2 st = gl_FragCoord.xy / u_resolution.xy;
                st.x *= u_resolution.x / u_resolution.y;

                // Adjust flow speed and scale using CPU stress
                float speed = u_time * (0.2 + u_cpu * 1.5);
                float scale = 2.0 + u_cpu * 5.0;

                // Dynamic velocity field
                vec2 velocity = curl(st * scale + vec2(speed));

                // Add concentrated fluid injections triggered by Memory Paging Rate
                float injection = sin(st.x * 10.0 + u_time) * cos(st.y * 10.0 + u_time) * u_page;
                
                // Calculate fluid flow field
                vec2 flow = st + velocity * (0.05 + u_page * 0.1) + vec2(injection * 0.02);

                // Multi-layered noise for visual depth
                float f = snoise(flow * 3.0);
                f += 0.5 * snoise(flow * 6.0 + vec2(u_time * 0.5));
                f += 0.25 * snoise(flow * 12.0);

                // Dynamic Color Palette mapped to Stress
                // Low stress -> Calm deep cyan/blue
                // High stress -> Violent neon pink, magenta, and fiery yellow
                vec3 calmColor = vec3(0.05, 0.15, 0.35);
                vec3 stressColor = vec3(1.0, 0.1, 0.4);
                vec3 pageBurstColor = vec3(1.0, 0.8, 0.1);

                vec3 color = mix(calmColor, stressColor, u_cpu);
                color = mix(color, pageBurstColor, sin(f * 3.1415 + u_page * 5.0) * 0.5 + 0.5);

                // Enhance contrast and turbulence field detail
                color *= (f * 0.5 + 0.5);
                color += vec3(pow(abs(f), 3.0) * (0.2 + u_cpu * 0.8));

                gl_FragColor = vec4(color, 1.0);
            }
        `;

        // Program Initialization
        const program = gl.createProgram();
        gl.attachShader(program, createShader(gl, gl.VERTEX_SHADER, vsSource));
        gl.attachShader(program, createShader(gl, gl.FRAGMENT_SHADER, fsSource));
        gl.linkProgram(program);
        gl.useProgram(program);

        // Geometry setup (full canvas quad)
        const positionBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
            -1, -1,  1, -1, -1,  1,
            -1,  1,  1, -1,  1,  1,
        ]), gl.STATIC_DRAW);

        const posAttr = gl.getAttribLocation(program, 'a_position');
        gl.enableVertexAttribArray(posAttr);
        gl.vertexAttribPointer(posAttr, 2, gl.FLOAT, false, 0, 0);

        // Uniform locations
        const uRes = gl.getUniformLocation(program, 'u_resolution');
        const uTime = gl.getUniformLocation(program, 'u_time');
        const uCpu = gl.getUniformLocation(program, 'u_cpu');
        const uPage = gl.getUniformLocation(program, 'u_page');

        // State targets for smooth interpolations
        let targetCpu = 0.0;
        let targetPage = 0.0;
        let currentCpu = 0.0;
        let currentPage = 0.0;

        // Fetch metrics from backend Python API
        async function fetchMetrics() {
            try {
                const res = await fetch('/api/metrics');
                const data = await res.json();
                targetCpu = data.cpu / 100.0; // Normalize 0..1
                
                // Map paging rate to a manageable 0..1 scale (assuming 1000 pages/s is heavy)
                targetPage = Math.min(data.paging_rate / 1000.0, 1.0);

                document.getElementById('cpu-val').innerText = data.cpu.toFixed(1);
                document.getElementById('page-val').innerText = data.paging_rate.toFixed(0);
            } catch (e) {
                console.error(e);
            }
        }
        setInterval(fetchMetrics, 500);

        function resize() {
            canvas.width = window.innerWidth;
            canvas.height = window.innerHeight;
            gl.viewport(0, 0, canvas.width, canvas.height);
        }
        window.addEventListener('resize', resize);
        resize();

        // Render Loop
        function render(now) {
            now *= 0.001; // Convert to seconds

            // Smooth transition/lerp to smooth out metric polling spikes
            currentCpu += (targetCpu - currentCpu) * 0.05;
            currentPage += (targetPage - currentPage) * 0.05;

            gl.uniform2f(uRes, canvas.width, canvas.height);
            gl.uniform1f(uTime, now);
            gl.uniform1f(uCpu, currentCpu);
            gl.uniform1f(uPage, currentPage);

            gl.drawArrays(gl.TRIANGLES, 0, 6);
            requestAnimationFrame(render);
        }
        requestAnimationFrame(render);
    </script>
</body>
</html>
"""

class MetricsTracker:
    def __init__(self):
        self.last_paging_count = self._get_paging_count()
        self.last_time = time.time()

    def _get_paging_count(self):
        # Calculate total page-ins and page-outs across platforms
        vm = psutil.swap_memory()
        return (getattr(vm, 'sin', 0) or 0) + (getattr(vm, 'sout', 0) or 0)

    def get_metrics(self):
        now = time.time()
        dt = now - self.last_time
        if dt <= 0: dt = 0.001

        # Real-time CPU usage percentage
        cpu = psutil.cpu_percent(interval=None)

        # Calculate live paging rates per second
        current_paging = self._get_paging_count()
        paging_diff = max(0, current_paging - self.last_paging_count)
        paging_rate = paging_diff / dt

        self.last_paging_count = current_paging
        self.last_time = now

        return {"cpu": cpu, "paging_rate": paging_rate}

metrics_tracker = MetricsTracker()

class WebGLServer(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/metrics':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            data = metrics_tracker.get_metrics()
            self.wfile.write(json.dumps(data).encode())
        else:
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode())

    def log_message(self, format, *args):
        # Silence console log spam
        pass

def run_server(port=8080):
    psutil.cpu_percent(interval=None) # Warm-up cpu timer
    server = socketserver.TCPServer(("", port), WebGLServer)
    print(f"Fluid Dynamics Streamer active at http://localhost:{port}")
    webbrowser.open(f"http://localhost:{port}")
    server.serve_forever()

if __name__ == '__main__':
    run_server()