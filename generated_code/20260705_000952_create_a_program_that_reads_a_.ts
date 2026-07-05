// main.ts - self‑contained browser script
// Reads webcam, extracts dominant colors, maps to notes, plays them,
// draws a kaleidoscopic fractal synced to music, and offers SVG download.

(async () => {
  // ==== Setup DOM ====
  const video = document.createElement('video');
  video.autoplay = true;
  video.playsInline = true;
  document.body.appendChild(video);

  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d')!;
  document.body.appendChild(canvas);

  const svgContainer = document.createElement('div');
  document.body.appendChild(svgContainer);

  const downloadBtn = document.createElement('button');
  downloadBtn.textContent = 'Download SVG';
  document.body.appendChild(downloadBtn);

  // ==== Get webcam stream ====
  const stream = await navigator.mediaDevices.getUserMedia({ video: true });
  video.srcObject = stream;
  await new Promise(r => video.onloadedmetadata = r);

  // Set canvas size to video size
  canvas.width = video.videoWidth;
  canvas.height = video.videoHeight;
  canvas.style.display = 'none'; // hide raw canvas

  // ==== Audio context ====
  const audioCtx = new (window.AudioContext || (window as any).webkitAudioContext)();
  const masterGain = audioCtx.createGain();
  masterGain.gain.value = 0.2;
  masterGain.connect(audioCtx.destination);

  // ==== Custom note scale (C minor pentatonic) ====
  const baseFreq = 261.63; // C4
  const intervals = [0, 3, 5, 7, 10]; // semitones
  const notes = intervals.map(i => baseFreq * Math.pow(2, i / 12));

  // ==== Simple k‑means for dominant colors (2 clusters) ====
  function dominantColors(imgData: ImageData): [number, number, number][] {
    const data = imgData.data;
    // initialize two random centroids
    let c1 = [Math.random() * 255, Math.random() * 255, Math.random() * 255];
    let c2 = [Math.random() * 255, Math.random() * 255, Math.random() * 255];
    for (let iter = 0; iter < 5; iter++) {
      let sum1 = [0, 0, 0], sum2 = [0, 0, 0];
      let cnt1 = 0, cnt2 = 0;
      for (let i = 0; i < data.length; i += 4) {
        const r = data[i], g = data[i+1], b = data[i+2];
        const d1 = (r-c1[0])**2 + (g-c1[1])**2 + (b-c1[2])**2;
        const d2 = (r-c2[0])**2 + (g-c2[1])**2 + (b-c2[2])**2;
        if (d1 < d2) {
          sum1[0] += r; sum1[1] += g; sum1[2] += b; cnt1++;
        } else {
          sum2[0] += r; sum2[1] += g; sum2[2] += b; cnt2++;
        }
      }
      if (cnt1) c1 = sum1.map(v=>v/cnt1) as any;
      if (cnt2) c2 = sum2.map(v=>v/cnt2) as any;
    }
    return [c1 as any, c2 as any];
  }

  // ==== Map RGB to note index ====
  function colorToNoteIdx([r,g,b]: number[]): number {
    // simple luminance based mapping
    const lum = 0.2126*r + 0.7152*g + 0.0722*b;
    return Math.floor((lum/255) * notes.length) % notes.length;
  }

  // ==== Fractal generation (recursive circles) ====
  function drawFractal(svg: SVGSVGElement, cx: number, cy: number, r: number, depth: number, hue: number) {
    if (depth === 0) return;
    const circle = document.createElementNS('http://www.w3.org/2000/svg','circle');
    circle.setAttribute('cx', cx.toString());
    circle.setAttribute('cy', cy.toString());
    circle.setAttribute('r', r.toString());
    circle.setAttribute('fill', `hsl(${hue},80%,60%)`);
    svg.appendChild(circle);
    const angleStep = Math.PI/3;
    for (let a = 0; a < 2*Math.PI; a += angleStep) {
      const nx = cx + Math.cos(a)*r*0.6;
      const ny = cy + Math.sin(a)*r*0.6;
      drawFractal(svg, nx, ny, r*0.4, depth-1, (hue+30)%360);
    }
  }

  // ==== Main loop ====
  function tick() {
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
    const img = ctx.getImageData(0,0,canvas.width,canvas.height);
    const domColors = dominantColors(img);
    // schedule notes for each dominant color
    domColors.forEach(col => {
      const idx = colorToNoteIdx(col);
      const freq = notes[idx];
      const osc = audioCtx.createOscillator();
      osc.type = 'sine';
      osc.frequency.value = freq;
      osc.connect(masterGain);
      osc.start();
      osc.stop(audioCtx.currentTime + 0.2);
    });

    // Draw kaleidoscopic fractal synced to average luminance
    const avgLum = domColors.reduce((s,c)=>s+0.2126*c[0]+0.7152*c[1]+0.0722*c[2],0)/domColors.length;
    const hue = (avgLum/255)*360;
    const size = Math.min(canvas.width,canvas.height)/2;
    const svgNS = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(svgNS,'svg');
    svg.setAttribute('width', canvas.width.toString());
    svg.setAttribute('height', canvas.height.toString());
    drawFractal(svg, canvas.width/2, canvas.height/2, size*0.5, 3, hue);
    // replace previous visual
    svgContainer.innerHTML = '';
    svgContainer.appendChild(svg);
    requestAnimationFrame(tick);
  }

  // ==== Download handler ====
  downloadBtn.onclick = () => {
    const svg = svgContainer.querySelector('svg');
    if (!svg) return;
    const serializer = new XMLSerializer();
    const source = serializer.serializeToString(svg);
    const blob = new Blob([source], {type:'image/svg+xml;charset=utf-8'});
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'fractal.svg';
    a.click();
    URL.revokeObjectURL(url);
  };

  // start audio context on user interaction
  document.body.addEventListener('click', () => audioCtx.resume(), {once:true});
  requestAnimationFrame(tick);
})();