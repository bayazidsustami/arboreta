(function() {
  // Create full-screen DOM container and inject styling
  const style = document.createElement('style');
  style.textContent = `
    body { margin: 0; overflow: hidden; background: #080911; font-family: monospace; color: #eee; }
    #canvas-container { width: 100vw; height: 100vh; display: block; }
    #ui { position: absolute; top: 15px; left: 15px; z-index: 10; background: rgba(10,12,20,0.85); padding: 15px; border-radius: 8px; border: 1px solid #333; max-width: 320px; box-shadow: 0 4px 20px rgba(0,0,0,0.5); }
    h2 { margin: 0 0 8px 0; font-size: 14px; text-transform: uppercase; letter-spacing: 1.5px; color: #ff5555; }
    .stat { display: flex; justify-content: space-between; margin: 4px 0; font-size: 11px; color: #aaa; }
    .stat-val { color: #50fa7b; font-weight: bold; }
    .conflict { color: #ff5555; font-weight: bold; }
    #log { margin-top: 10px; font-size: 10px; height: 60px; overflow-y: auto; border-top: 1px solid #333; padding-top: 6px; color: #8be9fd; }
  `;
  document.head.appendChild(style);

  const container = document.createElement('div');
  container.id = 'canvas-container';
  document.body.appendChild(container);

  const ui = document.createElement('div');
  ui.id = 'ui';
  ui.innerHTML = `
    <h2>Git Topo-Driver</h2>
    <div class="stat"><span>Simulated Commits:</span><span id="c-count" class="stat-val">0</span></div>
    <div class="stat"><span>Active Volcanos (Conflicts):</span><span id="v-count" class="conflict">0</span></div>
    <div class="stat"><span>Total Code Churn:</span><span id="churn-count" class="stat-val">0</span></div>
    <div id="log">> Initializing file system driver...</div>
  `;
  document.body.appendChild(ui);

  // Load Three.js dynamically to guarantee single self-contained script setup
  const script = document.createElement('script');
  script.src = '[https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js](https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js)';
  script.onload = () => initDriver();
  document.head.appendChild(script);

  function initDriver() {
    // 1. Core Scene Setup
    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x06070c);
    scene.fog = new THREE.FogExp2(0x06070c, 0.015);

    const camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 1000);
    camera.position.set(0, 45, 55);

    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(window.innerWidth, window.innerHeight);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;
    container.appendChild(renderer.domElement);

    // 2. Lighting Architecture
    const ambientLight = new THREE.AmbientLight(0x222436, 1.2);
    scene.add(ambientLight);

    const sunLight = new THREE.DirectionalLight(0xfffaed, 0.8);
    sunLight.position.set(30, 60, 20);
    sunLight.castShadow = true;
    scene.add(sunLight);

    // 3. Terrain Grid Data Structure
    const GRID_SIZE = 64;
    const WORLD_SIZE = 80;
    const geometry = new THREE.PlaneGeometry(WORLD_SIZE, WORLD_SIZE, GRID_SIZE - 1, GRID_SIZE - 1);
    geometry.rotateX(-Math.PI / 2);

    // Per-vertex data tracking: height, velocity, churn (mountain elevation), conflict flag (volcano)
    const posAttr = geometry.attributes.position;
    const vertexCount = posAttr.count;
    const terrainData = new Array(vertexCount).fill(0).map(() => ({
      height: 0,
      targetHeight: 0,
      churn: 0,
      isVolcano: false,
      lavaHeat: 0
    }));

    // Color attributes for terrain mapping (Grass -> Rock -> Snow/Lava)
    const colors = new Float32Array(vertexCount * 3);
    geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));

    const material = new THREE.MeshStandardMaterial({
      vertexColors: true,
      roughness: 0.8,
      metalness: 0.2,
      flatShading: true
    });

    const terrainMesh = new THREE.Mesh(geometry, material);
    terrainMesh.receiveShadow = true;
    terrainMesh.castShadow = true;
    scene.add(terrainMesh);

    // Wireframe Overlay for Cyberpunk/Git Aesthetic
    const wireframeMat = new THREE.MeshBasicMaterial({ color: 0x1e2538, wireframe: true, transparent: true, opacity: 0.4 });
    const wireframeMesh = new THREE.Mesh(geometry, wireframeMat);
    wireframeMesh.position.y += 0.05;
    scene.add(wireframeMesh);

    // 4. Volcanic Particle System for Merge Conflict Eruptions
    const maxParticles = 500;
    const particleGeo = new THREE.BufferGeometry();
    const particlePositions = new Float32Array(maxParticles * 3);
    const particleVelocities = [];

    for (let i = 0; i < maxParticles; i++) {
      particlePositions[i * 3] = 0;
      particlePositions[i * 3 + 1] = -100; // Hide initially
      particlePositions[i * 3 + 2] = 0;
      particleVelocities.push(new THREE.Vector3());
    }

    particleGeo.setAttribute('position', new THREE.BufferAttribute(particlePositions, 3));
    const particleMat = new THREE.PointsMaterial({
      color: 0xff3300,
      size: 0.8,
      transparent: true,
      blending: THREE.AdditiveBlending
    });
    const particleSystem = new THREE.Points(particleGeo, particleMat);
    scene.add(particleSystem);

    let activeParticleIdx = 0;
    function triggerEruption(x, y, z) {
      for (let i = 0; i < 25; i++) {
        const idx = (activeParticleIdx + i) % maxParticles;
        particlePositions[idx * 3] = x + (Math.random() - 0.5);
        particlePositions[idx * 3 + 1] = z + 1; // z in grid local = y in world space
        particlePositions[idx * 3 + 2] = y + (Math.random() - 0.5);

        particleVelocities[idx].set(
          (Math.random() - 0.5) * 0.4,
          Math.random() * 0.6 + 0.4,
          (Math.random() - 0.5) * 0.4
        );
      }
      activeParticleIdx = (activeParticleIdx + 25) % maxParticles;
    }

    // 5. Procedural Git Commit Engine (Simulates File System Churn)
    let totalCommits = 0;
    let totalChurn = 0;
    let activeVolcanoes = 0;

    function applyGitCommit() {
      totalCommits++;
      const isMergeConflict = Math.random() < 0.15; // 15% chance of conflict eruption
      const churnMagnitude = Math.floor(Math.random() * 15) + 5;
      totalChurn += churnMagnitude;

      // Select random coordinate on file system terrain plane
      const targetX = Math.floor(Math.random() * GRID_SIZE);
      const targetY = Math.floor(Math.random() * GRID_SIZE);
      const radius = Math.floor(Math.random() * 4) + 2;

      for (let x = -radius; x <= radius; x++) {
        for (let y = -radius; y <= radius; y++) {
          const gx = targetX + x;
          const gy = targetY + y;

          if (gx >= 0 && gx < GRID_SIZE && gy >= 0 && gy < GRID_SIZE) {
            const index = gy * GRID_SIZE + gx;
            const dist = Math.sqrt(x * x + y * y);
            const influence = Math.max(0, 1 - dist / radius);

            terrainData[index].churn += churnMagnitude * influence;
            
            if (isMergeConflict && dist < 1.5) {
              terrainData[index].isVolcano = true;
              terrainData[index].lavaHeat = 1.0;
              terrainData[index].targetHeight += (churnMagnitude * 0.8) + 4; // Sharp volcanic peak
              
              const vx = posAttr.getX(index);
              const vy = posAttr.getZ(index);
              triggerEruption(vx, vy, terrainData[index].targetHeight);
            } else {
              terrainData[index].targetHeight += churnMagnitude * 0.25 * influence;
            }
          }
        }
      }

      // UI Updates
      document.getElementById('c-count').innerText = totalCommits;
      document.getElementById('churn-count').innerText = totalChurn;
      if (isMergeConflict) {
        activeVolcanoes++;
        document.getElementById('v-count').innerText = activeVolcanoes;
        logMessage(`[CONFLICT] Merge failure at block 0x${targetX.toString(16)}${targetY.toString(16)}! Erupting!`);
      } else {
        logMessage(`[COMMIT] Local file modification +${churnMagnitude} lines.`);
      }
    }

    function logMessage(msg) {
      const log = document.getElementById('log');
      log.innerHTML = `> ${msg}<br>` + log.innerHTML;
    }

    // Interval to emulate active Git workspace activity stream
    setInterval(applyGitCommit, 1200);

    // 6. Terrain Color & Mesh Renderer Loop
    const clock = new THREE.Clock();

    function updateTerrain() {
      const positions = posAttr.array;
      const colorAttr = geometry.attributes.color;
      const colorArray = colorAttr.array;

      for (let i = 0; i < vertexCount; i++) {
        const node = terrainData[i];
        
        // Interpolate elevation smoothly (smooth deformation step)
        node.height += (node.targetHeight - node.height) * 0.05;
        positions[i * 3 + 1] = node.height; // Y axis is height

        // Calculate procedural terrain color scheme based on elevation and volcano status
        let r = 0.1, g = 0.4, b = 0.2; // Base valley / low churn (greenish)

        if (node.height > 2 && node.height <= 8) {
          // Foothills / Mid churn (rocky brown)
          r = 0.4; g = 0.3; b = 0.2;
        } else if (node.height > 8) {
          // High churn Mountain Peaks (Snow/Granite)
          r = 0.7; g = 0.7; b = 0.8;
        }

        // Active Volcano Lava Glow Effect
        if (node.isVolcano) {
          node.lavaHeat = Math.max(0, node.lavaHeat - 0.002); // Cool down over time
          r = THREE.MathUtils.lerp(r, 1.0, node.lavaHeat);
          g = THREE.MathUtils.lerp(g, 0.1, node.lavaHeat);
          b = THREE.MathUtils.lerp(b, 0.0, node.lavaHeat);
        }

        colorArray[i * 3] = r;
        colorArray[i * 3 + 1] = g;
        colorArray[i * 3 + 2] = b;
      }

      posAttr.needsUpdate = true;
      colorAttr.needsUpdate = true;
      geometry.computeVertexNormals();
    }

    function updateParticles(delta) {
      const pPos = particleGeo.attributes.position.array;
      for (let i = 0; i < maxParticles; i++) {
        if (pPos[i * 3 + 1] > -50) {
          pPos[i * 3] += particleVelocities[i].x;
          pPos[i * 3 + 1] += particleVelocities[i].y;
          pPos[i * 3 + 2] += particleVelocities[i].z;

          particleVelocities[i].y -= 9.8 * delta * 0.1; // Simulated gravity

          if (pPos[i * 3 + 1] < 0) {
            pPos[i * 3 + 1] = -100; // Reset particle below ground level
          }
        }
      }
      particleGeo.attributes.position.needsUpdate = true;
    }

    // Camera Orbit Controller
    let angle = 0;
    function animate() {
      requestAnimationFrame(animate);
      const delta = clock.getDelta();

      // Slow cinematic camera rotation around procedural map center
      angle += 0.002;
      camera.position.x = Math.sin(angle) * 65;
      camera.position.z = Math.cos(angle) * 65;
      camera.lookAt(0, 5, 0);

      updateTerrain();
      updateParticles(delta);

      renderer.render(scene, camera);
    }

    // Responsive Canvas Resizing
    window.addEventListener('resize', () => {
      camera.aspect = window.innerWidth / window.innerHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(window.innerWidth, window.innerHeight);
    });

    // Start simulation loop
    animate();
  }
})();