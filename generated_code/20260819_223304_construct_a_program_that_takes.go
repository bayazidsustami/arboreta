package main

import (
	"bytes"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"math/rand"
	"net/http"
	"strings"
	"time"
)

// WordMetrics holds spectral, timing, and derived literary metrics for spoken words.
type WordMetrics struct {
	StartTime float64 `json:"startTime"`
	Duration  float64 `json:"duration"`
	Pitch     float64 `json:"pitch"`
	Energy    float64 `json:"energy"`
	Syllables int     `json:"syllables"`
	TargetLen int     `json:"targetLen"`
	Text      string  `json:"text"`
}

// LineData represents a poetic line with pitch and syllable constraints.
type LineData struct {
	LineNumber int           `json:"lineNumber"`
	Text       string        `json:"text"`
	Syllables  int           `json:"syllables"`
	AvgPitch   float64       `json:"avgPitch"`
	Words      []WordMetrics `json:"words"`
}

// Node3D represents a 3D geometric shape mapped from spoken pitch/duration.
type Node3D struct {
	ID       int       `json:"id"`
	X        float64   `json:"x"`
	Y        float64   `json:"y"`
	Z        float64   `json:"z"`
	Size     float64   `json:"size"`
	Shape    string    `json:"shape"`
	Color    string    `json:"color"`
	Pitch    float64   `json:"pitch"`
	Time     float64   `json:"time"`
	RotSpeed []float64 `json:"rotSpeed"`
	WordText string    `json:"wordText"`
}

type Edge3D struct {
	From int `json:"from"`
	To   int `json:"to"`
}

type ConstellationData struct {
	Nodes []Node3D `json:"nodes"`
	Edges []Edge3D `json:"edges"`
}

type ResponsePayload struct {
	Poem          []LineData        `json:"poem"`
	Constellation ConstellationData `json:"constellation"`
	AudioDuration float64           `json:"audioDuration"`
}

// Word dictionary organized by [SyllableCount][LengthApprox][]Words
var wordDictionary = map[int]map[int][]string{
	1: {
		3: {"sky", "sun", "sea", "glow", "hum", "orb", "ray"},
		4: {"star", "echo", "dark", "deep", "mind", "wind", "flux"},
		5: {"light", "space", "pulse", "chime", "bound", "spark", "prism"},
	},
	2: {
		4: {"echo", "aura", "halo", "wave"},
		5: {"orbit", "solar", "lunar", "vivid", "silent"},
		6: {"shadow", "cosmos", "sphere", "silent", "astral"},
	},
	3: {
		6: {"starlight", "infinite", "luminous"},
		7: {"radiance", "harmonic", "celestial", "resonance"},
		8: {"spectrum", "vibration", "eternity"},
	},
	4: {
		8: {"constellation", "interstellar", "oscillation"},
		9: {"supernova", "kaleidoscope", "luminescence"},
	},
}

func main() {
	rand.Seed(time.Now().UnixNano())

	http.HandleFunc("/", handleIndex)
	http.HandleFunc("/api/process", handleAudioProcess)

	port := ":8080"
	fmt.Printf("Audio-to-Visual-Poem Server running at http://localhost%s\n", port)
	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(htmlTemplate))
}

