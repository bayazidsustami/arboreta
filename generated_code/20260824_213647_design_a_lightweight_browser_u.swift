import WebKit
import AVFoundation
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    var window: NSWindow!
    var webView: WKWebView!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let configuration = WKWebViewConfiguration()
        
        // Allow media capture and inline video playback
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Register IPC handler to communicate with native Cocoa if needed
        let contentController = WKUserContentController()
        contentController.add(self, name: "appHandler")
        configuration.userContentController = contentController
        
        // Standard full-window setup
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let windowRect = NSRect(x: screenRect.midX - 512, y: screenRect.midY - 384, width: 1024, height: 768)
        
        window = NSWindow(contentRect: windowRect,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                          backing: .buffered,
                          defer: false)
        window.title = "ASCII Fluid Dynamics & Poetry Current"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .black
        
        webView = WKWebView(frame: window.contentView!.bounds, configuration: configuration)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground") // Transparent background
        
        window.contentView?.addSubview(webView)
        window.makeKeyAndOrderFront(nil)
        
        // Prompt for camera permission via native API before loading web content
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.loadHTMLContent()
            }
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Native bridge receiver
    }

    func loadHTMLContent() {
        let htmlContent = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title>ASCII Fluid Mirror</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body, html { width: 100%; height: 100%; overflow: hidden; background: #000; color: #0f0; font-family: monospace; }
                #canvas-container { width: 100vw; height: 100vh; display: flex; align-items: center; justify-content: center; position: relative; }
                canvas { display: none; }
                #ascii-render { 
                    font-family: "Courier New", Courier, monospace; 
                    font-size: 11px; 
                    line-height: 9px; 
                    letter-spacing: 1px;
                    white-space: pre; 
                    color: #e0e0e0;
                    text-shadow: 0 0 3px rgba(255,255,255,0.4);
                    user-select: none;
                    cursor: default;
                }
                #instructions {
                    position: absolute;
                    bottom: 20px;
                    left: 20px;
                    font-size: 12px;
                    color: rgba(255,255,255,0.4);
                    pointer-events: none;
                    font-family: sans-serif;
                }
            </style>
        </head>
        <body>
            <div id="canvas-container">
                <pre id="ascii-render"></pre>
            </div>
            <div id="instructions">Type poetry into the current • Move in front of camera • Press Space to burst force</div>
            <video id="webcam" autoplay playsinline muted style="display:none;"></video>

            <script>
                // Navigation / Grid Configuration
                const GRID_W = 120;
                const GRID_H = 60;
                const DENSITY_RAMP = " .':i|_17tzYXHBM@";
                const RAMPSIZE = DENSITY_RAMP.length;

                // Fluid Dynamics Field Matrices (Navier-Stokes Grid Simulation)
                const N = 64;
                const iter = 4;
                
                function IX(x, y) {
                    x = Math.max(0, Math.min(N - 1, x));
                    y = Math.max(0, Math.min(N - 1, y));
                    return x + y * N;
                }

                class Fluid {
                    constructor(dt, diffusion, viscosity) {
                        this.size = N;
                        this.dt = dt;
                        this.diff = diffusion;
                        this.visc = viscosity;
                        
                        this.s = new Float32Array(N * N);
                        this.density = new Float32Array(N * N);
                        
                        this.Vx = new Float32Array(N * N);
                        this.Vy = new Float32Array(N * N);
                        
                        this.Vx0 = new Float32Array(N * N);
                        this.Vy0 = new Float32Array(N * N);

                        this.charGrid = Array(N * N).fill('');
                    }

                    step() {
                        let visc = this.visc, diff = this.diff, dt = this.dt;
                        let Vx = this.Vx, Vy = this.Vy, Vx0 = this.Vx0, Vy0 = this.Vy0;
                        let s = this.s, density = this.density;

                        diffuse(1, Vx0, Vx, visc, dt);
                        diffuse(2, Vy0, Vy, visc, dt);
                        
                        project(Vx0, Vy0, Vx, Vy);
                        
                        advect(1, Vx, Vx0, Vx0, Vy0, dt);
                        advect(2, Vy, Vy0, Vx0, Vy0, dt);
                        
                        project(Vx, Vy, Vx0, Vy0);
                        
                        diffuse(0, s, density, diff, dt);
                        advect(0, density, s, Vx, Vy, dt);
                    }

                    addDensity(x, y, amount, char = null) {
                        let idx = IX(x, y);
                        this.density[idx] += amount;
                        if(char) this.charGrid[idx] = char;
                    }

                    addVelocity(x, y, amountX, amountY) {
                        let index = IX(x, y);
                        this.Vx[index] += amountX;
                        this.Vy[index] += amountY;
                    }
                }

                function diffuse(b, x, x0, diff, dt) {
                    let a = dt * diff * (N - 2) * (N - 2);
                    lin_solve(b, x, x0, a, 1 + 6 * a);
                }

                function lin_solve(b, x, x0, a, c) {
                    let cRecip = 1.0 / c;
                    for (let k = 0; k < iter; k++) {
                        for (let j = 1; j < N - 1; j++) {
                            for (let i = 1; i < N - 1; i++) {
                                x[IX(i, j)] = (x0[IX(i, j)] + a * (x[IX(i + 1, j)] + x[IX(i - 1, j)] + x[IX(i, j + 1)] + x[IX(i, j - 1)])) * cRecip;
                            }
                        }
                        set_bnd(b, x);
                    }
                }

                function project(vx, vy, p, div) {
                    for (let j = 1; j < N - 1; j++) {
                        for (let i = 1; i < N - 1; i++) {
                            div[IX(i, j)] = -0.5 * (vx[IX(i + 1, j)] - vx[IX(i - 1, j)] + vy[IX(i, j + 1)] - vy[IX(i, j - 1)]) / N;
                            p[IX(i, j)] = 0;
                        }
                    }
                    set_bnd(0, div);
                    set_bnd(0, p);
                    lin_solve(0, p, div, 1, 6);
                    for (let j = 1; j < N - 1; j++) {
                        for (let i = 1; i < N - 1; i++) {
                            vx[IX(i, j)] -= 0.5 * (p[IX(i + 1, j)] - p[IX(i - 1, j)]) * N;
                            vy[IX(i, j)] -= 0.5 * (p[IX(i, j + 1)] - p[IX(i, j - 1)]) * N;
                        }
                    }
                    set_bnd(1, vx);
                    set_bnd(2, vy);
                }

                function advect(b, d, d0, vx, vy, dt) {
                    let i0, i1, j0, j1;
                    let dtx = dt * (N - 2);
                    let dty = dt * (N - 2);
                    let s0, s1, t0, t1;
                    let tmp1, tmp2, x, y;
                    let Nfloat = N - 2;

                    for (let j = 1; j < N - 1; j++) {
                        for (let i = 1; i < N - 1; i++) {
                            tmp1 = dtx * vx[IX(i, j)];
                            tmp2 = dty * vy[IX(i, j)];
                            x = i - tmp1;
                            y = j - tmp2;

                            if (x < 0.5) x = 0.5;
                            if (x > Nfloat + 0.5) x = Nfloat + 0.5;
                            i0 = Math.floor(x);
                            i1 = i0 + 1.0;
                            if (y < 0.5) y = 0.5;
                            if (y > Nfloat + 0.5) y = Nfloat + 0.5;
                            j0 = Math.floor(y);
                            j1 = j0 + 1.0;

                            s1 = x - i0;
                            s0 = 1.0 - s1;
                            t1 = y - j0;
                            t0 = 1.0 - t1;

                            let i0i = Math.floor(i0);
                            let i1i = Math.floor(i1);
                            let j0i = Math.floor(j0);
                            let j1i = Math.floor(j1);

                            d[IX(i, j)] = s0 * (t0 * d0[IX(i0i, j0i)] + t1 * d0[IX(i0i, j1i)]) +
                                         s1 * (t0 * d0[IX(i1i, j0i)] + t1 * d0[IX(i1i, j1i)]);
                        }
                    }
                    set_bnd(b, d);
                }

                function set_bnd(b, x) {
                    for (let i = 1; i < N - 1; i++) {
                        x[IX(i, 0)] = b === 2 ? -x[IX(i, 1)] : x[IX(i, 1)];
                        x[IX(i, N - 1)] = b === 2 ? -x[IX(i, N - 2)] : x[IX(i, N - 2)];
                    }
                    for (let j = 1; j < N - 1; j++) {
                        x[IX(0, j)] = b === 1 ? -x[IX(1, j)] : x[IX(1, j)];
                        x[IX(N - 1, j)] = b === 1 ? -x[IX(N - 2, j)] : x[IX(N - 2, j)];
                    }
                }

                // Global Instantiations
                const fluid = new Fluid(0.1, 0, 0.000001);
                const video = document.getElementById('webcam');
                const asciiPre = document.getElementById('ascii-render');
                
                // Canvas processing buffers
                const vCanvas = document.createElement('canvas');
                vCanvas.width = N;
                vCanvas.height = N;
                const vCtx = vCanvas.getContext('2d');

                let prevFrame = null;
                let textStream = [];

                // Initialize Webcam Stream
                navigator.mediaDevices.getUserMedia({ video: { width: N, height: N, frameRate: 30 } })
                    .then(stream => {
                        video.srcObject = stream;
                        video.play();
                    })
                    .catch(err => console.error("Webcam denied:", err));

                // Input Handling: Key Press Injector
                window.addEventListener('keydown', (e) => {
                    let key = e.key;
                    if(key === " ") {
                        // Explosion of fluid force
                        for(let i=0; i<360; i+=15) {
                            let rad = i * Math.PI / 180;
                            let fx = Math.cos(rad) * 10;
                            let fy = Math.sin(rad) * 10;
                            fluid.addVelocity(Math.floor(N/2), Math.floor(N/2), fx, fy);
                            fluid.addDensity(Math.floor(N/2), Math.floor(N/2), 50, "*");
                        }
                        return;
                    }

                    if(key.length === 1) {
                        // Inject typed poetry at random swirling coordinates or center
                        let rx = Math.floor(N/4 + Math.random() * (N/2));
                        let ry = Math.floor(N/4 + Math.random() * (N/2));
                        let angle = Math.random() * Math.PI * 2;
                        let force = 15;

                        fluid.addVelocity(rx, ry, Math.cos(angle) * force, Math.sin(angle) * force);
                        fluid.addDensity(rx, ry, 250, key);
                    }
                });

                // Optical Flow & Camera Motion Detection
                function processWebcam() {
                    if (video.readyState === video.HAVE_ENOUGH_DATA) {
                        vCtx.drawImage(video, 0, 0, N, N);
                        let currentFrame = vCtx.getImageData(0, 0, N, N);
                        let data = currentFrame.data;

                        if (prevFrame) {
                            let pData = prevFrame.data;
                            for (let y = 1; y < N - 1; y++) {
                                for (let x = 1; x < N - 1; x++) {
                                    let i = (y * N + x) * 4;
                                    
                                    // Brightness calculation
                                    let bCurr = (data[i] + data[i+1] + data[i+2]) / 3;
                                    let bPrev = (pData[i] + pData[i+1] + pData[i+2]) / 3;
                                    let diff = bCurr - bPrev;

                                    if (Math.abs(diff) > 15) { // Sensitivity threshold
                                        // Infer directional motion gradient (Simple Optical Flow approximation)
                                        let bLeft = (data[i - 4] + data[i - 3] + data[i - 2]) / 3;
                                        let bRight = (data[i + 4] + data[i + 5] + data[i + 6]) / 3;
                                        let bUp = (data[i - N*4] + data[i - N*4 + 1] + data[i - N*4 + 2]) / 3;
                                        let bDown = (data[i + N*4] + data[i + N*4 + 1] + data[i + N*4 + 2]) / 3;

                                        let dx = (bRight - bLeft) * 0.1;
                                        let dy = (bDown - bUp) * 0.1;

                                        // Mirror X-axis for natural camera feedback
                                        let mirroredX = N - 1 - x;
                                        
                                        fluid.addVelocity(mirroredX, y, -dx * 2, dy * 2);
                                        fluid.addDensity(mirroredX, y, Math.abs(diff) * 2);
                                    }
                                }
                            }
                        }
                        prevFrame = currentFrame;
                    }
                }

                // Render ASCII Scene Frame
                function render() {
                    fluid.step();
                    processWebcam();

                    let output = "";
                    for (let y = 0; y < N; y++) {
                        for (let x = 0; x < N; x++) {
                            let idx = IX(x, y);
                            let d = fluid.density[idx];
                            let char = fluid.charGrid[idx];

                            if (d > 20 && char && Math.random() > 0.1) {
                                // Draw injected floating character
                                output += char + " ";
                            } else {
                                // Draw fluid field using density mapped to ramp
                                let rampIndex = Math.min(RAMPSIZE - 1, Math.floor(d / 10));
                                let c = DENSITY_RAMP[rampIndex] || ' ';
                                output += c + " ";
                            }
                            
                            // Passive decay of text overlay
                            if(d > 0) fluid.density[idx] *= 0.99;
                        }
                        output += "\\n";
                    }
                    asciiPre.textContent = output;
                    requestAnimationFrame(render);
                }

                render();
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
}

// App execution setup
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()