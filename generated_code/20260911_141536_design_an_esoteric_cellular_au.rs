// Cosmic-Gothic Stained Glass Cellular Automaton
// Dependencies required in Cargo.toml:
// [dependencies]
// minifb = "0.25"
// sysinfo = "0.29"

use minifb::{Window, WindowOptions};
use std::f64::consts::PI;
use std::time::{Instant, SystemTime, UNIX_EPOCH};
use sysinfo::{CpuExt, System, SystemExt};

const WIDTH: usize = 600;
const HEIGHT: usize = 800;

// Planck's Law model for Cosmic Microwave Background (CMB) spectral radiance
fn cmb_spectral_radiance(freq_ghz: f64, temp_k: f64) -> f64 {
    let h = 6.62607015e-34; // Planck constant
    let c = 2.99792458e8;   // Speed of light
    let k = 1.380649e-23;    // Boltzmann constant
    let nu = freq_ghz * 1e9;

    let exponent = (h * nu) / (k * temp_k);
    if exponent > 700.0 {
        return 0.0;
    }
    (2.0 * h * nu.powi(3) / c.powi(2)) / (exponent.exp() - 1.0)
}

// Compute Shannon entropy from CPU usage per core
fn compute_cpu_entropy(sys: &mut System) -> f64 {
    sys.refresh_cpu();
    let cpus = sys.cpus();
    if cpus.is_empty() {
        return 0.5;
    }

    let usages: Vec<f64> = cpus.iter().map(|c| c.cpu_usage() as f64).collect();
    let total: f64 = usages.iter().sum();

    if total == 0.0 {
        return 0.0;
    }

    // Normalized probability distribution across CPU cores
    let mut entropy = 0.0;
    for &u in &usages {
        if u > 0.0 {
            let p = u / total;
            entropy -= p * p.log2();
        }
    }

    let max_entropy = (cpus.len() as f64).log2();
    if max_entropy > 0.0 {
        entropy / max_entropy
    } else {
        0.5
    }
}

// Map HSL to RGB packed into a u32
fn hsl_to_rgb(h: f64, s: f64, l: f64) -> u32 {
    let c = (1.0 - (2.0 * l - 1.0).abs()) * s;
    let x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
    let m = l - c / 2.0;

    let (r_prime, g_prime, b_prime) = match h as u32 {
        0..=59 => (c, x, 0.0),
        60..=119 => (x, c, 0.0),
        120..=179 => (0.0, c, x),
        180..=239 => (0.0, x, c),
        240..=299 => (x, 0.0, c),
        _ => (c, 0.0, x),
    };

    let r = ((r_prime + m) * 255.0).clamp(0.0, 255.0) as u32;
    let g = ((g_prime + m) * 255.0).clamp(0.0, 255.0) as u32;
    let b = ((b_prime + m) * 255.0).clamp(0.0, 255.0) as u32;

    (r << 16) | (g << 8) | b
}

// Gothic tracery architectural mask (Pointed Lancets and Rose Arch)
fn is_gothic_lead_tracery(x: usize, y: usize) -> bool {
    let nx = (x as f64) / (WIDTH as f64);
    let ny = (y as f64) / (HEIGHT as f64);

    // Frame border
    if x < 12 || x > WIDTH - 12 || y < 12 || y > HEIGHT - 12 {
        return true;
    }

    // Pointed Gothic arch boundary: y_arch = 1.8 * min(nx, 1-nx)
    let arch_height = 1.8 * (nx.min(1.0 - nx));
    if (1.0 - ny) > arch_height {
        return true;
    }

    // Central Lancets (Vertical Mullions)
    if (nx - 0.333).abs() < 0.008 || (nx - 0.666).abs() < 0.008 {
        return true;
    }

    // Rose Window Tracery in Upper Vault
    let rose_cx = 0.5;
    let rose_cy = 0.3;
    let dist_to_rose = ((nx - rose_cx).powi(2) + (ny - rose_cy).powi(2)).sqrt();

    // Concentric lead rims
    if (dist_to_rose - 0.18).abs() < 0.006 || (dist_to_rose - 0.08).abs() < 0.005 {
        return true;
    }

    // Radial spokes in Rose Window (12-fold symmetry)
    if dist_to_rose < 0.18 {
        let angle = (ny - rose_cy).atan2(nx - rose_cx);
        let spoke_sector = (angle * 6.0 / PI).sin().abs();
        if spoke_sector < 0.08 {
            return true;
        }
    }

    false
}

