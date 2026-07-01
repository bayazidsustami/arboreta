import Foundation

// Read all input text from stdin
let input = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""

// Simple deterministic mapping from character to frequency (A4 = 440Hz)
func frequency(for char: Character) -> Double {
    let scalar = char.unicodeScalars.first!.value
    // Map into a musical fifths circle (mod 12) and an octave range (2–4)
    let pitchClass = Int(scalar % 12)
    let octave = 2 + Int((scalar / 12) % 3)
    // Calculate frequency using equal temperament
    let a4 = 440.0
    let semitone = pitchClass - 9 // A is 9 steps above C
    return a4 * pow(2.0, Double(octave - 4) + Double(semitone) / 12.0)
}

// Build a JavaScript array of frequencies
let freqArray = input.map { frequency(for: $0) }
let jsFrequencies = freqArray.map { String(format: "%.3f", $0) }.joined(separator: ",")

// HTML/JS template
let html = """
<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'>
<title>Fractal Melody</title>
<style>
body {margin:0; overflow:hidden; background:#111;}
canvas {display:block;}
</style>
</head>
<body>
<canvas id='c'></canvas>
<script>
const freqs = [\(jsFrequencies)];
let ctx, width, height;
let audioCtx = new (window.AudioContext||window.webkitAudioContext)();
let masterGain = audioCtx.createGain();
masterGain.gain.value = 0.2;
masterGain.connect(audioCtx.destination);
let analyser = audioCtx.createAnalyser();
analyser.fftSize = 256;
masterGain.connect(analyser);
let dataArray = new Uint8Array(analyser.frequencyBinCount);
let oscIndex = 0, startTime = audioCtx.currentTime;

// Schedule notes sequentially
function scheduleNotes() {
    if (oscIndex >= freqs.length) return;
    let freq = freqs[oscIndex];
    let osc = audioCtx.createOscillator();
    osc.type = 'sine';
    osc.frequency.value = freq;
    osc.connect(masterGain);
    let dur = 0.3;
    osc.start(startTime);
    osc.stop(startTime + dur);
    startTime += dur;
    oscIndex++;
    setTimeout(scheduleNotes, dur*1000);
}
scheduleNotes();

// Canvas setup
function resize() {
    const canvas = document.getElementById('c');
    ctx = canvas.getContext('2d');
    width = canvas.width = window.innerWidth;
    height = canvas.height = window.innerHeight;
}
window.onresize = resize;
resize();

// Recursive fractal tree drawing
function drawTree(x, y, length, angle, depth) {
    if (depth === 0) return;
    const rad = angle * Math.PI/180;
    const x2 = x + Math.cos(rad)*length;
    const y2 = y + Math.sin(rad)*length;
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x2, y2);
    ctx.strokeStyle = `hsl(${(depth*30)%360},80%,60%)`;
    ctx.lineWidth = depth;
    ctx.stroke();
    const newLen = length * 0.7;
    drawTree(x2, y2, newLen, angle-30, depth-1);
    drawTree(x2, y2, newLen, angle+30, depth-1);
}

// Animation loop synced to frequency data
function animate() {
    requestAnimationFrame(animate);
    analyser.getByteFrequencyData(dataArray);
    const avg = dataArray.reduce((a,b)=>a+b)/dataArray.length;
    const scale = 0.5 + avg/255;
    ctx.clearRect(0,0,width,height);
    ctx.save();
    ctx.translate(width/2, height);
    ctx.scale(scale, scale);
    drawTree(0,0, height/4, -90, 9);
    ctx.restore();
}
animate();
</script>
</body>
</html>
"""

// Write the HTML to stdout
FileHandle.standardOutput.write(html.data(using: .utf8)!)