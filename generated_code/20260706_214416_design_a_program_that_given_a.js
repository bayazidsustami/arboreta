const fs = require('fs');

// ---------- Helper functions ----------
function intToBytes(num, bytes) {
    const arr = new Uint8Array(bytes);
    for (let i = 0; i < bytes; i++) {
        arr[bytes - 1 - i] = num & 0xFF;
        num >>= 8;
    }
    return arr;
}
function writeVarLen(value) {
    const buffer = [];
    let val = value & 0x0FFFFFFF;
    let bytes = [val & 0x7F];
    while ((val >>= 7)) bytes.unshift((val & 0x7F) | 0x80);
    return Uint8Array.from(bytes);
}
function temperatureToPitch(t) {
    // map -10..35 -> 40..80
    const minT = -10, maxT = 35, minP = 40, maxP = 80;
    return Math.round(((t - minT) / (maxT - minT)) * (maxP - minP) + minP);
}
function monthToProgram(month) {
    // simple mapping month (0‑11) to instrument program (0‑127)
    return (month * 10) % 128;
}
function encodeMetadata(tempData) {
    const json = JSON.stringify(tempData);
    // simple reversible Caesar cipher (+1 char code)
    let enc = '';
    for (let i = 0; i < json.length; i++) enc += String.fromCharCode(json.charCodeAt(i) + 1);
    return enc;
}

// ---------- Generate synthetic temperature map ----------
function generateYearTemps(year) {
    const days = (new Date(year, 11, 31) - new Date(year, 0, 0)) / 86400000;
    const temps = [];
    for (let d = 0; d < days; d++) {
        // random daily average temperature
        const avg = -10 + Math.random() * 45;
        temps.push(avg);
    }
    return temps;
}

// ---------- Build MIDI ----------
function buildMidi(year, temps) {
    const header = new Uint8Array([
        ...[0x4d,0x54,0x68,0x64],               // "MThd"
        ...intToBytes(6,4),                    // header length
        0x00,0x01,                             // format 1
        0x00,0x02,                             // 2 tracks
        0x00,0x60                              // division 96 ticks per quarter
    ]);

    // ----- Track 0 : meta data (tempo, text) -----
    const tempo = 120; // BPM
    const microsecondsPerQuarter = Math.round(60000000 / tempo);
    const metaEvents = [
        Uint8Array.from([0x00,0xFF,0x51,0x03,...intToBytes(microsecondsPerQuarter,3)]), // Set tempo
        Uint8Array.from([0x00,0xFF,0x01,...Uint8Array.from(encodeMetadata(temps),c=>c.charCodeAt(0))]) // Text meta
    ];
    const track0Data = Uint8Array.from(metaEvents.reduce((a,b)=>a.concat(Array.from(b)),[]));
    const track0 = new Uint8Array([
        ...[0x4d,0x54,0x72,0x6b],
        ...intToBytes(track0Data.length,4),
        ...track0Data,
        0x00,0xFF,0x2F,0x00 // End of track
    ]);

    // ----- Track 1 : notes -----
    const events = [];
    const ticksPerMinute = 96; // quarter note = 96 ticks, we give each minute a quarter note
    const minutesPerDay = 24*60;
    const totalDays = temps.length;

    for (let day = 0; day < totalDays; day++) {
        const month = new Date(year,0,1+day).getMonth();
        const program = monthToProgram(month);
        // Program change at start of each day
        events.push(Uint8Array.from([0x00,0xC0,program]));
        for (let m = 0; m < minutesPerDay; m++) {
            const pitch = temperatureToPitch(temps[day]);
            const velocity = 80;
            const delta = writeVarLen(ticksPerMinute);
            // Note On
            events.push(Uint8Array.from([...delta,0x90,pitch,velocity]));
            // Note Off after half beat
            const offDelta = writeVarLen(Math.round(ticksPerMinute/2));
            events.push(Uint8Array.from([...offDelta,0x80,pitch,0x40]));
        }
    }
    // End of track
    events.push(Uint8Array.from([0x00,0xFF,0x2F,0x00]));

    const track1Data = Uint8Array.from(events.reduce((a,b)=>a.concat(Array.from(b)),[]));
    const track1 = new Uint8Array([
        ...[0x4d,0x54,0x72,0x6b],
        ...intToBytes(track1Data.length,4),
        ...track1Data
    ]);

    // Concatenate all
    return Uint8Array.from([...header, ...track0, ...track1]);
}

// ---------- Main ----------
const year = process.argv[2] ? parseInt(process.argv[2]) : new Date().getFullYear();
const temps = generateYearTemps(year);
const midi = buildMidi(year, temps);
fs.writeFileSync(`year_${year}_score.mid`, Buffer.from(midi));
console.log(`MIDI file written: year_${year}_score.mid`);