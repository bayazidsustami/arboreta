package main

import (
	"encoding/json"
	"flag"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/go-midi/midi"
	"github.com/go-midi/midi/event"
	"github.com/gorilla/websocket"
)

// Data sent to the client for visualisation
type MusicData struct {
	Intervals      []int     `json:"intervals"`      // pitch intervals in semitones
	RhythmicDensity float64   `json:"density"`       // notes per second
	Spectrum       []float64 `json:"spectrum"`      // dummy timbral spectrum
	TempoFactor    float64   `json:"tempoFactor"`   // user‑driven tempo multiplier
}

// Global websocket upgrader
var upgrader = websocket.Upgrader{CheckOrigin: func(r *http.Request) bool { return true }}

// Parse MIDI file and extract simple musical features
func parseMIDI(path string) (MusicData, error) {
	f, err := os.Open(path)
	if err != nil {
		return MusicData{}, err
	}
	defer f.Close()
	rd := midi.NewReader()
	var notes []int
	var timestamps []time.Duration
	var lastTick uint64
	var ppq uint16 = 480 // default pulses per quarter note
	tempo := 500000.0    // default microseconds per quarter note (120 BPM)

	rd.Msg = func(pos *midi.Position, msg midi.Message) {
		// capture tempo meta events
		if meta, ok := msg.(event.MetaMessage); ok && meta.Type == event.SetTempo {
			tempo = float64(meta.Tempo)
		}
		// capture note‑on events
		if ne, ok := msg.(event.NoteOnMessage); ok && ne.Velocity > 0 {
			notes = append(notes, int(ne.Key()))
			tick := pos.AbsoluteTicks
			if len(timestamps) > 0 {
				lastTick = timestamps[len(timestamps)-1].Ticks()
			}
			abs := time.Duration(float64(tick-lastTick) * tempo / float64(ppq) * 1e-6 * float64(time.Second))
			timestamps = append(timestamps, time.Now().Add(abs))
		}
	}
	if err := rd.ReadSMF(f); err != nil {
		return MusicData{}, err
	}
	// compute intervals
	var intervals []int
	for i := 1; i < len(notes); i++ {
		intervals = append(intervals, notes[i]-notes[i-1])
	}
	// compute rhythmic density
	var density float64
	if len(timestamps) > 1 {
		totalDur := timestamps[len(timestamps)-1].Sub(timestamps[0]).Seconds()
		if totalDur > 0 {
			density = float64(len(notes)) / totalDur
		}
	}
	// dummy timbral spectrum (random but deterministic)
	spectrum := make([]float64, 8)
	for i := range spectrum {
		spectrum[i] = 0.5 + 0.5*float64(i%2)
	}
	return MusicData{
		Intervals:      intervals,
		RhythmicDensity: density,
		Spectrum:       spectrum,
		TempoFactor:    1.0,
	}, nil
}

// Serve the websocket, pushing music data and reacting to tempo changes
func wsHandler(data *MusicData) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		c, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Println("ws upgrade:", err)
			return
		}
		defer c.Close()

		// send initial data
		if err := c.WriteJSON(data); err != nil {
			return
		}
		// listen for tempo adjustments from client
		for {
			_, msg, err := c.ReadMessage()
			if err != nil {
				return
			}
			var payload struct{ TempoFactor float64 }
			if json.Unmarshal(msg, &payload) == nil && payload.TempoFactor > 0 {
				data.TempoFactor = payload.TempoFactor
				// echo back updated factor
				c.WriteJSON(data)
			}
		}
	}
}

// Minimal HTML/JS front‑end using Three.js
const indexHTML = `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>MIDI 3D Sculpture</title>
<style>body{margin:0;overflow:hidden}</style>
</head>
<body>
<script src="https://cdn.jsdelivr.net/npm/three@0.158/build/three.min.js"></script>
<script>
let scene, cam, renderer, sculpture;
let tempo = 1.0;
function init() {
    scene = new THREE.Scene();
    cam = new THREE.PerspectiveCamera(60, innerWidth/innerHeight, 0.1, 1000);
    cam.position.z = 30;
    renderer = new THREE.WebGLRenderer({antialias:true});
    renderer.setSize(innerWidth, innerHeight);
    document.body.appendChild(renderer.domElement);
    const light = new THREE.DirectionalLight(0xffffff,1);
    light.position.set(5,10,7);
    scene.add(light);
    window.addEventListener('resize',()=>renderer.setSize(innerWidth,innerHeight));
    animate();
}
function buildSculpture(data) {
    if (sculpture) scene.remove(sculpture);
    const geometry = new THREE.TubeGeometry(
        new THREE.CatmullRomCurve3(data.intervals.map((i,idx)=>new THREE.Vector3(idx*2, i*0.5, 0))),
        200, 2, 8, false);
    const colors = data.spectrum.map(v=>new THREE.Color(v,1-v,0.5));
    const mat = new THREE.MeshStandardMaterial({vertexColors:true});
    const pos = geometry.attributes.position;
    const colorsAttr = new Float32Array(pos.count*3);
    for(let i=0;i<pos.count;i++){
        const c = colors[i%colors.length];
        colorsAttr[i*3]=c.r;colorsAttr[i*3+1]=c.g;colorsAttr[i*3+2]=c.b;
    }
    geometry.setAttribute('color',new THREE.BufferAttribute(colorsAttr,3));
    sculpture = new THREE.Mesh(geometry, mat);
    scene.add(sculpture);
}
function animate(){
    requestAnimationFrame(animate);
    if (sculpture) sculpture.rotation.y += 0.001*tempo;
    renderer.render(scene, cam);
}
function connectWS(){
    const ws = new WebSocket(`ws://${location.host}/ws`);
    ws.onmessage = e=>{const d=JSON.parse(e.data);buildSculpture(d);tempo=d.tempoFactor;};
    // UI slider for tempo
    const slider=document.createElement('input');
    slider.type='range';slider.min=0.5;slider.max=2;slider.step=0.01;slider.value=1;
    slider.style.position='absolute';slider.style.top='10px';slider.style.left='10px';
    slider.oninput=()=>{ws.send(JSON.stringify({tempoFactor:parseFloat(slider.value)}));};
    document.body.appendChild(slider);
}
init();
connectWS();
</script>
</body>
</html>`

func main() {
	midiPath := flag.String("midi", "example.mid", "path to MIDI file")
	addr := flag.String("addr", ":8080", "http service address")
	flag.Parse()

	musicData, err := parseMIDI(*midiPath)
	if err != nil {
		log.Fatalf("failed to parse MIDI: %v", err)
	}
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(indexHTML))
	})
	http.HandleFunc("/ws", wsHandler(&musicData))
	log.Printf("serving on %s", *addr)
	log.Fatal(http.ListenAndServe(*addr, nil))
}