const CANVAS_WIDTH = 80;
const CANVAS_HEIGHT = 35;
const SAMPLE_RATE = 44100;

// Initialize Web Audio Context
const AudioCtx = window.AudioContext || window.webkitAudioContext;
const audioCtx = new AudioCtx();

// Algorithmic 8-bit Synthesizer & Audio Processor
let masterGain, analyser, dataArray;

function initAudio() {
    masterGain = audioCtx.createGain();
    masterGain.gain.setValueAtTime(0.15, audioCtx.currentTime);
    masterGain.connect(audioCtx.destination);

    analyser = audioCtx.createAnalyser();
    analyser.fftSize = 64;
    analyser.connect(masterGain);

    dataArray = new Uint8Array(analyser.frequencyBinCount);

    // Pentatonic scale frequencies for generative ambient chiptune soundscape
    const scale = [110, 130.81, 146.83, 164.81, 196.00, 220, 261.63, 293.66];
    
    function triggerNote() {
        if (audioCtx.state === 'suspended') return;
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        
        // 8-bit pulse/square wave
        osc.type = Math.random() > 0.5 ? 'square' : 'sawtooth';
        const freq = scale[Math.floor(Math.random() * scale.length)];
        osc.frequency.setValueAtTime(freq, audioCtx.currentTime);

        // Envelope generator
        gain.gain.setValueAtTime(0.01, audioCtx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.1, audioCtx.currentTime + 0.1);
        gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 1.5);

        osc.connect(gain);
        gain.connect(analyser);

        osc.start();
        osc.stop(audioCtx.currentTime + 1.6);

        setTimeout(triggerNote, 400 + Math.random() * 800);
    }

    triggerNote();
}

// Generate Synthetic Raw CPU Temp Logs & Memory Dumps
function generateSystemTelemetry(time) {
    // Simulated CPU Temps (35°C - 90°C) with sinusoidal load spikes
    const cpuTemp = 45 + Math.sin(time * 0.002) * 25 + Math.random() * 10;
    
    // Simulated Hexadecimal Memory Dump Page
    let memDump = '';
    for (let i = 0; i < 16; i++) {
        memDump += Math.floor((Math.sin(time * 0.001 + i) + 1) * 127)
            .toString(16)
            .padStart(2, '0');
    }
    return { cpuTemp, memDump };
}

// ASCII Tapestry Density Palette
const ASCII_PALETTE = [' ', '.', ':', '-', '=', '+', '*', '%', '@', '#', '█'];

// ASCII Rendering Loop
const display = document.createElement('pre');
display.style.cssText = `
    font-family: 'Courier New', monospace;
    font-size: 12px;
    line-height: 10px;
    background: #050508;
    color: #33ff66;
    padding: 15px;
    margin: 0;
    overflow: hidden;
    height: 100vh;
    box-sizing: border-box;
    text-shadow: 0 0 5px #33ff66;
`;
document.body.appendChild(display);
document.body.style.margin = '0';
document.body.style.background = '#050508';

let frame = 0;

function render() {
    frame++;
    const { cpuTemp, memDump } = generateSystemTelemetry(frame * 16);

    // Fetch Audio Spectrum Data
    let audioEnergy = 0;
    if (analyser) {
        analyser.getByteFrequencyData(dataArray);
        audioEnergy = dataArray.reduce((a, b) => a + b, 0) / dataArray.length;
    }

    let asciiFrame = '';
    const tempRatio = (cpuTemp - 35) / 55; // Normalized 0-1

    for (let y = 0; y < CANVAS_HEIGHT; y++) {
        for (let x = 0; x < CANVAS_WIDTH; x++) {
            // Generative noise pattern incorporating Memory Hex Values
            const hexChar = memDump.charCodeAt((x + y) % memDump.length);
            
            // Mathematical interference field modulated by audio & CPU temp
            const wave1 = Math.sin(x * 0.1 + frame * 0.05 + (audioEnergy * 0.02));
            const wave2 = Math.cos(y * 0.15 - frame * 0.03 + (tempRatio * 3.0));
            const pattern = (wave1 + wave2 + (hexChar / 255)) / 3; // Normalized -1 to 1 range

            // Select ASCII character based on field intensity and audio reactivity
            const index = Math.floor(
                Math.abs(pattern * ASCII_PALETTE.length + (audioEnergy * 0.05))
            ) % ASCII_PALETTE.length;

            asciiFrame += ASCII_PALETTE[index];
        }
        asciiFrame += '\n';
    }

    // Telemetry Status Bar Overlay
    asciiFrame += `\n[SYSTEM METRICS] CPU TEMP: ${cpuTemp.toFixed(1)}°C | MEM DUMP PAGE: 0x${memDump.substring(0, 8)}... | AUDIO AMPLITUDE: ${Math.floor(audioEnergy)}`;

    display.textContent = asciiFrame;

    // Shift color tint dynamically according to CPU Temperature
    const r = Math.floor(tempRatio * 255);
    const g = Math.floor((1 - tempRatio) * 255);
    display.style.color = `rgb(${r}, ${g}, 150)`;
    display.style.textShadow = `0 0 5px rgb(${r}, ${g}, 150)`;

    requestAnimationFrame(render);
}

// User Interaction Trigger to Unlock Audio Context
window.addEventListener('click', () => {
    if (audioCtx.state === 'suspended') {
        audioCtx.resume();
        initAudio();
    }
}, { once: true });

// Start Visual Renderer
render();