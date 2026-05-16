// A script that generates recursive binary patterns which fade into abstract, music-inspired visuals.

(function() {
  const canvas = document.createElement('canvas');
  document.body.appendChild(canvas);
  const ctx = canvas.getContext('2d');
  let width = canvas.width = window.innerWidth;
  let height = canvas.height = window.innerHeight;

  // Recursive function to draw binary tree structures with varying angles and colors
  function drawBinaryFractal(x, y, length, angle, depth, v) {
    if (depth <= 0) return;

    const endX = x + Math.cos(angle) * length;
    const endY = y + Math.sin(angle) * length;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(endX, endY);
    ctx.strokeStyle = `hsla(${v * 360}, 70%, 50%, ${Math.max(0.1, 1 - v)})`;
    ctx.lineWidth = 2;
    ctx.stroke();

    // Recursive branches diverging symmetrically based on binary choices (left/right)
    if (depth % 2 === 0) {
      drawBinaryFractal(endX, endY, length*0.7, angle - 0.5, depth-1, v+0.05);
      drawBinaryFractal(endX, endY, length*0.7, angle + 0.5, depth-1, v+0.1);
    } else {
      drawBinaryFractal(endX, endY, length*0.7, angle + 0.3, depth-1, v+0.08);
      drawBinaryFractal(endX, endY, length*0.7, angle - 0.3, depth-1, v+0.12);
    }
  }

  let t = 0;

  // Animation loop to create a mosaic effect with time-based variations
  function animate() {
    t += 0.01;
    ctx.fillStyle = 'rgba(0,0,0,0.05)';
    ctx.fillRect(0, 0, width, height); // Fading trail effect

    // Harmonic parameters for color rotation and branch dynamics
    const hue = Math.sin(t * 0.5) * 180 + 180;
    const angle = Math.cos(t * 0.3) * 0.2;

    // Draw multiple binary fractals with variations
    drawBinaryFractal(width/2, height/2, 150, angle, 12, hue / 360);
    drawBinaryFractal(width/2.5, height/3, 100, angle + 0.5, 10, Math.random());
    drawBinaryFractal(width/1.5, height/1.5, 120, angle - 0.3, 11, t * 0.05 % 1);

    requestAnimationFrame(animate);
  }

  window.addEventListener('resize', () => {
    width = canvas.width = window.innerWidth;
    height = canvas.height = window.innerHeight;
  });

  animate();
})();