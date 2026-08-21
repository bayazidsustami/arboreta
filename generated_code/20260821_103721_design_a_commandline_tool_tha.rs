use std::f32::consts::PI;
use std::io::{stdout, Write};
use std::thread;
use std::time::{Duration, Instant};

// Simulated thermal camera frame dimensions
const WIDTH: usize = 80;
const HEIGHT: usize = 35;

// ASCII character density gradient (darkest/coolest to brightest/hottest)
const ASCII_GRADIENT: &[char] = &[' ', '.', ':', '-', '=', '+', '*', '#', '%', '@'];

// Typographical "heat poetry" fragments mapped to heat flux thresholds
const POETIC_FRAGMENTS: &[&str] = &[
    "ember", "flicker", "kindle", "ignite", "blaze", "radiate", "consume", "inferno",
];

struct HeatSource {
    x: f32,
    y: f32,
    intensity: f32,
    phase: f32,
    frequency: f32,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut stdout = stdout();
    let start_time = Instant::now();

    // Initialize dynamic thermal sources simulating a live flame feed
    let mut heat_sources = vec![
        HeatSource { x: 40.0, y: 30.0, intensity: 1.0, phase: 0.0, frequency: 1.2 },
        HeatSource { x: 25.0, y: 28.0, intensity: 0.8, phase: 1.5, frequency: 0.9 },
        HeatSource { x: 55.0, y: 28.0, intensity: 0.85, phase: 2.7, frequency: 1.1 },
        HeatSource { x: 40.0, y: 15.0, intensity: 0.5, phase: 0.5, frequency: 2.0 },
    ];

    // Hide cursor and clear screen
    print!("\x1B[?25l\x1B[2J");

    loop {
        let t = start_time.elapsed().as_secs_f32();

        // 1. Capture real-time thermal camera feed (simulated via fluid turbulence equations)
        let thermal_grid = capture_thermal_feed(WIDTH, HEIGHT, t, &mut heat_sources);

        // 2. Render typographical flame map using character density & heat flux modulation
        let mut frame_buffer = String::with_capacity((WIDTH + 1) * HEIGHT + 32);
        
        // Reset terminal cursor to top-left
        frame_buffer.push_str("\x1B[H");

        for y in 0..HEIGHT {
            let mut x = 0;
            while x < WIDTH {
                let heat_val = thermal_grid[y * WIDTH + x];
                let heat_flux = calculate_heat_flux(&thermal_grid, x, y, WIDTH, HEIGHT);

                // Dynamically modulate font styling/color using ANSI escape codes based on heat
                let color_code = heat_to_ansi_color(heat_val, heat_flux);

                // High heat flux region: inject visual poetry words inline
                if heat_val > 0.65 && heat_flux > 0.08 && x + 7 < WIDTH {
                    let word_idx = ((heat_val * 10.0) as usize + y) % POETIC_FRAGMENTS.len();
                    let word = POETIC_FRAGMENTS[word_idx];
                    
                    frame_buffer.push_str(&format!("\x1B[1;{}m{}\x1B[0m", color_code, word));
                    x += word.len();
                    continue;
                }

                // Standard thermal pixel mapping to ASCII density
                let density_idx = ((heat_val.clamp(0.0, 0.99)) * ASCII_GRADIENT.len() as f32) as usize;
                let ch = ASCII_GRADIENT[density_idx];

                // Bold weight modulation for turbulent/high-flux pixels
                if heat_flux > 0.05 {
                    frame_buffer.push_str(&format!("\x1B[1;{}m{}\x1B[0m", color_code, ch));
                } else {
                    frame_buffer.push_str(&format!("\x1B[0;{}m{}\x1B[0m", color_code, ch));
                }

                x += 1;
            }
            frame_buffer.push('\n');
        }

        // Output rendered frame directly to terminal buffer
        write!(stdout, "{}", frame_buffer)?;
        stdout.flush()?;

        // Target ~30 FPS loop
        thread::sleep(Duration::from_millis(33));
    }
}

/// Simulates a real-time thermal camera sensor grid with buoyancy and convective dissipation
fn capture_thermal_feed(
    width: usize,
    height: usize,
    t: f32,
    sources: &mut [HeatSource],
) -> Vec<f32> {
    let mut grid = vec![0.0f32; width * height];

    // Modulate thermal sources over time
    for src in sources.iter_mut() {
        src.x += (t * src.frequency + src.phase).sin() * 0.4;
        src.y += (t * src.frequency * 0.5 + src.phase).cos() * 0.2;
    }

    for y in 0..height {
        let y_f = y as f32;
        for x in 0..width {
            let x_f = x as f32;
            let mut temp = 0.0;

            // Thermal field superposition
            for src in sources.iter() {
                let dx = x_f - src.x;
                let dy = y_f - src.y;
                let dist_sq = dx * dx + dy * dy;
                temp += src.intensity * (-dist_sq / 120.0).exp();
            }

            // Thermal noise and convective turbulence
            let turbulence = ((x_f * 0.1 + t * 2.0).sin() * (y_f * 0.15 - t * 3.0).cos()) * 0.15;
            let upward_draft = (height as f32 - y_f) / height as f32;

            grid[y * width + x] = (temp + turbulence * upward_draft).clamp(0.0, 1.0);
        }
    }

    grid
}

/// Calculates localized ambient heat flux vector magnitude (spatial gradient)
fn calculate_heat_flux(
    grid: &[f32],
    x: usize,
    y: usize,
    width: usize,
    height: usize,
) -> f32 {
    let current = grid[y * width + x];
    let dx = if x + 1 < width { (grid[y * width + (x + 1)] - current).abs() } else { 0.0 };
    let dy = if y + 1 < height { (grid[(y + 1) * width + x] - current).abs() } else { 0.0 };

    (dx * dx + dy * dy).sqrt()
}

/// Maps heat value and thermal flux gradient to ANSI 256-color palette
fn heat_to_ansi_color(heat: f32, flux: f32) -> u8 {
    if flux > 0.12 {
        231 // Bright White (extreme heat reaction/ignition point)
    } else if heat > 0.85 {
        196 // Deep Red
    } else if heat > 0.65 {
        202 // Orange-Red
    } else if heat > 0.45 {
        214 // Orange-Yellow
    } else if heat > 0.25 {
        226 // Yellow
    } else if heat > 0.10 {
        240 // Dark Grey (Cool smoke/ambient)
    } else {
        234 // Charcoal / Background
    }
}