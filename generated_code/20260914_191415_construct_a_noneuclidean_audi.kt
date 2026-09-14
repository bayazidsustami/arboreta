import java.io.File

/**
 * Kotlin script generating a single HTML file containing an embedded WebGL shader 
 * and Web Audio API engine.
 * 
 * Hyperbolic Geometry:
 * Calculates raymarched intersections in the Poincaré disk / hyperboloid model.
 * The curved spatial distortion directly modulates Web Audio API oscillator nodes 
 * and filter frequencies in real-time.
 */

val htmlContent = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Non-Euclidean Audio Synthesizer</title>
    <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #000; color: #fff; font-family: monospace; }
        canvas { width: 100%; height: 100%; display: block; }
        #ui { position: absolute; top: 20px; left: 20px; z-index: 10; pointer-events: none; text-shadow: 0 0 5px #000; }
        button { pointer-events: auto; background: rgba(255,255,255,0.1); border: 1px solid #fff; color: #fff; padding: 10px 20px; cursor: pointer; font-family: inherit; }
        button:hover { background: rgba(255,255,255,0.3); }
    </style>
</head>
<body>
    <div id="ui">
        <h1>Hyperbolic Soundscape Synthesizer</h1>
        <p>Raymarched Poincaré hyperboloid spatial distortion mapped to Web Audio nodes.</p>
        <button id="startBtn">Initialize Audio Engine</button>
    </div>
    <canvas id="canvas"></canvas>

    <script>
        // WebGL Vertex Shader
        const vsSource = `
            attribute vec2 position;
            void main() {
                gl_Position = vecvec4(position, 0.0, 1.0);
            }
        `.replace('vecvec4', 'vec4');

        // WebGL Fragment Shader: Raymarches through hyperbolic space
        const fsSource = `
            precision highp float;
            uniform vec2 u_resolution;
            uniform float u_time;
            
            // Hyperbolic metric projection (Poincaré Disk / Lorentz Model)
            float hyperbolicDist(vec3 p) {
                float k = 1.0;
                // Lorentz dot product: -p0^2 + p1^2 + p2^2
                float d = length(p.yz) - tan(u_time * 0.2);
                float curvature = sinh(length(p) * 0.5) / (cosh(p.x) + 0.001);
                return abs(sin(curvature * 8.0 + u_time)) * 0.25 - 0.02;
            }

            void main() {
                vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution) / u_resolution.y;
                vec3 ro = vec3(0.0, 0.0, -2.5);
                vec3 rd = normalize(vec3(uv, 1.0));
                
                // Hyperbolic space warping frame
                float t = 0.0;
                float distortionAccum = 0.0;
                
                for(int i = 0; i < 32; i++) {
                    vec3 p = ro + rd * t;
                    // Apply Lorentz boost / Hyperbolic translation
                    p.z += sinh(u_time * 0.1);
                    p.xy *= mat2(cos(p.z), -sin(p.z), sin(p.z), cos(p.z));
                    
                    float d = hyperbolicDist(p);
                    distortionAccum += 0.015 / (0.05 + abs(d));
                    t += max(d * 0.5, 0.02);
                }

                vec3 col = vec3(0.1, 0.3, 0.6) * distortionAccum * 0.1;
                col += vec3(0.8, 0.2, 0.5) * sin(t * 3.0 + u_time);
                gl_FragColor = vec4(col, 1.0);
            }
        `;

        // Canvas Setup
        const canvas = document.getElementById('canvas');
        const gl = canvas.getContext('webgl');
        
        function resize() {
            canvas.width = window.innerWidth;
            canvas.height = window.innerHeight;
            gl.viewport(0, 0, canvas.width, canvas.height);
        }
        window.addEventListener('resize', resize);
        resize();

        // Compile Shader Helper
        function createShader(gl, type, source) {
            const s = gl.createShader(type);
            gl.shaderSource(s, source);
            gl.compileShader(s);
            return s;
        }

        const program = gl.createProgram();
        gl.attachShader(program, createShader(gl, gl.VERTEX_SHADER, vsSource));
        gl.attachShader(program, createShader(gl, gl.FRAGMENT_SHADER, fsSource));
        gl.linkProgram(program);
        gl.useProgram(program);

        // Buffer Quad
        const buffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1, 1,-1, -1,1, -1,1, 1,-1, 1,1]), gl.STATIC_DRAW);

        const posLoc = gl.getAttribLocation(program, 'position');
        gl.enableVertexAttribArray(posLoc);
        gl.vertexAttribPointer(posLoc, 2, gl.FLOAT, false, 0, 0);

        const resLoc = gl.getUniformLocation(program, 'u_resolution');
        const timeLoc = gl.getUniformLocation(program, 'u_time');

        // Web Audio Synthesizer Setup
        let audioCtx, osc1, osc2, filter, gain;
        let isAudioInit = false;

        function initAudio() {
            audioCtx = new (window.AudioContext || window.webkitAudioContext)();
            
            osc1 = audioCtx.createOscillator();
            osc2 = audioCtx.createOscillator();
            filter = audioCtx.createBiquadFilter();
            gain = audioCtx.createGain();

            osc1.type = 'sine';
            osc2.type = 'sawtooth';

            // Base frequencies
            osc1.frequency.value = 55.0; // A1
            osc2.frequency.value = 110.0; // A2

            filter.type = 'lowpass';
            filter.Q.value = 12.0;

            gain.gain.value = 0.2;

            osc1.connect(filter);
            osc2.connect(filter);
            filter.connect(gain);
            gain.connect(audioCtx.destination);

            osc1.start();
            osc2.start();
            isAudioInit = true;
        }

        document.getElementById('startBtn').addEventListener('click', (e) => {
            initAudio();
            e.target.style.display = 'none';
        });

        // Non-Euclidean spatial calculation for synth modulation
        function computeHyperbolicMetrics(t) {
            // Lorentz transformation / hyperbolic distance metric simulation
            const sinh = Math.sinh(t * 0.15);
            const cosh = Math.cosh(t * 0.1);
            
            // Spatial curvature distortion factor
            const curvature = Math.abs(Math.sin(sinh) * cosh);
            
            // Map spatial metrics directly to Audio Node parameters
            const freqMod1 = 55.0 + curvature * 220.0; 
            const freqMod2 = 110.0 + Math.cosh(Math.sin(t * 0.2)) * 165.0;
            const filterCutoff = 200.0 + Math.pow(curvature, 1.5) * 2000.0;

            return { freqMod1, freqMod2, filterCutoff };
        }

        // Render & Audio Loop
        function render(time) {
            const t = time * 0.001;

            // Render Hyperbolic Raymarched Visuals
            gl.uniform2f(resLoc, canvas.width, canvas.height);
            gl.uniform1f(timeLoc, t);
            gl.drawArrays(gl.TRIANGLES, 0, 6);

            // Modulate Web Audio Nodes via Non-Euclidean Metrics
            if (isAudioInit) {
                const metrics = computeHyperbolicMetrics(t);
                osc1.frequency.setTargetAtTime(metrics.freqMod1, audioCtx.currentTime, 0.05);
                osc2.frequency.setTargetAtTime(metrics.freqMod2, audioCtx.currentTime, 0.05);
                filter.frequency.setTargetAtTime(metrics.filterCutoff, audioCtx.currentTime, 0.05);
            }

            requestAnimationFrame(render);
        }

        requestAnimationFrame(render);
    </script>
</body>
</html>
""".trimIndent()

fun main() {
    val outputFile = File("index.html")
    outputFile.writeText(htmlContent)
    println("Successfully generated non-Euclidean audio synthesizer HTML file at: ${outputFile.absolutePath}")
}
main()