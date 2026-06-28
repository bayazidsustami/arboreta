import sys, json, math, pathlib, itertools, collections, re, textwrap
# Ensure NLTK CMU dict is available
import nltk, nltk.corpus
try:
    cmudict = nltk.corpus.cmudict.dict()
except LookupError:
    nltk.download('cmudict')
    cmudict = nltk.corpus.cmudict.dict()

def stress_pattern(word):
    """Return list of primary (1) and secondary (2) stress numbers for a word."""
    w = word.lower()
    if w not in cmudict:
        return []  # unknown word
    # choose first pronunciation
    pron = cmudict[w][0]
    return [int(p[-1]) for p in pron if p[-1].isdigit()]

def line_stress(line):
    """Combine stress patterns of words in a line."""
    stresses = []
    for w in re.findall(r"\b\w+\b", line):
        stresses.extend(stress_pattern(w))
    return stresses

def rhyme_key(word):
    """Return the vowel+rest part of the last stressed vowel for rhyme comparison."""
    w = word.lower()
    if w not in cmudict:
        return w
    pron = cmudict[w][0]
    # find the primary stress vowel and take from there
    for i in range(len(pron)-1, -1, -1):
        if pron[i][-1] == '1':  # primary stress
            return "".join(pron[i:])
    return "".join(pron[-2:])  # fallback

def stanza_rhymes(stanza):
    """Assign rhyme letters to lines of a stanza."""
    last_words = [re.findall(r"\b\w+\b", line.lower())[-1] for line in stanza if line.strip()]
    keys = [rhyme_key(w) for w in last_words]
    mapping = {}
    label = 0
    scheme = []
    for k in keys:
        if k not in mapping:
            mapping[k] = chr(ord('A') + label)
            label += 1
        scheme.append(mapping[k])
    return scheme

def parse_poem(text):
    """Split poem into stanzas, extract stress patterns and rhyme scheme."""
    stanzas = [ [l.rstrip() for l in s.splitlines() if l.strip()] 
                for s in text.strip().split("\n\n") if s.strip() ]
    data = []
    for stanza in stanzas:
        stresses = [line_stress(l) for l in stanza]
        rhyme = stanza_rhymes(stanza)
        data.append({"lines": stanza, "stresses": stresses, "rhyme": rhyme})
    return data

def generate_html(poem_data, out_path):
    """Create a self‑contained HTML file with three.js animation."""
    # Map rhyme letters to colors
    colors = {}
    palette = ["#e6194b","#3cb44b","#ffe119","#0082c8","#f58231",
               "#911eb4","#46f0f0","#f032e6","#d2f53c","#fabebe",
               "#008080","#e6beff","#aa6e28","#800000","#808000",
               "#fffac8","#800080","#aaffc3","#808080","#ffd8b1"]
    for stanza in poem_data:
        for r in stanza["rhyme"]:
            if r not in colors:
                colors[r] = palette[len(colors) % len(palette)]

    # Build JS data arrays
    js_stanzas = []
    for i, stanza in enumerate(poem_data):
        rad = 2 + i*1.2
        js_stanzas.append({
            "radius": rad,
            "color": colors[stanza["rhyme"][0]],   # use first rhyme color for whole stanza
            "stresses": stanza["stresses"]
        })
    js_data = json.dumps(js_stanzas)

    html = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><title>Poem Mandala</title>
<style>body{{margin:0;overflow:hidden;background:#111;}}</style>
</head><body>
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r152/three.min.js"></script>
<script>
const data = {js_data};
let scene, camera, renderer, clock;
init();
animate();

function init(){ 
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(45, window.innerWidth/window.innerHeight, 0.1, 100);
    camera.position.z = 10;
    renderer = new THREE.WebGLRenderer({{antialias:true}});
    renderer.setSize(window.innerWidth, window.innerHeight);
    document.body.appendChild(renderer.domElement);
    clock = new THREE.Clock();

    data.forEach(stanza=>{ 
        const geometry = new THREE.RingGeometry(stanza.radius-0.2, stanza.radius+0.2, 64);
        const material = new THREE.MeshBasicMaterial({{color: stanza.color, side:THREE.DoubleSide, transparent:true, opacity:0.6}});
        const mesh = new THREE.Mesh(geometry, material);
        mesh.userData = {{stresses: stanza.stresses.flat(), baseScale:1}};
        scene.add(mesh);
    });

    // Simple chime using Web Audio API
    const audioCtx = new (window.AudioContext||window.webkitAudioContext)();
    function playChime(time, freq){
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.type='sine';
        osc.frequency.value = freq;
        gain.gain.setValueAtTime(0, time);
        gain.gain.linearRampToValueAtTime(0.2, time+0.01);
        gain.gain.exponentialRampToValueAtTime(0.001, time+0.3);
        osc.connect(gain).connect(audioCtx.destination);
        osc.start(time);
        osc.stop(time+0.4);
    }

    // schedule chimes based on stress patterns
    let start = audioCtx.currentTime+0.5;
    data.forEach(stanza=>{ 
        let t = start;
        stanza.stresses.flat().forEach(st=>{{ 
            const freq = st===1?800:500; // primary vs secondary
            playChime(t, freq);
            t+=0.4;
        }});
        start = t+0.5;
    });
}}

function animate(){
    requestAnimationFrame(animate);
    const elapsed = clock.getElapsedTime();
    scene.children.forEach(mesh=>{ 
        const stresses = mesh.userData.stresses;
        // compute a simple pulse from the average stress (1 or 2)
        const avg = stresses.reduce((a,b)=>a+b,0)/stresses.length||0;
        const scale = 1+0.3*Math.sin(elapsed* (0.5+avg*0.2));
        mesh.scale.set(scale,scale,scale);
    });
    renderer.render(scene,camera);
}
window.addEventListener('resize',()=>{ 
    camera.aspect = window.innerWidth/window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth,window.innerHeight);
});
</script>
</body></html>"""
    pathlib.Path(out_path).write_text(html, encoding='utf8')
    print(f"Visualization written to {out_path}")

def main():
    if len(sys.argv)!=3:
        print("Usage: python script.py <poem.txt> <output.html>")
        sys.exit(1)
    poem_path, out_html = sys.argv[1], sys.argv[2]
    text = pathlib.Path(poem_path).read_text(encoding='utf8')
    data = parse_poem(text)
    generate_html(data, out_html)

if __name__=="__main__":
    main()