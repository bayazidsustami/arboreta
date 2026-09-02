import * as THREE from 'three';

// --- Web Audio API & Audio Feature Extraction ---

class AudioAnalyzer {
  private ctx!: AudioContext;
  private analyser!: AnalyserNode;
  private dataArray!: Uint8Array;
  private bufferLength: number = 0;
  public pitch: number = 0; // Normalized [0, 1] based on fundamental frequency (approx 80Hz - 1000Hz)
  public volume: number = 0; // Normalized [0, 1] RMS amplitude
  public consonance: number = 0; // Normalized [0, 1] Spectral Flatness / Harmonicity measure

  async init(): Promise<void> {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
    this.ctx = new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)();
    const source = this.ctx.createMediaStreamSource(stream);
    this.analyser = this.ctx.createAnalyser();
    this.analyser.fftSize = 2048;
    this.analyser.smoothingTimeConstant = 0.8;
    source.connect(this.analyser);
    this.bufferLength = this.analyser.frequencyBinCount;
    this.dataArray = new Uint8Array(this.bufferLength);
  }

  update(): void {
    if (!this.analyser) return;
    this.analyser.getByteFrequencyData(this.dataArray);

    // 1. Volume (RMS)
    let sumSquares = 0;
    for (let i = 0; i < this.bufferLength; i++) {
      const norm = this.dataArray[i] / 255;
      sumSquares += norm * norm;
    }
    this.volume = Math.sqrt(sumSquares / this.bufferLength);

    // 2. Pitch (Peak Frequency Detection)
    let maxVal = -1;
    let maxIdx = 0;
    for (let i = 0; i < this.bufferLength; i++) {
      if (this.dataArray[i] > maxVal) {
        maxVal = this.dataArray[i];
        maxIdx = i;
      }
    }
    const nyquist = this.ctx.sampleRate / 2;
    const peakFreq = (maxIdx / this.bufferLength) * nyquist;
    // Map pitch between 80 Hz and 1000 Hz to [0, 1]
    this.pitch = Math.min(Math.max((peakFreq - 80) / 920, 0), 1);

    // 3. Consonance (Spectral Flatness: Geometric Mean / Arithmetic Mean)
    // Low flatness -> harmonic/consonant tone; High flatness -> noise/dissonant
    let sum = 0;
    let logSum = 0;
    const eps = 1e-6;
    for (let i = 0; i < this.bufferLength; i++) {
      const val = (this.dataArray[i] / 255) + eps;
      sum += val;
      logSum += Math.log(val);
    }
    const arithmeticMean = sum / this.bufferLength;
    const geometricMean = Math.exp(logSum / this.bufferLength);
    const flatness = geometricMean / arithmeticMean;
    // Invert so high consonance = clear harmonic tone, low = noisy
    this.consonance = Math.min(Math.max(1.0 - flatness, 0), 1);
  }
}

// --- Shader Sources for Ping-Pong GPGPU Particle Fluid Simulation ---

const simulationVertexShader = `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = vec4(position, 1.0);
  }
`;

