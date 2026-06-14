import { fromEvent, interval, merge, Observable } from 'https://esm.run/rxjs';
import { map, filter, tap } from 'https://esm.run/rxjs/operators';

// ----- Configuration ---------------------------------------------------------

const EMOJI_POOL = ['😀','🎉','🚀','🌈','🔥','💧','⚡','🍀','🧩','🦄']; // sample emojis
const MIN_FREQ = 200;   // Hz
const MAX_FREQ = 1200;  // Hz
const BASE_NOTE = 440;  // A4

// ----- Helpers ----------------------------------------------------------------

function emojiToFreq(emoji: string): number {
    const code = emoji.codePointAt(0) ?? 0;
    // map Unicode range to audible frequency range
    const norm = (code % 0x1000) / 0x1000; // 0..1
    return MIN_FREQ + norm * (MAX_FREQ - MIN_FREQ);
}

function createOscillator(freq: number, ctx: AudioContext): OscillatorNode {
    const osc = ctx.createOscillator();
    osc.frequency.value = freq;
    osc.type = 'sine';
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.1, ctx.currentTime);
    osc.connect(gain).connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.5);
    return osc;
}

// ----- Simulated Twitter emoji stream -----------------------------------------

function fakeTwitterStream(): Observable<string> {
    return interval(300).pipe(
        map(() => EMOJI_POOL[Math.floor(Math.random() * EMOJI_POOL.length)])
    );
}

// ----- Audio setup ------------------------------------------------------------

const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
const analyser = audioCtx.createAnalyser();
analyser.fftSize = 256;
const dataArray = new Uint8Array(analyser.frequencyBinCount);
const analyserNode = analyser;

// ----- SVG kaleidoscope -------------------------------------------------------

const svgNS = "http://www.w3.org/2000/svg";
const svg = document.createElementNS(svgNS, "svg");
svg.setAttribute("width", "100%");
svg.setAttribute("height", "100%");
svg.style.position = "fixed";
svg.style.top = "0";
svg.style.left = "0";
svg.style.zIndex = "-1";
document.body.appendChild(svg);

// create a few rotating groups
const groups: SVGElement[] = [];
for (let i = 0; i < 6; i++) {
    const g = document.createElementNS(svgNS, "g");
    g.setAttribute("transform", `rotate(${i * 60})`);
    svg.appendChild(g);
    groups.push(g);
}

// draw initial polygons
function drawPolys() {
    groups.forEach((g, idx) => {
        g.innerHTML = "";
        const sides = 3 + (idx % 5);
        const radius = 80 + idx * 20;
        const poly = document.createElementNS(svgNS, "polygon");
        const points = [];
        for (let i = 0; i < sides; i++) {
            const angle = (i / sides) * Math.PI * 2;
            points.push(`${Math.cos(angle) * radius},${Math.sin(angle) * radius}`);
        }
        poly.setAttribute("points", points.join(" "));
        poly.setAttribute("fill", `hsl(${(idx * 60) % 360},70%,50%)`);
        poly.setAttribute("stroke", "#fff");
        poly.setAttribute("stroke-width", "2");
        g.appendChild(poly);
    });
}
drawPolys();

// ----- Reactive pipeline -----------------------------------------------------

const emoji$ = fakeTwitterStream();

emoji$.pipe(
    tap(emoji => {
        const freq = emojiToFreq(emoji);
        createOscillator(freq, audioCtx);
    })
).subscribe();

// Connect every oscillator to analyser
audioCtx.audioWorklet.addModule('data:application/javascript,export default class {}').catch(()=>{});
audioCtx.destination.connect(analyser);

// ----- Animation loop ---------------------------------------------------------

function animate() {
    requestAnimationFrame(animate);
    analyser.getByteFrequencyData(dataArray);

    // derive speed, scale and hue from spectrum
    const avg = dataArray.reduce((a, b) => a + b, 0) / dataArray.length;
    const speed = 0.05 + (avg / 255) * 0.3;
    const scale = 0.8 + (avg / 255) * 0.4;
    const hueShift = (avg / 255) * 360;

    groups.forEach((g, idx) => {
        const rot = (performance.now() * speed + idx * 60) % 360;
        g.setAttribute("transform", `rotate(${rot}) scale(${scale})`);
        const poly = g.firstElementChild as SVGPolygonElement;
        if (poly) {
            poly.setAttribute("fill", `hsl(${(idx * 60 + hueShift) % 360},70%,50%)`);
        }
    });
}
animate();

// ----- Interaction: click to resume audio context --------------------------------

fromEvent(document, 'click')
    .pipe(tap(() => audioCtx.state === 'suspended' && audioCtx.resume()))
    .subscribe();