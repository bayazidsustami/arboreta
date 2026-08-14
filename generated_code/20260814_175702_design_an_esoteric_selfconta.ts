import { createServer, IncomingMessage, ServerResponse } from 'http';

/**
 * Esoteric Cellular Automaton: Weather Tapestry & Generative Ambient Audio
 * 
 * Features:
 * - Pure Node.js implementation (zero external dependencies).
 * - Real-time ASCII cellular automaton engine mapped to weather metrics (Temp, Humidity, Wind).
 * - Algorithmic WAV audio synthesizer streaming ambient drone & arpeggios based on automaton states.
 * - Live HTTP Dashboard serving the ASCII terminal tapestry and streaming audio sync.
 */

// --- Types & Data Models ---
interface WeatherState {
  temperature: number; // -10 to 40 (°C) -> Dictates CA Rule / Speed
  humidity: number;    // 0 to 100 (%)    -> Dictates Symbol Density / Reverb tail
  windSpeed: number;   // 0 to 50 (km/h)  -> Dictates Horizontal Drift / Pitch Perturbation
  description: string;
}

// --- Dynamic Simulated Weather Provider ---
function fetchLiveWeather(): WeatherState {
  const time = Date.now() / 10000;
  const temp = Math.sin(time * 0.5) * 20 + 15;
  const humidity = Math.floor((Math.cos(time * 0.3) + 1) * 45 + 10);
  const wind = Math.floor((Math.sin(time * 0.8) + 1) * 20 + 2);
  
  let desc = 'Clear';
  if (humidity > 75) desc = 'Rain';
  else if (temp < 0) desc = 'Snow';
  else if (wind > 25) desc = 'Gale';

  return { temperature: temp, humidity, windSpeed: wind, description: desc };
}

// --- Esoteric Cellular Automaton (Grid Tapestry Engine) ---
class WeatherAutomaton {
  public width: number;
  public height: number;
  public grid: number[][];
  
  // ASCII Palette mapped to cell energy
  private palette = [' ', '.', '·', ':', '¬', '≈', '≡', '▒', '▓', '█', '✦', '✺'];

  constructor(width = 64, height = 32) {
    this.width = width;
    this.height = height;
    this.grid = Array.from({ length: height }, () => 
      Array.from({ length: width }, () => Math.random() > 0.7 ? Math.floor(Math.random() * 5) : 0)
    );
  }

  public step(weather: WeatherState): void {
    const nextGrid = this.grid.map(row => [...row]);
    const ruleShift = Math.floor(Math.abs(weather.temperature) % 4);
    const windShift = weather.windSpeed > 15 ? (Math.random() > 0.5 ? 1 : -1) : 0;

    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        // Compute 8-neighbor state sum
        let neighbors = 0;
        for (let dy = -1; dy <= 1; dy++) {
          for (let dx = -1; dx <= 1; dx++) {
            if (dx === 0 && dy === 0) continue;
            const nx = (x + dx + windShift + this.width) % this.width;
            const ny = (y + dy + this.height) % this.height;
            neighbors += this.grid[ny][nx] > 0 ? 1 : 0;
          }
        }

        const current = this.grid[y][x];
        // Dynamic state transition based on humidity and temperature
        const spawnChance = weather.humidity / 200;

        if (current > 0) {
          if (neighbors < 2 || neighbors > (3 + ruleShift)) {
            nextGrid[y][x] = Math.max(0, current - 1); // Decay
          } else {
            nextGrid[y][x] = Math.min(this.palette.length - 1, current + 1); // Flourish
          }
        } else {
          if (neighbors === 3 || Math.random() < spawnChance) {
            nextGrid[y][x] = 1; // Birth
          }
        }
      }
    }
    this.grid = nextGrid;
  }

  public render(): string {
    return this.grid
      .map(row => row.map(val => this.palette[val % this.palette.length]).join(''))
      .join('\n');
  }

  public getEnergyDensity(): number {
    let total = 0;
    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        total += this.grid[y][x];
      }
    }
    return total / (this.width * this.height * (this.palette.length - 1));
  }
}

// --- Algorithmic Audio Synthesizer (Generates Live PCM Audio Stream) ---
class GenerativeSynthesizer {
  private sampleRate = 22050;
  private phase1 = 0;
  private phase2 = 0;
  private arpIndex = 0;
  
  // Pentatonic scale (Hz)
  private scale = [130.81, 146.83, 164.81, 196.00, 220.00, 261.63, 293.66, 329.63, 392.00, 440.00];

