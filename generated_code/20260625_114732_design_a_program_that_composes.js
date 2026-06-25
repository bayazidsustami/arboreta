<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Living Poem Mandala</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/p5.js/1.9.0/p5.min.js"></script>
</head>
<body style="margin:0;overflow:hidden;background:#111;">
<script>
// ---------- CONFIG ----------
const CA_RULE = 30;               // 1‑D cellular automaton rule
const CA_WIDTH = 80;              // cells per row
const CA_HEIGHT = 120;            // rows to keep in history
const UPDATE_INTERVAL = 2000;     // ms between Twitter polls (simulated)

// ---------- STATE ----------
let caGrid = [];                  // 2‑D array of 0/1
let sentiment = { polarity: 0, volume: 0 }; // mock sentiment
let hashtags = [];                // current trending tags

// ---------- SETUP ----------
function setup() {
  createCanvas(windowWidth, windowHeight);
  angleMode(DEGREES);
  textAlign(CENTER, CENTER);
  initCA();
  // start “Twitter” polling (replace with real fetch in production)
  setInterval(pollTwitter, UPDATE_INTERVAL);
}

// ---------- INITIALIZE CELLULAR AUTOMATON ----------
function initCA() {
  // start with a single live cell in the middle
  let row = Array(CA_WIDTH).fill(0);
  row[Math.floor(CA_WIDTH / 2)] = 1;
  caGrid = [row];
}

// ---------- MAIN DRAW ----------
function draw() {
  background(10, 10, 20, 15); // trailing effect
  translate(width / 2, height / 2);
  const layers = 12;          // mandala repetitions
  const angleStep = 360 / layers;
  const radius = min(width, height) * 0.35;

  // map sentiment to visual parameters
  const baseHue = map(sentiment.polarity, -1, 1, 0, 360);
  const scaleFactor = map(sentiment.volume, 0, 100, 0.5, 2);
  const fontSize = map(sentiment.volume, 0, 100, 12, 32);

  // draw each layer
  for (let i = 0; i < layers; i++) {
    push();
    rotate(i * angleStep);
    drawCA(radius, baseHue, scaleFactor, fontSize);
    pop();
  }

  // overlay current hashtags as floating text
  drawHashtags();
}

// ---------- DRAW ONE LAYER OF THE AUTOMATON ----------
function drawCA(radius, hueBase, scaleF, fSize) {
  const cellSize = (radius * 2) / CA_WIDTH;
  push();
  translate(-radius, -radius);
  for (let y = 0; y < caGrid.length; y++) {
    const row = caGrid[y];
    for (let x = 0; x < row.length; x++) {
      if (row[x] === 1) {
        const hue = (hueBase + y * 2) % 360;
        fill(color(`hsla(${hue},80%,60%,0.7)`));
        noStroke();
        const sz = cellSize * scaleF;
        rect(x * cellSize, y * cellSize, sz, sz);
        // optional typographic flourish
        fill(255, 200);
        textSize(fSize);
        text('#', x * cellSize + sz / 2, y * cellSize + sz / 2);
      }
    }
  }
  pop();
}

// ---------- DRAW HASHTAGS ----------
function drawHashtags() {
  push();
  rotate(frameCount * 0.05); // slow spin
  fill(255, 180);
  textSize(18);
  const spaced = hashtags.map(t => `#${t}`).join('   ');
  text(spaced, 0, 0);
  pop();
}

// ---------- UPDATE AUTOMATON ----------
function nextCARow(prev) {
  const next = Array(CA_WIDTH).fill(0);
  for (let i = 0; i < CA_WIDTH; i++) {
    const left = prev[(i - 1 + CA_WIDTH) % CA_WIDTH];
    const center = prev[i];
    const right = prev[(i + 1) % CA_WIDTH];
    const pattern = (left << 2) | (center << 1) | right;
    next[i] = (CA_RULE >> pattern) & 1;
  }
  return next;
}

// ---------- POLL TWITTER (SIMULATED) ----------
function pollTwitter() {
  // *** Replace this stub with a real fetch to Twitter API ***
  // Simulate trending hashtags and sentiment analysis
  const mockTags = ['joy', 'rain', 'storm', 'love', 'code', 'art', 'music'];
  hashtags = Array.from({length: 5}, () =>
    mockTags[int(random(mockTags.length))]
  );
  // Random polarity [-1,1] and volume [0,100]
  sentiment.polarity = random(-1, 1);
  sentiment.volume = random(0, 100);

  // Advance CA using a row derived from sentiment volume
  const lastRow = caGrid[caGrid.length - 1];
  const newRow = nextCARow(lastRow);
  caGrid.push(newRow);
  if (caGrid.length > CA_HEIGHT) caGrid.shift();
}

// ---------- RESPONSIVE ----------
function windowResized() {
  resizeCanvas(windowWidth, windowHeight);
}
</script>
</body>
</html>