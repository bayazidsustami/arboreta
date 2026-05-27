package main

import (
	"log"
	"net/http"
	"strings"
	"time"
)

// generate a deterministic pseudo‑random walk of Unicode combining characters.
// The walk is deterministic based on the current second.
func generateLine(t time.Time) string {
	seed := int64(t.Unix())
	const walkLen = 80
	const baseRune = 0x0300 // Combining Grave Accent
	var sb strings.Builder
	for i := 0; i < walkLen; i++ {
		// simple linear congruential generator
		seed = (seed*1664525 + 1013904223) & 0x7fffffff
		comb := rune(baseRune + (seed % 0x0300)) // range of combining marks
		sb.WriteRune('a')
		sb.WriteRune(comb)
	}
	return sb.String()
}

// handler serves a minimal HTML page that does the heavy lifting in the browser.
func handler(w http.ResponseWriter, r *http.Request) {
	html := `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Self‑Refracting Poem</title>
<style>
body{margin:0;background:#111;color:#eee;font-family:monospace;overflow:hidden}
svg{width:100vw;height:100vh}
</style>
</head>
<body>
<svg id="canvas"></svg>
<script>
// Capture microphone, perform real‑time FFT, and drive SVG updates.
(async()=> {
	const audioCtx = new (window.AudioContext||window.webkitAudioContext)();
	const stream = await navigator.mediaDevices.getUserMedia({audio:true});
	const source = audioCtx.createMediaStreamSource(stream);
	const analyser = audioCtx.createAnalyser();
	analyser.fftSize = 256;
	source.connect(analyser);
	const data = new Uint8Array(analyser.frequencyBinCount);
	const svg = document.getElementById('canvas');

	// Generate a line of combining characters in Go‑style deterministic walk.
	function genLine() {
		const now = Math.floor(Date.now()/1000);
		let seed = now;
		const walkLen = 80;
		const base = 0x0300;
		let line = '';
		for(let i=0;i<walkLen;i++){
			seed = (seed*1664525 + 1013904223) & 0x7fffffff;
			const comb = String.fromCharCode(base + (seed % 0x0300));
			line += 'a' + comb;
		}
		return line;
	}

	function draw() {
		analyser.getByteFrequencyData(data);
		const amp = data.reduce((a,b)=>a+b)/data.length; // average amplitude
		const line = genLine();
		const text = document.createElementNS('http://www.w3.org/2000/svg','text');
		text.setAttribute('x',0);
		text.setAttribute('y',amp*2+20); // vertical position from sound
		text.setAttribute('font-size',12);
		text.textContent = line;
		svg.appendChild(text);
		// keep only recent elements to avoid memory blow‑up
		if(svg.childElementCount>100){
			svg.removeChild(svg.firstElementChild);
		}
		requestAnimationFrame(draw);
	}
	draw();
})();
</script>
</body>
</html>`
	w.Header().Set("Content-Type", "text/html")
	w.Write([]byte(html))
}

func main() {
	http.HandleFunc("/", handler)
	log.Println("Serving on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}