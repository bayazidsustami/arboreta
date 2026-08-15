/**
 * Audio-to-Plant Lossy Compressor & 3D Procedural Tree Generator
 * 
 * Converts raw PCM audio into a highly compressed, lossy procedural "Plant Genome" payload.
 * The compressed genome encodes spectral features (energy, centroid, flux, bass/treble balance)
 * into 3D structural growth parameters (trunk girth, branching angle, split count, foliage density),
 * rendering the original audio soundscape as a unique 3D digital tree.
 */

// ============================================================================
// 1. DATA STRUCTURES & TYPES
// ============================================================================

/** 3D Vector for geometry calculations */
interface Vector3 {
  x: number;
  y: number;
  z: number;
}

/** Vertex structure with position, normal, and RGB color */
interface Vertex {
  position: Vector3;
  normal: Vector3;
  color: [number, number, number];
}

/** Polygon face referencing vertex indices */
type Face = [number, number, number];

/** 3D Mesh container */
interface Mesh3D {
  vertices: Vertex[];
  faces: Face[];
}

/** Extracted audio frame features */
interface AudioFeatures {
  rmsEnergy: number;         // Overall volume / amplitude
  spectralCentroid: number;  // Brightness / pitch center (Hz)
  bassRatio: number;         // Low frequency energy ratio (20 - 250 Hz)
  trebleRatio: number;       // High frequency energy ratio (4k - 20k Hz)
  spectralFlux: number;      // Transient / rhythm intensity
}

/** Lossy compressed representation of audio ("Plant Genome") */
interface PlantGenome {
  seed: number;
  baseRadius: number;
  heightScale: number;
  branchingAngle: number;
  splitProbability: number;
  decayRate: number;
  leafDensity: number;
  foliageColor: [number, number, number];
  trunkColor: [number, number, number];
  generations: number;
  compressedSizeBytes: number;
}

// ============================================================================
// 2. VECTOR & QUATERNION MATH HELPERS
// ============================================================================

class Vec3 {
  static create(x: number, y: number, z: number): Vector3 {
    return { x, y, z };
  }

  static add(a: Vector3, b: Vector3): Vector3 {
    return { x: a.x + b.x, y: a.y + b.y, z: a.z + b.z };
  }

  static scale(v: Vector3, s: number): Vector3 {
    return { x: v.x * s, y: v.y * s, z: v.z * s };
  }

  static length(v: Vector3): number {
    return Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
  }

  static normalize(v: Vector3): Vector3 {
    const len = Vec3.length(v) || 1;
    return { x: v.x / len, y: v.y / len, z: v.z / len };
  }

  static cross(a: Vector3, b: Vector3): Vector3 {
    return {
      x: a.y * b.z - a.z * b.y,
      y: a.z * b.x - a.x * b.z,
      z: a.x * b.y - a.y * b.x
    };
  }

  /** Rotates vector v around an axis by a given angle in radians */
  static rotateAxis(v: Vector3, axis: Vector3, angle: number): Vector3 {
    const normAxis = Vec3.normalize(axis);
    const cosA = Math.cos(angle);
    const sinA = Math.sin(angle);
    const crossVal = Vec3.cross(normAxis, v);
    const dotVal = normAxis.x * v.x + normAxis.y * v.y + normAxis.z * v.z;

    return {
      x: v.x * cosA + crossVal.x * sinA + normAxis.x * dotVal * (1 - cosA),
      y: v.y * cosA + crossVal.y * sinA + normAxis.y * dotVal * (1 - cosA),
      z: v.z * cosA + crossVal.z * sinA + normAxis.z * dotVal * (1 - cosA)
    };
  }
}

// ============================================================================
// 3. AUDIO SIGNAL ANALYSIS & DSP (FFT)
// ============================================================================

