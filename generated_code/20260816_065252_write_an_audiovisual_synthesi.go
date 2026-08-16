// Package main implements an audio-visual synthesizer in pure Go and GLSL.
// It runs an embedded WebGL and WebAudio engine that translates string seed inputs 
// into procedural cellular automata fractal shaders and harmonic soundwaves.
package main

import (
	"fmt"
	"net/http"
	"os/exec"
	"runtime"
	"time"
)

// Embedded HTML application containing WebGL GLSL shaders and Audio Worklet synthesizers.
const htmlPage = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>GLSL Cellular Audio-Visual Synthesizer</title>
    <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #050508; font-family: 'Courier New', monospace; color: #00f0ff; }
        #canvas { width: 100vw; height: 100vh; display: block; }
        #ui { position: absolute; top: 20px; left: 20px; z-index: 10; background: rgba(5, 5, 12, 0.85); padding: 20px; border: 1px solid #00f0ff; border-radius: 8px; box-shadow: 0 0 20px rgba(0, 240, 255, 0.3); backdrop-filter: blur(5px); }
        h3 { margin: 0 0 10px 0; font-size: 14px; letter-spacing: 2px; text-transform: uppercase; }
        input { background: #0a0a14; color: #00f0ff; border: 1px solid #00f0ff; padding: 10px; font-family: monospace; width: 280px; font-size: 14px; outline: none; border-radius: 4px; }
        button { background: #00f0ff; color: #050508; border: none; padding: 10px 18px; font-weight: bold; cursor: pointer; font-family: monospace; margin-left: 8px; border-radius: 4px; transition: all 0.2s; }
        button:hover { background: #ffffff; box-shadow: 0 0 12px #ffffff; }
    </style>
</head>
<body>
    <div id="ui">
        <h3>Harmonic String Vector</h3>
        <input type="text" id="seedInput" value="Chaos Harmony 432Hz" placeholder="Type mathematical seed..." />
        <button id="startBtn">INITIALIZE</button>
    </div>
    <canvas id="canvas"></canvas>

    <!-- Vertex Shader -->
    <script id="vs" type="x-shader/x-vertex">
        attribute vec2 position;
        void main() {
            gl_Position = vec4(position, 0.0, 1.0);
        }
    </script>

    <!-- Fragment Shader: Cellular Automata Fractal Engine -->
    <script id="fs" type="x-shader/x-fragment">
        precision highp float;
        uniform vec2 u_resolution;
        uniform float u_time;
        uniform vec4 u_seed;

        // Hash function mapped to input string structure
        float hash(vec2 p) {
            p = fract(p * vec2(123.34, 456.21) + u_seed.xy);
            p += dot(p, p + 45.32);
            return fract(p.x * p.y);
        }

        // Procedural continuous Cellular Automata field
        float cellular(vec2 p) {
            vec2 i = floor(p);
            vec2 f = fract(p);
            float minDist = 1.0;
            for(int y = -1; y <= 1; y++) {
                for(int x = -1; x <= 1; x++) {
                    vec2 lattice = vec2(float(x), float(y));
                    vec2 offset = vec2(
                        sin(u_time * 0.4 + hash(i + lattice) * 6.28) * 0.5 + 0.5,
                        cos(u_time * 0.4 + hash(i + lattice + u_seed.zw) * 6.28) * 0.5 + 0.5
                    );
                    vec2 distVec = lattice + offset - f;
                    minDist = min(minDist, length(distVec));
                }
            }
            return minDist;
        }

        void main() {
            vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / min(u_resolution.x, u_resolution.y);
            
            // Fractal iteration fold driven by seed parameters
            float scale = 2.5 + u_seed.x * 3.0;
            vec2 p = uv * scale;
            
            float ca = 0.0;
            float amp = 0.5;
            for(int i = 0; i < 5; i++) {
                ca += amp * cellular(p + vec2(u_time * 0.08, u_time * 0.04));
                p *= 2.05 + u_seed.y * 0.4;
                float angle = 0.5 + u_seed.z * 0.5;
                p = vec2(p.x * cos(angle) - p.y * sin(angle), p.x * sin(angle) + p.y * cos(angle));
                amp *= 0.52;
            }

            // Evolving harmonic visual palette
            vec3 color = 0.5 + 0.5 * cos(u_time * 0.25 + ca * 8.0 + vec3(0.0, 2.0, 4.0) + u_seed.xyz * 4.0);
            
            // Organic glow vignette
            color *= (1.2 - length(uv) * 0.7);
            
            gl_FragColor = vec4(color, 1.0);
        }
    </script>

    <script>
        let audioCtx, isPlaying = false;
        let seedVector = [0.1, 0.2, 0.3, 0.4];

        // Maps typed string inputs to a normalized 4D float vector seed
        function stringToSeed(str) {
            let h1 = 0, h2 = 0, h3 = 0, h4 = 0;
            for (let i = 0; i < str.length; i++) {
                let code = str.charCodeAt(i);
                h1 = (h1 * 31 + code) % 10007;
                h2 = (h2 * 37 + code) % 10009;
                h3 = (h3 * 41 + code) % 10037;
                h4 = (h4 * 43 + code) % 10069;
            }
            return [h1 / 10007, h2 / 10009, h3 / 10037, h4 / 10069];
        }

        // WebGL Pipeline Initialization
        const canvas = document.getElementById('canvas');
        const gl = canvas.getContext('webgl');

        function createShader(gl, type, source) {
            const shader = gl.createShader(type);
            gl.shaderSource(shader, source);
            gl.compileShader(shader);
            return shader;
        }

        const vs = createShader(gl, gl.VERTEX_SHADER, document.getElementById('vs').text);
        const fs = createShader(gl, gl.FRAGMENT_SHADER, document.getElementById('fs').text);
        const program = gl.createProgram();
        gl.attachShader(program, vs);
        gl.attachShader(program, fs);
        gl.linkProgram(program);
        gl.useProgram(program);

        const posBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, posBuffer);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1, 1,-1, -1,1, -1,1, 1,-1, 1,1]), gl.STATIC_DRAW);

        const posAttr = gl.getAttribLocation(program, 'position');
        gl.enableVertexAttribArray(posAttr);
        gl.vertexAttribPointer(posAttr, 2, gl.FLOAT, false, 0, 0);

        const uRes = gl.getUniformLocation(program, 'u_resolution');
        const uTime = gl.getUniformLocation(program, 'u_time');
        const uSeed = gl.getUniformLocation(program, 'u_seed');

        function resize() {
            canvas.width = window.innerWidth;
            canvas.height = window.innerHeight;
            gl.viewport(0, 0, canvas.width, canvas.height);
        }
        window.addEventListener('resize', resize);
        resize();

        // WebAudio procedural harmonic synthesizer driven by string cellular math
        function startAudio() {
            if (audioCtx) return;
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            
            const bufferSize = 2048;
            const scriptNode = audioCtx.createScriptProcessor(bufferSize, 0, 1);
            
            scriptNode.onaudioprocess = function(e) {
                const output = e.getAudioBuffer().getChannelData(0);
                const rootFreq = 110 + seedVector[0] * 330; // Base frequency derived from string
                const modFreq = 1 + seedVector[1] * 12;      // Cellular modulation speed

                for (let i = 0; i < bufferSize; i++) {
                    let t = audioCtx.currentTime + (i / audioCtx.sampleRate);
                    
                    // Procedural harmonic wave synthesis mirroring GLSL cellular noise
                    let FM = Math.sin(2 * Math.PI * modFreq * t) * (seedVector[2] * 10);
                    let h1 = Math.sin(2 * Math.PI * rootFreq * t + FM);
                    let h2 = Math.sin(2 * Math.PI * (rootFreq * 1.5) * t) * 0.4;
                    let h3 = Math.sin(2 * Math.PI * (rootFreq * 2.01) * t + FM * 0.5) * (seedVector[3] * 0.3);
                    
                    // Controlled chaos threshold fold
                    let cellularFold = (Math.sin(t * 800 * seedVector[0]) > 0.5 ? 0.015 : -0.015) * seedVector[1];
                    
                    output[i] = (h1 + h2 + h3 + cellularFold) * 0.12;
                }
            };

            scriptNode.connect(audioCtx.destination);
        }

        const seedInput = document.getElementById('seedInput');
        seedVector = stringToSeed(seedInput.value);

        document.getElementById('startBtn').addEventListener('click', () => {
            seedVector = stringToSeed(seedInput.value);
            if (!isPlaying) {
                startAudio();
                isPlaying = true;
                document.getElementById('startBtn').innerText = 'UPDATE SEED';
            }
        });

        seedInput.addEventListener('input', (e) => {
            seedVector = stringToSeed(e.target.value);
        });

        // Main animation loop
        function render(time) {
            time *= 0.001; // Convert to seconds
            gl.uniform2f(uRes, canvas.width, canvas.height);
            gl.uniform1f(uTime, time);
            gl.uniform4fv(uSeed, seedVector);
            gl.drawArrays(gl.TRIANGLES, 0, 6);
            requestAnimationFrame(render);
        }
        requestAnimationFrame(render);
    </script>
</body>
</html>`

// Automatically opens the default web browser cross-platform
func openBrowser(url string) {
	var err error
	switch runtime.GOOS {
	case "linux":
		err = exec.Command("xdg-open", url).Start()
	case "windows":
		err = exec.Command("rundll32", "url.dll,FileProtocolHandler", url).Start()
	case "darwin":
		err = exec.Command("open", url).Start()
	}
	if err != nil {
		fmt.Printf("Please open browser manually at %s\n", url)
	}
}

func main() {
	port := ":8080"
	url := "http://localhost" + port

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		w.Write([]byte(htmlPage))
	})

	fmt.Printf("Synthesizer running on %s\n", url)
	go func() {
		time.Sleep(500 * time.Millisecond)
		openBrowser(url)
	}()

	if err := http.ListenAndServe(port, nil); err != nil {
		fmt.Printf("Server failed: %v\n", err)
	}
}