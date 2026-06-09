import http.server, socketserver, threading, os, sys, webbrowser, time, pathlib, json, base64, hashlib, shutil, subprocess, textwrap

PORT = 8000
ROOT = pathlib.Path(__file__).parent.resolve()

HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Audio‑Driven Voronoi</title>
<style>body,html{margin:0;height:100%;overflow:hidden;background:#000}</style>
</head>
<body>
<canvas id="glcanvas"></canvas>
<button id="rec" style="position:absolute;top:10px;left:10px;">⏺ Record</button>
<script>
const canvas = document.getElementById('glcanvas');
canvas.width = innerWidth; canvas.height = innerHeight;
const gl = canvas.getContext('webgl2');
if (!gl) { alert('WebGL2 not supported'); }

const vertexSrc = `#version 300 es
in vec2 aPos;
out vec2 vUv;
void main(){vUv=aPos*0.5+0.5;gl_Position=vec4(aPos,0,1);}`;
const fragmentSrc = `#version 300 es
precision highp float;
in vec2 vUv;
out vec4 fragColor;
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iAudio;
float rand(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
float voronoi(vec2 uv, out vec3 col){
    vec2 p = uv*5.0;
    vec2 i = floor(p);
    vec2 f = fract(p);
    float minDist = 8.0;
    vec2 nearest;
    for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++){
        vec2 g = vec2(x,y);
        vec2 point = hash(i+g);
        vec2 diff = g+point-f;
        float d = length(diff);
        if(d<minDist){minDist=d;nearest=point;}
    }
    col = vec3(rand(i+nearest),rand(i+nearest*2.0),rand(i+nearest*3.0));
    return minDist;
}
vec2 hash(vec2 p){
    p = fract(p*0.1031);
    p += dot(p, p+33.33);
    return fract((vec2(269.5,183.3)*p));
}
void main(){
    vec3 color;
    float d = voronoi(vUv, color);
    float audio = texture(iAudio, vec2(vUv.x,0.0)).r;
    float beat = smoothstep(0.5,1.0, audio);
    color = mix(color, vec3(1.0,0.6,0.2), beat);
    fragColor = vec4(color/d*0.5,1.0);
}`;
function compileShader(src, type){
    const sh = gl.createShader(type);
    gl.shaderSource(sh, src);
    gl.compileShader(sh);
    if(!gl.getShaderParameter(sh, gl.COMPILE_STATUS))
        console.error(gl.getShaderInfoLog(sh));
    return sh;
}
const prog = gl.createProgram();
gl.attachShader(prog, compileShader(vertexSrc, gl.VERTEX_SHADER));
gl.attachShader(prog, compileShader(fragmentSrc, gl.FRAGMENT_SHADER));
gl.linkProgram(prog);
gl.useProgram(prog);
const posLoc = gl.getAttribLocation(prog, 'aPos');
const quad = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, quad);
gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1,-1, 1,-1, -1,1, 1,1]), gl.STATIC_DRAW);
gl.enableVertexAttribArray(posLoc);
gl.vertexAttribPointer(posLoc,2,gl.FLOAT,false,0,0);
const timeLoc = gl.getUniformLocation(prog,'iTime');
const resLoc = gl.getUniformLocation(prog,'iResolution');
const audioTexLoc = gl.getUniformLocation(prog,'iAudio');

const audioTex = gl.createTexture();
gl.bindTexture(gl.TEXTURE_2D, audioTex);
gl.texImage2D(gl.TEXTURE_2D,0,gl.R8,256,1,0,gl.RED,gl.UNSIGNED_BYTE,null);
gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);
gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);
gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);

let audioData = new Uint8Array(256);
navigator.mediaDevices.getUserMedia({audio:true}).then(stream=>{
    const ctx = new AudioContext();
    const analyser = ctx.createAnalyser();
    analyser.fftSize = 512;
    const source = ctx.createMediaStreamSource(stream);
    source.connect(analyser);
    const data = new Uint8Array(analyser.frequencyBinCount);
    function updateAudio(){
        analyser.getByteFrequencyData(data);
        for(let i=0;i<256;i++) audioData[i]=data[i];
        gl.bindTexture(gl.TEXTURE_2D, audioTex);
        gl.texSubImage2D(gl.TEXTURE_2D,0,0,0,256,1,gl.RED,gl.UNSIGNED_BYTE,audioData);
        requestAnimationFrame(updateAudio);
    }
    updateAudio();
});

let start = performance.now();
function render(){
    const now = (performance.now()-start)/1000;
    gl.viewport(0,0,canvas.width,canvas.height);
    gl.uniform1f(timeLoc, now);
    gl.uniform2f(resLoc, canvas.width, canvas.height);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, audioTex);
    gl.uniform1i(audioTexLoc,0);
    gl.drawArrays(gl.TRIANGLE_STRIP,0,4);
    requestAnimationFrame(render);
}
render();

let mediaRecorder, chunks=[];
document.getElementById('rec').onclick=()=> {
    if(mediaRecorder && mediaRecorder.state==='recording'){
        mediaRecorder.stop();
        return;
    }
    const stream = canvas.captureStream(30);
    mediaRecorder = new MediaRecorder(stream,{mimeType:'video/webm'});
    mediaRecorder.ondataavailable=e=>chunks.push(e.data);
    mediaRecorder.onstop=()=> {
        const blob = new Blob(chunks,{type:'video/webm'});
        const url = URL.createObjectURL(blob);
        const a=document.createElement('a'); a.href=url; a.download='voronoi.webm'; a.click();
        chunks=[];
    };
    mediaRecorder.start();
};
</script>
</body>
</html>
"""

def write_files():
    (ROOT/'index.html').write_text(HTML, encoding='utf-8')
    # minimal placeholder for favicon etc.
    (ROOT/'favicon.ico').write_bytes(b'')
    
class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=str(ROOT), **kw)

def serve():
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"Serving at http://localhost:{PORT}")
        threading.Thread(target=lambda: webbrowser.open(f'http://localhost:{PORT}'), daemon=True).start()
        httpd.serve_forever()

if __name__=="__main__":
    write_files()
    try:
        serve()
    except KeyboardInterrupt:
        sys.exit()