class AudioAnalyzer {
  /** In-place Cooley-Tukey Radix-2 Fast Fourier Transform */
  static fft(real: Float32Array, imag: Float32Array): void {
    const n = real.length;
    let j = 0;
    for (let i = 0; i < n; i++) {
      if (i < j) {
        const tempR = real[i]; real[i] = real[j]; real[j] = tempR;
        const tempI = imag[i]; imag[i] = imag[j]; imag[j] = tempI;
      }
      let m = n >> 1;
      while (m >= 1 && j >= m) {
        j -= m;
        m >>= 1;
      }
      j += m;
    }

    for (let len = 2; len <= n; len <<= 1) {
      const halfLen = len >> 1;
      const angle = (-2 * Math.PI) / len;
      const wStepR = Math.cos(angle);
      const wStepI = Math.sin(angle);
      for (let i = 0; i < n; i += len) {
        let wR = 1;
        let wI = 0;
        for (let k = 0; k < halfLen; k++) {
          const pos = i + k;
          const matchPos = pos + halfLen;
          const uR = real[pos];
          const uI = imag[pos];
          const vR = real[matchPos] * wR - imag[matchPos] * wI;
          const vI = real[matchPos] * wI + imag[matchPos] * wR;

          real[pos] = uR + vR;
          imag[pos] = uI + vI;
          real[matchPos] = uR - vR;
          imag[matchPos] = uI - vI;

          const nextWR = wR * wStepR - wI * wStepI;
          const nextWI = wR * wStepI + wI * wStepR;
          wR = nextWR;
          wI = nextWI;
        }
      }
    }
  }

  /** Analyzes PCM audio frames and extracts key acoustic descriptors */
  static analyze(pcmData: Float32Array, sampleRate: number): AudioFeatures[] {
    const frameSize = 1024;
    const hopSize = 512;
    const numFrames = Math.floor((pcmData.length - frameSize) / hopSize);
    const features: AudioFeatures[] = [];

    let prevSpectrum = new Float32Array(frameSize / 2);

    for (let f = 0; f < numFrames; f++) {
      const offset = f * hopSize;
      const real = new Float32Array(frameSize);
      const imag = new Float32Array(frameSize);

      // Apply Hann window & compute RMS energy
      let sumSq = 0;
      for (let i = 0; i < frameSize; i++) {
        const window = 0.5 * (1 - Math.cos((2 * Math.PI * i) / (frameSize - 1)));
        const sample = pcmData[offset + i] * window;
        real[i] = sample;
        sumSq += sample * sample;
      }
      const rmsEnergy = Math.sqrt(sumSq / frameSize);

      // Perform FFT
      AudioAnalyzer.fft(real, imag);

      // Compute magnitude spectrum
      const numBins = frameSize / 2;
      const magnitudes = new Float32Array(numBins);
      let totalMag = 0;
      let weightedFreqSum = 0;
      let bassEnergy = 0;
      let trebleEnergy = 0;
      let flux = 0;

      const binWidth = sampleRate / frameSize;

      for (let i = 0; i < numBins; i++) {
        const mag = Math.sqrt(real[i] * real[i] + imag[i] * imag[i]);
        magnitudes[i] = mag;
        totalMag += mag;

        const freq = i * binWidth;
        weightedFreqSum += freq * mag;

        if (freq >= 20 && freq <= 250) bassEnergy += mag;
        if (freq >= 4000 && freq <= 20000) trebleEnergy += mag;

        // Spectral flux (transient response)
        const diff = mag - prevSpectrum[i];
        if (diff > 0) flux += diff;
      }

      prevSpectrum = magnitudes;

      const spectralCentroid = totalMag > 0 ? weightedFreqSum / totalMag : 0;
      const bassRatio = totalMag > 0 ? bassEnergy / totalMag : 0;
      const trebleRatio = totalMag > 0 ? trebleEnergy / totalMag : 0;

      features.push({
        rmsEnergy,
        spectralCentroid,
        bassRatio,
        trebleRatio,
        spectralFlux: flux
      });
    }

    return features;
  }
}

// ============================================================================
// 4. LOSSY AUDIO-TO-PLANT COMPRESSOR
// ============================================================================