const simulationFragmentShader = `
  uniform sampler2D uPositionTex;
  uniform sampler2D uVelocityTex;
  uniform float uTime;
  uniform float uPitch;      // Controls swirl / turbulence dynamics
  uniform float uVolume;     // Controls density / particle emission energy
  uniform float uViscosity;  // Controls velocity damping (inverse of viscosity)
  uniform vec2 uResolution;
  varying vec2 vUv;

  // 3D Simplex Noise for physical fluid turbulence
  vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
  vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}
  
  float snoise(vec3 v){
    const vec2 C = vec2(1.0/6.0, 1.0/3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
    vec3 i  = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;
    i = mod(i, 289.0);
    vec4 p = permute(permute(permute(
              i.z + vec4(0.0, i1.z, i2.z, 1.0))
            + i.y + vec4(0.0, i1.y, i2.y, 1.0))
            + i.x + vec4(0.0, i1.x, i2.x, 1.0));
    float n_ = 0.142857142857;
    vec3 ns = n_ * D.wyz - D.xzx;
    vec4 j = p - 49.0 * floor(p * ns.z);
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);
    vec4 x = x_ *ns.x + ns.yyyy;
    vec4 y = y_ *ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);
    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);
    vec4 s0 = floor(b0)*2.0 + 1.0;
    vec4 s1 = floor(b1)*2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));
    vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww;
    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);
    vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
    p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
    vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
  }

  // Calculate Curl Noise for incompressible fluid flow field
  vec3 curlNoise(vec3 p) {
    float eps = 0.1;
    float n1 = snoise(p + vec3(0.0, eps, 0.0));
    float n2 = snoise(p + vec3(0.0, -eps, 0.0));
    float n3 = snoise(p + vec3(0.0, 0.0, eps));
    float n4 = snoise(p + vec3(0.0, 0.0, -eps));
    float n5 = snoise(p + vec3(eps, 0.0, 0.0));
    float n6 = snoise(p + vec3(-eps, 0.0, 0.0));

    float x = (n1 - n2) - (n3 - n4);
    float y = (n3 - n4) - (n5 - n6);
    float z = (n5 - n6) - (n1 - n2);
    return normalize(vec3(x, y, z));
  }

  void main() {
    vec3 pos = texture2D(uPositionTex, vUv).rgb;
    vec3 vel = texture2D(uVelocityTex, vUv).rgb;

    // Turbulence frequency dynamic with speech pitch
    float turbFreq = 0.5 + uPitch * 2.5;
    vec3 fluidForce = curlNoise(pos * turbFreq + vec3(uTime * 0.2)) * (0.01 + uVolume * 0.05);

    // Apply viscosity: lower viscosity means less resistance (higher persistence)
    vel = vel * (1.0 - uViscosity * 0.05) + fluidForce;
    pos += vel;

    // Boundary respawn condition to maintain constant fluid volume
    if (length(pos) > 5.0 || dot(pos, pos) < 0.001) {
      // Re-seed from center proportional to volume intensity
      float r = (fract(sin(dot(vUv, vec2(12.9898, 78.233))) * 43758.5453) * 0.5 + 0.1) * (0.2 + uVolume);
      float theta = vUv.x * 6.283185;
      float phi = vUv.y * 3.141592;
      pos = vec3(r * sin(phi) * cos(theta), r * sin(phi) * sin(theta), r * cos(phi));
      vel = vec3(0.0);
    }

    #ifdef UPDATE_VELOCITY
      gl_FragColor = vec4(vel, 1.0);
    #else
      gl_FragColor = vec4(pos, 1.0);
    #endif
  }
`;

const renderVertexShader = `
  uniform sampler2D uPositionTex;
  uniform float uPointSize;
  varying vec3 vPos;
  varying vec2 vUv;

  void main() {
    vUv = uv;
    vec3 pos = texture2D(uPositionTex, uv).rgb;
    vPos = pos;
    vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);
    gl_PointSize = uPointSize * (1.0 / -mvPosition.z);
    gl_Position = projectionMatrix * mvPosition;
  }
`;

const renderFragmentShader = `
  uniform float uPitch;
  uniform float uConsonance;
  varying vec3 vPos;

  // Spectral Color Mapping: Harmonics map to bright lush tones, noise to deep shifts
  vec3 palette(in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d) {
    return a + b * cos(6.28318 * (c * t + d));
  }

  void main() {
    // Soft particle point sphere
    float dist = length(gl_PointCoord - vec2(0.5));
    if (dist > 0.5) discard;
    float alpha = smoothstep(0.5, 0.0, dist);

    // Dynamic color gradient driven by consonance (harmonic pureness) and pitch
    vec3 c1 = vec3(0.5, 0.5, 0.5);
    vec3 c2 = vec3(0.5, 0.5, 0.5);
    vec3 c3 = vec3(1.0, 1.0, 1.0);
    vec3 c4 = mix(vec3(0.0, 0.33, 0.67), vec3(0.8, 0.1, 0.5), uConsonance);

    float t = length(vPos) * 0.3 + uPitch;
    vec3 col = palette(t, c1, c2, c3, c4);

    gl_FragColor = vec4(col * 1.5, alpha * 0.8);
  }
`;

// --- Main Application Setup ---

class FluidApp {
  private scene: THREE.Scene;
  private camera: THREE.PerspectiveCamera;
  private renderer: THREE.WebGLRenderer;
  private audioAnalyzer: AudioAnalyzer;

  // GPGPU Setup
  private simWidth: number = 256;
  private simHeight: number = 256;
  private numParticles: number;

  private pingPongPos: THREE.WebGLRenderTarget[];
  private pingPongVel: THREE.WebGLRenderTarget[];
  private currentBuffer: number = 0;

