const canvas = document.createElement('canvas');
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;
document.body.style.margin = '0';
document.body.style.overflow = 'hidden';
document.body.style.background = '#111';
document.body.appendChild(canvas);
const ctx = canvas.getContext('2d');

/* This function counts syllables roughly */
function countSyllables(text) {
    const words = text.toLowerCase().replace(/[^a-z]/g, ' ').split(/\s+/).filter(Boolean);
    let total = 0;
    for (let word of words) {
        if (word.length <= 3) { total += 1; continue; }
        const cleaned = word.replace(/(?:[^laeiouy]|ed|e)$/i, '').match(/[aeiouy]{1,2}/g);
        total += cleaned ? cleaned.length : 1;
    }
    return Math.max(1, total);
}

/* Extract comments from our own running source code */
const source = document.currentScript ? document.currentScript.textContent : 
    (function() {
        const scripts = document.querySelectorAll('script');
        let txt = '';
        scripts.forEach(s => txt += s.textContent + '\n');
        return txt || document.documentElement.outerHTML;
    })();

const commentMatches = source.match(/\/\*[\s\S]*?\*\/|\/\/.*/g) || ['// gravity is key'];
const totalSyllables = commentMatches.reduce((acc, c) => acc + countSyllables(c), 0);

/* Map syllables to gravity strength */
let gravity = totalSyllables * 0.05;

/* Create interactive physics particles */
const particles = Array.from({ length: 150 }, () => ({
    x: Math.random() * canvas.width,
    y: Math.random() * canvas.height * 0.5,
    vx: (Math.random() - 0.5) * 4,
    vy: (Math.random() - 0.5) * 4,
    radius: Math.random() * 6 + 4,
    color: `hsl(${Math.random() * 360}, 80%, 60%)`
}));

function animate() {
    ctx.fillStyle = 'rgba(17, 17, 17, 0.2)';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Update and draw particles with dynamic gravity
    for (let p of particles) {
        p.vy += gravity * 0.05;
        p.x += p.vx;
        p.y += p.vy;

        // Bounce off walls and floor
        if (p.y > canvas.height - p.radius) {
            p.y = canvas.height - p.radius;
            p.vy *= -0.7;
            p.vx *= 0.98;
        }
        if (p.x < p.radius || p.x > canvas.width - p.radius) {
            p.vx *= -1;
        }

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
        ctx.fillStyle = p.color;
        ctx.fill();
    }

    // Render stats on screen
    ctx.fillStyle = '#fff';
    ctx.font = '16px monospace';
    ctx.fillText(`Comments Syllables: ${totalSyllables}`, 20, 30);
    ctx.fillText(`Active Gravity: ${gravity.toFixed(2)}`, 20, 55);

    requestAnimationFrame(animate);
}

animate();