struct CellularAutomaton {
    grid: Vec<f64>,
    next_grid: Vec<f64>,
}

impl CellularAutomaton {
    fn new(width: usize, height: usize) -> Self {
        let mut grid = vec![0.0; width * height];
        // Seed grid with Planck CMB Spectral Radiance across spatial frequencies
        for y in 0..height {
            for x in 0..width {
                let freq = 10.0 + ((x * y) % 300) as f64; // GHz spectrum sampling
                let cmb_val = cmb_spectral_radiance(freq, 2.72548); // 2.7255 K CMB Temp
                grid[y * width + x] = (cmb_val * 1e18) % 1.0;
            }
        }
        Self {
            grid: grid.clone(),
            next_grid: grid,
        }
    }

    // Step automaton with non-linear reaction-diffusion governed by entropy
    fn step(&mut self, entropy: f64, t: f64) {
        for y in 1..HEIGHT - 1 {
            for x in 1..WIDTH - 1 {
                let idx = y * WIDTH + x;

                // 8-neighbor sum (Moore neighborhood)
                let neighbors = self.grid[idx - WIDTH - 1]
                    + self.grid[idx - WIDTH]
                    + self.grid[idx - WIDTH + 1]
                    + self.grid[idx - 1]
                    + self.grid[idx + 1]
                    + self.grid[idx + WIDTH - 1]
                    + self.grid[idx + WIDTH]
                    + self.grid[idx + WIDTH + 1];

                let avg = neighbors / 8.0;

                // Esoteric rule mixing CMB state, harmonic oscillator, and entropy chaos
                let harmonic = ((x as f64 * 0.02 + t).sin() + (y as f64 * 0.02 + t).cos()) * 0.1;
                let next_val = (avg * (1.0 + entropy) + harmonic) % 1.0;

                self.next_grid[idx] = if next_val < 0.0 { next_val + 1.0 } else { next_val };
            }
        }
        std::mem::swap(&mut self.grid, &mut self.next_grid);
    }
}

fn main() {
    let mut window = Window::new(
        "Cosmic Stained Glass Automaton",
        WIDTH,
        HEIGHT,
        WindowOptions::default(),
    )
    .unwrap_or_else(|e| panic!("{}", e));

    window.set_target_fps(60);

    let mut ca = CellularAutomaton::new(WIDTH, HEIGHT);
    let mut sys = System::new_all();
    let mut buffer: Vec<u32> = vec![0; WIDTH * HEIGHT];
    let start_time = Instant::now();

    while window.is_open() && !window.is_key_down(minifb::Key::Escape) {
        let t = start_time.elapsed().as_secs_f64();
        let entropy = compute_cpu_entropy(&mut sys);

        ca.step(entropy, t);

        // Render pass: cellular state + gothic geometry + entropy color palette
        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                let idx = y * WIDTH + x;

                if is_gothic_lead_tracery(x, y) {
                    // Lead came dark metallic frame with subtle specular highlights
                    buffer[idx] = 0x1a181c;
                } else {
                    let cell_state = ca.grid[idx];

                    // Base color palette shifts dynamically with CPU entropy:
                    // Low Entropy -> Deep Sacred Blues/Purples (300°)
                    // High Entropy -> Fiery Crimson/Gold (30°)
                    let base_hue = 260.0 - (entropy * 230.0);
                    let hue = (base_hue + cell_state * 60.0) % 360.0;
                    let saturation = 0.75 + 0.25 * (t.sin().abs());
                    let lightness = 0.2 + cell_state * 0.5;

                    buffer[idx] = hsl_to_rgb(hue, saturation, lightness);
                }
            }
        }

        window.update_with_buffer(&buffer, WIDTH, HEIGHT).unwrap();
    }
}