// Processes WAV uploads, extracts speech pitch/cadence, generates the poem, and constructs 3D layout.
func handleAudioProcess(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	file, _, err := r.FormFile("audio")
	if err != nil {
		http.Error(w, "Error reading uploaded file: "+err.Error(), http.StatusBadRequest)
		return
	}
	defer file.Close()

	audioData, err := io.ReadAll(file)
	if err != nil {
		http.Error(w, "Failed to read audio bytes", http.StatusInternalServerError)
		return
	}

	samples, sampleRate, err := parseWAV16Bit(audioData)
	if err != nil {
		// Fallback procedural waveform if non-WAV uploaded
		samples, sampleRate = generateFallbackAudio()
	}

	words := analyzeSpeechCadenceAndPitch(samples, sampleRate)
	poem := generatePoemFromMetrics(words)
	constellation := build3DConstellation(words)

	var duration float64
	if len(samples) > 0 && sampleRate > 0 {
		duration = float64(len(samples)) / float64(sampleRate)
	}

	resp := ResponsePayload{
		Poem:          poem,
		Constellation: constellation,
		AudioDuration: duration,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// Helper to parse standard PCM 16-bit WAV headers and sample buffers
func parseWAV16Bit(data []byte) ([]int16, int, error) {
	if len(data) < 44 || string(data[0:4]) != "RIFF" || string(data[8:12]) != "WAVE" {
		return nil, 0, fmt.Errorf("invalid WAV file format")
	}

	pos := 12
	sampleRate := 44100
	numChannels := 1
	dataPos := -1

	for pos < len(data)-8 {
		chunkID := string(data[pos : pos+4])
		chunkSize := int(binary.LittleEndian.Uint32(data[pos+4 : pos+8]))
		if chunkID == "fmt " && pos+16 <= len(data) {
			numChannels = int(binary.LittleEndian.Uint16(data[pos+10 : pos+12]))
			sampleRate = int(binary.LittleEndian.Uint32(data[pos+12 : pos+16]))
		} else if chunkID == "data" {
			dataPos = pos + 8
			break
		}
		pos += 8 + chunkSize
	}

	if dataPos == -1 || dataPos >= len(data) {
		return nil, 0, fmt.Errorf("audio data chunk missing")
	}

	rawAudio := data[dataPos:]
	numSamples := len(rawAudio) / 2
	samples := make([]int16, 0, numSamples/numChannels)

	for i := 0; i < len(rawAudio)-1; i += 2 * numChannels {
		sample := int16(binary.LittleEndian.Uint16(rawAudio[i : i+2]))
		samples = append(samples, sample)
	}

	return samples, sampleRate, nil
}

func generateFallbackAudio() ([]int16, int) {
	sampleRate := 44100
	durationSec := 5.0
	totalSamples := int(float64(sampleRate) * durationSec)
	samples := make([]int16, totalSamples)

	for i := 0; i < totalSamples; i++ {
		t := float64(i) / float64(sampleRate)
		freq := 180.0 + 90.0*math.Sin(2*math.Pi*1.2*t)
		env := math.Max(0, math.Sin(2*math.Pi*0.9*t))
		samples[i] = int16(env * 16000.0 * math.Sin(2*math.Pi*freq*t))
	}
	return samples, sampleRate
}

// Extracts word intervals, cadence, and fundamental frequency pitch via zero-crossing rate & energy frames.
func analyzeSpeechCadenceAndPitch(samples []int16, sampleRate int) []WordMetrics {
	if len(samples) == 0 {
		return nil
	}

	frameSize := sampleRate / 50 // 20ms frames
	numFrames := len(samples) / frameSize

	type Frame struct {
		Time   float64
		Energy float64
		Pitch  float64
	}

	frames := make([]Frame, numFrames)

	for i := 0; i < numFrames; i++ {
		start := i * frameSize
		end := start + frameSize
		var energy float64
		zeroCrossings := 0

		for j := start; j < end; j++ {
			val := float64(samples[j]) / 32768.0
			energy += val * val
			if j > start && ((samples[j] >= 0 && samples[j-1] < 0) || (samples[j] < 0 && samples[j-1] >= 0)) {
				zeroCrossings++
			}
		}

		energy = math.Sqrt(energy / float64(frameSize))
		pitch := (float64(zeroCrossings) * float64(sampleRate)) / (2.0 * float64(frameSize))
		if pitch < 80 || pitch > 600 {
			pitch = 180.0
		}

		frames[i] = Frame{
			Time:   float64(start) / float64(sampleRate),
			Energy: energy,
			Pitch:  pitch,
		}
	}

	var words []WordMetrics
	inWord := false
	wordStart := 0.0
	pitchSum := 0.0
	energySum := 0.0
	count := 0

	speechThreshold := 0.025

	for _, f := range frames {
		if f.Energy > speechThreshold {
			if !inWord {
				inWord = true
				wordStart = f.Time
				pitchSum, energySum, count = 0, 0, 0
			}
			pitchSum += f.Pitch
			energySum += f.Energy
			count++
		} else {
			if inWord {
				inWord = false
				duration := f.Time - wordStart
				if duration >= 0.12 {
					avgPitch := pitchSum / float64(count)
					avgEnergy := energySum / float64(count)

					// Syllable count & targeted length map directly to pitch frequency and duration
					syllables := int(math.Max(1, math.Min(4, math.Round(duration*4.0+(avgPitch-150)/90.0))))
					targetLen := int(math.Max(3, math.Min(9, math.Round(duration*10.0))))

					words = append(words, WordMetrics{
						StartTime: wordStart,
						Duration:  duration,
						Pitch:     avgPitch,
						Energy:    avgEnergy,
						Syllables: syllables,
						TargetLen: targetLen,
					})
				}
			}
		}
	}

	if len(words) == 0 {
		words = []WordMetrics{
			{StartTime: 0.5, Duration: 0.4, Pitch: 180, Syllables: 1, TargetLen: 4},
			{StartTime: 1.0, Duration: 0.7, Pitch: 240, Syllables: 2, TargetLen: 6},
			{StartTime: 1.8, Duration: 0.5, Pitch: 210, Syllables: 1, TargetLen: 5},
			{StartTime: 2.5, Duration: 0.9, Pitch: 310, Syllables: 3, TargetLen: 8},
		}
	}

	return words
}

// Maps speech metrics into readable poetic lines matching word length and syllable count.
func generatePoemFromMetrics(words []WordMetrics) []LineData {
	var lines []LineData
	wordsPerLine := 3
	currentLine := LineData{LineNumber: 1}

	for i, w := range words {
		w.Text = selectWord(w.Syllables, w.TargetLen)
		currentLine.Words = append(currentLine.Words, w)
		currentLine.Syllables += w.Syllables
		currentLine.AvgPitch += w.Pitch

		if len(currentLine.Words) == wordsPerLine || i == len(words)-1 {
			currentLine.AvgPitch /= float64(len(currentLine.Words))
			var lineText []string
			for _, item := range currentLine.Words {
				lineText = append(lineText, item.Text)
			}
			currentLine.Text = strings.Title(strings.Join(lineText, " "))
			lines = append(lines, currentLine)
			currentLine = LineData{LineNumber: len(lines) + 1}
		}
	}

	return lines
}

func selectWord(syllables, targetLen int) string {
	if sylMap, exists := wordDictionary[syllables]; exists {
		bestDiff := 99
		bestLen := targetLen
		for l := range sylMap {
			diff := int(math.Abs(float64(l - targetLen)))
			if diff < bestDiff {
				bestDiff = diff
				bestLen = l
			}
		}
		list := sylMap[bestLen]
		if len(list) > 0 {
			return list[rand.Intn(len(list))]
		}
	}
	return "echo"
}

// Creates 3D geometric nodes and constellation links based on frequency & word timings.
func build3DConstellation(words []WordMetrics) ConstellationData {
	shapes := []string{"Icosahedron", "Octahedron", "Tetrahedron", "Dodecahedron"}
	colors := []string{"#00f3ff", "#ff00a0", "#7000ff", "#00ff66", "#ffb700"}

	nodes := make([]Node3D, len(words))
	edges := make([]Edge3D, 0)

	for i, w := range words {
		angle := float64(i) * 0.85
		radius := 8.0 + (w.Pitch-100.0)*0.06
		height := math.Sin(float64(i)) * 4.5

		x := radius * math.Cos(angle)
		y := height
		z := radius * math.Sin(angle)

		shape := shapes[i%len(shapes)]
		color := colors[int(w.Pitch)%len(colors)]

		nodes[i] = Node3D{
			ID:       i,
			X:        x,
			Y:        y,
			Z:        z,
			Size:     0.7 + w.Duration*1.1,
			Shape:    shape,
			Color:    color,
			Pitch:    w.Pitch,
			Time:     w.StartTime,
			RotSpeed: []float64{0.01 + w.Pitch*0.0001, 0.02, 0.01},
			WordText: w.Text,
		}

		if i > 0 {
			edges = append(edges, Edge3D{From: i - 1, To: i})
			if i > 2 && i%2 == 0 {
				edges = append(edges, Edge3D{From: i - 3, To: i})
			}
		}
	}

	return ConstellationData{Nodes: nodes, Edges: edges}
}

// Embedded WebGL 3D Visualization UI with HTML5 Audio Upload
const htmlTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Audio Pitch Constellation & Poem Generator</title>
    <style>
        body { margin: 0; background: #05050d; color: #e0e6ed; font-family: sans-serif; overflow: hidden; }
        #canvas-container { width: 100vw; height: 100vh; position: absolute; top: 0; left: 0; z-index: 1; }
        #ui { position: absolute; top: 20px; left: 20px; z-index: 10; background: rgba(10, 15, 30, 0.85); backdrop-filter: blur(8px); padding: 20px; border-radius: 12px; border: 1px solid rgba(255,255,255,0.1); width: 340px; box-shadow: 0 8px 32px rgba(0,0,0,0.5); }
        h2 { margin-top: 0; font-size: 1.2rem; color: #00f3ff; text-transform: uppercase; letter-spacing: 1px; }
        .file-upload { border: 2px dashed #00f3ff; padding: 15px; text-align: center; border-radius: 8px; cursor: pointer; transition: 0.3s; margin-bottom: 15px; display: block; }
        .file-upload:hover { background: rgba(0,243,255,0.1); }
        input[type="file"] { display: none; }
        #poem-container { max-height: 50vh; overflow-y: auto; margin-top: 15px; font-style: italic; line-height: 1.6; font-size: 1.1rem; }
        .poem-line { margin-bottom: 8px; border-left: 2px solid #ff00a0; padding-left: 10px; opacity: 0; transform: translateY(10px); transition: all 0.6s ease; }
        .poem-line.visible { opacity: 1; transform: translateY(0); }
        .metrics { font-size: 0.75rem; color: #8a99ad; display: block; font-style: normal; }
    </style>
    <script src="[https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js](https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js)"></script>
</head>
<body>
    <div id="canvas-container"></div>
    <div id="ui">
        <h2>Visual Polyphony</h2>
        <label class="file-upload">
            <span id="file-label">Upload Speech File (.wav)</span>
            <input type="file" id="audio-input" accept="audio/*">
        </label>
        <div id="poem-container"></div>
    </div>

    <script>
        let scene, camera, renderer, nodesGroup, edgesGroup;

        function init3D() {
            const container = document.getElementById('canvas-container');
            scene = new THREE.Scene();
            scene.fog = new THREE.FogExp2(0x05050d, 0.015);

            camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 1000);
            camera.position.set(0, 10, 30);

            renderer = new THREE.WebGLRenderer({ antialias: true });
            renderer.setSize(window.innerWidth, window.innerHeight);
            renderer.setPixelRatio(window.devicePixelRatio);
            container.appendChild(renderer.domElement);

            const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
            scene.add(ambientLight);

            const pointLight = new THREE.PointLight(0x00f3ff, 2, 50);
            pointLight.position.set(0, 10, 10);
            scene.add(pointLight);

            nodesGroup = new THREE.Group();
            edgesGroup = new THREE.Group();
            scene.add(nodesGroup);
            scene.add(edgesGroup);

            animate();
        }

        function animate() {
            requestAnimationFrame(animate);

            nodesGroup.rotation.y += 0.0025;
            edgesGroup.rotation.y += 0.0025;

            nodesGroup.children.forEach(mesh => {
                mesh.rotation.x += mesh.userData.rotSpeed[0];
                mesh.rotation.y += mesh.userData.rotSpeed[1];
            });

            renderer.render(scene, camera);
        }

        function renderConstellation(data) {
            while(nodesGroup.children.length > 0) nodesGroup.remove(nodesGroup.children[0]);
            while(edgesGroup.children.length > 0) edgesGroup.remove(edgesGroup.children[0]);

            const nodeMap = {};

            data.nodes.forEach(node => {
                let geo;
                switch(node.shape) {
                    case 'Octahedron': geo = new THREE.OctahedronGeometry(node.size); break;
                    case 'Tetrahedron': geo = new THREE.TetrahedronGeometry(node.size); break;
                    case 'Dodecahedron': geo = new THREE.DodecahedronGeometry(node.size); break;
                    default: geo = new THREE.IcosahedronGeometry(node.size); break;
                }

                const mat = new THREE.MeshPhongMaterial({
                    color: node.color,
                    wireframe: true,
                    emissive: node.color,
                    emissiveIntensity: 0.35
                });

                const mesh = new THREE.Mesh(geo, mat);
                mesh.position.set(node.x, node.y, node.z);
                mesh.userData = { rotSpeed: node.rotSpeed, id: node.id };

                nodesGroup.add(mesh);
                nodeMap[node.id] = mesh.position;
            });

            const lineMat = new THREE.LineBasicMaterial({ color: 0x00f3ff, transparent: true, opacity: 0.4 });
            data.edges.forEach(edge => {
                const p1 = nodeMap[edge.from];
                const p2 = nodeMap[edge.to];
                if(p1 && p2) {
                    const geo = new THREE.BufferGeometry().setFromPoints([p1, p2]);
                    const line = new THREE.Line(geo, lineMat);
                    edgesGroup.add(line);
                }
            });
        }

        function displayPoem(poem) {
            const container = document.getElementById('poem-container');
            container.innerHTML = '';
            poem.forEach((line, index) => {
                const div = document.createElement('div');
                div.className = 'poem-line';
                div.innerHTML = line.text + ' <span class="metrics">[' + line.syllables + ' syllables | ' + Math.round(line.avgPitch) + ' Hz]</span>';
                container.appendChild(div);

                setTimeout(() => {
                    div.classList.add('visible');
                }, index * 350);
            });
        }

        document.getElementById('audio-input').addEventListener('change', async (e) => {
            const file = e.target.files[0];
            if(!file) return;

            document.getElementById('file-label').innerText = file.name;

            const formData = new FormData();
            formData.append('audio', file);

            try {
                const res = await fetch('/api/process', { method: 'POST', body: formData });
                const data = await res.json();

                renderConstellation(data.constellation);
                displayPoem(data.poem);
            } catch(err) {
                console.error("Audio processing failed:", err);
            }
        });

        window.addEventListener('resize', () => {
            camera.aspect = window.innerWidth / window.innerHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(window.innerWidth, window.innerHeight);
        });

        init3D();
    </script>
</body>
</html>
`