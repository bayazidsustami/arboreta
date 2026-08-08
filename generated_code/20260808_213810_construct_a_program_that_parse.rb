# Self-contained Ruby Constellation Trace Visualizer
# Uses TCPServer + HTML5 Canvas SSE to stream thread stack traces & exception supernovas in real time.

require 'socket'
require 'json'
require 'thread'

# --- 1. Real-Time Stack Trace & Exception Tracker ---
$events_queue = Queue.new

# Monitor caught exceptions and map them to supernova events
TracePoint.trace(:raise) do |tp|
  exc = tp.raised_exception
  call_stack = caller_locations(1..10).map(&:to_s)
  $events_queue << {
    type: 'supernova',
    exception: exc.class.name,
    message: exc.message,
    stack: call_stack,
    timestamp: Time.now.to_f
  }
end

# Routine thread state collector
Thread.new do
  loop do
    threads_data = Thread.list.map do |th|
      next if th == Thread.current
      backtrace = th.backtrace || []
      {
        id: th.object_id,
        name: th[:name] || "Thread-#{th.object_id.to_s(16)[-4..]}",
        status: th.status,
        depth: backtrace.size,
        top_frame: backtrace.first || "idle",
        frames: backtrace.first(6)
      }
    end.compact

    $events_queue << {
      type: 'constellation',
      threads: threads_data,
      timestamp: Time.now.to_f
    }
    sleep 0.1
  end
end

# --- 2. Mock Workload (Generates active threads and periodic supernovas) ---
def simulate_cosmic_activity
  5.times do |i|
    Thread.new do
      Thread.current[:name] = "OrbitStar-#{i + 1}"
      loop do
        sleep rand(0.5..2.0)
        # Deep nested calls to create rich stack traces
        stage_one(i)
      end
    end
  end
end

def stage_one(id)
  stage_two(id)
end

def stage_two(id)
  stage_three(id)
end

def stage_three(id)
  # Trigger caught exceptions periodically
  if rand < 0.25
    begin
      raise ZeroDivisionError, "Gravitational collapse at orbital layer #{id}"
    rescue => e
      # Exception is captured by TracePoint supernova listener
    end
  end
  sleep rand(0.1..0.5)
end

simulate_cosmic_activity

