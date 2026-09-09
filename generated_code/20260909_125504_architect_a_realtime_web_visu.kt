import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import io.ktor.http.*

/**
 * Atmospheric L-System Visualizer
 *
 * Runs an embedded HTTP server that renders an HTML5/Canvas dashboard.
 * - Simulates/fetches live weather parameters (Wind, Humidity, Temp) to grow L-System fractals.
 * - Uses Web Audio API (`getUserMedia`) to capture ambient mic noise, triggering dynamic decay & mutation.
 */
fun main() {
    embeddedServer(Netty, port = 8080) {
        routing {
            get("/") {
                call.respondText(HTML_PAYLOAD, ContentType.Text.Html)
            }
        }
    }.start(wait = true)
}

private const val HTML_PAYLOAD = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Atmospheric Organic L-System Visualizer</title>
    <style>
        body, html { margin: 0; padding: 0; overflow: hidden; background: #08090c; color: #e0e6ed; font-family: monospace; }
        canvas { display: block; width: 100vw; height: 100vh; }
        #ui { position: absolute; top: 15px; left: 15px; background: rgba(12, 16, 24, 0.85); padding: 15px; border-radius: 8px; border: 1px solid #1f293d; backdrop-filter: blur(4px); }
        h1 { margin: 0 0 10px 0; font-size: 1.1rem; color: #64ffda; }
        .metric { margin: 4px 0; font-size: 0.85rem; }
        .val { color: #82aaff; }
        button { margin-top: 8px; padding: 6px 12px; background: #1a233a; border: 1px solid #64ffda; color: #64ffda; border-radius: 4px; cursor: pointer; }
        button:hover { background: #64ffda; color: #08090c; }
    </style>
</head>
<body>
    <div id="ui">
        <h1>Atmospheric Organism</h1>
        <div class="metric">Wind Speed: <span id="m-wind" class="val">--</span> m/s</div>
        <div class="metric">Humidity: <span id="m-hum" class="val">--</span> %</div>
        <div class="metric">Temperature: <span id="m-temp" class="val">--</span> °C</div>
        <div class="metric">Mic Decay Impact: <span id="m-noise" class="val">--</span></div>
        <button id="mic-btn">Enable Mic Input</button>
    </div>
    <canvas id="canvas"></canvas>

    <script>
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');
        let width = canvas.width = window.innerWidth;
        let height = canvas.height = window.innerHeight;

        window.addEventListener('resize', () => {
            width = canvas.width = window.innerWidth;
            height = canvas.height = window.innerHeight;
        });

        // Weather state (simulated dynamic stream)
        const weather = { windSpeed: 5.0, humidity: 65, temp: 22 };
        
        function updateWeather() {
            weather.windSpeed = 2.0 + Math.sin(Date.now() * 0.0005) * 4.0 + Math.random() * 1.5;
            weather.humidity = 50 + Math.cos(Date.now() * 0.0003) * 35;
            weather.temp = 18 + Math.sin(Date.now() * 0.0002) * 10;
            
            document.getElementById('m-wind').innerText = weather.windSpeed.toFixed(1);
            document.getElementById('m-hum').innerText = Math.round(weather.humidity);
            document.getElementById('m-temp').innerText = weather.temp.toFixed(1);
        }
        setInterval(updateWeather, 2000);
        updateWeather();

        // Audio Mic processing setup
        let audioContext, analyser, microphone, dataArray;
        let ambientNoise = 0;

        document.getElementById('mic-btn').addEventListener('click', async () => {
            try {
                const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
                audioContext = new (window.AudioContext || window.webkitAudioContext)();
                analyser = audioContext.createAnalyser();
                analyser.fftSize = 256;
                microphone = audioContext.createMediaStreamSource(stream);
                microphone.connect(analyser);
                dataArray = new Uint8Array(analyser.frequencyBinCount);
                document.getElementById('mic-btn').innerText = 'Mic Active';
                document.getElementById('mic-btn').style.borderColor = '#c792ea';
                document.getElementById('mic-btn').style.color = '#c792ea';
            } catch (err) {
                alert('Microphone access denied or unavailable.');
            }
        });

        function sampleNoise() {
            if (analyser) {
                analyser.getByteFrequencyData(dataArray);
                let sum = 0;
                for (let i = 0; i < dataArray.length; i++) sum += dataArray[i];
                ambientNoise = sum / dataArray.length / 255.0; // Normalized [0, 1]
            }
            document.getElementById('m-noise').innerText = (ambientNoise * 100).toFixed(1) + '%';
        }

        // Stochastic L-System Fractal Engine
        function renderFractal() {
            sampleNoise();

            ctx.fillStyle = 'rgba(8, 9, 12, 0.25)';
            ctx.fillRect(0, 0, width, height);

            const depth = Math.min(6, 3 + Math.floor(weather.humidity / 25)); 
            const baseLength = Math.min(width, height) * 0.15 * (weather.temp / 20);
            const windAngleShift = Math.sin(Date.now() * 0.002) * (weather.windSpeed * 0.03);
            const baseAngle = (Math.PI / 6) + windAngleShift;
            
            // Draw tree starting from bottom center
            ctx.save();
            ctx.translate(width / 2, height - 50);
            drawBranch(depth, baseLength, baseAngle, ambientNoise);
            ctx.restore();

            requestAnimationFrame(renderFractal);
        }

        function drawBranch(depth, len, angle, decay) {
            if (depth === 0 || len < 2) return;

            // Ambient noise adds decay/mutation jitter
            const noiseFactor = (Math.random() - 0.5) * decay * 1.2;
            const branchAngle = angle + noiseFactor;

            // Dynamic organic color based on temperature and depth
            const hue = (140 + weather.temp * 3 - depth * 10) % 360;
            const sat = Math.max(30, weather.humidity);
            const light = 40 + (depth * 5);
            ctx.strokeStyle = `hsl(${hue}, ${sat}%, ${light}%)`;
            ctx.lineWidth = Math.max(1, depth * 1.8 * (1 - decay * 0.5));

            ctx.beginPath();
            ctx.moveTo(0, 0);
            
            // Introduce subtle structural bend via noise
            const endX = (Math.random() - 0.5) * decay * 10;
            const endY = -len * (1 - decay * 0.3); // High noise causes structural decay/shrinkage
            
            ctx.lineTo(endX, endY);
            ctx.stroke();

            ctx.save();
            ctx.translate(endX, endY);

            // Stochastic branching rules
            const lenRatio = 0.72 + (Math.random() - 0.5) * 0.1;
            
            // Left branch
            ctx.save();
            ctx.rotate(-branchAngle);
            drawBranch(depth - 1, len * lenRatio, angle, decay);
            ctx.restore();

            // Right branch
            ctx.save();
            ctx.rotate(branchAngle);
            drawBranch(depth - 1, len * lenRatio, angle, decay);
            ctx.restore();

            // Optional ambient-induced mutation branch
            if (decay > 0.35 && Math.random() < decay) {
                ctx.save();
                ctx.rotate(noiseFactor * 2);
                drawBranch(depth - 1, len * 0.5, angle, decay);
                ctx.restore();
            }

            ctx.restore();
        }

        requestAnimationFrame(renderFractal);
    </script>
</body>
</html>
"""