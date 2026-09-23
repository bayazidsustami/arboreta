// Bioluminescent Calligraphic Flocking Simulation driven by CPU thermal state
// Run with: rustc -O this_file.rs && ./this_file

use std::fs;
use std::io::{self, Write};
use std::thread;
use std::time::{Duration, Instant};

const WIDTH: usize = 80;
const HEIGHT: usize = 30;

#[derive(Clone)]
struct Boid {
    x: f32,
    y: f32,
    vx: f32,
    vy: f32,
}

// Reads system CPU temperature or falls back to a rhythmic thermal simulation
fn read_cpu_temp() -> f32 {
    if let Ok(content) = fs::read_to_string("/sys/class/thermal/thermal_zone0/temp") {
        if let Ok(millideg) = content.trim().parse::<f32>() {
            return millideg / 1000.0;
        }
    }
    let t = Instant::now().elapsed().as_secs_f32();
    45.0 + 15.0 * (t * 0.5).sin() + 8.0 * (t * 1.3).cos()
}

// Simple internal pseudo-random number generator to keep the script self-contained
fn rand_float() -> f32 {
    static mut SEED: u32 = 421153;
    unsafe {
        SEED ^= SEED << 13;
        SEED ^= SEED >> 17;
        SEED ^= SEED << 5;
        (SEED as f32) / (u32::MAX as f32)
    }
}

fn main() {
    // Clear the terminal screen and hide the cursor for an immersive experience
    print!("\x1b[2J\x1b[?25l");
    io::stdout().flush().unwrap();

    let mut boids: Vec<Boid> = (0..50).map(|i| {
        Boid {
            x: (i * 3) as f32 % WIDTH as f32,
            y: (i % HEIGHT) as f32,
            vx: 0.0,
            vy: 0.2,
        }
    }).collect();

    let start = Instant::now();

    loop {
        let temp = read_cpu_temp();
        // Thermal fluctuations modulate chaotic dispersion and downward weeping velocity
        let thermal_chaos = ((temp - 30.0) / 45.0).clamp(0.1, 2.5);
        let weeping_gravity = 0.05 + thermal_chaos * 0.15;

        // Update boid mechanics (flocking meets weeping calligraphy)
        for boid in &mut boids {
            boid.vy += weeping_gravity * 0.03;
            boid.vx += (rand_float() - 0.5) * thermal_chaos * 0.2;

            boid.vx *= 0.92;
            boid.vy *= 0.95;

            boid.x += boid.vx;
            boid.y += boid.vy;

            // Wrap and re-seed at the top for endless weeping streams
            if boid.y >= HEIGHT as f32 {
                boid.y = 0.0;
                boid.x = (boid.x * 13.0) % WIDTH as f32;
            }
            if boid.x < 0.0 { boid.x += WIDTH as f32; }
            if boid.x >= WIDTH as f32 { boid.x -= WIDTH as f32; }
        }

        // Render buffer
        let mut screen = vec![vec![' '; WIDTH]; HEIGHT];
        for boid in &boids {
            let ix = (boid.x as usize).min(WIDTH - 1);
            let iy = (boid.y as usize).min(HEIGHT - 1);
            screen[iy][ix] = if thermal_chaos > 1.5 { 'Ψ' } else { '∫' };
        }

        // Draw to terminal via ANSI escape sequences
        print!("\x1b[H");
        println!("CPU Temperature: {:.1}°C | Thermal Chaos Index: {:.2}", temp, thermal_chaos);

        for row in screen {
            let line: String = row.iter().collect();
            // Dynamic bioluminescent color mapping shifting from deep cyan to glowing emerald
            let green_channel = (temp * 4.0).clamp(80.0, 255.0) as u8;
            let blue_channel = (255.0 - temp * 1.5).clamp(40.0, 220.0) as u8;
            println!("\x1b[38;2;20;{};{}m{}\x1b[0m", green_channel, blue_channel, line);
        }

        thread::sleep(Duration::from_millis(40));

        // Run for 60 seconds before gracefully exiting
        if start.elapsed().as_secs() > 60 {
            break;
        }
    }

    // Restore terminal cursor state
    print!("\x1b[?25h");
    io::stdout().flush().unwrap();
}