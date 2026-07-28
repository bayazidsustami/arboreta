// Interactive File System Stellar Visualizer
// Renders direct filesystem structures as procedural orbital planetary systems.
// Physics & Aesthetics Mapping:
// - Central Star: Target Directory (Mass = Total Directory Size)
// - Planets: Subdirectories (◎) and Files (● / o)
// - Orbital Velocity: Access Timestamp (Recently accessed files orbit faster)
// - Mass & Radius: File Byte Size (Logarithmic mass scaling)
// - Atmosphere Color: Shannon Entropy Score (0.0 Low/Text = Cyan -> 8.0 High/Binary = Red)

use std::env;
use std::fs;
use std::io::{self, Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant, SystemTime};

struct Planet {
    name: String,
    size_bytes: u64,
    mass: f64,
    semi_major: f64,
    semi_minor: f64,
    orbital_speed: f64,
    entropy: f64,
    color_rgb: (u8, u8, u8),
    is_dir: bool,
}

struct StellarSystem {
    star_name: String,
    star_mass: u64,
    planets: Vec<Planet>,
}

// Compute Shannon entropy (0.0 - 8.0 bits/byte) to measure file randomness/density
fn calculate_shannon_entropy(path: &Path) -> f64 {
    if path.is_dir() {
        return 2.5; // Baseline entropy representation for directories
    }
    let mut file = match fs::File::open(path) {
        Ok(f) => f,
        Err(_) => return 0.0,
    };
    let mut buffer = [0u8; 8192];
    let bytes_read = match file.read(&mut buffer) {
        Ok(n) if n > 0 => n,
        _ => return 0.0,
    };

    let mut counts = [0u64; 256];
    for &b in &buffer[..bytes_read] {
        counts[b as usize] += 1;
    }

    let total = bytes_read as f64;
    let mut entropy = 0.0;
    for &count in &counts {
        if count > 0 {
            let p = count as f64 / total;
            entropy -= p * p.log2();
        }
    }
    entropy
}

// Map Shannon entropy to RGB spectrum: Low (Cyan/Blue) -> Mid (Green/Yellow) -> High (Red)
fn map_entropy_to_color(entropy: f64) -> (u8, u8, u8) {
    let t = (entropy / 8.0).clamp(0.0, 1.0);
    if t < 0.5 {
        let u = t * 2.0;
        (0, (255.0 * u) as u8, (255.0 * (1.0 - u)) as u8)
    } else {
        let u = (t - 0.5) * 2.0;
        ((255.0 * u) as u8, (255.0 * (1.0 - u)) as u8, 0)
    }
}

