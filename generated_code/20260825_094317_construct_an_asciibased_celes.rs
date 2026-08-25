use std::collections::HashMap;
use std::io::{self, Write};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

// Custom minimal LCG Pseudo-Random Number Generator for predictable cosmic generation
struct CosmosRng {
    state: u64,
}

impl CosmosRng {
    fn new(seed: u64) -> Self {
        Self { state: seed }
    }

    fn next_u32(&mut self) -> u32 {
        self.state = self.state.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (self.state >> 32) as u32
    }

    fn range(&mut self, min: f64, max: f64) -> f64 {
        let pct = (self.next_u32() as f64) / (u32::MAX as f64);
        min + pct * (max - min)
    }
}

// Visual representation of a star in the system memory constellation
#[derive(Clone)]
struct Star {
    x: f64,
    y: f64,
    vx: f64,
    vy: f64,
    luminosity: f64,
    decay_rate: f64,
    glyph: char,
    spectral_color: &'static str,
}

impl Star {
    fn new(x: f64, y: f64, memory_address_hash: u64) -> Self {
        let mut rng = CosmosRng::new(memory_address_hash);
        
        let angle = rng.range(0.0, std::f64::consts::TAU);
        let speed = rng.range(0.02, 0.15);
        let glyphs = ['*', ':', '.', '+', 'o', 'O', 'x', 'x', 'o'];
        let colors = [
            "\x1b[38;5;15m",  // White
            "\x1b[38;5;81m",  // Cyan
            "\x1b[38;5;221m", // Gold
            "\x1b[38;5;204m", // Pink
            "\x1b[38;5;141m", // Purple
        ];

        Self {
            x,
            y,
            vx: angle.cos() * speed,
            vy: angle.sin() * speed * 0.5, // Aspect ratio compensation
            luminosity: rng.range(0.8, 1.0),
            decay_rate: rng.range(0.005, 0.03),
            glyph: glyphs[(rng.next_u32() as usize) % glyphs.len()],
            spectral_color: colors[(rng.next_u32() as usize) % colors.len()],
        }
    }

    fn update(&mut self, center_x: f64, center_y: f64, gravity_strength: f64) {
        // Orbital mechanics towards dynamic center of mass
        let dx = center_x - self.x;
        let dy = center_y - self.y;
        let dist_sq = (dx * dx + dy * dy).max(1.0);
        let force = gravity_strength / dist_sq;

        self.vx += dx * force;
        self.vy += dy * force;

        self.x += self.vx;
        self.y += self.vy;

        // Apply star decay over time
        self.luminosity -= self.decay_rate;
    }
}

// Celestial Map canvas for rendering space
struct CelestialCanvas {
    width: usize,
    height: usize,
    buffer: Vec<Vec<(&'static char) str,>>,
}

impl CelestialCanvas {
    fn new(width: usize, height: usize) -> Self {
        Self {
            width,
            height,
            buffer: vec![vec![("\x1b[0m", ' '); width]; height],
        }
    }

    fn clear(&mut self) {
        for row in self.buffer.iter_mut() {
            for cell in row.iter_mut() {
                *cell = ("\x1b[0m", ' ');
            }
        }
    }

    fn draw_star(&mut self, star: &Star) {
        let ix = star.x.round() as i32;
        let iy = star.y.round() as i32;

        if ix >= 0 && ix < self.width as i32 && iy >= 0 && iy < self.height as i32 {
            let dim_color = if star.luminosity < 0.3 {
                "\x1b[38;5;238m"
            } else if star.luminosity < 0.6 {
                "\x1b[38;5;244m"
            } else {
                star.spectral_color
            };

            self.buffer[iy as usize][ix as usize] = (dim_color, star.glyph);
        }
    }

    fn draw_constellation_line(&mut self, s1: &Star, s2: &Star) {
        let x0 = s1.x.round() as i32;
        let y0 = s1.y.round() as i32;
        let x1 = s2.x.round() as i32;
        let y1 = s2.y.round() as i32;

        // Bresenham's line algorithm for constellation links
        let dx = (x1 - x0).abs();
        let dy = -(y1 - y0).abs();
        let sx = if x0 < x1 { 1 } else { -1 };
        let sy = if y0 < y1 { 1 } else { -1 };
        let mut err = dx + dy;

        let mut curr_x = x0;
        let mut curr_y = y0;

        while curr_x != x1 || curr_y != y1 {
            if curr_x >= 0 && curr_x < self.width as i32 && curr_y >= 0 && curr_y < self.height as i32 {
                if self.buffer[curr_y as usize][curr_x as usize].1 == ' ' {
                    self.buffer[curr_y as usize][curr_x as usize] = ("\x1b[38;5;236m", '·');
                }
            }

            let e2 = 2 * err;
            if e2 >= dy {
                err += dy;
                curr_x += sx;
            }
            if e2 <= dx {
                err += dx;
                curr_y += sy;
            }
        }
    }

