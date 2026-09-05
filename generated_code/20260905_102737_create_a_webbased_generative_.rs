use tiny_http::{Server, Response};
use std::thread;
use std::time::Duration;

fn main() {
    // Start an embedded lightweight HTTP server to serve the generative art web client.
    let server = Server::http("127.0.0.1:8080").unwrap();
    println!("🎨 Generative Art Memory Engine running at [http://127.0.0.1:8080](http://127.0.0.1:8080)");

    // HTML page containing the self-contained client-side Web-based Generative Art system.
    // The system renders directly to an HTML5 canvas and uses its own visual memory buffer
    // (via pixel feedback, convolutions, and color shifting) to endlessly decay, echo, and evolve.
    let html_content = r#"<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Memory Echoes - Generative Art Engine</title>
    <style>
        body, html {
            margin: 0;
            padding: 0;
            width: 100%;
            height: 100%;
            overflow: hidden;
            background: #000;
            font-family: monospace;
            color: #fff;
        }
        canvas {
            display: block;
            width: 100vw;
            height: 100vh;
        }
        #hud {
            position: absolute;
            bottom: 20px;
            left: 20px;
            background: rgba(0, 0, 0, 0.7);
            border: 1px solid rgba(255, 255, 255, 0.2);
            padding: 10px 15px;
            font-size: 12px;
            letter-spacing: 1px;
            pointer-events: none;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <canvas id="artCanvas"></canvas>
    <div id="hud">MEMORY_FEEDBACK_ENGINE // STATUS: EVOLVING</div>

    <script>
        const canvas = document.getElementById('artCanvas');
        const ctx = canvas.getContext('2d', { willReadFrequently: true });

        // Maintain an internal low-res simulation buffer for high-performance feedback diffusion
        const WIDTH = 320;
        const HEIGHT = 180;
        
        const offCanvas = document.createElement('canvas');
        offCanvas.width = WIDTH;
        offCanvas.height = HEIGHT;
        const offCtx = offCanvas.getContext('2d', { willReadFrequently: true });

        let tick = 0;

        function init() {
            offCtx.fillStyle = '#000000';
            offCtx.fillRect(0, 0, WIDTH, HEIGHT);
        }

        function renderFrame() {
            tick++;

            // 1. Capture current visual state from the memory buffer
            let imgData = offCtx.getImageData(0, 0, WIDTH, HEIGHT);
            let data = imgData.data;

            // 2. Apply a recursive cellular/convolution decay and memory feedback effect
            // Each pixel looks at its past self and neighbors to echo, bleed, and drift colors.
            let bufferCopy = new Uint8ClampedArray(data);

            for (let y = 0; y < HEIGHT; y++) {
                for (let x = 0; x < WIDTH; x++) {
                    let idx = (y * WIDTH + x) * 4;

                    // Sample offset neighbors to create liquid-like fluid echo dynamics
                    let nx1 = (x + 1) % WIDTH;
                    let ny1 = (y + 1) % HEIGHT;
                    let nIdx1 = (ny1 * WIDTH + nx1) * 4;

                    let nx2 = (x - 1 + WIDTH) % WIDTH;
                    let ny2 = (y + 2) % HEIGHT;
                    let nIdx2 = (ny2 * WIDTH + nx2) * 4;

                    // Feedback mixing formula: blend past pixel state with shifted neighbor echoes
                    let r = (bufferCopy[nIdx1] * 0.5 + bufferCopy[nIdx2] * 0.5);
                    let g = (bufferCopy[nIdx+1] * 0.7 + bufferCopy[nIdx1+1] * 0.3);
                    let b = (bufferCopy[nIdx2+2] * 0.8 + bufferCopy[nIdx] * 0.2);

                    // Decay coefficient (causes natural fading over time unless reinjected)
                    data[idx]     = Math.floor(r * 0.96);
                    data[idx + 1] = Math.floor(g * 0.95);
                    data[idx + 2] = Math.floor(b * 0.97);
                }
            }

            offCtx.putImageData(imgData, 0, 0);

            // 3. Inject new algorithmic lifeforms/seeds driven by procedural time and trigonometric interference
            offCtx.save();
            offCtx.globalCompositeOperation = 'screen';
            
            let cx = WIDTH / 2 + Math.sin(tick * 0.02) * (WIDTH * 0.3);
            let cy = HEIGHT / 2 + Math.cos(tick * 0.015) * (HEIGHT * 0.3);

            let grad = offCtx.createRadialGradient(cx, cy, 2, cx, cy, 60);
            grad.addColorStop(0, `hsl(${(tick * 0.5) % 360}, 100%, 60%)`);
            grad.addColorStop(1, 'transparent');

            offCtx.fillStyle = grad;
            offCtx.beginPath();
            offCtx.arc(cx, cy, 60, 0, Math.PI * 2);
            offCtx.fill();

            // Inject secondary geometric echoes
            let rx = WIDTH / 2 + Math.cos(tick * 0.03) * (WIDTH * 0.4);
            let ry = HEIGHT / 2 + Math.sin(tick * 0.04) * (HEIGHT * 0.4);
            offCtx.fillStyle = `hsla(${(tick * 1.2) % 360}, 80%, 50%, 0.4)`;
            offCtx.fillRect(rx - 10, ry - 10, 20, 20);

            offCtx.restore();

            // 4. Stretch and scale the low-resolution memory buffer onto the main viewport canvas with smooth filtering
            ctx.imageSmoothingEnabled = true;
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            ctx.drawImage(offCanvas, 0, 0, canvas.width, canvas.height);

            requestAnimationFrame(renderFrame);
        }

        window.addEventListener('resize', () => {
            canvas.width = window.innerWidth;
            canvas.height = window.innerHeight;
        });

        // Trigger initial canvas sizing and launch animation loop
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
        init();
        requestAnimationFrame(renderFrame);
    </script>
</body>
</html>
"#;

    // Handle incoming HTTP requests and serve the generative web page
    for request in server.incoming_requests() {
        let response = Response::from_string(html_content)
            .with_header(tiny_http::Header::from_bytes(&b"Content-Type"[..], &b"text/html; charset=UTF-8"[..]).unwrap());
        let _ = request.respond(response);
    }
}