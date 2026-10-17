#!/usr/bin/env kotlinc -script
// Self-modifying quine fern generator in Kotlin script generating an HTML5 canvas experience

fun main() {
    val htmlContent = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>Self-Modifying Quine Fern</title>
        <style>
            body { background: #111; color: #eee; text-align: center; font-family: monospace; margin-top: 40px; }
            canvas { background: #000; border: 1px solid #333; box-shadow: 0 0 20px rgba(0,255,0,0.2); }
        </style>
    </head>
    <body>
        <h2>Self-Modifying Quine & Procedural Fern</h2>
        <canvas id="fernCanvas" width="600" height="600"></canvas>
        <script>
        // Self-referential source container
        let sourceCode = document.currentScript.outerHTML;
        const canvas = document.getElementById('fernCanvas');
        const ctx = canvas.getContext('2d');
        
        // Web Audio API setup for microtonal frequencies
        const audioCtx = new (window.AudioContext || window.webkitAudioContext)();

        function playMicrotonalNote(asciiValue) {
            if (audioCtx.state === 'suspended') {
                audioCtx.resume();
            }
            const osc = audioCtx.createOscillator();
            const gainNode = audioCtx.createGain();
            
            // Map ASCII value to a microtonal frequency scale
            const frequency = 150 + (asciiValue * 2.5);
            osc.type = 'sine';
            osc.frequency.setValueAtTime(frequency, audioCtx.currentTime);
            
            osc.connect(gainNode);
            gainNode.connect(audioCtx.destination);
            
            gainNode.gain.setValueAtTime(0.08, audioCtx.currentTime);
            gainNode.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + 0.4);
            
            osc.start();
            osc.stop(audioCtx.currentTime + 0.4);
        }

        function stepQuineEvolution() {
            // Mutate a random punctuation mark in the source string
            let chars = sourceCode.split('');
            let punctuationIndices = [];
            chars.forEach((char, index) => {
                if (/[\.,;:!?]/.test(char)) {
                    punctuationIndices.push(index);
                }
            });

            if (punctuationIndices.length > 0) {
                const targetIndex = punctuationIndices[Math.floor(Math.random() * punctuationIndices.length)];
                const ascii = chars[targetIndex].charCodeAt(0);
                playMicrotonalNote(ascii);
                chars[targetIndex] = '♫'; // Mutation marker representing a musical note
                sourceCode = chars.join('');
            }

            // Render blooming procedural Barnsley fern
            ctx.fillStyle = 'rgba(0, 0, 0, 0.08)';
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.fillStyle = '#00ff66';

            let x = 0.0, y = 0.0;
            for (let i = 0; i < 800; i++) {
                let nextX, nextY;
                const r = Math.random();
                if (r < 0.01) {
                    nextX = 0;
                    nextY = 0.16 * y;
                } else if (r < 0.86) {
                    nextX = 0.85 * x + 0.04 * y;
                    nextY = -0.04 * x + 0.85 * y + 1.6;
                } else if (r < 0.93) {
                    nextX = 0.2 * x - 0.26 * y;
                    nextY = 0.23 * x + 0.22 * y + 1.6;
                } else {
                    nextX = -0.15 * x + 0.28 * y;
                    nextY = 0.26 * x + 0.24 * y + 0.44;
                }
                x = nextX;
                y = nextY;
                
                const px = canvas.width / 2 + x * 50;
                const py = canvas.height - y * 50;
                ctx.fillRect(px, py, 1.2, 1.2);
            }
        }

        // Trigger continuous self-modification and blooming fern growth
        setInterval(stepQuineEvolution, 800);
        </script>
    </body>
    </html>
    """.trimIndent()

    println(htmlContent)
}

main()