// Scan path and convert entries into planetary celestial bodies
fn scan_directory(target: &Path) -> io::Result<StellarSystem> {
    let mut planets = Vec::new();
    let mut total_size = 0u64;

    if let Ok(entries) = fs::read_dir(target) {
        let now = SystemTime::now();
        let mut idx = 1;

        for entry in entries.flatten() {
            let path = entry.path();
            let metadata = match entry.metadata() {
                Ok(m) => m,
                Err(_) => continue,
            };

            let is_dir = metadata.is_dir();
            let size = if is_dir { 4096 } else { metadata.len() };
            total_size += size;

            // Access timestamps drive orbital speed dynamics
            let access_time = metadata.accessed().unwrap_or(now);
            let age_secs = now.duration_since(access_time).unwrap_or(Duration::ZERO).as_secs() as f64;
            let recency_factor = 1.0 / (1.0 + (age_secs / 86400.0).sqrt());
            let speed = (0.4 + recency_factor * 1.5) * (if idx % 2 == 0 { 1.0 } else { -1.0 });

            let entropy = calculate_shannon_entropy(&path);
            let color = map_entropy_to_color(entropy);

            // Semi-major & semi-minor orbital axes (adjusted for 1:2 terminal character aspect ratio)
            let semi_major = 5.0 + (idx as f64) * 2.8;
            let semi_minor = semi_major * 0.45;

            let name = path.file_name().unwrap_or_default().to_string_lossy().into_owned();

            planets.push(Planet {
                name,
                size_bytes: size,
                mass: (size as f64).log10().max(1.0),
                semi_major,
                semi_minor,
                orbital_speed: speed,
                entropy,
                color_rgb: color,
                is_dir,
            });

            idx += 1;
            if idx > 10 { break; } // Bound system size for standard terminal dimensions
        }
    }

    let star_name = target.canonicalize()
        .unwrap_or_else(|_| target.to_path_buf())
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| "Root".into());

    Ok(StellarSystem {
        star_name,
        star_mass: total_size,
        planets,
    })
}

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    let dir_path = if args.len() > 1 {
        PathBuf::from(&args[1])
    } else {
        env::current_dir()?
    };

    let system = scan_directory(&dir_path)?;

    // Hide cursor and clear viewport
    print!("\x1b[2J\x1b[?25l");
    io::stdout().flush()?;

    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();

    // Spawn non-blocking thread to capture exit trigger (ENTER)
    thread::spawn(move || {
        let mut buffer = [0u8; 1];
        while r.load(Ordering::Relaxed) {
            if io::stdin().read(&mut buffer).is_ok() {
                r.store(false, Ordering::Relaxed);
                break;
            }
        }
    });

    let width = 76;
    let height = 26;
    let center_x = width / 2;
    let center_y = height / 2;

    let start_time = Instant::now();

    while running.load(Ordering::Relaxed) {
        let t = start_time.elapsed().as_secs_f64();
        let mut frame = vec![vec![' '; width]; height];
        let mut color_map = vec![vec![(255, 255, 255); width]; height];

        // Render Central Star
        if center_y < height && center_x < width {
            frame[center_y][center_x] = '★';
            color_map[center_y][center_x] = (255, 215, 0);
        }

        // Render Orbits & Orbiting Planetary Masses
        for planet in &system.planets {
            let steps = 48;
            for i in 0..steps {
                let theta = (i as f64) * 2.0 * std::f64::consts::PI / (steps as f64);
                let ox = (center_x as f64 + planet.semi_major * theta.cos()).round() as i32;
                let oy = (center_y as f64 + planet.semi_minor * theta.sin()).round() as i32;

                if ox >= 0 && ox < width as i32 && oy >= 0 && oy < height as i32 {
                    let ux = ox as usize;
                    let uy = oy as usize;
                    if frame[uy][ux] == ' ' {
                        frame[uy][ux] = '·';
                        color_map[uy][ux] = (50, 50, 65);
                    }
                }
            }

            // Real-time planetary trajectory calculations
            let angle = t * planet.orbital_speed;
            let px = (center_x as f64 + planet.semi_major * angle.cos()).round() as i32;
            let py = (center_y as f64 + planet.semi_minor * angle.sin()).round() as i32;

            if px >= 0 && px < width as i32 && py >= 0 && py < height as i32 {
                let ux = px as usize;
                let uy = py as usize;
                let symbol = if planet.is_dir { '◎' } else if planet.mass > 5.0 { '●' } else { 'o' };
                frame[uy][ux] = symbol;
                color_map[uy][ux] = planet.color_rgb;
            }
        }

        // Frame rendering with double-buffered ANSI output
        let mut buffer = String::with_capacity(width * height * 16);
        buffer.push_str("\x1b[H");
        buffer.push_str(&format!(
            " STELLAR SYSTEM: \x1b[1;33m{}\x1b[0m | Total Mass: {} KB | Objects: {}\n",
            system.star_name,
            system.star_mass / 1024,
            system.planets.len()
        ));
        buffer.push_str(&"━".repeat(width));
        buffer.push('\n');

        for y in 0..height {
            for x in 0..width {
                let ch = frame[y][x];
                let (cr, cg, cb) = color_map[y][x];
                if ch != ' ' {
                    buffer.push_str(&format!("\x1b[38;2;{};{};{}m{}\x1b[0m", cr, cg, cb, ch));
                } else {
                    buffer.push(' ');
                }
            }
            buffer.push('\n');
        }

        buffer.push_str(&"━".repeat(width));
        buffer.push_str("\n Atmosphere (Entropy): \x1b[38;2;0;255;255mLow (Code/Text)\x1b[0m ➔ \x1b[38;2;255;0;0mHigh (Binary/Compressed)\x1b[0m");
        buffer.push_str("\n Press [ENTER] to disengage system view...\n");

        print!("{}", buffer);
        io::stdout().flush()?;

        thread::sleep(Duration::from_millis(50));
    }

    // Reset terminal viewport state
    print!("\x1b[?25h\x1b[2J\x1b[H");
    io::stdout().flush()?;
    println!("Stellar File System Visualizer closed.");

    Ok(())
}