  private simScene: THREE.Scene;
  private simCamera: THREE.OrthographicCamera;
  private simMaterialPos: THREE.ShaderMaterial;
  private simMaterialVel: THREE.ShaderMaterial;
  private simQuad: THREE.Mesh;

  private renderParticles: THREE.Points;
  private renderMaterial: THREE.ShaderMaterial;

  constructor() {
    this.numParticles = this.simWidth * this.simHeight;

    // Setup Main ThreeJS Scene
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 100);
    this.camera.position.set(0, 0, 4);

    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
    this.renderer.setSize(window.innerWidth, window.innerHeight);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    document.body.appendChild(this.renderer.domElement);

    this.audioAnalyzer = new AudioAnalyzer();

    // Init Framebuffers for Velocity & Position GPGPU simulation
    const options: THREE.RenderTargetOptions = {
      format: THREE.RGBAFormat,
      type: THREE.FloatType,
      minFilter: THREE.NearestFilter,
      magFilter: THREE.NearestFilter,
      depthBuffer: false,
      stencilBuffer: false,
    };

    this.pingPongPos = [
      new THREE.WebGLRenderTarget(this.simWidth, this.simHeight, options),
      new THREE.WebGLRenderTarget(this.simWidth, this.simHeight, options)
    ];

    this.pingPongVel = [
      new THREE.WebGLRenderTarget(this.simWidth, this.simHeight, options),
      new THREE.WebGLRenderTarget(this.simWidth, this.simHeight, options)
    ];

    // Seed Initial Data
    const posData = new Float32Array(this.numParticles * 4);
    const velData = new Float32Array(this.numParticles * 4);
    for (let i = 0; i < this.numParticles; i++) {
      const i4 = i * 4;
      posData[i4] = (Math.random() - 0.5) * 2;
      posData[i4 + 1] = (Math.random() - 0.5) * 2;
      posData[i4 + 2] = (Math.random() - 0.5) * 2;
      posData[i4 + 3] = 1.0;

      velData[i4] = 0.0;
      velData[i4 + 1] = 0.0;
      velData[i4 + 2] = 0.0;
      velData[i4 + 3] = 1.0;
    }

    const posTex = new THREE.DataTexture(posData, this.simWidth, this.simHeight, THREE.RGBAFormat, THREE.FloatType);
    posTex.needsUpdate = true;
    const velTex = new THREE.DataTexture(velData, this.simWidth, this.simHeight, THREE.RGBAFormat, THREE.FloatType);
    velTex.needsUpdate = true;

    // Setup GPGPU Orthographic Scene
    this.simScene = new THREE.Scene();
    this.simCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

    this.simMaterialPos = new THREE.ShaderMaterial({
      vertexShader: simulationVertexShader,
      fragmentShader: simulationFragmentShader,
      uniforms: {
        uPositionTex: { value: posTex },
        uVelocityTex: { value: velTex },
        uTime: { value: 0 },
        uPitch: { value: 0 },
        uVolume: { value: 0 },
        uViscosity: { value: 0 },
        uResolution: { value: new THREE.Vector2(this.simWidth, this.simHeight) }
      }
    });

    this.simMaterialVel = new THREE.ShaderMaterial({
      vertexShader: simulationVertexShader,
      fragmentShader: '#define UPDATE_VELOCITY\n' + simulationFragmentShader,
      uniforms: {
        uPositionTex: { value: posTex },
        uVelocityTex: { value: velTex },
        uTime: { value: 0 },
        uPitch: { value: 0 },
        uVolume: { value: 0 },
        uViscosity: { value: 0 },
        uResolution: { value: new THREE.Vector2(this.simWidth, this.simHeight) }
      }
    });

