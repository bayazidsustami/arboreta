// Simple live‑audio visualizer that maps frequency bins to glyph‑clusters and scrolls them as text
(async()=>{ // main async IIFE
  // get microphone
  const stream=await navigator.mediaDevices.getUserMedia({audio:true});
  const audioCtx=new (window.AudioContext||webkitAudioContext)();
  const source=audioCtx.createMediaStreamSource(stream);
  const analyser=audioCtx.createAnalyser();
  analyser.fftSize=256; // 128 bins
  source.connect(analyser);
  const data=new Uint8Array(analyser.frequencyBinCount);
  // glyph‑clusters (base + combining chars) – extend as desired
  const glyphs=[
    "𝔊͓̙⃟","𝕏̾ͤͦ","🜂̾͂","𝔉͙⃜","𝔖͖̤","🜏̖͚","𝔏͓͖","𝔇̤͛","🜍͚͖","𝔑͖⃟"
  ];
  // create a hidden pre element for scrolling text
  const pre=document.createElement('pre');
  pre.style.position='fixed';
  pre.style.bottom='0';
  pre.style.left='0';
  pre.style.right='0';
  pre.style.height='1.2em';
  pre.style.margin='0';
  pre.style.padding='0 1ch';
  pre.style.overflow='hidden';
  pre.style.whiteSpace='nowrap';
  pre.style.fontFamily='monospace';
  pre.style.fontSize='1.6rem';
  pre.style.lineHeight='1.2';
  pre.style.background='black';
  pre.style.color='lime';
  document.body.appendChild(pre);
  // buffer holding the scrolling line
  let line='';
  // mapping function: amplitude→glyph
  const ampToGlyph=amp=>glyphs[Math.floor(amp/256*glyphs.length)];
  // animation loop
  function draw(){
    analyser.getByteFrequencyData(data);
    // build a slice of glyphs for this frame
    let slice='';
    for(let i=0;i<data.length;i++){
      slice+=ampToGlyph(data[i]);
    }
    line+=slice; // append new slice
    // wrap horizontally: keep only last N characters (approx screen width)
    const maxLen=Math.floor(window.innerWidth/10)*glyphs.length; // rough estimate
    if(line.length>maxLen) line=line.slice(line.length-maxLen);
    pre.textContent=line;
    requestAnimationFrame(draw);
  }
  draw();
})();