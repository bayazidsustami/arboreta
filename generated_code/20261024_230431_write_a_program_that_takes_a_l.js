// Bird-Song Brainfuck Metacompiler & Vector Mandala Engine
(async () => {
  // Create immersive fullscreen canvas for vector mandala rendering
  const canvas = document.createElement('canvas');
  canvas.style.position = 'fixed';
  canvas.style.top = '0';
  canvas.style.left = '0';
  canvas.style.width = '100vw';
  canvas.style.height = '100vh';
  canvas.style.background = '#0a0a0f';
  canvas.style.zIndex = '99999';
  document.body.appendChild(canvas);
  
  const ctx = canvas.getContext('2d');
  let width = canvas.width = window.innerWidth;
  let height = canvas.height = window.innerHeight;
  
  window.addEventListener('resize', () => {
    width = canvas.width = window.innerWidth;
    height = canvas.height = window.innerHeight;
  });

  // Initialize Web Audio API to capture local audio stream of bird songs
  let audioCtx, analyser, dataArray;
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    const source = audioCtx.createMediaStreamSource(stream);
    analyser = audioCtx.createAnalyser();
    analyser.fftSize = 256;
    source.connect(analyser);
    dataArray = new Uint8Array(analyser.frequencyBinCount);
  } catch (e) {
    console.warn('Microphone access unavailable. Engaging synthetic avian harmonics simulator.');
  }

  // Define an esoteric dialect of Brainfuck with mutated tokens
  const dialectSymbols = {
    right: '>', left: '<', inc: '+', dec: '-',
    out: '.', in: ':', loopStart: '«', loopEnd: '»'
  };

  let programCode = "";
  let angleOffset = 0;

  // Continuously compile frequency spectrum into esoteric Brainfuck instructions
  function compileBirdSongToDialect(freqData) {
    if (!freqData) return '';
    let code = '';
    for (let i = 0; i < freqData.length; i += 4) {
      const val = freqData[i];
      const opIndex = val % 7;
      switch(opIndex) {
        case 0: code += dialectSymbols.right; break;
        case 1: code += dialectSymbols.left; break;
        case 2: code += dialectSymbols.inc; break;
        case 3: code += dialectSymbols.dec; break;
        case 4: code += dialectSymbols.out; break;
        case 5: code += dialectSymbols.loopStart; break;
        case 6: code += dialectSymbols.loopEnd; break;
      }
    }
    return code;
  }

  // Draw shifting vector mandalas reactive to audio and code evolution
  function drawMandala(avgFreq, highFreq) {
    ctx.fillStyle = 'rgba(10, 10, 15, 0.15)';
    ctx.fillRect(0, 0, width, height);

    ctx.save();
    ctx.translate(width / 2, height / 2);
    
    const petals = 12;
    const radius = 100 + avgFreq * 1.5;
    angleOffset += 0.01 + (highFreq * 0.0005);

    for (let i = 0; i < petals; i++) {
      ctx.save();
      ctx.rotate((Math.PI * 2 / petals) * i + angleOffset);
      
      ctx.beginPath();
      ctx.strokeStyle = `hsl(${(i * 30 + angleOffset * 50) % 360}, 80%, 60%)`;
      ctx.lineWidth = 1.5;

      for (let t = 0; t < Math.PI; t += 0.1) {
        const x = Math.sin(t) * radius * Math.cos(highFreq * 0.01);
        const y = Math.cos(t * 2) * (radius * 0.5);
        if (t === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.stroke();
      ctx.restore();
    }

    // Render real-time esoteric bytecode stream onto the display
    ctx.fillStyle = '#00ffcc';
    ctx.font = '12px monospace';
    ctx.fillText(`ESOTERIC BF STREAM: ${programCode.slice(-60)}`, -width / 3, height / 2 - 40);

    ctx.restore();
  }

  // Main execution loop
  function loop() {
    requestAnimationFrame(loop);

    let avg = 50;
    let high = 20;

    if (analyser && dataArray) {
      analyser.getByteFrequencyData(dataArray);
      let sum = 0;
      for (let i = 0; i < dataArray.length; i++) sum += dataArray[i];
      avg = sum / dataArray.length;
      high = dataArray[dataArray.length - 1];
    } else {
      avg = 40 + Math.sin(Date.now() * 0.005) * 30;
      high = Math.random() * 50;
    }

    programCode += compileBirdSongToDialect(dataArray || new Uint8Array([Math.floor(avg)]));
    if (programCode.length > 500) programCode = programCode.slice(-500);

    drawMandala(avg, high);
  }

  loop();
})();