    this.simQuad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), this.simMaterialPos);
    this.simScene.add(this.simQuad);

    // Setup Renderable Particle System Scene
    const geometry = new THREE.BufferGeometry();
    const uvs = new Float32Array(this.numParticles * 2);
    for (let y = 0; y < this.simHeight; y++) {
      for (let x = 0; x < this.simWidth; x++) {
        const i = y * this.simWidth + x;
        uvs[i * 2] = x / this.simWidth;
        uvs[i * 2 + 1] = y / this.simHeight;
      }
    }
    geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(this.numParticles * 3), 3));
    geometry.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));

    this.renderMaterial = new THREE.ShaderMaterial({
      vertexShader: renderVertexShader,
      fragmentShader: renderFragmentShader,
      uniforms: {
        uPositionTex: { value: null },
        uPointSize: { value: 12.0 },
        uPitch: { value: 0 },
        uConsonance: { value: 0 }
      },
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending
    });

    this.renderParticles = new THREE.Points(geometry, this.renderMaterial);
    this.scene.add(this.renderParticles);

    // User Interaction Overlay
    this.createUI();

    window.addEventListener('resize', this.onWindowResize.bind(this));
  }

  private createUI(): void {
    const btn = document.createElement('button');
    btn.innerText = 'Start Audio Fluid Reactivity';
    Object.assign(btn.style, {
      position: 'absolute',
      top: '50%',
      left: '50%',
      transform: 'translate(-50%, -50%)',
      padding: '16px 32px',
      fontSize: '18px',
      fontWeight: 'bold',
      color: '#fff',
      background: 'linear-gradient(45deg, #fe08b5, #ffb000)',
      border: 'none',
      borderRadius: '30px',
      cursor: 'pointer',
      boxShadow: '0px 0px 20px rgba(254, 8, 181, 0.6)',
      zIndex: '9999'
    });

    btn.onclick = async () => {
      await this.audioAnalyzer.init();
      btn.remove();
    };
    document.body.appendChild(btn);
  }

  private onWindowResize(): void {
    this.camera.aspect = window.innerWidth / window.innerHeight;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(window.innerWidth, window.innerHeight);
  }

  public animate(time: number): void {
    requestAnimationFrame(this.animate.bind(this));

    const seconds = time * 0.001;

    // 1. Audio Data Updates
    this.audioAnalyzer.update();
    const pitch = this.audioAnalyzer.pitch;
    const volume = this.audioAnalyzer.volume;
    const consonance = this.audioAnalyzer.consonance;

    // Viscosity is inversely affected by volume and pitch (low pitch/high dynamic speech = thicker fluid flow)
    const viscosity = Math.min(Math.max(1.0 - (volume * 0.7 + pitch * 0.3), 0.05), 0.95);

    // 2. Physics Ping-Pong Passes
    const readIdx = this.currentBuffer;
    const writeIdx = 1 - this.currentBuffer;

    // Pass A: Update Velocity
    this.simQuad.material = this.simMaterialVel;
    this.simMaterialVel.uniforms.uPositionTex.value = this.pingPongPos[readIdx].texture;
    this.simMaterialVel.uniforms.uVelocityTex.value = this.pingPongVel[readIdx].texture;
    this.simMaterialVel.uniforms.uTime.value = seconds;
    this.simMaterialVel.uniforms.uPitch.value = pitch;
    this.simMaterialVel.uniforms.uVolume.value = volume;
    this.simMaterialVel.uniforms.uViscosity.value = viscosity;
    this.renderer.setRenderTarget(this.pingPongVel[writeIdx]);
    this.renderer.render(this.simScene, this.simCamera);

    // Pass B: Update Position
    this.simQuad.material = this.simMaterialPos;
    this.simMaterialPos.uniforms.uPositionTex.value = this.pingPongPos[readIdx].texture;
    this.simMaterialPos.uniforms.uVelocityTex.value = this.pingPongVel[writeIdx].texture;
    this.simMaterialPos.uniforms.uTime.value = seconds;
    this.simMaterialPos.uniforms.uPitch.value = pitch;
    this.simMaterialPos.uniforms.uVolume.value = volume;
    this.simMaterialPos.uniforms.uViscosity.value = viscosity;
    this.renderer.setRenderTarget(this.pingPongPos[writeIdx]);
    this.renderer.render(this.simScene, this.simCamera);

    // Swap State Buffers
    this.currentBuffer = writeIdx;

    // 3. Render Particles Scene
    this.renderer.setRenderTarget(null);
    this.renderMaterial.uniforms.uPositionTex.value = this.pingPongPos[this.currentBuffer].texture;
    this.renderMaterial.uniforms.uPitch.value = pitch;
    this.renderMaterial.uniforms.uConsonance.value = consonance;

    // Orbit Camera dynamic rotation based on voice inputs
    this.scene.rotation.y = seconds * 0.1 + pitch * 0.5;
    this.scene.rotation.x = Math.sin(seconds * 0.05) * 0.2;

    this.renderer.render(this.scene, this.camera);
  }
}

// Global bootstrap
document.body.style.margin = '0';
document.body.style.overflow = 'hidden';
document.body.style.backgroundColor = '#000';
const app = new FluidApp();
app.animate(0);