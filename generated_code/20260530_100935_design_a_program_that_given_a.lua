local html = [[
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Synesthetic Kaleido</title>
<style>
body,html{margin:0;padding:0;overflow:hidden;background:#111}
#canvas{position:absolute;top:0;left:0;width:100%;height:100%}
#video{display:none}
</style>
</head>
<body>
<video id="video" autoplay playsinline></video>
<canvas id="canvas"></canvas>
<script>
// ---- CONFIG ----
const scale = {
    // simple major scale mapping (C,E,G,A,B,D,F)
    // each entry is a frequency in Hz
    0:261.63, // C4
    1:329.63, // E4
    2:392.00, // G4
    3:440.00, // A4
    4:493.88, // B4
    5:587.33, // D5
    6:698.46  // F5
};
const chordMap = [
    [0,2,4], // C major
    [1,3,5],
    [2,4,6],
    [3,5,0],
    [4,6,1],
    [5,0,2],
    [6,1,3]
];
const tensionCurve = t=>Math.sin(t*0.5)*0.5+0.5; // 0..1

// ---- AUDIO ----
const AudioContext = window.AudioContext||window.webkitAudioContext;
const ctx = new AudioContext();
let masterGain = ctx.createGain();
masterGain.gain.value = 0.2;
masterGain.connect(ctx.destination);

// generate chord tone
function playChord(paletteIdx){
    const now = ctx.currentTime;
    const chord = chordMap[paletteIdx%chordMap.length];
    chord.forEach(i=>{
        const osc = ctx.createOscillator();
        osc.type='sine';
        osc.frequency.value = scale[i];
        osc.connect(masterGain);
        osc.start(now);
        osc.stop(now+0.6);
    });
}

// ---- VIDEO & COLOR ----
const video = document.getElementById('video');
navigator.mediaDevices.getUserMedia({video:true}).then(s=>{video.srcObject=s});
const hidden = document.createElement('canvas');
hidden.width=64; hidden.height=48;
const hctx = hidden.getContext('2d');

// simple k‑means (2 clusters) for dominant colors
function getPalette(){
    hctx.drawImage(video,0,0,hidden.width,hidden.height);
    const data = hctx.getImageData(0,0,hidden.width,hidden.height).data;
    let c1=[255,0,0],c2=[0,255,0];
    for(let iter=0; iter<5; iter++){
        let sum1=[0,0,0],sum2=[0,0,0],cnt1=0,cnt2=0;
        for(let i=0;i<data.length;i+=4){
            const p=[data[i],data[i+1],data[i+2]];
            const d1=(p[0]-c1[0])**2+(p[1]-c1[1])**2+(p[2]-c1[2])**2;
            const d2=(p[0]-c2[0])**2+(p[1]-c2[1])**2+(p[2]-c2[2])**2;
            if(d1<d2){
                sum1[0]+=p[0];sum1[1]+=p[1];sum1[2]+=p[2];cnt1++;
            }else{
                sum2[0]+=p[0];sum2[1]+=p[1];sum2[2]+=p[2];cnt2++;
            }
        }
        if(cnt1) c1=sum1.map(v=>v/cnt1);
        if(cnt2) c2=sum2.map(v=>v/cnt2);
    }
    // return brighter cluster index
    const bright = (c)=>0.2126*c[0]+0.7152*c[1]+0.0722*c[2];
    return bright(c1)>bright(c2)?0:1;
}

// ---- KALO ----
const canvas = document.getElementById('canvas');
const ctx2 = canvas.getContext('2d');
let t=0;
function draw(){
    const w=canvas.width=window.innerWidth;
    const h=canvas.height=window.innerHeight;
    const paletteIdx=getPalette();
    playChord(paletteIdx);
    const tension=tensionCurve(t);
    ctx2.clearRect(0,0,w,h);
    ctx2.save();
    ctx2.translate(w/2,h/2);
    const sides=6+Math.round(tension*6);
    const radius=Math.min(w,h)*0.4;
    for(let i=0;i<sides;i++){
        const angle=i*2*Math.PI/sides;
        ctx2.rotate(angle);
        ctx2.beginPath();
        ctx2.moveTo(0,0);
        ctx2.lineTo(radius*Math.cos(t*0.03), radius*Math.sin(t*0.07));
        ctx2.strokeStyle=`hsl(${(t*5+i*30)%360},80%,${50+30*tension}%)`;
        ctx2.lineWidth=2+tension*4;
        ctx2.stroke();
        ctx2.rotate(-angle);
    }
    ctx2.restore();
    t+=0.05;
    requestAnimationFrame(draw);
}
window.addEventListener('resize',()=>{canvas.width=window.innerWidth;canvas.height=window.innerHeight;});
video.addEventListener('playing',()=>{requestAnimationFrame(draw);});
</script>
</body>
</html>
]]

local file = io.open("synesthetic_kaleido.html","w")
file:write(html)
file:close()
print("Generated synesthetic_kaleido.html – open it in a browser.")