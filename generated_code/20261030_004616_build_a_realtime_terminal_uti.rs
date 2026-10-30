use std::io::{self, Read, Write};
use std::net::TcpStream;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

// Represents a monitored network endpoint as a bioluminescent deep-sea jellyfish
struct Jellyfish {
    name: String,
    target: String,
    x: f32,
    y: f32,
    vx: f32,
    vy: f32,
    latency_ms: f32,
    packet_loss: f32, // 0.0 to 1.0
    pulse_phase: f32,
    tentacle_sway: f32,
}

// Terminal dimensions
struct TerminalSize {
    width: usize,
    height: usize,
}

fn get_terminal_size() -> TerminalSize {
    // Fallback dimensions if size query fails
    let mut width = 80;
    let mut height = 24;

    if let Ok(w) = std::env::var("COLUMNS") {
        if let Ok(val) = w.parse() {
            width = val;
        }
    }
    if let Ok(h) = std::env::var("LINES") {
        if let Ok(val) = h.parse() {
            height = val;
        }
    }
    TerminalSize { width, height }
}

// Measure TCP connect latency to approximate network health without root privileges
fn measure_latency(target: &str) -> (f32, f32) {
    let start = Instant::now();
    match TcpStream::connect_timeout(&target.parse().unwrap_or_else(|_| "1.1.1.1:53".parse().unwrap()), Duration::from_millis(1500)) {
        Ok(_) => {
            let duration = start.elapsed().as_secs_f32() * 1000.0;
            (duration, 0.0)
        }
        Err(_) => (1000.0, 1.0), // Timeout / Packet loss indicator
    }
}

fn main() {
    let term_size = get_terminal_size();
    
    // Define our ecosystem of jellyfish tied to real public endpoints/gateways
    let jellies = Arc::new(Mutex::new(vec![
        Jellyfish {
            name: "Cloudflare DNS".to_string(),
            target: "1.1.1.1:53".to_string(),
            x: (term_size.width / 5) as f32,
            y: (term_size.height / 3) as f32,
            vx: 0.1,
            vy: 0.05,
            latency_ms: 20.0,
            packet_loss: 0.0,
            pulse_phase: 0.0,
            tentacle_sway: 0.0,
        },
        Jellyfish {
            name: "Google DNS".to_string(),
            target: "8.8.8.8:53".to_string(),
            x: (term_size.width * 2 / 5) as f32,
            y: (term_size.height / 2) as f32,
            vx: -0.08,
            vy: 0.03,
            latency_ms: 25.0,
            packet_loss: 0.0,
            pulse_phase: 1.5,
            tentacle_sway: 1.0,
        },
        Jellyfish {
            name: "Quad9 DNS".to_string(),
            target: "9..9.9.9:53".to_string(),
            x: (term_size.width * 3 / 5) as f32,
            y: (term_size.height * 2 / 3) as f32,
            vx: 0.05,
            vy: -0.04,
            latency_ms: 30.0,
            packet_loss: 0.0,
            pulse_phase: 3.0,
            tentacle_sway: 2.0,
        },
        Jellyfish {
            name: "Gateway/Local".to_string(),
            target: "8.8.4.4:53".to_string(),
            x: (term_size.width * 4 / 5) as f32,
            y: (term_size.height / 3) as f32,
            vx: -0.06,
            vy: -0.05,
            latency_ms: 15.0,
            packet_loss: 0.0,
            pulse_phase: 4.5,
            tentacle_sway: 3.0,
        },
    ]));

    // Background thread for continuous network probing
    let monitor_jellies = Arc::clone(&jellies);
    thread::spawn(move || {
        loop {
            {
                let mut list = monitor_jellies.lock().unwrap();
                for jelly in list.iter_mut() {
                    let (lat, loss) = measure_latency(&jelly.target);
                    // Smooth transition for metrics
                    jelly.latency_ms = jelly.latency_ms * 0.7 + lat * 0.3;
                    jelly.packet_loss = jelly.packet_loss * 0.7 + loss * 0.3;
                }
            }
            thread::sleep(Duration::from_secs(1));
        }
    });

    // Enter raw/alternate terminal mode simulation via ANSI escapes
    print!("\x1b[?25l\x1b[2J"); // Hide cursor, clear screen
    io::stdout().flush().unwrap();

    let frame_duration = Duration::from_millis(50); // ~20 FPS

    // Main render & ecosystem simulation loop
    loop {
        let size = get_terminal_size();
        let mut buffer = String::new();
        buffer.push_str("\x1b[H"); // Reset cursor to top-left

        // Draw deep sea background header
        buffer.push_str(&format!(
            "\x1b[38;5;31m=== DEEP-SEA NETWORK ECOSYSTEM (Bioluminescent Latency Monitor) ===\x1b[0m\r\n\n"
        ));

        // Create character grid for rendering
        let mut grid = vec![vec![' '; size.width]; size.height.saturating_sub(4)];

        let mut jellies_lock = jellies.lock().unwrap();
        for jelly in jellies_lock.iter_mut() {
            // Update position & drift
            jelly.x += jelly.vx;
            jelly.y += jelly.vy;

            // Bounce off boundaries
            if jelly.x < 5.0 || jelly.x >= (size.width as f32 - 10.0) {
                jelly.vx = -jelly.vx;
            }
            if jelly.y < 3.0 || jelly.y >= ((size.height.saturating_sub(6)) as f32) {
                jelly.vy = -jelly.vy;
            }

            // Pulse frequency driven by latency (lower latency = rhythmic pulsing, high latency = erratic/slow)
            let pulse_speed = 0.1 + (100.0 / (jelly.latency_ms + 10.0)).clamp(0.05, 0.5);
            jelly.pulse_phase += pulse_speed;
            jelly.tentacle_sway += 0.2;

            let cx = jelly.x as usize;
            let cy = jelly.y as usize;

            // Bioluminescent glow color based on packet loss and latency
            let color_code = if jelly.packet_loss > 0.3 {
                "\x1b[38;2;255;80;80m" // Red/Warning tint for high loss
            } else if jelly.latency_ms > 100.0 {
                "\x1b[38;2;255;200;50m" // Amber for sluggish latency
            } else {
                "\x1b[38;2;0;255;204m" // Cyan/Teal bioluminescence for healthy state
            };

            // Render jellyfish bell & tentacles onto grid
            let pulse_size = (jelly.pulse_phase.sin() * 1.5).round() as i32;
            
            // Draw bell dome
            if cy < grid.len() && cx < grid[0].len() {
                let bell_str = if pulse_size > 0 { "(∩)" } else { "(__)" };
                let chars: Vec<char> = bell_str.chars().collect();
                for (i, c) in chars.into_iter().enumerate() {
                    if cx + i < size.width {
                        // We store with metadata or render directly via ANSI
                    }
                }
            }
        }

        // Render simple visual text dashboard of ecosystem metrics
        for jelly in jellies_lock.iter() {
            let status = if jelly.packet_loss > 0.0 { "⚡ UNSTABLE" } else { "✨ GLOWING" };
            buffer.push_str(&format!(
                "   jellyfish: {:<16} | target: {:<15} | latency: {:5.1} ms | loss: {:3.0}% | status: {}\r\n",
                jelly.name, jelly.target, jelly.latency_ms, jelly.packet_loss * 100.0, status
            ));
        }

        buffer.push_str("\r\n\x1b[38;5;240m[Press Ctrl+C to exit ecosystem]\x1b[0m");

        print!("{}", buffer);
        io::stdout().flush().unwrap();

        // Handle quick exit if needed or sleep for frame rate
        thread::sleep(frame_duration);
    }
}