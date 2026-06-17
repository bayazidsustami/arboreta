// Self‑modifying musical palindrome – Node.js version
// Reads its own source, maps prime‑indexed characters to MIDI notes,
// "plays" them (console output), then rewrites itself with inverted pitches.

const fs = require('fs');
const path = require('path');

// ---------- Utility ----------
function isPrime(n) {
  if (n < 2) return false;
  for (let i = 2, r = Math.sqrt(n); i <= r; i++) if (n % i === 0) return false;
  return true;
}

// ---------- Configuration ----------
const FILE = __filename;                     // own source file
const DURATION_MS = 150;                     // note length (simulated)
const BASE_NOTE = 60;                        // middle C as reference
let direction = 1; // 1 = forward, -1 = inversion (will be toggled)

// ---------- Load & parse source ----------
let src = fs.readFileSync(FILE, 'utf8');
let primeChars = [];
for (let i = 0; i < src.length; i++) {
  if (isPrime(i)) primeChars.push(src[i]);
}

// ---------- Map chars to MIDI notes ----------
function charToMidi(ch, dir) {
  // simple deterministic mapping: char code modulo 12 + offset, then apply direction
  let note = (ch.charCodeAt(0) % 12) + BASE_NOTE;
  return dir === 1 ? note : 127 - note; // inversion around max MIDI note
}
let notes = primeChars.map(ch => charToMidi(ch, direction));

// ---------- "Play" the melody ----------
function play(notes) {
  // In a real environment we'd send MIDI or use Web Audio.
  // Here we simulate by printing timestamps.
  console.log('Playing melody (direction:', direction === 1 ? 'forward' : 'inversion', ')');
  notes.forEach((n, idx) => {
    setTimeout(() => console.log('Note', idx + 1, ': MIDI', n), idx * DURATION_MS);
  });
}
play(notes);

// ---------- Prepare next version ----------
function invertDirection(dir) { return dir === 1 ? -1 : 1; }

// Replace the direction constant in the source with the opposite value.
let newSrc = src.replace(/let direction = [\-]?1;/, `let direction = ${invertDirection(direction)};`);

// Write the modified source back to disk (overwrites current file).
fs.writeFileSync(FILE, newSrc, 'utf8');

// End of script.