class AudioToPlantCompressor {
  /**
   * Quantizes and maps a sequence of audio features into a tiny procedural genome.
   * Compresses thousands of audio bytes into a compact growth instruction payload.
   */
  static compress(pcmData: Float32Array, sampleRate: number): PlantGenome {
    const rawAudioBytes = pcmData.length * 4; // 32-bit float size
    const features = AudioAnalyzer.analyze(pcmData, sampleRate);

    if (features.length === 0) {
      throw new Error("Audio buffer too short for spectral analysis.");
    }

    // Aggregate audio features across the file timeline
    let avgEnergy = 0;
    let avgCentroid = 0;
    let avgBass = 0;
    let avgTreble = 0;
    let avgFlux = 0;

    for (const f of features) {
      avgEnergy += f.rmsEnergy;
      avgCentroid += f.spectralCentroid;
      avgBass += f.bassRatio;
      avgTreble += f.trebleRatio;
      avgFlux += f.spectralFlux;
    }

    avgEnergy /= features.length;
    avgCentroid /= features.length;
    avgBass /= features.length;
    avgTreble /= features.length;
    avgFlux /= features.length;

    // Map audio traits to plant phenotype parameters:
    // - Bass drives trunk thickness & base structural stability
    // - Audio amplitude drives tree height scale
    // - Spectral centroid (pitch brightness) dictates branching angle
    // - Spectral flux (rhythmic complexity) controls branch splitting probability
    // - Treble energy determines foliage/leaf density and color hues
    const baseRadius = 0.3 + avgBass * 1.8;
    const heightScale = 1.0 + avgEnergy * 15.0;
    const branchingAngle = (20 + (avgCentroid / (sampleRate / 2)) * 60) * (Math.PI / 180);
    const splitProbability = Math.min(0.9, 0.3 + avgFlux * 0.05);
    const decayRate = 0.65 + Math.min(0.25, avgEnergy * 0.5);
    const leafDensity = Math.min(1.0, avgTreble * 3.0 + 0.2);

    // Compute dynamic color palettes from audio spectrum
    const trunkR = Math.min(1.0, 0.3 + avgBass * 0.5);
    const trunkG = Math.min(1.0, 0.2 + avgEnergy * 0.4);
    const trunkB = 0.1;

    const foliageR = Math.min(1.0, avgTreble * 2.0);
    const foliageG = Math.min(1.0, 0.5 + avgEnergy * 1.5);
    const foliageB = Math.min(1.0, avgCentroid / 5000);

    // Create binary packed representation (16 bytes payload) to measure lossy size
    const buffer = new ArrayBuffer(24);
    const view = new DataView(buffer);
    view.setUint16(0, Math.floor(baseRadius * 1000), true);
    view.setUint16(2, Math.floor(heightScale * 100), true);
    view.setUint16(4, Math.floor(branchingAngle * 1000), true);
    view.setUint16(6, Math.floor(splitProbability * 1000), true);
    view.setUint16(8, Math.floor(decayRate * 1000), true);
    view.setUint16(10, Math.floor(leafDensity * 1000), true);
    view.setUint8(12, Math.floor(trunkR * 255));
    view.setUint8(13, Math.floor(trunkG * 255));
    view.setUint8(14, Math.floor(trunkB * 255));
    view.setUint8(15, Math.floor(foliageR * 255));
    view.setUint8(16, Math.floor(foliageG * 255));
    view.setUint8(17, Math.floor(foliageB * 255));

    return {
      seed: Math.floor(avgCentroid + avgEnergy * 10000),
      baseRadius,
      heightScale,
      branchingAngle,
      splitProbability,
      decayRate,
      leafDensity,
      trunkColor: [trunkR, trunkG, trunkB],
      foliageColor: [foliageR, foliageG, foliageB],
      generations: 5,
      compressedSizeBytes: buffer.byteLength
    };
  }
}

// ============================================================================
// 5. PROCEDURAL 3D TREE GEOMETRY GENERATOR
// ============================================================================

class ProceduralTreeBuilder {
  private mesh: Mesh3D = { vertices: [], faces: [] };

