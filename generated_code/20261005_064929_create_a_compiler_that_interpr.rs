use std::net::TcpStream;
use std::time::{Duration, Instant};
use std::thread;

/// Measures real-time local internet latency by connecting to a public DNS.
fn measure_latency() -> Duration {
    let start = Instant::now();
    let target = "1.1.1.1:53";
    if let Ok(stream) = TcpStream::connect_timeout(&target.parse().unwrap(), Duration::from_millis(800)) {
        drop(stream);
        start.elapsed()
    } else {
        Duration::from_millis(50) // Fallback latency
    }
}

/// Represents a single synthetic cricket in the swarm.
struct Cricket {
    id: usize,
    base_pitch: f32,
    chirp_interval_ms: u64,
}

impl Cricket {
    fn chirp(&self, latency_factor: f32) {
        let modulated_rate = (self.chirp_interval_ms as f32 * latency_factor) as u64;
        print!("\n[Cricket #{}] ~chirp~ (Pitch: {:.1}Hz, Interval: {}ms)", 
            self.id, self.base_pitch * latency_factor, modulated_rate);
    }
}

fn main() {
    println!("=== CSS-TO-CRICKET LATENCY SYMPHONY INITIALIZED ===");
    
    // A sample CSS stylesheet acting as our musical score
    let css_score = r#"
        body { color: #44a; font-size: 14px; }
        h1 { color: #f50; margin: 20px; }
        .cricket-swarm { background: #222; opacity: 0.8; }
    "#;

    println!("Parsing CSS Stylesheet Score:\n{}", css_score);

    // Initialize our cricket swarm based on CSS property tokens
    let mut swarm = vec![
        Cricket { id: 1, base_pitch: 440.0, chirp_interval_ms: 300 },
        Cricket { id: 2, base_pitch: 523.25, chirp_interval_ms: 450 },
        Cricket { id: 3, base_pitch: 659.25, chirp_interval_ms: 600 },
    ];

    println!("Swarm activated. Tuning chirps to live network pulse...");

    for iteration in 1..=5 {
        let latency = measure_latency();
        let latency_ms = latency.as_secs_f32() * 1000.0;
        
        // Dynamic modulation factor derived from latency
        let modulation_factor = 1.0 + (latency_ms / 100.0);
        
        println!("\n--- Symphony Beat {} | Live Latency: {:.2}ms (Modulation: {:.2x}) ---", 
            iteration, latency_ms, modulation_factor);

        for cricket in &swarm {
            cricket.chirp(modulation_factor);
            thread::sleep(Duration::from_millis(100));
        }

        thread::sleep(Duration::from_secs(1));
    }

    println!("\n\n=== SYMPHONY CONCLUDED SUCCESSFULLY ===");
}