    fn render(&self, stdout: &mut io::Stdout, memory_bytes: usize, star_count: usize) -> io::Result<()> {
        let mut out = String::with_capacity(self.width * self.height * 10);
        out.push_str("\x1b[H"); // Move cursor to top-left

        // Header interface
        out.push_str("\x1b[38;5;39m=== CELESTIAL NAVIGATOR :: MEMORY ORBITAL MAP ===\x1b[0m\n");
        out.push_str(&format!(
            "\x1b[38;5;250mSystem Allocation: \x1b[38;5;82m{:>10} B\x1b[0m | Active Stars: \x1b[38;5;220m{:>4}\x1b[0m | Orbit Gravity: \x1b[38;5;208mDynamic\x1b[0m\n",
            memory_bytes, star_count
        ));
        out.push_str("\x1b[38;5;238m" );
        out.push_str(&"─".repeat(self.width));
        out.push_str("\x1b[0m\n");

        // Canvas grid
        for row in &self.buffer {
            for (color, ch) in row {
                out.push_str(color);
                out.push(*ch);
            }
            out.push('\n');
        }

        out.push_str("\x1b[38;5;238m");
        out.push_str(&"─".repeat(self.width));
        out.push_str("\x1b[0m\n");
        out.push_str("\x1b[38;5;242mPress [Ctrl+C] to return to earthly realms.\x1b[0m");

        stdout.write_all(out.as_bytes())?;
        stdout.flush()
    }
}

// Celestial System managing allocations and stars
struct CelestialNavigator {
    stars: Vec<Star>,
    allocations: HashMap<usize, Vec<u8>>,
    canvas: CelestialCanvas,
    center_x: f64,
    center_y: f64,
    time_step: usize,
}

impl CelestialNavigator {
    fn new(width: usize, height: usize) -> Self {
        Self {
            stars: Vec::new(),
            allocations: HashMap::new(),
            canvas: CelestialCanvas::new(width, height),
            center_x: (width / 2) as f64,
            center_y: (height / 2) as f64,
            time_step: 0,
        }
    }

    // Translate real-time system memory allocation into procedural stars
    fn pulse_memory(&mut self) {
        self.time_step += 1;
        let mut rng = CosmosRng::new(self.time_step as u64 * 1337);

        // Procedurally allocate or deallocate heap chunks to drive memory movement
        if rng.next_u32() % 2 == 0 || self.allocations.is_empty() {
            let size = ((rng.next_u32() % 1024) + 256) as usize;
            let vec: Vec<u8> = vec![42; size];
            let ptr = vec.as_ptr() as usize;
            self.allocations.insert(ptr, vec);

            // Spawn star linked to heap address
            let spawn_radius = rng.range(5.0, 20.0);
            let angle = rng.range(0.0, std::f64::consts::TAU);
            let x = self.center_x + angle.cos() * spawn_radius;
            let y = self.center_y + angle.sin() * spawn_radius * 0.5;

            self.stars.push(Star::new(x, y, ptr as u64));
        } else if !self.allocations.is_empty() {
            let keys: Vec<usize> = self.allocations.keys().copied().collect();
            let target_key = keys[(rng.next_u32() as usize) % keys.len()];
            self.allocations.remove(&target_key);
        }

        // Dynamically move orbital gravitational center
        self.center_x = (self.canvas.width as f64 / 2.0) + (self.time_step as f64 * 0.05).cos() * 10.0;
        self.center_y = (self.canvas.height as f64 / 2.0) + (self.time_step as f64 * 0.05).sin() * 5.0;
    }

    fn update_cosmos(&mut self) {
        let cx = self.center_x;
        let cy = self.center_y;

        // Update orbits and decay
        for star in self.stars.iter_mut() {
            star.update(cx, cy, 0.4);
        }

        // Filter out decayed stars
        self.stars.retain(|s| s.luminosity > 0.0);

        // Render buffer construction
        self.canvas.clear();

        // Connect proximate stars into procedural constellations
        let star_count = self.stars.len();
        for i in 0..star_count {
            for j in (i + 1)..star_count {
                let dx = self.stars[i].x - self.stars[j].x;
                let dy = self.stars[i].y - self.stars[j].y;
                let dist = (dx * dx + dy * dy).sqrt();

                if dist < 8.0 {
                    let s1 = self.stars[i].clone();
                    let s2 = self.stars[j].clone();
                    self.canvas.draw_constellation_line(&s1, &s2);
                }
            }
        }

        // Draw individual stars
        for star in &self.stars {
            self.canvas.draw_star(star);
        }
    }

    fn calculate_allocated_bytes(&self) -> usize {
        self.allocations.values().map(|v| v.capacity()).sum()
    }
}

fn main() -> io::Result<()> {
    // Setup terminal interface
    let mut stdout = io::stdout();
    stdout.write_all(b"\x1b[?25l\x1b[2J")?; // Hide cursor and clear screen

    // Handle graceful exit interrupt flag
    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();
    
    // Simple terminal setup
    let width = 70;
    let height = 22;
    let mut navigator = CelestialNavigator::new(width, height);

    let start_time = Instant::now();

    while running.load(Ordering::SeqCst) {
        navigator.pulse_memory();
        navigator.update_cosmos();
        
        let total_mem = navigator.calculate_allocated_bytes();
        navigator.canvas.render(&mut stdout, total_mem, navigator.stars.len())?;

        // Run simulation for ~20 seconds then gracefully terminate
        if start_time.elapsed() > Duration::from_secs(20) {
            break;
        }

        thread::sleep(Duration::from_millis(80));
    }

    // Reset terminal settings on exit
    stdout.write_all(b"\x1b[?25h\x1b[2J\x1b[H")?;
    stdout.flush()?;
    println!("Celestial navigation complete. Constellations safely collapsed.");

    Ok(())
}