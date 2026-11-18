// Generative Moss Wallpaper Engine driven by Network Packet Fluctuations
// Written in Rust for maximum performance and elegance.

use std::fs::File;
use std::io::{BufRead, BufReader};
use std::thread;
use std::time::{Duration, Instant};

// Simple struct to track network bytes
struct NetStats {
    rx_bytes: u64,
    tx_bytes: u64,
}

impl NetStats {
    // Read network stats from Linux /proc/net/dev, fallback to simulated flux if unavailable
    fn read() -> Self {
        if let Ok(file) = File::open("/proc/net/dev") {
            let reader = BufReader::new(file);
            let mut total_rx = 0;
            let mut total_tx = 0;
            for line in reader.lines().flatten() {
                if line.contains(':') {
                    let parts: Vec<&str> = line.split_whitespace().collect();
                    if parts.len() >= 10 {
                        if let (Ok(rx), Ok(tx)) = (parts[1].parse::<u64>(), parts[9].parse::<u64>()) {
                            total_rx += rx;
                            total_tx += tx;
                        }
                    }
                }
            }
            if total_rx > 0 || total_tx > 0 {
                return Self { rx_bytes: total_rx, tx_bytes: total_tx };
            }
        }
        // Fallback mock for non-Linux or systems without /proc/net/dev
        let now = Instant::now().elapsed().as_millis() as u64;
        Self {
            rx_bytes: (now * 1337) % 100_000_000,
            tx_bytes: (now * 7331) % 100_000_000,
        }
    }
}

#[derive(Clone)]
struct MossCell {
    energy: f32,
    hue: f32, // Moss color variation spectrum
}

fn main() {
    println!("Initializing Moss Network Symbiosis Engine...");
    
    const WIDTH: usize = 120;
    const HEIGHT: usize = 40;
    
    let mut grid: Vec<Vec<MossCell>> = (0..HEIGHT)
        .map(|_| {
            (0..WIDTH)
                .map(|_| MossCell { energy: 0.0, hue: 0.3 })
                .collect()
        })
        .collect();

    // Seed initial moss spores at random anchor points
    grid[HEIGHT / 2][WIDTH / 2].energy = 1.0;
    grid[HEIGHT / 4][WIDTH / 4].energy = 0.8;
    grid[(HEIGHT * 3) / 4][(WIDTH * 3) / 4].energy = 0.9;

    let mut last_stats = NetStats::read();
    let mut iteration = 0;

    loop {
        thread::sleep(Duration::from_millis(250));
        
        let current_stats = NetStats::read();
        let rx_diff = current_stats.rx_bytes.wrapping_sub(last_stats.rx_bytes);
        let tx_diff = current_stats.tx_bytes.wrapping_sub(last_stats.tx_bytes);
        last_stats = current_stats;

        // Packet activity coefficient governs moss growth rate and chromatic shift
        let activity = (rx_diff + tx_diff) as f32 / 1024.0; // KB delta
        let growth_boost = (activity.ln_1p() * 0.1).clamp(0.01, 0.5);

        // Diffuse and grow moss across the grid based on packet turbulence
        let mut new_grid = grid.clone();
        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                let cell = &grid[y][x];
                if cell.energy > 0.05 {
                    let neighbors = [
                        (y.wrapping_sub(1), x),
                        (y + 1, x),
                        (y, x.wrapping_sub(1)),
                        (y, x + 1),
                    ];
                    for &(ny, nx) in &neighbors {
                        if ny < HEIGHT && nx < WIDTH {
                            new_grid[ny][nx].energy = (new_grid[ny][nx].energy + cell.energy * 0.15 * growth_boost).min(1.0);
                            new_grid[ny][nx].hue = (cell.hue + 0.01) % 0.4;
                        }
                    }
                }
            }
        }
        grid = new_grid;

        // Render generative moss tapestry to terminal frame buffer
        print!("\x1B[2J\x1B[H");
        println!("--- MOSS NETWORK SYMBOSIS ENGINE (Iteration {}) ---", iteration);
        println!("Packet Flux Delta: RX +{} KB, TX +{} KB | Growth Rate: {:.3}", rx_diff / 1024, tx_diff / 1024, growth_boost);
        
        for row in &grid {
            for cell in row {
                let ch = if cell.energy > 0.8 {
                    '▓'
                } else if cell.energy > 0.5 {
                    '▒'
                } else if cell.energy > 0.2 {
                    '░'
                } else {
                    '.'
                };
                print!("{}", ch);
            }
            println!();
        }

        iteration += 1;
        if iteration > 1000 {
            break;
        }
    }
}