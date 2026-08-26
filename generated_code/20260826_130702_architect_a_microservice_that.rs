use std::f64::consts::PI;
use std::io::Write;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

// --- 1. Thermodynamic Telemetry & State ---

#[derive(Debug, Clone, Copy)]
pub struct AtmosphericTelemetry {
    pub temperature_k: f64, // Temperature in Kelvin
    pub pressure_hpa: f64,   // Pressure in hPa
    pub humidity_pct: f64,   // Relative humidity (%)
    pub wind_speed_ms: f64,  // Wind speed (m/s)
}

impl AtmosphericTelemetry {
    /// Generates dynamic local weather telemetry simulating subtle continuous fluctuations.
    pub fn sample_mock(start_time: Instant) -> Self {
        let t = start_time.elapsed().as_secs_f64();
        Self {
            temperature_k: 288.15 + 5.0 * (t * 0.05).sin() + 1.2 * (t * 0.13).cos(),
            pressure_hpa: 1013.25 + 15.0 * (t * 0.02).cos() + 3.0 * (t * 0.07).sin(),
            humidity_pct: (50.0 + 25.0 * (t * 0.03).sin() + 10.0 * (t * 0.11).cos()).clamp(0.0, 100.0),
            wind_speed_ms: (8.0 + 6.0 * (t * 0.08).cos() + 3.0 * (t * 0.19).sin()).abs(),
        }
    }

    /// Derives thermodynamic properties: Entropy (S) proxy and Enthalpy (H) proxy.
    pub fn derive_thermodynamics(&self) -> (f64, f64) {
        // Approximate specific enthalpy of moist air (kJ/kg)
        let temp_c = self.temperature_k - 273.15;
        let humidity_ratio = (self.humidity_pct / 100.0) * 0.01; 
        let enthalpy = 1.006 * temp_c + humidity_ratio * (2501.0 + 1.86 * temp_c);

        // Approximate entropy proxy based on temperature and pressure relationship
        let entropy = 1.005 * self.temperature_k.ln() - 0.287 * (self.pressure_hpa / 1013.25).ln() + (self.humidity_pct / 100.0) * 0.5;

        (entropy, enthalpy)
    }
}

// --- 2. Procedural Non-Repeating Quilt Weaver ---

pub struct QuiltWeaver {
    pub width: usize,
    pub height: usize,
    time_offset: f64,
}

impl QuiltWeaver {
    pub fn new(width: usize, height: usize) -> Self {
        Self {
            width,
            height,
            time_offset: 0.0,
        }
    }

    /// Simulates 2D Simplex/Perlin-like noise using a synthesis of trigonometric basis functions.
    fn basis_noise(x: f64, y: f64, seed: f64) -> f64 {
        let q = (x * 0.05 + seed).sin() * (y * 0.05 + seed).cos();
        let r = ((x + y) * 0.03 - seed * 0.5).sin();
        let s = ((x * x + y * y).sqrt() * 0.02 + seed).cos();
        (q + r + s) / 3.0
    }

    /// Renders a single frame of the infinite digital quilt derived from current atmospheric telemetry.
    pub fn render_frame(&mut self, telemetry: &AtmosphericTelemetry) -> Vec<Vec<(u8, u8) u8,>> {
        self.time_offset += 0.03 + (telemetry.wind_speed_ms * 0.002);
        let (entropy, enthalpy) = telemetry.derive_thermodynamics();

        let mut grid = vec![vec![(0, 0, 0); self.width]; self.height];

        for y in 0..self.height {
            for x in 0..self.width {
                let fx = x as f64;
                let fy = y as f64;

                // Synthesize thread patterns using thermodynamic state variables as wave modifiers
                let warp = Self::basis_noise(fx + self.time_offset * 10.0, fy, entropy);
                let weft = Self::basis_noise(fx, fy + self.time_offset * 10.0, enthalpy * 0.01);

                // Algorithmic fabric weave structure (interlacing warp/weft)
                let weave_pattern = ((fx * 0.4 + warp * 5.0).sin() * (fy * 0.4 + weft * 5.0).cos()).abs();
                
                // Map telemetry to dynamic RGB palette
                // Temperature maps Red, Pressure maps Blue, Humidity maps Green, Wind drives Luminescence
                let r_val = ((telemetry.temperature_k - 270.0) * 8.0 + warp * 80.0 + weave_pattern * 50.0).clamp(0.0, 255.0) as u8;
                let g_val = (telemetry.humidity_pct * 2.2 + weft * 60.0 + (self.time_offset * 2.0).sin() * 30.0).clamp(0.0, 255.0) as u8;
                let b_val = ((telemetry.pressure_hpa - 980.0) * 5.0 + (warp + weft) * 40.0).clamp(0.0, 255.0) as u8;

                grid[y][x] = (r_val, g_val, b_val);
            }
        }

        grid
    }
}

// --- 3. Telemetry Ingestion & Render Micro-service ---

fn main() {
    let frame_width = 80;
    let frame_height = 24;

    // Shared thread-safe state container for telemetry ingestion
    let telemetry_store = Arc::new(Mutex::new(AtmosphericTelemetry {
        temperature_k: 288.15,
        pressure_hpa: 1013.25,
        humidity_pct: 50.0,
        wind_speed_ms: 5.0,
    }));

    let telemetry_producer = Arc::clone(&telemetry_store);
    let start_time = Instant::now();

    // Background thread: Ingests real-time atmospheric sensor updates asynchronously
    thread::spawn(move || {
        loop {
            let current_telemetry = AtmosphericTelemetry::sample_mock(start_time);
            if let Ok(mut lock) = telemetry_producer.lock() {
                *lock = current_telemetry;
            }
            thread::sleep(Duration::from_millis(100)); // 10Hz ingestion rate
        }
    });

    let mut weaver = QuiltWeaver::new(frame_width, frame_height);
    let mut stdout = std::io::stdout();

    // Clear terminal screen and hide cursor
    print!("\x1B[2J\x1B[?25l");

    // Main Service Loop: Algorithmic synthesis and infinite ANSI terminal rendering
    loop {
        let current_telemetry = {
            let lock = telemetry_store.lock().unwrap();
            *lock
        };

        let frame = weaver.render_frame(&current_telemetry);

        // Move cursor to top-left home position
        print!("\x1B[H");

        // Render Telemetry HUD Header
        let (entropy, enthalpy) = current_telemetry.derive_thermodynamics();
        println!(
            "\x1B[1;37m=== THERMODYNAMIC DIGITAL QUILT SERVICE ===\x1B[0m"
        );
        println!(
            "\x1B[36mTemp: {:.2}K | Press: {:.1}hPa | Hum: {:.1}% | Wind: {:.1}m/s | S: {:.3} | H: {:.1}kJ/kg\x1B[0m\x1B[K",
            current_telemetry.temperature_k,
            current_telemetry.pressure_hpa,
            current_telemetry.humidity_pct,
            current_telemetry.wind_speed_ms,
            entropy,
            enthalpy
        );

        // Render Quilt Pixels using TrueColor ANSI background escape sequences
        for row in frame.iter() {
            for &(r, g, b) in row.iter() {
                print!("\x1B[48;2;{};{};{}m \x1B[0m", r, g, b);
            }
            println!("\x1B[K");
        }

        stdout.flush().unwrap();
        thread::sleep(Duration::from_millis(50)); // Render ~20 FPS
    }
}