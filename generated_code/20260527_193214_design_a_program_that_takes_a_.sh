#!/usr/bin/env bash
# Synesthetic Live Installation – Bash orchestrator
# Requires: ffmpeg, python3, pygame, numpy, opencv-python, scikit-learn, pyaudio, moderngl, pyrr
# Captures webcam, extracts palette, drives audio and 3D visualisation.

set -euo pipefail

#--- Configuration ---
CAM_DEVICE=${CAM_DEVICE:-0}          # webcam index
FPS=${FPS:-15}                       # processing frame rate
PALETTE_SIZE=${PALETTE_SIZE:-5}      # number of dominant colors
PY_SCRIPT="/tmp/synesthetic_core.py"

#--- Create the Python core (runs audio + 3D) ---
cat >"$PY_SCRIPT" <<'PYEOF'
import sys, queue, threading, numpy as np, cv2, pygame, pyaudio, moderngl, struct
from sklearn.cluster import KMeans
from pyrr import Matrix44

# audio setup
p = pyaudio.PyAudio()
STREAM = p.open(format=pyaudio.paFloat32, channels=1, rate=44100, output=True)
audio_q = queue.Queue()

def audio_worker():
    while True:
        freqs = audio_q.get()
        if freqs is None: break
        # simple sine synth mapping frequencies -> samples
        t = np.arange(0, 0.1, 1/44100, dtype=np.float32)
        sample = sum(np.sin(2*np.pi*f*t) for f in freqs) * 0.1
        STREAM.write(sample.tobytes())
threading.Thread(target=audio_worker, daemon=True).start()

# OpenGL / pygame visualisation
pygame.init()
win = pygame.display.set_mode((800, 600), pygame.OPENGL | pygame.DOUBLEBUF)
ctx = moderngl.create_context()
prog = ctx.program(
    vertex_shader='''
        #version 330
        uniform mat4 Mvp;
        in vec3 in_vert;
        in vec3 in_color;
        out vec3 v_color;
        void main() {
            gl_Position = Mvp * vec4(in_vert, 1.0);
            v_color = in_color;
        }
    ''',
    fragment_shader='''
        #version 330
        in vec3 v_color;
        out vec4 f_color;
        void main() {
            f_color = vec4(v_color, 1.0);
        }
    ''',
)

# lattice generation (simple grid)
def make_grid(size, spacing):
    verts, cols, idx = [], [], []
    for x in range(-size, size+1):
        for y in range(-size, size+1):
            z = 0
            verts.extend([x*spacing, y*spacing, z])
            cols.extend([0.5,0.5,0.5])
            if x < size and y < size:
                i = (x+size)*(2*size+1)+(y+size)
                idx.extend([i, i+1, i+(2*size+1)])
    return np.array(verts, dtype='f4'), np.array(cols, dtype='f4'), np.array(idx, dtype='i4')
vtx, clr, idx = make_grid(10, 0.2)
vbo = ctx.buffer(vtx.tobytes())
cbo = ctx.buffer(clr.tobytes())
ibo = ctx.buffer(idx.tobytes())
vao = ctx.vertex_array(prog, [(vbo, '3f', 'in_vert'), (cbo, '3f', 'in_color')], ibo)

clock = pygame.time.Clock()
angle = 0.0

# receive frames from Bash
def frame_worker():
    global angle
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            break
        # decode palette (floats 0-1 RGB)
        cols = np.frombuffer(line, dtype='f4')
        if cols.size < 3:
            continue
        # drive audio (map hue to freq)
        hue = np.mean(cols.reshape(-1,3),axis=0)  # crude avg
        freq = 200 + 800 * hue[0]  # red -> high pitch
        audio_q.put([freq])
        # update vertex colors
        clr[:] = np.tile(cols[:3], vtx.shape[0]//3)
        cbo.write(clr.tobytes())
        # rotate lattice based on green component
        angle += hue[1]*0.05
        # render
        ctx.clear(0.0, 0.0, 0.0)
        proj = Matrix44.perspective_projection(45.0, 800/600, 0.1, 100.0)
        look = Matrix44.look_at([5,5,5], [0,0,0], [0,0,1])
        rot = Matrix44.from_y_rotation(angle)
        mvp = proj * look * rot
        prog['Mvp'].write(mvp.astype('f4').tobytes())
        vao.render()
        pygame.display.flip()
        clock.tick(30)

threading.Thread(target=frame_worker, daemon=True).start()

# keep main thread alive until window closed
while True:
    for e in pygame.event.get():
        if e.type == pygame.QUIT:
            sys.exit(0)
    pygame.time.wait(10)
PYEOF

#--- Launch Python visualiser in background, feeding it palette data ---
exec 3< <(python3 "$PY_SCRIPT")
#--- Capture frames, extract palette, send to Python ---
cleanup() {
    exec 3>&-
    rm -f "$PY_SCRIPT"
}
trap cleanup EXIT

ffmpeg -f v4l2 -framerate "$FPS" -i /dev/video"$CAM_DEVICE" -vf "format=rgb24,scale=160:120" -f rawvideo - |
while IFS= read -r -d '' -n $((160*120*3)) frame; do
    # Convert raw frame to numpy array via python for palette extraction
    palette=$(python3 - <<PY
import sys, numpy as np, cv2, struct
data = sys.stdin.buffer.read($((160*120*3)))
img = np.frombuffer(data, dtype=np.uint8).reshape((120,160,3))
k = $PALETTE_SIZE
samples = img.reshape(-1,3).astype(np.float32)/255.0
_, labels, centers = cv2.kmeans(samples, k, None,
                                 (cv2.TERM_CRITERIA_EPS+cv2.TERM_CRITERIA_MAX_ITER,10,1.0),
                                 10, cv2.KMEANS_RANDOM_CENTERS)
out = centers.astype(np.float32).tobytes()
sys.stdout.buffer.write(out)
PY
)
    # send palette floats (RGB) to python visualiser
    printf "%s" "$palette" >&3
done