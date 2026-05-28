import * as fs from 'fs';
import * as path from 'path';

/**
 * Simple multi‑language word banks.
 */
const LANGUAGES = {
    english: ['whisper', 'moon', 'silence', 'dream', 'river', 'star', 'echo', 'shadow'],
    spanish: ['susurro', 'luna', 'silencio', 'sueño', 'río', 'estrella', 'eco', 'sombra'],
    french:  ['murmure', 'lune', 'silence', 'rêve', 'rivière', 'étoile', 'écho', 'ombre'],
    italian: ['sussurro', 'luna', 'silenzio', 'sogno', 'fiume', 'stella', 'eco', 'ombra']
};

/**
 * Randomly pick a language and compose a short 4‑line poem.
 */
function composePoem(): {lang: string, lines: string[]} {
    const langs = Object.keys(LANGUAGES) as (keyof typeof LANGUAGES)[];
    const lang = langs[Math.floor(Math.random()*langs.length)];
    const pool = LANGUAGES[lang];
    const lines = [];
    for (let i=0;i<4;i++) {
        const line = [pool[Math.floor(Math.random()*pool.length)],
                      pool[Math.floor(Math.random()*pool.length)]].join(' ');
        lines.push(line);
    }
    return {lang, lines};
}

/**
 * Very naive phonetic extraction – only vowels matter for sound mapping.
 */
function extractVowels(text: string): string[] {
    const match = text.toLowerCase().match(/[aeiouáéíóúü]/g);
    return match ?? [];
}

/**
 * Map vowels to frequencies (C‑scale) for a simple ambient drone.
 */
function vowelToFreq(vowel: string): number {
    const base = 261.63; // C4
    const map: {[k:string]:number} = {
        a:0, e:2, i:4, o:5, u:7,
        á:0, é:2, í:4, ó:5, ú:7, ü:9
    };
    const semitone = map[vowel] ?? 0;
    return base * Math.pow(2, semitone/12);
}

/**
 * Generate the final self‑contained HTML.
 */
function buildHTML(poem: {lang:string, lines:string[]}): string {
    const verses = poem.lines.map((l,i)=>`<text id="line${i}" x="50%" y="${30+ i*15}%" dominant-baseline="middle" text-anchor="middle" class="verse">${l}</text>`).join('\n');

    const vowelSeq = poem.lines.map(l=>extractVowels(l)).flat();
    const frequencies = vowelSeq.map(v=>vowelToFreq(v));

    const audioScript = `
        const ctx = new (window.AudioContext||window.webkitAudioContext)();
        const now = ctx.currentTime;
        frequencies.forEach((freq,i)=> {
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'sine';
            osc.frequency.setValueAtTime(freq, now + i*0.4);
            gain.gain.setValueAtTime(0.0, now + i*0.4);
            gain.gain.linearRampToValueAtTime(0.2, now + i*0.4 + 0.2);
            gain.gain.linearRampToValueAtTime(0.0, now + i*0.4 + 1.0);
            osc.connect(gain).connect(ctx.destination);
            osc.start(now + i*0.4);
            osc.stop(now + i*0.4 + 1.2);
        });
    `.trim();

    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Poetic SVG + Audio</title>
<style>
body{margin:0;background:#111;color:#eee;font-family:sans-serif;overflow:hidden;}
svg{width:100vw;height:100vh;}
.verse{font-size:4vw;fill:#fff;}
@keyframes morph{
    0%   {opacity:0; transform:scale(0.8);}
    20%  {opacity:1; transform:scale(1.0);}
    80%  {opacity:1; transform:scale(1.0);}
    100% {opacity:0; transform:scale(0.8);}
}
${[0,1,2,3].map(i=>`
#line${i}{animation: morph 8s infinite ${i*2}s ease-in-out;}
`).join('')}
</style>
</head>
<body>
<svg viewBox="0 0 100 100">
${verses}
</svg>
<script>
${audioScript}
</script>
</body>
</html>`;
}

/* ------------------- Main execution ------------------- */
const poem = composePoem();
const html = buildHTML(poem);
const outPath = path.resolve(__dirname, 'poem.html');
fs.writeFileSync(outPath, html);
console.log('Generated poem.html using language:', poem.lang);