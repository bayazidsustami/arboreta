import http from 'node.js:http'; // Node.js built-in HTTP module
import { Readable } from 'node.js:stream';

/**
 * Micro-service that converts real-time global seismic sensor feeds into an 
 * infinitely evolving, multi-track polyrhythmic ambient musical score rendered 
 * as dynamic, chunked HTTP response headers.
 */

// Scales and Notes mapping (Frequencies translated to pitch names)
const PITCHES = ['C2', 'Eb2', 'F2', 'G2', 'Bb2', 'C3', 'Eb3', 'F3', 'G3', 'Bb3', 'C4', 'Eb4', 'F4', 'G4', 'Bb4'];
const TRACK_DIVISORS = [3, 4, 5, 7]; // Polyrhythmic time-signature pulse dividers (3:4:5:7)

// Dynamic state derived from global seismic events
let seismicState = {
  magnitudeSum: 4.5,
  eventCount: 8,
  deepestDepth: 35.0,
  lastUpdated: Date.now()
};

// Poll real-time global USGS seismic feed every 30 seconds
async function updateSeismicData() {
  try {
    const res = await fetch('[https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson](https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson)');
    const data = await res.json();
    if (data.features && data.features.length > 0) {
      seismicState.eventCount = data.features.length;
      seismicState.magnitudeSum = data.features.reduce((acc, f) => acc + Math.max(0, f.properties.mag || 0), 0);
      seismicState.deepestDepth = Math.max(...data.features.map(f => f.geometry.coordinates[2] || 0));
      seismicState.lastUpdated = Date.now();
    }
  } catch (err) {
    // Fallback gently if network or feed is temporarily unreachable
  }
}
setInterval(updateSeismicData, 30000);
updateSeismicData();

// Algorithmic music generator based on current seismic metrics
function generateMusicalFrame(tick) {
  const avgMag = seismicState.magnitudeSum / (seismicState.eventCount || 1);
  const baseBpm = Math.min(180, Math.max(40, 60 + avgMag * 12));
  
  // Track 1: Sub-Bass (Rhythmic foundation governed by deep seismic activity)
  const track1Pulse = tick % TRACK_DIVISORS[0] === 0;
  const t1Note = PITCHES[Math.floor(seismicState.deepestDepth % 4)];
  
  // Track 2: Polyrhythmic Arp 1 (Governed by total magnitude activity)
  const track2Pulse = tick % TRACK_DIVISORS[1] === 0;
  const t2Note = PITCHES[4 + Math.floor((tick + seismicState.magnitudeSum) % 4)];
  
  // Track 3: Counterpoint Pulse (Governed by total event count)
  const track3Pulse = tick % TRACK_DIVISORS[2] === 0;
  const t3Note = PITCHES[8 + Math.floor((tick * 2 + seismicState.eventCount) % 4)];
  
  // Track 4: Ambient Atmosphere (Generative texture shift)
  const track4Pulse = tick % TRACK_DIVISORS[3] === 0;
  const t4Note = PITCHES[11 + Math.floor((tick + seismicState.deepestDepth) % 4)];

  return {
    bpm: baseBpm.toFixed(1),
    tick,
    polyRhythmRatio: TRACK_DIVISORS.join(':'),
    tracks: {
      'X-Track-1-SubBass': track1Pulse ? `NOTE=${t1Note}; VELOCITY=${Math.min(100, Math.floor(avgMag * 20))}; PAN=-0.5` : 'REST',
      'X-Track-2-RhythmArp': track2Pulse ? `NOTE=${t2Note}; VELOCITY=75; PAN=0.3` : 'REST',
      'X-Track-3-Counterpoint': track3Pulse ? `NOTE=${t3Note}; VELOCITY=65; PAN=-0.3` : 'REST',
      'X-Track-4-EtherealPad': track4Pulse ? `NOTE=${t4Note}; VELOCITY=50; PAN=0.8; REVERB=0.85` : 'REST'
    }
  };
}

// HTTP Server streaming live polyrhythmic score headers
const server = http.createServer((req, res) => {
  if (req.url === '/favicon.ico') {
    res.writeHead(404);
    return res.end();
  }

  // Use HTTP/1.1 Chunked Transfer Encoding to continuously send trailing headers
  res.writeHead(200, {
    'Content-Type': 'text/plain; charset=utf-8',
    'Transfer-Encoding': 'chunked',
    'X-Audio-Score': 'Seismic-Polyrhythmic-Ambient-v1',
    'X-Audio-Format': 'MIDI-Event-Stream-Headers',
    'Trailer': 'X-Score-Frame, X-BPM, X-Polyrhythm-Ratio, X-Track-1-SubBass, X-Track-2-RhythmArp, X-Track-3-Counterpoint, X-Track-4-EtherealPad'
  });

  res.write("=== SEISMIC POLYRHYTHMIC AMBIENT SCORE STREAM ===\n");
  res.write("Listening to global live seismic sensors...\n");
  res.write("Inspect incoming HTTP Trailers / Headers for real-time multi-track notes.\n\n");

  let tick = 0;

  // Stream infinite musical beats as dynamic HTTP trailing headers
  const interval = setInterval(() => {
    if (res.writableEnded || res.destroyed) {
      clearInterval(interval);
      return;
    }

    const frame = generateMusicalFrame(tick++);
    
    // Set response trailers for the current beat pulse
    try {
      res.addTrailers({
        'X-Score-Frame': frame.tick.toString(),
        'X-BPM': frame.bpm,
        'X-Polyrhythm-Ratio': frame.polyRhythmRatio,
        ...frame.tracks
      });

      // Stream text pulse visualization to keep stream alive
      const activeNotes = Object.entries(frame.tracks)
        .filter(([_, v]) => v !== 'REST')
        .map(([k, v]) => `${k.replace('X-Track-', '')}:${v.split(';')[0].replace('NOTE=', '')}`)
        .join(' | ');

      res.write(`[Tick ${String(frame.tick).padStart(5, '0')}] ${activeNotes || '~ ambient decay ~'}\n`);
    } catch (e) {
      clearInterval(interval);
    }
  }, 400); // Pulse speed (tick rate)

  req.on('close', () => clearInterval(interval));
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Seismic Polyrhythmic Music Service running on port ${PORT}`);
});