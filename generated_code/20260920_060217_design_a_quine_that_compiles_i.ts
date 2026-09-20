// Dying Star Quine & SVG Mandala Generator
const src = `// Dying Star Quine & SVG Mandala Generator
const src = \`TEMPLATE\`;
const pulse = (n: number) => ' '.repeat(Math.max(1, Math.floor(4 + 3 * Math.sin(n * 0.3) * Math.exp(n * 0.02))));
const starPulse = (t: number) => Math.sin(t) * Math.exp(-t * 0.1);
const generateMandalaSVG = () => {
  let svg = '<svg viewBox="-100 -100 200 200" xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)">\\n';
  for (let i = 0; i < 12; i++) {
    const angle = (i * Math.PI) / 6;
    const r = 50 + 20 * starPulse(i);
    svg += \`  <circle cx="\${r * Math.cos(angle)}" cy="\${r * Math.sin(angle)}" r="10" fill="none" stroke="gold" stroke-width="2"/>\\n\`;
  }
  return svg + '</svg>';
};
console.log(generateMandalaSVG());
let quine = src.replace('TEMPLATE', src);
let pulsed = '';
for (let i = 0; i < quine.length; i++) {
  if (quine[i] === ' ') pulsed += pulse(i);
  else pulsed += quine[i];
}
console.log(pulsed);`;
const pulse = (n: number) => ' '.repeat(Math.max(1, Math.floor(4 + 3 * Math.sin(n * 0.3) * Math.exp(n * 0.02))));
const starPulse = (t: number) => Math.sin(t) * Math.exp(-t * 0.1);
const generateMandalaSVG = () => {
  let svg = '<svg viewBox="-100 -100 200 200" xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)">\n';
  for (let i = 0; i < 12; i++) {
    const angle = (i * Math.PI) / 6;
    const r = 50 + 20 * starPulse(i);
    svg += `  <circle cx="${r * Math.cos(angle)}" cy="${r * Math.sin(angle)}" r="10" fill="none" stroke="gold" stroke-width="2"/>\n`;
  }
  return svg + '</svg>';
};
console.log(generateMandalaSVG());
let quine = src.replace('TEMPLATE', src);
let pulsed = '';
for (let i = 0; i < quine.length; i++) {
  if (quine[i] === ' ') pulsed += pulse(i);
  else pulsed += quine[i];
}
console.log(pulsed);