  /** Simple deterministic pseudo-random number generator */
  private random(seed: number): () => number {
    let s = seed;
    return () => {
      s = (s * 9301 + 49297) % 233280;
      return s / 233280;
    };
  }

  /** Synthesizes a 3D digital tree mesh from compressed plant growth instructions */
  buildTree(genome: PlantGenome): Mesh3D {
    this.mesh = { vertices: [], faces: [] };
    const rand = this.random(genome.seed);

    const startPos = Vec3.create(0, 0, 0);
    const startDir = Vec3.create(0, 1, 0);

    this.growBranch(
      startPos,
      startDir,
      genome.heightScale,
      genome.baseRadius,
      0,
      genome,
      rand
    );

    return this.mesh;
  }

  /** Recursively constructs cylindrical branch segments and leaf structures */
  private growBranch(
    start: Vector3,
    direction: Vector3,
    length: number,
    radius: number,
    depth: number,
    genome: PlantGenome,
    rand: () => number
  ): void {
    const end = Vec3.add(start, Vec3.scale(direction, length));
    const radialSegments = Math.max(3, Math.floor(8 - depth));

    // Build branch cylinder segment
    this.addCylinder(start, end, radius, radius * genome.decayRate, radialSegments, genome.trunkColor);

    // Terminal leaf growth
    if (depth >= genome.generations) {
      if (rand() < genome.leafDensity) {
        this.addLeaf(end, direction, radius * 4.0, genome.foliageColor);
      }
      return;
    }

    // Determine sub-branch count derived from compressed audio flux parameters
    const splits = rand() < genome.splitProbability ? 3 : 2;

    for (let i = 0; i < splits; i++) {
      // Compute orthogonal rotational axes
      const spreadAngle = genome.branchingAngle * (0.8 + rand() * 0.4);
      const azimuthAngle = (i * (2 * Math.PI / splits)) + (rand() - 0.5) * 0.5;

      // Primary orthog vector
      let perp = Vec3.cross(direction, Vec3.create(0, 0, 1));
      if (Vec3.length(perp) < 0.001) {
        perp = Vec3.cross(direction, Vec3.create(1, 0, 0));
      }
      perp = Vec3.normalize(perp);

      // Rotate direction vector to yield new branch direction
      let childDir = Vec3.rotateAxis(direction, perp, spreadAngle);
      childDir = Vec3.rotateAxis(childDir, direction, azimuthAngle);
      childDir = Vec3.normalize(childDir);

      this.growBranch(
        end,
        childDir,
        length * genome.decayRate,
        radius * genome.decayRate,
        depth + 1,
        genome,
        rand
      );
    }
  }

  /** Generates cylindrical 3D mesh geometry for trunk/branches */
  private addCylinder(
    start: Vector3,
    end: Vector3,
    rStart: number,
    rEnd: number,
    segments: number,
    color: [number, number, number]
  ): void {
    const dir = Vec3.normalize(Vec3.add(end, Vec3.scale(start, -1)));
    let side = Vec3.cross(dir, Vec3.create(0, 1, 0));
    if (Vec3.length(side) < 0.001) side = Vec3.cross(dir, Vec3.create(1, 0, 0));
    side = Vec3.normalize(side);
    const up = Vec3.normalize(Vec3.cross(dir, side));

    const baseIndex = this.mesh.vertices.length;

    for (let i = 0; i < segments; i++) {
      const theta = (i / segments) * 2 * Math.PI;
      const cos = Math.cos(theta);
      const sin = Math.sin(theta);

      const offset = Vec3.add(Vec3.scale(side, cos), Vec3.scale(up, sin));
      const normal = Vec3.normalize(offset);

      // Bottom ring vertex
      this.mesh.vertices.push({
        position: Vec3.add(start, Vec3.scale(offset, rStart)),
        normal,
        color
      });

      // Top ring vertex
      this.mesh.vertices.push({
        position: Vec3.add(end, Vec3.scale(offset, rEnd)),
        normal,
        color
      });
    }

    // Connect rings with quad faces (triangulated)
    for (let i = 0; i < segments; i++) {
      const next = (i + 1) % segments;
      const b1 = baseIndex + i * 2;
      const t1 = baseIndex + i * 2 + 1;
      const b2 = baseIndex + next * 2;
      const t2 = baseIndex + next * 2 + 1;

      this.mesh.faces.push([b1, b2, t1]);
      this.mesh.faces.push([t1, b2, t2]);
    }
  }

