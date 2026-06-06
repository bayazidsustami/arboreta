package main

import (
	"encoding/json"
	"log"
	"math"
	"net/http"
	"sync"
	"time"
)

// ------------------------------------------------------------
// Mock structures simulating a live Twitter feed.
// In a real implementation these would be replaced with
// actual Twitter streaming API calls and sentiment analysis.
// ------------------------------------------------------------
type Tweet struct {
	Text string `json:"text"`
}

// simple sentiment mock: returns polarity [-1,1] and arousal [0,1]
func analyze(text string) (polarity float64, arousal float64) {
	// dummy: count exclamation marks for arousal, length for polarity
	arousal = math.Min(float64(len(text))/100.0, 1.0)
	if len(text)%2 == 0 {
		polarity = 0.5
	} else {
		polarity = -0.5
	}
	return
}

// ------------------------------------------------------------
// Shared state for the visualisation.
// ------------------------------------------------------------
type VoxelState struct {
	sync.RWMutex
	Polarity float64 // average polarity [-1,1]
	Arousal  float64 // average arousal [0,1]
	// a simple word-frequency histogram (top 20 words)
	Words map[string]int `json:"words"`
}

var state = VoxelState{
	Words: make(map[string]int),
}

// ------------------------------------------------------------
// Background goroutine that "receives" tweets and updates state.
// ------------------------------------------------------------
func feedSimulator() {
	sampleTexts := []string{
		"Go is awesome! #golang",
		"I love watching the sunrise.",
		"Feeling sad about the news...",
		"Excited for the weekend!!!",
		"Just had a terrible coffee.",
	}
	for {
		for _, txt := range sampleTexts {
			p, a := analyze(txt)

			state.Lock()
			state.Polarity = (state.Polarity + p) / 2
			state.Arousal = (state.Arousal + a) / 2

			// naive word count
			for _, w := range splitWords(txt) {
				state.Words[w]++
			}
			state.Unlock()

			time.Sleep(2 * time.Second)
		}
	}
}

// splitWords is a tiny tokenizer.
func splitWords(s string) []string {
	words := []string{}
	cur := ""
	for _, r := range s {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') {
			cur += string(r)
		} else {
			if cur != "" {
				words = append(words, cur)
				cur = ""
			}
		}
	}
	if cur != "" {
		words = append(words, cur)
	}
	return words
}

// ------------------------------------------------------------
// HTTP handlers.
// ------------------------------------------------------------
func stateHandler(w http.ResponseWriter, r *http.Request) {
	state.RLock()
	resp, _ := json.Marshal(state)
	state.RUnlock()
	w.Header().Set("Content-Type", "application/json")
	w.Write(resp)
}

// serve the minimal WebGL page.
// The page uses three.js to render a voxel field whose
// color/intensity follows the server‑provided polarity and arousal.
// A binaural beat is generated with Web Audio API using the arousal value.
func pageHandler(w http.ResponseWriter, r *http.Request) {
	const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Voxel Sentiment Sculpture</title>
<style>body{margin:0;overflow:hidden;background:#111}</style>
</head>
<body>
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r152/three.min.js"></script>
<script>
let scene, cam, renderer, cubeGroup;
let beatOsc;
init();
animate();

function init(){
    scene = new THREE.Scene();
    cam = new THREE.PerspectiveCamera(60,innerWidth/innerHeight,0.1,1000);
    cam.position.set(0,30,60);
    renderer = new THREE.WebGLRenderer({antialias:true});
    renderer.setSize(innerWidth,innerHeight);
    document.body.appendChild(renderer.domElement);
    cubeGroup = new THREE.Group();
    scene.add(cubeGroup);
    // light
    const light = new THREE.DirectionalLight(0xffffff,1);
    light.position.set(0,1,0);
    scene.add(light);
    // audio context for binaural beat
    const ctx = new (window.AudioContext||window.webkitAudioContext)();
    beatOsc = ctx.createOscillator();
    const gain = ctx.createGain();
    beatOsc.frequency.value = 200; // base tone
    beatOsc.connect(gain);
    gain.connect(ctx.destination);
    gain.gain.value = 0.0;
    beatOsc.start();
}
function fetchState(){
    fetch('/state').then(r=>r.json()).then(updateScene);
}
function updateScene(data){
    // adjust color based on polarity (-1 red, +1 blue)
    const hue = (data.polarity+1)/2*240; // 0..240
    const sat = 0.8;
    const light = 0.5;
    const col = new THREE.Color(`hsl(${hue},${sat*100}%,${light*100}%)`);
    // adjust density based on arousal
    const count = Math.round( data.arousal * 30 ) + 10;
    // rebuild voxel field
    while(cubeGroup.children.length) cubeGroup.remove(cubeGroup.children[0]);
    const geom = new THREE.BoxGeometry(1,1,1);
    for(let i=0;i<count;i++){
        const mesh = new THREE.Mesh(geom, new THREE.MeshLambertMaterial({color:col}));
        mesh.position.set(
            (Math.random()-0.5)*20,
            Math.random()*20,
            (Math.random()-0.5)*20
        );
        cubeGroup.add(mesh);
    }
    // binaural beat: left ear base, right ear base+delta
    const ctx = beatOsc.context;
    const delta = data.arousal*40+5; // 5-45Hz difference
    const left = ctx.createOscillator();
    const right = ctx.createOscillator();
    left.frequency.value = beatOsc.frequency.value;
    right.frequency.value = beatOsc.frequency.value+delta;
    const splitter = ctx.createChannelSplitter(2);
    const merger = ctx.createChannelMerger(2);
    left.connect(splitter,0,0);
    right.connect(splitter,0,1);
    splitter.connect(merger,0,0);
    splitter.connect(merger,1,1);
    merger.connect(ctx.destination);
    left.start();
    right.start();
    setTimeout(()=>{left.stop();right.stop();},0.2);
}
function animate(){
    requestAnimationFrame(animate);
    renderer.render(scene,cam);
    fetchState();
}
window.addEventListener('resize',()=>{renderer.setSize(innerWidth,innerHeight);cam.aspect=innerWidth/innerHeight;cam.updateProjectionMatrix();});
</script>
</body>
</html>`
	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(html))
}

// ------------------------------------------------------------
// Main entry point.
// ------------------------------------------------------------
func main() {
	go feedSimulator()
	http.HandleFunc("/", pageHandler)
	http.HandleFunc("/state", stateHandler)
	log.Println("Server listening on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}