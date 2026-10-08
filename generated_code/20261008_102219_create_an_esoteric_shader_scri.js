<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Living Mandelbrot Lyric Shader</title>
<style>
  body { margin: 0; background: #050508; overflow: hidden; display: flex; flex-direction: column; justify-content: center; align-items: center; height: 100vh; font-family: monospace; color: #0ff; }
  canvas { box-shadow: 0 0 30px rgba(0,255,255,0.2); border-radius: 4px; }
  #lyric-display { margin-top: 15px; font-size: 14px; text-shadow: 0 0 8px #0ff; letter-spacing: 1px; }
</style>
</head>
<body>
<canvas id="shaderCanvas" width="300" height="300"></canvas>
<div id="lyric-display">Initializing sonic fractal...</div>
<script>
// Favorite song: "Bohemian Rhapsody" by Queen
const lyrics = "Is this the real life? Is this just fantasy? Caught in a landslide, no escape from reality.";
const canvas = document.getElementById('shaderCanvas');
const ctx = canvas.getContext('2d');
const lyricDisplay = document.getElementById('lyric-display');
const width = canvas.width;
const height = canvas.height;
const imgData = ctx.createImageData(width, height);
const data = imgData.data;

let lyricIndex = 0;
let time = 0;

function renderFrame() {
  // Extract current character and calculate its real-time ASCII value
  const currentChar = lyrics[lyricIndex % lyrics.length];
  const asciiValue = currentChar.charCodeAt(0);
  
  lyricDisplay.innerText = `Char: '${currentChar}' | ASCII: ${asciiValue} | Index: ${lyricIndex % lyrics.length}`;

  // Dynamically modulate Mandelbrot constraints using the live ASCII value
  const maxIterations = (asciiValue % 40) + 10;
  const zoom = 1.2 + Math.sin(time * 0.04) * 0.4;
  const centerX = -0.75 + Math.cos(time * 0.02) * 0.05;
  const centerY = Math.sin(time * 0.03) * 0.05;

  for (let py = 0; py < height; py++) {
    for (let px = 0; px < width; px++) {
      // Map pixel coordinates to complex plane
      const x0 = (px - width / 2) / (0.4 * zoom * width) + centerX;
      const y0 = (py - height / 2) / (0.4 * zoom * height) + centerY;

      let x = 0;
      let y = 0;
      let iteration = 0;

      // Escape time algorithm calculated using live lyric ASCII influences
      while (x * x + y * y <= 4 && iteration < maxIterations) {
        const xTemp = x * x - y * y + x0;
        y = 2 * x * y + y0;
        x = xTemp;
        iteration++;
      }

      const pixelIndex = (py * width + px) * 4;
      if (iteration === maxIterations) {
        data[pixelIndex] = 5;     // R
        data[pixelIndex + 1] = 5; // G
        data[pixelIndex + 2] = 10;// B
      } else {
        // Color shifting governed by ASCII values and iterations
        data[pixelIndex] = (iteration * asciiValue * 3) % 256;
        data[pixelIndex + 1] = (iteration * 12) % 256;
        data[pixelIndex + 2] = (asciiValue * 5) % 256;
      }
      data[pixelIndex + 3] = 255; // Alpha
    }
  }

  ctx.putImageData(imgData, 0, 0);

  // Advance lyric progression over time
  if (Math.floor(time * 10) % 15 === 0) {
    lyricIndex++;
  }
  
  time += 0.1;
  requestAnimationFrame(renderFrame);
}

renderFrame();
</script>
</body>
</html>