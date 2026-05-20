use std::time::{SystemTime, UNIX_EPOCH};
use std::f64::consts::PI;

/// A representation of a moment in a developer's life, 
/// distilled from the chaos of raw code and time.
struct LifeMoment {
    timestamp: f64,
    complexity: f64, // The "noise" of the code at that moment
    entropy: f64,    // The chaos level
}

/// The ShimmeringSculpture acts as a generative engine that 
/// transforms linear time into multidimensional geometry.
struct ShimmeringSculpture {
    moments: Vec<LifeMoment>,
    resolution: usize,
}

impl ShimmeringSculpture {
    fn new(history: Vec<LifeMoment>) -> Self {
        Self {
            moments: history,
            resolution: 100,
        }
    }

    /// Transforms the chronological timeline into a shimmering visual representation
    /// expressed via ANSI-colored terminal output (a "digital sculpture").
    fn manifest(&self) {
        println!("\n--- INITIATING TEMPORAL TRANSFORMATION ---\n");

        for frame in 0..self.resolution {
            let t = frame as f64 / self.resolution as f64;
            let mut line = String::new();

            // We simulate a 3D swirl by calculating an orbital path 
            // influenced by the developer's life history.
            for x_idx in 0..60 {
                let x = (x_idx as f64 - 30.0) / 10.0;
                let mut intensity = 0.0;

                for moment in &self.moments {
                    // The core transformation: 
                    // Time (t) + Code Complexity + Life Entropy = Spatial Oscillation
                    let wave = (moment.timestamp * 2.0 + t * PI * 4.0).sin();
                    let chaos = (moment.entropy * x).cos();
                    let distance = ((x * x + (wave + chaos).powi(2)).sqrt() - moment.complexity).abs();

                    if distance < 0.15 {
                        intensity += 1.0;
                    }
                }

                line.push_str(self.get_shimmer_char(intensity, t));
            }
            println!("{}", line);
        }
        println!("\n--- SCULPTURE STABILIZED ---\n");
    }

    /// Maps intensity to a shimmering spectrum of ANSI colors.
    fn get_shimmer_char(&self, intensity: f64, t: f64) -> String {
        if intensity <= 0.0 {
            return " ".to_string();
        }

        // Generate a shifting color palette using sine waves to simulate "shimmering"
        let r = ((intensity * 5.0 + t.sin()).sin() * 127.0 + 128.0) as u8;
        let g = ((intensity * 3.0 + t.cos()).sin() * 127.0 + 128.0) as u8;
        let b = ((intensity * 7.0 + t).sin() * 127.0 + 128.0) as u8;

        let chars = ['*', '.', '°', '¤', '✧', '•'];
        let idx = ((intensity * 5.0) as usize).min(chars.len() - 1);
        
        format!("\x1b[38;2;{};{};{}m{}\x1b[0m", r, g, b, chars[idx])
    }
}

fn main() {
    // Simulate a developer's life journey through varying states of code-chaos
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs_f64();

    let life_history = vec![
        // The Early Days: Simple, low entropy, low complexity
        LifeMoment { timestamp: now - 1000.0, complexity: 1.0, entropy: 0.1 },
        // The Learning Years: Growing complexity, rising entropy
        LifeMoment { timestamp: now - 500.0, complexity: 2.5, entropy: 0.5 },
        // The Production Grind: High complexity, high chaos
        LifeMoment { timestamp: now - 100.0, complexity: 4.0, entropy: 0.8 },
        // The Zen State: Refined complexity, rhythmic entropy
        LifeMoment { timestamp: now, complexity: 3.0, entropy: 0.3 },
    ];

    let sculpture = ShimmeringSculpture::new(life_history);
    
    // Execute the transformation
    sculpture.manifest();
}