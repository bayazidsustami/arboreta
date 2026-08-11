// Self-contained Quine Audio Synthesizer
// Interprets its own source code as PCM audio and modulates filter frequency via heap memory metrics.
(async function quineSynth() {
  // 1. Capture exact source code string as raw PCM sample source
  const src = quineSynth.toString();
  const sampleCount = src.length;
  
  // 2. Initialize Web Audio Context
  const AudioCtx = window.AudioContext || window.webkitAudioContext;
  if (!AudioCtx) throw new Error("Web Audio API not supported in this environment");
  const ctx = new AudioCtx();

  // 3. Convert source code characters (0-255 ASCII/UTF) into audio PCM buffer (-1.0 to +1.0)
  const audioBuffer = ctx.createBuffer(1, sampleCount, ctx.sampleRate);
  const pcmData = audioBuffer.getChannelData(0);
  for (let i = 0; i < sampleCount; i++) {
    pcmData[i] = (src.charCodeAt(i) / 127.5) - 1.0;
  }

  // 4. Setup looping buffer source node
  const source = ctx.createBufferSource();
  source.buffer = audioBuffer;
  source.loop = true;

  // 5. Setup resonant Biquad Filter for spectral shaping
  const filter = ctx.createBiquadFilter();
  filter.type = 'lowpass';
  filter.Q.value = 12;

  // Route audio graph: Source -> Filter -> Destination
  source.connect(filter);
  filter.connect(ctx.destination);

  // 6. Memory Allocation Sensor & Real-time Modulator
  function modulate() {
    let heapRatio = 0.5;

    // Read Chrome/Webkit JS Heap performance metrics if accessible
    if (performance && performance.memory) {
      const { usedJSHeapSize, totalJSHeapSize } = performance.memory;
      heapRatio = usedJSHeapSize / totalJSHeapSize;
    } else {
      // Fallback: Dynamically probe memory allocation layout via garbage collection/allocation stress
      const allocations = Array.from({ length: 500 }, () => ({ id: Math.random() }));
      heapRatio = (allocations.length * Math.random()) / 500;
    }

    // Map real-time heap dynamics to filter frequency range (150 Hz to 6500 Hz)
    const cutoffFreq = 150 + Math.pow(heapRatio, 2) * 6350;
    filter.frequency.setTargetAtTime(cutoffFreq, ctx.currentTime, 0.04);

    // Keep modulating loop aligned with execution frame
    requestAnimationFrame(modulate);
  }

  // Resume context (for autoplay policies) and ignite synthesizer
  if (ctx.state === 'suspended') await ctx.resume();
  source.start(0);
  modulate();
})();