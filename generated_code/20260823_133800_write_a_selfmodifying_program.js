// Self-Modifying JavaScript Code Executing as Celestial Zodiac Mutation Trace
(function mutate(gen = 0) {
  // Memory registers mapped to virtual celestial coordinates (RA / Dec)
  const memory = {
    alpha: Math.sin(gen) * 180 + 180,
    beta: Math.cos(gen * 0.7) * 90,
    gamma: (gen * 13) % 360,
    delta: (gen * 37) % 180 - 90
  };

  // Generate ASCII Constellation Canvas (40x15)
  const width = 40, height = 15;
  const grid = Array.from({ length: height }, () => Array(width).fill(' '));
  const zodiacSigns = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio"];
  const currentZodiac = zodiacSigns[gen % zodiacSigns.length];

  // Project variable celestial addresses onto ASCII viewport
  const stars = [];
  Object.entries(memory).forEach(([key, val], idx) => {
    const x = Math.floor((val % 360) / 360 * (width - 1));
    const y = Math.floor(((val + 90) % 180) / 180 * (height - 1));
    grid[y][x] = String.fromCharCode(65 + idx); // Variable identity
    stars.push({ x, y, name: key });
  });

  // Render constellation lines connecting variables
  for (let i = 0; i < stars.length - 1; i++) {
    let { x: x0, y: y0 } = stars[i];
    let { x: x1, y: y1 } = stars[i + 1];
    let steps = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0));
    for (let s = 1; s < steps; s++) {
      let cx = Math.floor(x0 + (x1 - x0) * (s / steps));
      let cy = Math.floor(y0 + (y1 - y0) * (s / steps));
      if (grid[cy][cx] === ' ') grid[cy][cx] = '.';
    }
  }

  // Draw the celestial trace frame
  console.clear();
  console.log(`=== EXECUTION TRACE GEN ${gen} :: ZODIAC [${currentZodiac}] ===`);
  console.log('+' + '-'.repeat(width) + '+');
  grid.forEach(row => console.log('|' + row.join('') + '|'));
  console.log('+' + '-'.repeat(width) + '+');

  // Self-mutation phase: modify source logic function and loop
  if (gen < 10) {
    const nextCode = mutate.toString().replace(/gen = \d+/, `gen = ${gen + 1}`);
    const mutated = new Function(`return ${nextCode}`)();
    setTimeout(() => mutated(gen + 1), 600);
  }
})();