package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"strings"
	"time"
)

// simple sentiment: positive words increase hue, negative decrease
var positive = []string{"joy", "love", "bright", "sun", "hope", "peace"}
var negative = []string{"sad", "dark", "pain", "storm", "grief", "fear"}
var nouns = []string{"wind", "river", "mountain", "star", "forest", "ocean"}

type lineInfo struct {
	Text   string
	Hue    int // 0-360
	Scale  float64
	Offset float64
}

// generate a pseudo‑poem line and a hue based on simple word sentiment
func makeLine() lineInfo {
	words := []string{}
	hue := 180 // neutral cyan
	// pick a noun
	words = append(words, nouns[rand.Intn(len(nouns))])
	// add random adjectives (some positive, some negative)
	for i := 0; i < 2; i++ {
		if rand.Intn(2) == 0 {
			w := positive[rand.Intn(len(positive))]
			words = append(words, w)
			hue = (hue + 30) % 360
		} else {
			w := negative[rand.Intn(len(negative))]
			words = append(words, w)
			hue = (hue - 30 + 360) % 360
		}
	}
	text := strings.Title(strings.Join(words, " "))
	// random scale and phase for animation
	scale := 0.5 + rand.Float64()*1.0
	offset := rand.Float64() * 2 * 3.14159
	return lineInfo{Text: text, Hue: hue, Scale: scale, Offset: offset}
}

// assemble full HTML with embedded JS/CSS
func buildHTML(lines []lineInfo) string {
	var buf bytes.Buffer
	buf.WriteString(`<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><title>Fractal Poem</title>
<style>
body{margin:0;background:#111;color:#eee;font-family:sans-serif;display:flex;flex-direction:column;align-items:center;height:100vh;overflow:hidden;}
#poem{position:absolute;bottom:20px;font-size:2em;text-align:center;}
svg{width:100vw;height:100vh;position:absolute;top:0;left:0;}
</style>
</head><body>
<svg id="fractal"></svg>
<div id="poem"></div>
<script>
const lines = `)
	data, _ := json.Marshal(lines)
	buf.Write(data)
	buf.WriteString(`;
let idx = 0;
const poemDiv = document.getElementById('poem');
const svg = document.getElementById('fractal');

// simple recursive fractal (Koch-like) drawn with path
function drawFractal(hue, scale, offset) {
    const size = Math.min(window.innerWidth, window.innerHeight) * 0.4 * scale;
    const pts = [];
    const steps = 4;
    for (let i = 0; i <= steps; i++) {
        const angle = offset + i * Math.PI * 2 / steps;
        pts.push([Math.cos(angle) * size, Math.sin(angle) * size]);
    }
    let d = '';
    for (let i = 0; i < pts.length; i++) {
        const [x, y] = pts[i];
        d += (i===0?'M':'L') + x + ',' + y;
    }
    d += 'Z';
    svg.innerHTML = '<path d="'+d+'" fill="hsl('+hue+',70%,50%)" stroke="#fff" stroke-width="2"/>';
}

// speech synthesis with callback to sync
function speak(line, onEnd) {
    const utter = new SpeechSynthesisUtterance(line);
    utter.onend = onEnd;
    speechSynthesis.speak(utter);
}

// animation loop
function animate() {
    const line = lines[idx];
    poemDiv.textContent = line.Text;
    drawFractal(line.Hue, line.Scale, line.Offset + performance.now()/1000);
    // restart after speech ends
    speak(line.Text, () => {
        idx = (idx + 1) % lines.length;
        animate();
    });
}

// start after user interaction (required by many browsers)
document.body.addEventListener('click', function init() {
    document.body.removeEventListener('click', init);
    animate();
});
</script>
</body></html>`)
	return buf.String()
}

func main() {
	rand.Seed(time.Now().UnixNano())
	const lineCount = 5
	lines := make([]lineInfo, lineCount)
	for i := 0; i < lineCount; i++ {
		lines[i] = makeLine()
	}
	html := buildHTML(lines)
	if err := os.WriteFile("poem.html", []byte(html), 0644); err != nil {
		fmt.Println("write error:", err)
	}
	fmt.Println("Generated poem.html – click anywhere to start the recitation.")
}