  /** Adds a leaf polygon to branch tips */
  private addLeaf(
    pos: Vector3,
    dir: Vector3,
    scale: number,
    color: [number, number, number]
  ): void {
    const baseIndex = this.mesh.vertices.length;
    let side = Vec3.cross(dir, Vec3.create(0, 1, 0));
    if (Vec3.length(side) < 0.001) side = Vec3.create(1, 0, 0);
    side = Vec3.normalize(side);

    const v0 = Vec3.add(pos, Vec3.scale(side, -scale * 0.5));
    const v1 = Vec3.add(pos, Vec3.scale(side, scale * 0.5));
    const v2 = Vec3.add(pos, Vec3.scale(dir, scale * 1.5));

    const normal = Vec3.normalize(Vec3.cross(side, dir));

    this.mesh.vertices.push({ position: v0, normal, color });
    this.mesh.vertices.push({ position: v1, normal, color });
    this.mesh.vertices.push({ position: v2, normal, color });

    this.mesh.faces.push([baseIndex, baseIndex + 1, baseIndex + 2]);
  }
}

// ============================================================================
// 6. EXPORTERS & VISUALIZERS
// ============================================================================

class Exporter {
  /** Formats 3D tree mesh into Wavefront OBJ format string */
  static toOBJ(mesh: Mesh3D): string {
    let obj = `# SoundTree Procedural 3D Model\n`;
    obj += `# Vertices: ${mesh.vertices.length}\n`;
    obj += `# Faces: ${mesh.faces.length}\n\n`;

    for (const v of mesh.vertices) {
      const p = v.position;
      const c = v.color;
      obj += `v ${p.x.toFixed(4)} ${p.y.toFixed(4)} ${p.z.toFixed(4)} ${c[0].toFixed(3)} ${c[1].toFixed(3)} ${c[2].toFixed(3)}\n`;
    }

    for (const v of mesh.vertices) {
      const n = v.normal;
      obj += `vn ${n.x.toFixed(4)} ${n.y.toFixed(4)} ${n.z.toFixed(4)}\n`;
    }

    for (const f of mesh.faces) {
      // 1-based index in Wavefront OBJ
      const idx1 = f[0] + 1;
      const idx2 = f[1] + 1;
      const idx3 = f[2] + 1;
      obj += `f ${idx1}//${idx1} ${idx2}//${idx2} ${idx3}//${idx3}\n`;
    }

    return obj;
  }

  /** Renders an ASCII front-projection preview of the 3D tree for terminal output */
  static renderASCII(mesh: Mesh3D, width: number = 60, height: number = 30): string {
    const grid: string[][] = Array.from({ length: height }, () => Array(width).fill(" "));
    
    // Compute bounding box
    let minX = Infinity, maxX = -Infinity;
    let minY = Infinity, maxY = -Infinity;

    for (const v of mesh.vertices) {
      if (v.position.x < minX) minX = v.position.x;
      if (v.position.x > maxX) maxX = v.position.x;
      if (v.position.y < minY) minY = v.position.y;
      if (v.position.y > maxY) maxY = v.position.y;
    }

    const spanX = (maxX - minX) || 1;
    const spanY = (maxY - minY) || 1;

    // Project 3D vertices to 2D character grid
    for (const v of mesh.vertices) {
      const nx = Math.floor(((v.position.x - minX) / spanX) * (width - 1));
      const ny = Math.floor((1 - (v.position.y - minY) / spanY) * (height - 1));

      if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
        // Use color green ratio to choose leaf vs wood glyph
        const isLeaf = v.color[1] > v.color[0] && v.color[1] > 0.4;
        grid[ny][nx] = isLeaf ? "*" : "#";
      }
    }

