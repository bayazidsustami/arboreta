use std::env;
use std::fs;

// Simple LCG PRNG seeded by file bytes
struct Lcg {
    state: u64,
}

impl Lcg {
    fn new(seed: u64) -> Self {
        Self {
            state: if seed == 0 { 0x123456789abcdef } else { seed },
        }
    }

    fn next_f64(&mut self) -> f64 {
        self.state = self
            .state
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        (self.state >> 11) as f64 / (1u64 << 53) as f64
    }
}

// Simple value noise for fractal landscape generation
fn noise(x: f64, y: f64, seed: u64) -> f64 {
    let xi = x.floor() as i64;
    let yi = y.floor() as i64;
    let xf = x - x.floor();
    let yf = y - y.floor();

    let hash = |px: i64, py: i64| -> f64 {
        let s = (px as u64)
            .wrapping_mul(374761393)
            ^ (py as u64).wrapping_mul(668265263)
            ^ seed;
        let mut lcg = Lcg::new(s);
        lcg.next_f64()
    };

    let n00 = hash(xi, yi);
    let n10 = hash(xi + 1, yi);
    let n01 = hash(xi, yi + 1);
    let n11 = hash(xi + 1, yi + 1);

    let sx = xf * xf * (3.0 - 2.0 * xf);
    let sy = yf * yf * (3.0 - 2.0 * yf);

    let nx0 = n00 * (1.0 - sx) + n10 * sx;
    let nx1 = n01 * (1.0 - sx) + n11 * sx;

    nx0 * (1.0 - sy) + nx1 * sy
}

// Fractal Brownian Motion (fBm) for realistic terrain
fn fractal_brownian_motion(x: f64, y: f64, octaves: usize, seed: u64) -> f64 {
    let mut total = 0.0;
    let mut frequency = 1.0;
    let mut amplitude = 1.0;
    let mut max_value = 0.0;

    for i in 0..octaves {
        total += noise(x * frequency, y * frequency, seed + i as u64) * amplitude;
        max_value += amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    total / max_value
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let sample_text = if args.len() > 1 {
        fs::read_to_string(&args[1]).unwrap_or_else(|_| args[1].clone())
    } else {
        String::from(
            "The quick brown fox jumps over the lazy dog. Esoteric compression encodes text into mountains and valleys!",
        )
    };

    println!("=== ETERNAL CARTOGRAPHY: Esoteric Text-to-Landscape Compression ===");
    println!("Original Text Length: {} bytes", sample_text.len());

    // Compress text into a unique landscape seed via FNV-1a hash variant
    let mut seed: u64 = 0xCBF29CE484222325;
    for byte in sample_text.bytes() {
        seed = seed.wrapping_mul(0x100000001B3) ^ (byte as u64);
    }

    let width = 64;
    let height = 24;
    let mut landscape = vec![vec![0.0; width]; height];

    // Generate pristine fractal terrain from the compressed seed
    for y in 0..height {
        for x in 0..width {
            let nx = x as f64 / 12.0;
            let ny = y as f64 / 6.0;
            landscape[y][x] = fractal_brownian_motion(nx, ny, 4, seed);
        }
    }

    println!("\n--- Pristine Compressed Landscape ---");
    render_landscape(&landscape, None);

    // Simulate file corruption by triggering a volcanic eruption at coordinates derived from data
    let corruption_index = sample_text.len() / 3;
    let erupt_x = corruption_index % width;
    let erupt_y = (corruption_index / width) % height;

    println!("\n[!] FILE CORRUPTION DETECTED at offset {}!", corruption_index);
    println!("[!] Manifesting volcanic eruption at coordinates ({}, {})...", erupt_x, erupt_y);

    // Inject volcanic peak into the elevation map
    for y in 0..height {
        for x in 0..width {
            let dx = (x as i32 - erupt_x as i32) as f64;
            let dy = (y as i32 - erupt_y as i32) as f64;
            let dist_sq = dx * dx + dy * dy;
            let volcano = 1.8 * (-dist_sq / 3.0).exp();
            landscape[y][x] += volcano;
        }
    }

    println!("\n--- Corrupted Landscape (Volcanic Eruption Active) ---");
    render_landscape(&landscape, Some((erupt_x, erupt_y)));
}

fn render_landscape(landscape: &[Vec<f64>], eruption: Option<(usize, usize)>) {
    let chars = [' ', '.', ':', '-', '=', '+', '*', '#', '%', '@'];
    let height = landscape.len();
    let width = landscape[0].len();

    for y in 0..height {
        let mut line = String::new();
        for x in 0..width {
            let val = landscape[y][x];
            if let Some((ex, ey)) = eruption {
                if x == ex && y == ey {
                    line.push('^'); // Volcanic peak
                    continue;
                }
                let dx = (x as i32 - ex as i32).abs();
                let dy = (y as i32 - ey as i32).abs();
                if val > 1.3 && dx <= 2 && dy <= 2 {
                    line.push('~'); // Lava flow
                    continue;
                }
            }
            let idx = ((val * (chars.len() - 1) as f64).clamp(0.0, (chars.len() - 1) as f64))
                as usize;
            line.push(chars[idx]);
        }
        println!("{}", line);
    }
}