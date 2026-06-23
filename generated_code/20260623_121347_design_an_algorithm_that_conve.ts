import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.165/build/three.module.js';
import { OrbitControls } from 'https://cdn.jsdelivr.net/npm/three@0.165/examples/jsm/controls/OrbitControls.js';

// ==== Audio analysis =========================================================
async function getAudioData(): Promise<Float32Array> {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
    const ctx = new AudioContext();
    const source = ctx.createMediaStreamSource(stream);
    const analyser = ctx.createAnalyser();
    analyser.fftSize = 256;
    source.connect(analyser);
    const buffer = new Float32Array(analyser.frequencyBinCount);
    // expose a getter that updates the buffer each call
    return new Proxy(buffer, {
        get(_, p) {
            analyser.getFloatFrequencyData(buffer);
            return Reflect.get(buffer, p);
        }
    }) as Float32Array;
}

// ==== Voxel field ============================================================
const GRID = 16;                     // 16³ voxels
const VOXEL_SIZE = 0.6;
const HALF = (GRID * VOXEL_SIZE) / 2;

function makeInstancedVoxels(): THREE.InstancedMesh {
    const geometry = new THREE.BoxGeometry(VOXEL_SIZE, VOXEL_SIZE, VOXEL_SIZE);
    const material = new THREE.MeshStandardMaterial({ vertexColors: true });
    const mesh = new THREE.InstancedMesh(geometry, material, GRID * GRID * GRID);
    const dummy = new THREE.Object3D();
    const color = new THREE.Color();

    let i = 0;
    for (let x = 0; x < GRID; x++) {
        for (let y = 0; y < GRID; y++) {
            for (let z = 0; z < GRID; z++) {
                dummy.position.set(
                    x * VOXEL_SIZE - HALF + VOXEL_SIZE / 2,
                    y * VOXEL_SIZE - HALF + VOXEL_SIZE / 2,
                    z * VOXEL_SIZE - HALF + VOXEL_SIZE / 2
                );
                dummy.updateMatrix();
                mesh.setMatrixAt(i, dummy.matrix);
                // initial color (will be overwritten each frame)
                mesh.setColorAt(i, color);
                i++;
            }
        }
    }
    mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
    mesh.instanceColor!.setUsage(THREE.DynamicDrawUsage);
    return mesh;
}

// ==== Self‑modifying shader ===================================================
let fragmentTemplate = `
precision highp float;
varying vec3 vPosition;
varying vec3 vNormal;
uniform vec3 uCamPos;
uniform float uTime;
uniform vec3 uPalette[3];

void main(){
    float d = length(vPosition);
    vec3 col = mix(uPalette[0], uPalette[1], sin(d*5.0+uTime)*0.5+0.5);
    col = mix(col, uPalette[2], dot(normalize(vNormal), normalize(uCamPos - vPosition))*0.5+0.5);
    gl_FragColor = vec4(col, 1.0);
}
`;

function compileShader(vertexSrc: string, fragmentSrc: string): THREE.ShaderMaterial {
    return new THREE.ShaderMaterial({
        vertexShader: vertexSrc,
        fragmentShader: fragmentSrc,
        uniforms: {
            uCamPos: { value: new THREE.Vector3() },
            uTime: { value: 0 },
            uPalette: { value: [new THREE.Color(0x442222), new THREE.Color(0x22aa22), new THREE.Color(0x2222aa)] }
        },
        side: THREE.DoubleSide
    });
}

// ==== Main ==============================================================
(async () => {
    const audioData = await getAudioData();

    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(60, innerWidth / innerHeight, 0.1, 1000);
    camera.position.set(0, 0, GRID);
    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(innerWidth, innerHeight);
    document.body.style.margin = '0';
    document.body.appendChild(renderer.domElement);

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;

    // lighting
    scene.add(new THREE.AmbientLight(0xffffff, 0.5));
    const dir = new THREE.DirectionalLight(0xffffff, 0.7);
    dir.position.set(5, 10, 7);
    scene.add(dir);

    // voxel mesh with custom shader
    const voxels = makeInstancedVoxels();
    const vertexShader = `
        attribute vec3 position;
        attribute vec3 color;
        attribute mat4 instanceMatrix;
        varying vec3 vPosition;
        varying vec3 vNormal;
        void main(){
            vPosition = (instanceMatrix * vec4(position,1.0)).xyz;
            vNormal = normalize(mat3(instanceMatrix) * normal);
            gl_Position = projectionMatrix * viewMatrix * vec4(vPosition,1.0);
        }
    `;
    let material = compileShader(vertexShader, fragmentTemplate);
    voxels.material = material;
    scene.add(voxels);

    // helper to update palette based on camera movement patterns
    let lastCamPos = new THREE.Vector3();
    function updateShaderBasedOnMovement() {
        const delta = camera.position.clone().sub(lastCamPos);
        if (delta.lengthSq() > 0.01) {
            // mutate palette colours slightly
            const uniforms = (material as THREE.ShaderMaterial).uniforms;
            const pal: THREE.Color[] = uniforms.uPalette.value;
            for (let i = 0; i < pal.length; i++) {
                const hueShift = (Math.random() - 0.5) * 0.1;
                pal[i].setHSL((pal[i].getHSL({}).h + hueShift) % 1, 0.6, 0.5);
            }
            // re‑compile (simulated by flagging needsUpdate)
            (material as THREE.ShaderMaterial).needsUpdate = true;
            lastCamPos.copy(camera.position);
        }
    }

    // animate loop
    const clock = new THREE.Clock();
    function animate() {
        requestAnimationFrame(animate);
        const t = clock.getElapsedTime();
        material.uniforms.uTime.value = t;
        material.uniforms.uCamPos.value.copy(camera.position);
        controls.update();

        // map audio spectrum to voxel colors
        const freq = audioData;
        const color = new THREE.Color();
        const tmp = new THREE.Vector3();
        const dummy = new THREE.Object3D();
        const count = GRID * GRID * GRID;
        for (let i = 0; i < count; i++) {
            // pick a frequency band based on voxel index
            const band = Math.floor((i / count) * freq.length);
            const intensity = Math.max(0, (freq[band] + 140) / 140); // normalize
            color.setHSL(intensity, 0.8, 0.5);
            voxels.setColorAt(i, color);
        }
        voxels.instanceColor!.needsUpdate = true;

        updateShaderBasedOnMovement();

        renderer.render(scene, camera);
    }
    animate();

    // handle resize
    addEventListener('resize', () => {
        camera.aspect = innerWidth / innerHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(innerWidth, innerHeight);
    });
})();