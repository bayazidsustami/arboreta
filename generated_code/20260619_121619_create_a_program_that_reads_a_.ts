import { createFFmpeg, fetchFile } from '@ffmpeg/ffmpeg';
import * as tf from '@tensorflow/tfjs-node';
import * as tone from 'tone';
import { writeFileSync } from 'fs';
import { Canvas, loadImage } from 'canvas';

// ---------- Config ----------
const INPUT_VIDEO = 'input.mp4';          // source video
const OUTPUT_VIDEO = 'output.mp4';        // final MP4
const FRAME_RATE = 30;                    // processing fps
const CANVAS_W = 256, CANVAS_H = 256;     // CA resolution
const CA_STEPS = 4;                       // CA iterations per frame

// ---------- Simple CA ----------
type Cell = number; // 0..1 intensity
function initCA(): Cell[][] {
  const grid: Cell[][] = [];
  for (let y = 0; y < CANVAS_H; y++) {
    const row: Cell[] = [];
    for (let x = 0; x < CANVAS_W; x++) row.push(Math.random());
    grid.push(row);
  }
  return grid;
}
function stepCA(grid: Cell[][], influence: number): Cell[][] {
  const newGrid: Cell[][] = [];
  for (let y = 0; y < CANVAS_H; y++) {
    const row: Cell[] = [];
    for (let x = 0; x < CANVAS_W; x++) {
      const sum =
        (grid[(y - 1 + CANVAS_H) % CANVAS_H][(x - 1 + CANVAS_W) % CANVAS_W] +
          grid[(y - 1 + CANVAS_H) % CANVAS_H][x] +
          grid[(y - 1 + CANVAS_H) % CANVAS_H][(x + 1) % CANVAS_W] +
          grid[y][(x - 1 + CANVAS_W) % CANVAS_W] +
          grid[y][(x + 1) % CANVAS_W] +
          grid[(y + 1) % CANVAS_H][(x - 1 + CANVAS_W) % CANVAS_W] +
          grid[(y + 1) % CANVAS_H][x] +
          grid[(y + 1) % CANVAS_H][(x + 1) % CANVAS_W]) / 8;
      const val = Math.min(1, Math.max(0, sum + (Math.random() - 0.5) * 0.1 + influence * 0.2));
      row.push(val);
    }
    newGrid.push(row);
  }
  return newGrid;
}
function renderCA(grid: Cell[][]): Buffer {
  const canvas = new Canvas(CANVAS_W, CANVAS_H);
  const ctx = canvas.getContext('2d');
  const imgData = ctx.createImageData(CANVAS_W, CANVAS_H);
  for (let y = 0; y < CANVAS_H; y++) {
    for (let x = 0; x < CANVAS_W; x++) {
      const i = (y * CANVAS_W + x) * 4;
      const v = Math.floor(grid[y][x] * 255);
      imgData.data[i] = v;          // r
      imgData.data[i + 1] = 255 - v; // g
      imgData.data[i + 2] = v * 0.5; // b
      imgData.data[i + 3] = 255;
    }
  }
  ctx.putImageData(imgData, 0, 0);
  return canvas.toBuffer('image/png');
}

// ---------- Sentiment net (very simple placeholder) ----------
let sentimentModel: tf.LayersModel;
async function loadSentimentModel() {
  // Use a tiny mobilenet‑like model; in practice load a proper emotion classifier.
  sentimentModel = await tf.loadLayersModel('https://tfhub.dev/google/tfjs-model/ssd_mobilenet_v2/1/default/1', { fromTFHub: true }).catch(() => null);
}
function predictSentiment(frame: tf.Tensor3D): number {
  // Placeholder: return random sentiment [-1,1]
  return Math.random() * 2 - 1;
}

// ---------- Audio synthesis ----------
let synth: tone.PolySynth<Tone.Synth<Tone.SynthOptions>>;
function initAudio() {
  synth = new tone.PolySynth(tone.Synth).toDestination();
}
function playNoteFromSentiment(sent: number) {
  const midi = 60 + Math.round(sent * 12); // map -1..1 to 48..72
  const freq = tone.Frequency(midi, 'midi').toFrequency();
  synth.triggerAttackRelease(freq, '8n');
}

// ---------- Main pipeline ----------
(async () => {
  const ffmpeg = createFFmpeg({ log: true });
  await ffmpeg.load();

  // Load video into FFmpeg FS
  ffmpeg.FS('writeFile', INPUT_VIDEO, await fetchFile(INPUT_VIDEO));

  // Extract frames
  await ffmpeg.run(
    '-i', INPUT_VIDEO,
    '-vf', `fps=${FRAME_RATE}`,
    'frame_%05d.png'
  );

  // Load model and audio
  await loadSentimentModel();
  initAudio();

  // Process each frame
  const files = ffmpeg.FS('readdir', '.').filter(f => f.startsWith('frame_') && f.endsWith('.png'));
  let caGrid = initCA();
  const processedFrames: string[] = [];

  for (const file of files) {
    const imgBuf = ffmpeg.FS('readFile', file);
    const img = await loadImage(Buffer.from(imgBuf));
    const tfImg = tf.browser.fromPixels(img).toFloat().div(255).expandDims(0);
    const sentiment = predictSentiment(tfImg.squeeze() as tf.Tensor3D); // -1..1

    // evolve CA with sentiment influence
    for (let i = 0; i < CA_STEPS; i++) caGrid = stepCA(caGrid, sentiment);
    const caImg = renderCA(caGrid);
    const outName = `out_${file}`;
    ffmpeg.FS('writeFile', outName, caImg);
    processedFrames.push(outName);

    // schedule audio (synchronous with video time)
    const now = tone.Transport.seconds;
    tone.Transport.scheduleOnce(() => playNoteFromSentiment(sentiment), now);
  }

  // render audio to a wav file (using Tone's offline rendering)
  const duration = processedFrames.length / FRAME_RATE;
  const offline = await Tone.Offline(async ({ transport }) => {
    initAudio();
    for (let i = 0; i < processedFrames.length; i++) {
      const sentiment = 0; // dummy, real notes already scheduled
      transport.scheduleOnce(() => playNoteFromSentiment(sentiment), i / FRAME_RATE);
    }
    transport.start(0);
  }, duration);
  const wavBuf = await offline.toWav();
  ffmpeg.FS('writeFile', 'audio.wav', await fetchFile(wavBuf));

  // Combine CA frames and audio into final video
  await ffmpeg.run(
    '-r', `${FRAME_RATE}`,
    '-i', 'out_frame_%05d.png',
    '-i', 'audio.wav',
    '-c:v', 'libx264',
    '-pix_fmt', 'yuv420p',
    '-c:a', 'aac',
    '-shortest',
    OUTPUT_VIDEO
  );

  // Write output to real FS
  const data = ffmpeg.FS('readFile', OUTPUT_VIDEO);
  writeFileSync(OUTPUT_VIDEO, Buffer.from(data));
  console.log('Finished:', OUTPUT_VIDEO);
})();