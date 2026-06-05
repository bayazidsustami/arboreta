// Self‑contained script – include after three.js, dat.gui and @tonejs/midi CDN scripts in HTML
// <script src="https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.min.js"></script>
// <script src="https://cdn.jsdelivr.net/npm/three@0.160.0/examples/js/controls/OrbitControls.js"></script>
// <script src="https://cdn.jsdelivr.net/npm/dat.gui@0.7.9/build/dat.gui.min.js"></script>
// <script src="https://cdn.jsdelivr.net/npm/@tonejs/midi@2.0.27/build/TonejsMidi.min.js"></script>

(() => {
    const URL = new URL(location);
    const midiUrl = URL.searchParams.get('midi') || 'example.mid'; // supply ?midi=path.mid

    // ----- Three.js setup ----------------------------------------------------
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(60, innerWidth / innerHeight, 0.1, 1000);
    camera.position.set(0, 30, 80);
    const renderer = new THREE.WebGLRenderer({ antialias: true });
    renderer.setSize(innerWidth, innerHeight);
    document.body.style.margin = 0;
    document.body.appendChild(renderer.domElement);
    const controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;

    // Light
    const light = new THREE.PointLight(0xffffff, 2);
    light.position.set(0, 50, 0);
    scene.add(light);
    scene.add(new THREE.AmbientLight(0x404040));

    // ----- Global state -------------------------------------------------------
    const notes = []; // {time, duration, pitch, velocity, program}
    const systems = []; // visual particle systems
    let startTime = null;
    const state = {
        tempo: 120,            // BPM
        transpose: 0,          // semitones
        play: true
    };

    // ----- Load MIDI -----------------------------------------------------------
    fetch(midiUrl)
        .then(r => r.arrayBuffer())
        .then(buf => {
            const midi = new TonejsMidi.Midi(buf);
            midi.tracks.forEach(track => {
                const program = track.instrumentNumber || 0;
                track.notes.forEach(n => notes.push({
                    time: n.time,
                    duration: n.duration,
                    pitch: n.midi,
                    velocity: n.velocity,
                    program
                }));
            });
            notes.sort((a, b) => a.time - b.time);
            initVisualization();
            animate();
        })
        .catch(err => console.error('MIDI load error', err));

    // ----- Helpers -------------------------------------------------------------
    const pitchToColor = p => {
        const hue = (p % 12) / 12 * 360;
        return new THREE.Color(`hsl(${hue},80%,60%)`);
    };
    const programToMotion = prog => {
        const speed = 0.2 + (prog % 8) * 0.05;
        const axis = new THREE.Vector3(
            (prog % 3) - 1,
            ((prog >> 2) % 3) - 1,
            ((prog >> 4) % 3) - 1
        ).normalize();
        return { speed, axis };
    };

    // ----- Create particle system for a note -----------------------------------
    function spawnSystem(note) {
        const count = Math.max(32, Math.floor(note.velocity * 200));
        const geometry = new THREE.BufferGeometry();
        const positions = new Float32Array(count * 3);
        const scales = new Float32Array(count);
        for (let i = 0; i < count; i++) {
            const theta = Math.random() * Math.PI * 2;
            const phi = Math.acos(2 * Math.random() - 1);
            const r = Math.pow(Math.random(), 0.5) * 5;
            positions[i * 3] = r * Math.sin(phi) * Math.cos(theta);
            positions[i * 3 + 1] = r * Math.sin(phi) * Math.sin(theta);
            positions[i * 3 + 2] = r * Math.cos(phi);
            scales[i] = Math.random() * 0.5 + 0.5;
        }
        geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
        geometry.setAttribute('scale', new THREE.BufferAttribute(scales, 1));

        const material = new THREE.ShaderMaterial({
            uniforms: {
                uColor: { value: pitchToColor(note.pitch + state.transpose) },
                uTime: { value: 0 }
            },
            vertexShader: `
                attribute float scale;
                varying vec3 vPos;
                void main(){
                    vPos = position;
                    vec4 mvPos = modelViewMatrix * vec4(position,1.0);
                    gl_PointSize = scale * (300.0 / -mvPos.z);
                    gl_Position = projectionMatrix * mvPos;
                }
            `,
            fragmentShader: `
                uniform vec3 uColor;
                varying vec3 vPos;
                void main(){
                    float d = length(gl_PointCoord - 0.5);
                    if (d > 0.5) discard;
                    gl_FragColor = vec4(uColor, 1.0 - d);
                }
            `,
            transparent: true,
            depthWrite: false,
            blending: THREE.AdditiveBlending
        });

        const points = new THREE.Points(geometry, material);
        points.userData = {
            birth: performance.now(),
            life: note.duration * 1000 * (120 / state.tempo),
            motion: programToMotion(note.program),
            startPos: new THREE.Vector3(
                (note.pitch % 12 - 6) * 2,
                note.velocity * 20,
                (note.program - 32) * 0.5
            )
        };
        points.position.copy(points.userData.startPos);
        scene.add(points);
        systems.push(points);
    }

    // ----- Initialize UI -------------------------------------------------------
    function initGUI() {
        const gui = new dat.GUI();
        gui.add(state, 'tempo', 30, 240, 1).name('Tempo (BPM)');
        gui.add(state, 'transpose', -12, 12, 1).name('Transpose');
        gui.add(state, 'play').name('Play');
    }
    initGUI();

    // ----- Visualization driver ------------------------------------------------
    function initVisualization() {
        // pre‑spawn first notes to avoid initial silence
        notes.forEach(n => {
            if (n.time < 0.5) spawnSystem(n);
        });
    }

    function animate(ts) {
        requestAnimationFrame(animate);
        if (!startTime) startTime = ts;
        const elapsed = (ts - startTime) / 1000; // seconds
        const beatSec = 60 / state.tempo;

        // schedule notes
        if (state.play) {
            notes.forEach(n => {
                const noteTime = (n.time + state.transpose / 12) * (120 / state.tempo);
                if (noteTime <= elapsed && noteTime + n.duration * (120 / state.tempo) > elapsed) {
                    // check not already spawned
                    if (!n.spawned) {
                        spawnSystem(n);
                        n.spawned = true;
                    }
                }
            });
        }

        // update particle systems
        const now = performance.now();
        for (let i = systems.length - 1; i >= 0; i--) {
            const sys = systems[i];
            const data = sys.userData;
            const age = now - data.birth;
            if (age > data.life) {
                scene.remove(sys);
                systems.splice(i, 1);
                continue;
            }
            // simple orbital motion
            const theta = age * 0.001 * data.motion.speed;
            sys.position.addScaledVector(data.motion.axis, Math.sin(theta) * 0.05);
            sys.material.uniforms.uTime.value = age * 0.001;
            sys.material.uniforms.uColor.value = pitchToColor(sys.material.uniforms.uColor.value.getHSL().h * 360 + state.transpose);
        }

        controls.update();
        renderer.render(scene, camera);
    }

    // ----- Resize handling -----------------------------------------------------
    window.addEventListener('resize', () => {
        camera.aspect = innerWidth / innerHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(innerWidth, innerHeight);
    });
})();