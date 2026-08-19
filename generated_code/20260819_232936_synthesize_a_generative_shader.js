import { WebGLRenderer, Scene, OrthographicCamera, PlaneGeometry, ShaderMaterial, Mesh, Vector2 } from '[https://unpkg.com/three@0.160.0/build/three.module.js](https://unpkg.com/three@0.160.0/build/three.module.js)';

// Setup full-screen WebGL canvas and renderer
const renderer = new WebGLRenderer({ antialias: true });
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
document.body.style.margin = '0';
document.body.style.overflow = 'hidden';
document.body.appendChild(renderer.domElement);

// Minimal setup for a full-screen shader quad
const scene = new Scene();
const camera = new OrthographicCamera(-1, 1, 1, -1, 0, 1);

// GLSL Fragment Shader: Synthesizes biome growth, bioluminescent memory leak fungi, and CPU lightning
const fragmentShader = `
uniform vec2 u_resolution;
uniform float u_time;
uniform float u_cpu_spikes;
uniform float u_memory_leaks;

// Pseudo-random noise generator
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// 2D Perlin-style Noise for organic fluid motion
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Procedural Bioluminescent Fungi (Spores growing from memory leak accumulation)
float fungi(vec2 uv, float leakAmount) {
    vec2 grid = fract(uv * 8.0) - 0.5;
    vec2 id = floor(uv * 8.0);
    float n = hash(id);
    
    // Growth depends on total simulated memory leaks
    float size = 0.15 + 0.25 * sin(u_time * 2.0 + n * 6.28) * clamp(leakAmount * 0.1, 0.1, 1.0);
    float dist = length(grid);
    float cap = smoothstep(size, size - 0.05, dist);
    
    // Pulsing spore glow effect
    float glow = 0.02 / (dist + 0.01) * step(dist, size * 1.5);
    return (cap + glow) * step(0.3, n);
}

// Algorithmic Lightning Storms triggered by CPU spikes
float lightning(vec2 uv, float intensity) {
    if (intensity < 0.1) return 0.0;
    
    // Fractal bolt generation using offset noise
    float bolt = 0.0;
    vec2 st = uv;
    st.x += (noise(vec2(st.y * 10.0, u_time * 25.0)) - 0.5) * 0.4;
    
    float dist = abs(st.x);
    bolt = 0.008 / (dist + 0.001);
    bolt *= step(0.1, intensity);
    return bolt * intensity;
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;
    
    // Dynamic background biome flora color mapping
    float baseNoise = noise(uv * 3.0 + vec2(0.0, u_time * 0.1));
    vec3 deepBiome = mix(vec3(0.02, 0.05, 0.08), vec3(0.05, 0.15, 0.10), baseNoise);
    
    // Bioluminescent Fungi Layer (Cyan/Magenta glow for memory leaks)
    float fVal = fungi(uv + vec2(baseNoise * 0.2), u_memory_leaks);
    vec3 fungiColor = mix(vec3(0.0, 0.8, 0.6), vec3(0.9, 0.1, 0.8), sin(u_time + uv.x) * 0.5 + 0.5);
    vec3 biome = deepBiome + fVal * fungiColor * (1.0 + u_memory_leaks * 0.2);
    
    // Lightning Storm Layer (Bright blue-white discharges on CPU spikes)
    float lVal = lightning(uv, u_cpu_spikes);
    vec3 lightningColor = vec3(0.7, 0.85, 1.0) * lVal * 2.0;
    
    vec3 finalColor = biome + lightningColor;
    gl_FragColor = vec4(finalColor, 1.0);
}
`;

const uniforms = {
    u_resolution: { value: new Vector2(window.innerWidth, window.innerHeight) },
    u_time: { value: 0 },
    u_cpu_spikes: { value: 0.0 },
    u_memory_leaks: { value: 0.0 }
};

const material = new ShaderMaterial({
    vertexShader: `void main() { gl_Position = vec4(position, 1.0); }`,
    fragmentShader,
    uniforms
});

scene.add(new Mesh(new PlaneGeometry(2, 2), material));

// Simulated System Kernel Log Stream parser
let logMemoryAccumulator = 0;
let cpuSpikeEnergy = 0;

function simulateKernelLogs() {
    const isCpuEvent = Math.random() < 0.05;
    const isMemLeak = Math.random() < 0.15;
    
    if (isCpuEvent) {
        // High intensity load spikes
        cpuSpikeEnergy = 1.5 + Math.random() * 2.0;
    }
    
    if (isMemLeak) {
        // Leaks accumulate endless bioluminescent growth over time
        logMemoryAccumulator += 0.5;
    }
}

// Run kernel log parser event loop
setInterval(simulateKernelLogs, 200);

// Render Loop
const clock = new THREE.Clock?.() || { getElapsedTime: () => performance.now() * 0.001 };
function animate() {
    requestAnimationFrame(animate);
    
    // Decay CPU lightning rapidly per frame
    cpuSpikeEnergy *= 0.92;
    
    uniforms.u_time.value = clock.getElapsedTime();
    uniforms.u_cpu_spikes.value = cpuSpikeEnergy;
    uniforms.u_memory_leaks.value = logMemoryAccumulator;
    
    renderer.render(scene, camera);
}
animate();

// Handle viewport resizing
window.addEventListener('resize', () => {
    renderer.setSize(window.innerWidth, window.innerHeight);
    uniforms.u_resolution.value.set(window.innerWidth, window.innerHeight);
});