# --- 3. Embedded Interactive Visualizer (HTML5 / WebGL Canvas + SSE) ---
HTML_CLIENT = <<~HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Runtime Constellation Map & Supernova Tracker</title>
  <style>
    body { margin: 0; background: #03030c; overflow: hidden; font-family: monospace; color: #a0a0ff; }
    canvas { display: block; }
    #hud { position: absolute; top: 15px; left: 15px; pointer-events: none; text-shadow: 0 0 5px #00ffff; }
    h1 { margin: 0 0 5px 0; font-size: 18px; color: #70a0ff; letter-spacing: 2px; }
  </style>
</head>
<body>
  <div id="hud">
    <h1>✦ RUNTIME CONSTELLATION MAP ✦</h1>
    <div id="stats">Connecting to Ruby runtime stream...</div>
  </div>
  <canvas id="sky"></canvas>

  <script>
    const canvas = document.getElementById('sky');
    const ctx = canvas.getContext('2d');
    let width = canvas.width = window.innerWidth;
    let height = canvas.height = window.innerHeight;

    window.addEventListener('resize', () => {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    });

    const centerX = width / 2;
    const centerY = height / 2;

    let threads = [];
    let supernovas = [];
    let stars = Array.from({length: 150}, () => ({
      x: Math.random() * width,
      y: Math.random() * height,
      r: Math.random() * 1.5,
      alpha: Math.random()
    }));

    // SSE Stream connection
    const evtSource = new EventSource('/stream');
    evtSource.onmessage = (event) => {
      const data = JSON.parse(event.data);
      if (data.type === 'constellation') {
        threads = data.threads;
        document.getElementById('stats').innerText = `Active Orbiting Threads: ${threads.length} | Supernovas Caught: ${supernovas.length}`;
      } else if (data.type === 'supernova') {
        createSupernova(data);
      }
    };

    function createSupernova(data) {
      const angle = Math.random() * Math.PI * 2;
      const dist = 100 + Math.random() * 250;
      const x = centerX + Math.cos(angle) * dist;
      const y = centerY + Math.sin(angle) * dist;

      const particles = [];
      for (let i = 0; i < 60; i++) {
        const pAngle = Math.random() * Math.PI * 2;
        const speed = 2 + Math.random() * 6;
        particles.push({
          x: x, y: y,
          vx: Math.cos(pAngle) * speed,
          vy: Math.sin(pAngle) * speed,
          life: 1.0,
          color: `hsl(${Math.random() * 60 + 330}, 100%, 70%)`
        });
      }

      supernovas.push({
        x, y,
        info: `${data.exception}: ${data.message}`,
        radius: 5,
        maxRadius: 120,
        alpha: 1.0,
        particles
      });
    }

    let angleOffset = 0;
    function render() {
      angleOffset += 0.005;
      ctx.fillStyle = 'rgba(3, 3, 12, 0.25)';
      ctx.fillRect(0, 0, width, height);

      // Background starfield
      ctx.fillStyle = '#ffffff';
      stars.forEach(s => {
        ctx.globalAlpha = Math.abs(Math.sin(Date.now() * 0.001 + s.alpha));
        ctx.beginPath();
        ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
        ctx.fill();
      });
      ctx.globalAlpha = 1.0;

      // Draw Orbiting Thread Constellations
      const positions = [];
      threads.forEach((th, idx) => {
        const orbitRadius = 120 + (idx * 45);
        const speed = (idx % 2 === 0 ? 1 : -1) * (0.8 / (idx + 1));
        const theta = angleOffset * speed + (idx * (Math.PI * 2 / threads.length));

        const x = centerX + Math.cos(theta) * orbitRadius;
        const y = centerY + Math.sin(theta) * orbitRadius;
        positions.push({ x, y, name: th.name, frames: th.frames, depth: th.depth });

        // Thread Star Core
        ctx.beginPath();
        ctx.arc(x, y, 6 + th.depth, 0, Math.PI * 2);
        ctx.fillStyle = '#00ffff';
        ctx.shadowBlur = 15;
        ctx.shadowColor = '#00ffff';
        ctx.fill();
        ctx.shadowBlur = 0;

        // Orbit Trail
        ctx.beginPath();
        ctx.arc(centerX, centerY, orbitRadius, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(0, 255, 255, 0.08)';
        ctx.stroke();

        // Label
        ctx.fillStyle = '#80e0ff';
        ctx.font = '11px monospace';
        ctx.fillText(`${th.name} (stack depth: ${th.depth})`, x + 12, y + 4);
      });

      // Constellation lines connecting thread nodes
      ctx.beginPath();
      ctx.strokeStyle = 'rgba(100, 180, 255, 0.35)';
      ctx.lineWidth = 1;
      for (let i = 0; i < positions.length; i++) {
        for (let j = i + 1; j < positions.length; j++) {
          ctx.moveTo(positions[i].x, positions[i].y);
          ctx.lineTo(positions[j].x, positions[j].y);
        }
      }
      ctx.stroke();

      // Render Radiant Supernova Explosions
      for (let i = supernovas.length - 1; i >= 0; i--) {
        const sn = supernovas[i];
        
        // Expansion ring
        ctx.beginPath();
        ctx.arc(sn.x, sn.y, sn.radius, 0, Math.PI * 2);
        ctx.strokeStyle = `rgba(255, 80, 120, ${sn.alpha})`;
        ctx.lineWidth = 3;
        ctx.shadowBlur = 20;
        ctx.shadowColor = '#ff2a6d';
        ctx.stroke();
        ctx.shadowBlur = 0;

        // Particle explosion
        sn.particles.forEach(p => {
          ctx.beginPath();
          ctx.arc(p.x, p.y, 2, 0, Math.PI * 2);
          ctx.fillStyle = p.color;
          ctx.fill();
          p.x += p.vx;
          p.y += p.vy;
          p.vx *= 0.96;
          p.vy *= 0.96;
        });

        // Label
        ctx.fillStyle = `rgba(255, 180, 200, ${sn.alpha})`;
        ctx.font = '10px monospace';
        ctx.fillText(`💥 ${sn.info}`, sn.x + sn.radius + 5, sn.y);

        sn.radius += 2;
        sn.alpha -= 0.015;

        if (sn.alpha <= 0) {
          supernovas.splice(i, 1);
        }
      }

      requestAnimationFrame(render);
    }

    render();
  </script>
</body>
</html>
HTML

# --- 4. Embedded Web Server (Pure Ruby TCPServer) ---
server = TCPServer.new('0.0.0.0', 4567)
puts "====================================================================="
puts "✦ Constellation Map Running at http://localhost:4567"
puts "✦ Press Ctrl+C to stop."
puts "====================================================================="

# Automatically attempt to open the visualizer in the default browser
Thread.new do
  sleep 1
  if RUBY_PLATFORM =~ /darwin/
    system("open http://localhost:4567")
  elsif RUBY_PLATFORM =~ /linux/
    system("xdg-open http://localhost:4567 > /dev/null 2>&1")
  elsif RUBY_PLATFORM =~ /mingw|mswin/
    system("start http://localhost:4567")
  end
end

loop do
  client = server.accept
  request_line = client.gets
  next unless request_line

  path = request_line.split[1]

  if path == '/stream'
    # Server-Sent Events (SSE) stream for real-time trace updates
    client.puts "HTTP/1.1 200 OK"
    client.puts "Content-Type: text/event-stream"
    client.puts "Cache-Control: no-cache"
    client.puts "Connection: keep-alive"
    client.puts "Access-Control-Allow-Origin: *"
    client.puts "\n"

    begin
      loop do
        event = $events_queue.pop
        client.puts "data: #{event.to_json}\n\n"
      end
    rescue Errno::ECONNRESET, Errno::EPIPE
      # Client disconnected
    ensure
      client.close rescue nil
    end
  else
    # Serve main HTML constellation dashboard
    client.puts "HTTP/1.1 200 OK"
    client.puts "Content-Type: text/html"
    client.puts "Content-Length: #{HTML_CLIENT.bytesize}"
    client.puts "Connection: close"
    client.puts "\n"
    client.puts HTML_CLIENT
    client.close
  end
end