    return grid.map(row => row.join("")).join("\n");
  }
}

// ============================================================================
// 7. SYNTHETIC AUDIO GENERATOR (TEST DATA)
// ============================================================================

/** Generates synthetic musical audio containing bass kick, mid synth, and high shimmer */
function createSyntheticAudio(durationSec: number, sampleRate: number): Float32Array {
  const numSamples = durationSec * sampleRate;
  const buffer = new Float32Array(numSamples);

  for (let i = 0; i < numSamples; i++) {
    const t = i / sampleRate;

    // Bass Kick (100 Hz decaying envelope every 0.5s)
    const kickEnv = Math.exp(-10 * (t % 0.5));
    const bass = Math.sin(2 * Math.PI * 60 * t) * kickEnv;

    // Mid synth chord (220 Hz + 330 Hz harmonic)
    const mid = Math.sin(2 * Math.PI * 220 * t) * 0.3 + Math.sin(2 * Math.PI * 330 * t) * 0.2;

    // Treble shimmer (6 kHz hi-hat burst every 0.25s)
    const hatEnv = Math.exp(-40 * (t % 0.25));
    const treble = (Math.random() * 2 - 1) * hatEnv * 0.15;

    buffer[i] = (bass + mid + treble) * 0.5;
  }

  return buffer;
}

// ============================================================================
// 8. MAIN EXECUTION PIPELINE
// ============================================================================

function main() {
  const sampleRate = 44100;
  const durationSec = 3.0;

  console.log("=== AUDIO TO 3D PROCEDURAL TREE COMPRESSOR ===");
  console.log(`Generating synthetic audio buffer (${durationSec}s @ ${sampleRate} Hz)...`);
  const rawAudio = createSyntheticAudio(durationSec, sampleRate);
  const rawSizeBytes = rawAudio.length * 4; // 32-bit floats

  console.log(`Raw Audio Size: ${rawSizeBytes.toLocaleString()} bytes`);

  // 1. Compress raw audio to procedural growth genome
  console.log("\nCompressing audio spectrum into procedural Plant Genome...");
  const genome = AudioToPlantCompressor.compress(rawAudio, sampleRate);

  const ratio = (rawSizeBytes / genome.compressedSizeBytes).toFixed(1);
  console.log("\n--- COMPRESSION STATS ---");
  console.log(`Compressed Genome Payload: ${genome.compressedSizeBytes} bytes`);
  console.log(`Compression Ratio: ${ratio}:1`);
  console.log(`Growth Parameters Extracted:`);
  console.log(` - Base Radius:       ${genome.baseRadius.toFixed(3)} m`);
  console.log(` - Height Scale:      ${genome.heightScale.toFixed(3)} m`);
  console.log(` - Branching Angle:   ${(genome.branchingAngle * (180 / Math.PI)).toFixed(1)}°`);
  console.log(` - Split Probability: ${(genome.splitProbability * 100).toFixed(1)}%`);
  console.log(` - Foliage Density:   ${(genome.leafDensity * 100).toFixed(1)}%`);

  // 2. Render 3D Digital Tree Mesh from compressed instructions
  console.log("\nDecompressing plant growth instructions into 3D Mesh...");
  const builder = new ProceduralTreeBuilder();
  const treeMesh = builder.buildTree(genome);

  console.log(`Generated 3D Tree Mesh: ${treeMesh.vertices.length} vertices, ${treeMesh.faces.length} faces.`);

  // 3. Render ASCII Preview
  console.log("\n--- 3D DIGITAL TREE TERMINAL PREVIEW ---");
  console.log(Exporter.renderASCII(treeMesh));

  // 4. Export OBJ String preview
  const objData = Exporter.toOBJ(treeMesh);
  console.log("\n--- OBJ EXPORT SNIPPET ---");
  console.log(objData.split("\n").slice(0, 12).join("\n"));
  console.log("... [Wavefront OBJ output ready for rendering]");
}

main();