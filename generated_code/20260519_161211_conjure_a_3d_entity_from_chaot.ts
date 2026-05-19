```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bio-Noise Entity</title>
    <style>
        body { margin: 0; overflow: hidden; background: #000; }
        canvas { display: block; }
    </style>
</head>
<body>
<script type="module">
// Import Three.js from CDN
import * as THREE from 'https://unpkg.com/three@0.158.0/build/three.module.js';

// Create scene, camera, renderer
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setSize(window.innerWidth, window.innerHeight);
document.body.appendChild(renderer.domElement);

// Entity parameters
const baseRadius = 2;
const noiseHistorySize = 100;
const noiseHistory = new Array(noiseHistorySize).fill(0);
let historyIndex = 0;

// Create base sphere geometry
const baseGeometry = new THREE.SphereGeometry(baseRadius, 64, 64);
const baseMesh = new THREE.Mesh(baseGeometry, new THREE.MeshPhongMaterial({
    color: 0x00aaff,
    shininess: 100,
    wireframe: false
}));
scene.add(baseMesh);

// Add point lights
const light1 = new THREE.PointLight(0xffffff, 1, 100);
light1.position.set(10, 10, 10);
scene.add(light1);
const light2 = new THREE.PointLight(0xff00ff, 0.5, 100);
light2.position.set(-10, -10, 5);
scene.add(light2);

// Camera position
camera.position.z = 8;

// Compute variance from noise history
function computeVariance() {
    const mean = noiseHistory.reduce((a, b) => a + b, 0) / noiseHistorySize;
    const squaredDiffs = noiseHistory.map(x => Math.pow(x - mean, 2));
    return Math.sqrt(squaredDiffs.reduce((a, b) => a + b, 0) / noiseHistorySize);
}

// Generate chaotic noise (pseudo-random but deterministic based on time)
function generateNoise() {
    const time = Date.now() * 0.001;
    return Math.sin(time * 1.3) * Math.cos(time * 0.7) * Math.sin(time * 2.1) * 3;
}

// Update entity geometry based on variance
function updateEntity(variance) {
    const positions = baseGeometry.attributes.position;
    const normals = baseGeometry.attributes.normal;
    const vertex = new THREE.Vector3();
    
    // Displace vertices along their normals by variance factor
    for (let i = 0; i < positions.count; i++) {
        vertex.fromBufferAttribute(positions, i);
        const normal = new THREE.Vector3().fromBufferAttribute(normals, i);
        const displacement = baseRadius * (0.5 + variance * 1.5);
        vertex.add(normal.multiplyScalar(displacement - baseRadius));
        positions.setXYZ(i, vertex.x, vertex.y, vertex.z);
    }
    
    baseGeometry.computeVertexNormals();
    baseGeometry.attributes.position.needsUpdate = true;
    
    // Change color based on variance (cool to warm)
    const hue = (0.5 - variance * 0.5) % 1;
    baseMesh.material.color.setHSL(hue, 0.8, 0.5);
}

// Animation loop
function animate() {
    requestAnimationFrame(animate);
    
    // Update noise history
    noiseHistory[historyIndex] = generateNoise();
    historyIndex = (historyIndex + 1) % noiseHistorySize;
    
    // Compute current variance
    const variance = computeVariance();
    
    // Update entity
    updateEntity(variance);
    
    // Rotate entity slowly
    baseMesh.rotation.y += 0.005;
    baseMesh.rotation.z += 0.002;
    
    renderer.render(scene, camera);
}

// Handle resize
window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
});

animate();
</script>
</body>
</html>
```