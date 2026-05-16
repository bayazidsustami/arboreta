(() => {
  constcanvas = document.createElement('canvas');
  document.body.style.margin = '0';
  document.body.appendChild(canvas);
  const ctx = canvas.getContext('2d');
  const resize = () => { canvas.width = window.innerWidth; canvas.height = window.innerHeight; };
  window.addEventListener('resize', resize);
  resize();

  const words = ["whisper","echo","dream","shadow","glow","silence","fire","rain","star","bound"];
  const syllableBank = ["ba","ri","lu","ti","na","ka","mo","ro","vi","go","su","lu","zu","fe","xe","ko","tu","na","ba"];
  const particleCount = words.length;
  const particles = Array.from({length: particleCount}, () => {
    const angle = Math.random()*Math.PI*2;
    const speed = 0.5 + Math.random()*1.5;
    return {
      x: Math.random()*canvas.width,
      y: Math.random()*canvas.height,
      vx: Math.cos(angle)*speed,
      vy: Math.sin(angle)*speed,
      ax: 0,
      ay: 0,
      speed: speed,
      wordIdx: 0,
      word: ''
    };
  });
  particles.forEach((p,i)=>{ p.wordIdx=i; p.word=words[i]; });

  const positive = ["love","happy","joy","light","peace","free","bright","warm","good","nice"];
  const negative = ["hate","sad","pain","dark","cold","sorrow","bad","angry","mad","dark"];
  function getSentiment(txt){
    const lower = txt.toLowerCase();
    let pos=0, neg=0;
    positive.forEach(w=>{ if(lower.includes(w)) pos++; });
    negative.forEach(w=>{ if(lower.includes(w)) neg++; });
    return Math.max(-1, Math.min(1, (pos-neg)/(positive.length+negative.length)));
  }
  const userInput = prompt('Enter text to influence the poem sentiment:');
  const sentimentScore = userInput ? getSentiment(userInput) : 0;
  const hueColor = Math.round(240 - sentimentScore*120);

  let frame = 0;
  function animate(){
    particles.forEach(p=>{
      p.ax = (Math.random()-0.5)*0.05;
      p.ay = (Math.random()-0.5)*0.05;
      p.vx += p.ax;
      p.vy += p.ay;
      const sp = Math.hypot(p.vx, p.vy);
      if(sp>3){ p.vx*=0.9; p.vy*=0.9; }
      p.x += p.vx;
      p.y += p.vy;
      if(p.x<0){ p.x=0; p.vx*=-0.5; }
      if(p.x>canvas.width){ p.x=canvas.width; p.vx*=-0.5; }
      if(p.y<0){ p.y=0; p.vy*=-0.5; }
      if(p.y>canvas.height){ p.y=canvas.height; p.vy*=-0.5; }
      p.speed = sp;
    });
    const avgSpeed = particles.reduce((s,p)=>s+p.speed,0)/particles.length;
    const syllableCount = Math.max(4, Math.min(12, Math.round(avgSpeed*2)));
    const wordIdx = frame % words.length;
    const curWord = words[wordIdx];
    const curParticle = particles[wordIdx];
    const minSp = 0.1, maxSp = 3;
    const opacity = Math.max(0.2, Math.min(1, (curParticle.speed-minSp)/(maxSp-minSp)));
    ctx.clearRect(0,0,canvas.width,canvas.height);
    ctx.font = '48px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = `hsla(${hueColor}, 80%, 60%, ${opacity})`;
    ctx.fillText(curWord, canvas.width/2, canvas.height/2);
    const syllables = Array.from({length:syllableCount},()=> syllableBank[Math.floor(Math.random()*syllableBank.length)]);
    ctx.fillStyle = `hsla(${hueColor}, 80%, 60%, ${opacity*0.6})`;
    ctx.font = '24px sans-serif';
    ctx.fillText(syllables.join(' '), canvas.width/2, canvas.height/2+40);
    console.log(syllables.join(' ') + ' ' + curWord);
    frame++;
    requestAnimationFrame(animate);
  }
  requestAnimationFrame(animate);
})();