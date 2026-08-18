import Foundation
import WebKit
import Cocoa

class AppController: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentController = WKUserContentController()
        contentController.add(self, name: "systemBridge")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self

        let windowStyle: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 900),
                          styleMask: windowStyle,
                          backing: .buffered,
                          defer: false)
        window.center()
        window.title = "Gothic Cathedral - CPU Generative Architecture"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .black
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)

        loadCanvasEngine()
        startCPUMonitoring()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}

    // Collect aggregate CPU load across all physical/logical cores
    func getCPUUsage() -> Double {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return 0.0 }
        
        var totalUsage: Double = 0.0
        let cpuLoadInfo = UnsafeBufferPointer(start: UnsafePointer<processor_cpu_load_info>(OpaquePointer(info)), count: Int(numCPUs))
        
        for cpu in cpuLoadInfo {
            let user = Double(cpu.cpu_ticks.0)
            let system = Double(cpu.cpu_ticks.1)
            let idle = Double(cpu.cpu_ticks.2)
            let nice = Double(cpu.cpu_ticks.3)
            let total = user + system + idle + nice
            if total > 0 {
                totalUsage += (user + system + nice) / total
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), vm_size_t(numCPUInfo * UInt(MemoryLayout<integer_t>.size)))
        return totalUsage / Double(numCPUs)
    }

    func startCPUMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let usage = self.getCPUUsage()
            let js = "window.updateCPUUsage(\(usage));"
            DispatchQueue.main.async {
                self.webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }

    func loadCanvasEngine() {
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #050408; font-family: monospace; }
                canvas { display: block; width: 100%; height: 100%; }
                #hud {
                    position: absolute; top: 20px; left: 20px; color: #a393bf;
                    text-shadow: 0 0 10px #3f225e; font-size: 11px; letter-spacing: 2px;
                    pointer-events: none; z-index: 10;
                }
            </style>
        </head>
        <body>
            <div id="hud">SYSTEM LOGIC: CPU TRANSMUTATION RUNNING<br>LOAD: <span id="loadVal">0</span>%</div>
            <canvas id="gothicCanvas"></canvas>
            <script>
                const canvas = document.getElementById('gothicCanvas');
                const ctx = canvas.getContext('2d');
                let width, height;

                let cpuUsage = 0.0;
                let targetCPU = 0.0;
                let idleTime = 0;
                let spires = [];
                let windows = [];
                let time = 0;

                function resize() {
                    width = canvas.width = window.innerWidth;
                    height = canvas.height = window.innerHeight;
                }
                window.addEventListener('resize', resize);
                resize();

                window.updateCPUUsage = function(val) {
                    targetCPU = val;
                };

                class Spire {
                    x; height; targetHeight; width; tier;
                    constructor(x, width, targetHeight) {
                        this.x = x;
                        this.width = width;
                        this.height = 0;
                        this.targetHeight = targetHeight;
                        this.color = '#150f1d';
                    }
                    update() {
                        this.height += (this.targetHeight - this.height) * 0.05;
                    }
                    draw(ctx) {
                        ctx.save();
                        ctx.translate(this.x, height);
                        
                        // Main Steeple
                        ctx.fillStyle = '#0a0812';
                        ctx.strokeStyle = '#43325c';
                        ctx.lineWidth = 1.5;

                        ctx.beginPath();
                        ctx.moveTo(-this.width / 2, 0);
                        ctx.lineTo(-this.width / 4, -this.height * 0.7);
                        ctx.lineTo(0, -this.height);
                        ctx.lineTo(this.width / 4, -this.height * 0.7);
                        ctx.lineTo(this.width / 2, 0);
                        ctx.closePath();
                        ctx.fill();
                        ctx.stroke();

                        // Gothic Lancet Ribs
                        ctx.beginPath();
                        ctx.moveTo(0, 0);
                        ctx.lineTo(0, -this.height);
                        ctx.strokeStyle = '#281a3b';
                        ctx.stroke();

                        // Arch embellishment near base
                        ctx.beginPath();
                        ctx.arc(0, -this.height * 0.3, this.width / 4, Math.PI, 0);
                        ctx.strokeStyle = '#5a3d7c';
                        ctx.stroke();

                        ctx.restore();
                    }
                }

                class RoseWindow {
                    x; y; radius; maxRadius; petals; complexity; alpha;
                    constructor(x, y, maxRadius) {
                        this.x = x;
                        this.y = y;
                        this.radius = 0;
                        this.maxRadius = maxRadius;
                        this.petals = 6 + Math.floor(Math.random() * 6) * 2;
                        this.alpha = 0;
                        this.hue = Math.random() * 60 + 260; // Deep purples, blues, crimson
                    }
                    grow() {
                        if (this.radius < this.maxRadius) this.radius += 0.2;
                        if (this.alpha < 0.85) this.alpha += 0.01;
                    }
                    draw(ctx) {
                        ctx.save();
                        ctx.translate(this.x, this.y);
                        ctx.globalAlpha = this.alpha;

                        // Outer Frame
                        ctx.strokeStyle = '#1e1429';
                        ctx.lineWidth = 3;
                        ctx.beginPath();
                        ctx.arc(0, 0, this.radius, 0, Math.PI * 2);
                        ctx.stroke();

                        // Stained Glass Fill
                        for (let i = 0; i < this.petals; i++) {
                            let angle = (Math.PI * 2 / this.petals) * i;
                            ctx.save();
                            ctx.rotate(angle + time * 0.002);

                            // Geometric Petal Arch
                            ctx.beginPath();
                            ctx.moveTo(0, 0);
                            ctx.quadraticCurveTo(this.radius * 0.5, this.radius * 0.5, 0, this.radius);
                            ctx.quadraticCurveTo(-this.radius * 0.5, this.radius * 0.5, 0, 0);
                            
                            let fillGrad = ctx.createRadialGradient(0, 0, 0, 0, 0, this.radius);
                            fillGrad.addColorStop(0, `hsla(${this.hue}, 80%, 60%, 0.8)`);
                            fillGrad.addColorStop(0.7, `hsla(${this.hue + 40}, 90%, 40%, 0.5)`);
                            fillGrad.addColorStop(1, 'rgba(10, 5, 20, 0.9)');
                            
                            ctx.fillStyle = fillGrad;
                            ctx.fill();
                            ctx.strokeStyle = '#000';
                            ctx.lineWidth = 1;
                            ctx.stroke();

                            // Inner Traceries
                            ctx.beginPath();
                            ctx.arc(0, this.radius * 0.5, this.radius * 0.2, 0, Math.PI * 2);
                            ctx.fillStyle = `hsla(${this.hue - 30}, 100%, 70%, 0.6)`;
                            ctx.fill();

                            ctx.restore();
                        }

                        // Central Eye
                        ctx.beginPath();
                        ctx.arc(0, 0, this.radius * 0.2, 0, Math.PI * 2);
                        ctx.fillStyle = '#ffeedd';
                        ctx.shadowColor = '#d4af37';
                        ctx.shadowBlur = 15;
                        ctx.fill();

                        ctx.restore();
                    }
                }

                function initArchitecture() {
                    spires = [];
                    let count = 15;
                    let spacing = width / count;
                    for (let i = 0; i < count; i++) {
                        let centerDist = 1 - Math.abs((i - count/2) / (count/2));
                        let baseWidth = spacing * (0.8 + Math.random() * 0.5);
                        spires.push({
                            x: i * spacing + spacing / 2,
                            width: baseWidth,
                            centerWeight: centerDist
                        });
                    }
                }

                let activeSpires = [];
                function syncSpires() {
                    if (activeSpires.length === 0) {
                        activeSpires = spires.map(s => {
                            let h = (200 + s.centerWeight * 300) * (0.5 + cpuUsage * 2.5);
                            return new Spire(s.x, s.width, h);
                        });
                    } else {
                        activeSpires.forEach((spire, idx) => {
                            let s = spires[idx];
                            let target = (200 + s.centerWeight * 400) * (0.3 + Math.pow(cpuUsage, 1.5) * 3.0);
                            spire.targetHeight = target;
                            spire.update();
                        });
                    }
                }

                function animate() {
                    time++;
                    cpuUsage += (targetCPU - cpuUsage) * 0.05;
                    document.getElementById('loadVal').innerText = (cpuUsage * 100).toFixed(1);

                    // Ambient Background (Gothic Night / Mist)
                    let bgGrad = ctx.createLinearGradient(0, 0, 0, height);
                    bgGrad.addColorStop(0, '#030206');
                    bgGrad.addColorStop(0.6, '#0c0714');
                    bgGrad.addColorStop(1, '#1a0d24');
                    ctx.fillStyle = bgGrad;
                    ctx.fillRect(0, 0, width, height);

                    // Dynamic CPU Spikes -> Raise Spires
                    syncSpires();
                    activeSpires.forEach(spire => spire.draw(ctx));

                    // Idle States -> Grow Intricate Stained Glass Windows
                    if (cpuUsage < 0.15) {
                        idleTime++;
                        if (idleTime % 40 === 0 && windows.length < 12) {
                            let winX = Math.random() * (width - 200) + 100;
                            let winY = height - (Math.random() * 300 + 200);
                            let maxR = 30 + Math.random() * 50;
                            windows.push(new RoseWindow(winX, winY, maxR));
                        }
                    } else {
                        idleTime = Math.max(0, idleTime - 2);
                        if (cpuUsage > 0.4 && windows.length > 0 && time % 10 === 0) {
                            windows.shift(); // Spikes shatter/consume idle windows
                        }
                    }

                    // Render Rose Windows
                    windows.forEach(w => {
                        w.grow();
                        w.draw(ctx);
                    });

                    // Mist Layer at Cathedral Base
                    ctx.fillStyle = 'rgba(10, 5, 16, 0.4)';
                    ctx.fillRect(0, height - 120, width, 120);

                    requestAnimationFrame(animate);
                }

                initArchitecture();
                animate();
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
}

// Run Swift Native App Loop
let app = NSApplication.shared
let delegate = AppController()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()