  public generateChunk(samples: number, automatonEnergy: number, weather: WeatherState): Buffer {
    const buffer = Buffer.alloc(samples * 2); // 16-bit mono PCM
    
    // Choose base scale frequency dictated by temperature
    const basePitch = this.scale[Math.floor(Math.abs(weather.temperature)) % this.scale.length];
    const modulationFreq = 0.2 + (weather.windSpeed / 50) * 5;

    for (let i = 0; i < samples; i++) {
      // Harmonic Drone Synthesizer
      this.phase1 += (basePitch / this.sampleRate) * (1 + 0.05 * Math.sin(2 * Math.PI * modulationFreq * (i / this.sampleRate)));
      const sineWave = Math.sin(2 * Math.PI * this.phase1);
      
      // CA Energy Arpeggiator
      if (i % 2000 === 0) {
        this.arpIndex = (this.arpIndex + 1) % this.scale.length;
      }
      const arpPitch = this.scale[(this.arpIndex + Math.floor(automatonEnergy * 10)) % this.scale.length];
      this.phase2 += arpPitch / this.sampleRate;
      const squareWave = (Math.sin(2 * Math.PI * this.phase2) > 0 ? 0.3 : -0.3) * automatonEnergy;

      // Combine & scale amplitude
      let sample = (sineWave * 0.4 + squareWave * 0.3) * 32767;
      
      // Soft Clipping
      sample = Math.max(-32767, Math.min(32767, sample));
      
      buffer.writeInt16LE(Math.floor(sample), i * 2);
    }
    return buffer;
  }

  public getWavHeader(dataByteLength: number): Buffer {
    const header = Buffer.alloc(44);
    header.write('RIFF', 0);
    header.writeUInt32LE(36 + dataByteLength, 4);
    header.write('WAVE', 8);
    header.write('fmt ', 12);
    header.writeUInt32LE(16, 16); // Subchunk1Size (PCM)
    header.writeUInt16LE(1, 20);  // AudioFormat (1 = PCM)
    header.writeUInt16LE(1, 22);  // NumChannels (1 = Mono)
    header.writeUInt32LE(this.sampleRate, 24);
    header.writeUInt32LE(this.sampleRate * 2, 28); // ByteRate
    header.writeUInt16LE(2, 32);  // BlockAlign
    header.writeUInt16LE(16, 34); // BitsPerSample
    header.write('data', 36);
    header.writeUInt32LE(dataByteLength, 40);
    return header;
  }
}

// --- Application Runtime & Server Setup ---
const ca = new WeatherAutomaton(70, 25);
const synth = new GenerativeSynthesizer();
const PORT = 3000;

const server = createServer((req: IncomingMessage, res: ServerResponse) => {
  if (req.url === '/audio') {
    // Infinite Audio Stream Setup
    res.writeHead(200, {
      'Content-Type': 'audio/wav',
      'Transfer-Encoding': 'chunked',
    });

    // Write indefinite WAV Header
    res.write(synth.getWavHeader(0xFFFFFFFF));

    const audioInterval = setInterval(() => {
      const weather = fetchLiveWeather();
      const chunk = synth.generateChunk(2048, ca.getEnergyDensity(), weather);
      if (!res.writableEnded) {
        res.write(chunk);
      } else {
        clearInterval(audioInterval);
      }
    }, 100);

    req.on('close', () => clearInterval(audioInterval));
    return;
  }

  // Live HTTP ASCII Tapestry UI
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>Weather Automaton Tapestry</title>
        <style>
          body { background: #050508; color: #7af; font-family: monospace; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; }
          #tapestry { white-space: pre; background: #0a0a10; padding: 20px; border-radius: 8px; box-shadow: 0 0 20px rgba(0,255,200,0.1); border: 1px solid #1a2a3a; font-size: 14px; line-height: 1.1; }
          #stats { margin-top: 15px; color: #88a; text-align: center; }
          button { background: #1a2a3a; color: #7af; border: 1px solid #7af; padding: 10px 20px; cursor: pointer; font-family: monospace; border-radius: 4px; margin-top: 15px; }
          button:hover { background: #7af; color: #050508; }
        </style>
      </head>
      <body>
        <div id="tapestry">Initializing tapestry...</div>
        <div id="stats">Connecting to weather automaton stream...</div>
        <button onclick="playAudio()">🔊 Toggle Ambient Audio Stream</button>

        <script>
          let audio = null;
          function playAudio() {
            if (!audio) {
              audio = new Audio('/audio');
              audio.play();
            } else {
              audio.paused ? audio.play() : audio.pause();
            }
          }

          async function update() {
            const res = await fetch('/data');
            const data = await res.json();
            document.getElementById('tapestry').innerText = data.tapestry;
            document.getElementById('stats').innerText = 
              \`Weather: \${data.weather.description} | Temp: \${data.weather.temperature.toFixed(1)}°C | Humidity: \${data.weather.humidity}% | Wind: \${data.weather.windSpeed} km/h\`;
          }
          setInterval(update, 200);
        </script>
      </body>
    </html>
  `);
});

// JSON API Route for UI Updates
server.on('request', (req, res) => {
  if (req.url === '/data') {
    const weather = fetchLiveWeather();
    ca.step(weather);
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      tapestry: ca.render(),
      weather
    }));
  }
});

// Terminal Output loop
setInterval(() => {
  const weather = fetchLiveWeather();
  ca.step(weather);
  console.clear();
  console.log('\x1b[36m%s\x1b[0m', '=== Weather Tapestry Esoteric Cellular Automaton ===');
  console.log('\x1b[33m%s\x1b[0m', ca.render());
  console.log(`\x1b[90mCondition: ${weather.description} | Temp: ${weather.temperature.toFixed(1)}°C | Wind: ${weather.windSpeed} km/h | Audio HTTP: http://localhost:${PORT}\x1b[0m`);
}, 250);

server.listen(PORT, () => {
  console.log(`Esoteric Engine active at http://localhost:${PORT}`);
});