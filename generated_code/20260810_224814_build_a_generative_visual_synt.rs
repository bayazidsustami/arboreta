// Generative Visual Synthesizer: Real-Time GC Log Fluid Dynamics Simulation
// Converts memory allocation metrics and leak events into an Eulerian 2D fluid simulation.
// Run directly with: rustc main.rs && ./main

use std::f32::consts::PI;
use std::io::{self, Write};
use std::thread::sleep;
use std::time::{Duration, Instant};

const WIDTH: usize = 80;
const HEIGHT: usize = 40;
const SIZE: usize = WIDTH * HEIGHT;
const ITERATIONS: usize = 4; // Solver precision steps

/// GC Event Types derived from log telemetry
#[derive(Debug, Clone)]
enum GcEvent {
    MinorGc { freed_kb: usize, duration_ms: f32 },
    MajorGc { reclaimed_kb: usize, duration_ms: f32 },
    MemoryLeak { address: usize, leak_size_kb: usize },
    Allocation { size_kb: usize },
}

/// Simulated GC Log Parser/Streamer
struct GcLogStream {
    start_time: Instant,
    step_count: u64,
}

impl GcLogStream {
    fn new() -> Self {
        Self {
            start_time: Instant::now(),
            step_count: 0,
        }
    }

    /// Generates realistic synthetic GC telemetry streams
    fn next_event(&mut self) -> (String, Option<GcEvent>) {
        self.step_count += 1;
        let elapsed = self.start_time.elapsed().as_secs_f32();

        if self.step_count % 35 == 0 {
            let addr = 0x7fff0000 + (self.step_count as usize * 0x100);
            let size = 512 + (self.step_count as usize % 10) * 256;
            let log = format!("[CRITICAL] MEMORY LEAK detected at 0x{:x} ({} KB retained, unreferenced)", addr, size);
            (log, Some(GcEvent::MemoryLeak { address: addr, leak_size_kb: size }))
        } else if self.step_count % 12 == 0 {
            let reclaimed = 2048 + ((elapsed * 100.0) as usize % 4096);
            let duration = 5.0 + (elapsed % 3.0) * 2.5;
            let log = format!("[GC Major] Pause: {:.2}ms, Reclaimed: {} KB, Heap Compacted", duration, reclaimed);
            (log, Some(GcEvent::MajorGc { reclaimed_kb: reclaimed, duration_ms: duration }))
        } else if self.step_count % 4 == 0 {
            let freed = 128 + (self.step_count as usize % 512);
            let duration = 0.4 + (elapsed % 1.5);
            let log = format!("[GC Minor] Young Gen collection: freed {} KB in {:.2}ms", freed, duration);
            (log, Some(GcEvent::MinorGc { freed_kb: freed, duration_ms: duration }))
        } else {
            let alloc = 32 + (self.step_count as usize % 128);
            let log = format!("[ALLOC] Thread #{}: allocated {} KB", self.step_count % 4, alloc);
            (log, Some(GcEvent::Allocation { size_kb: alloc }))
        }
    }
}

/// 2D Fluid Dynamics Grid implementing Eulerian Navier-Stokes equations
struct FluidGrid {
    dt: f32,
    diff: f32,
    visc: f32,
    s: Vec<f32>,
    density: Vec<f32>,
    vx: Vec<f32>,
    vy: Vec<f32>,
    vx0: Vec<f32>,
    vy0: Vec<f32>,
}

impl FluidGrid {
    fn new(dt: f32, diffusion: f32, viscosity: f32) -> Self {
        Self {
            dt,
            diff: diffusion,
            visc: viscosity,
            s: vec![0.0; SIZE],
            density: vec![0.0; SIZE],
            vx: vec![0.0; SIZE],
            vy: vec![0.0; SIZE],
            vx0: vec![0.0; SIZE],
            vy0: vec![0.0; SIZE],
        }
    }

    #[inline]
    fn ix(x: usize, y: usize) -> usize {
        x.clamp(0, WIDTH - 1) + y.clamp(0, HEIGHT - 1) * WIDTH
    }

    fn add_density(&mut self, x: usize, y: usize, amount: f32) {
        let idx = Self::ix(x, y);
        self.density[idx] += amount;
    }

    fn add_velocity(&mut self, x: usize, y: usize, amount_x: f32, amount_y: f32) {
        let idx = Self::ix(x, y);
        self.vx[idx] += amount_x;
        self.vy[idx] += amount_y;
    }

    /// Spawns an expanding topological vortex ring representing a memory leak
    fn inject_topological_vortex(&mut self, cx: usize, cy: usize, strength: f32, radius: usize) {
        let cx_f = cx as f32;
        let cy_f = cy as f32;

        for dy in -(radius as isize)..=(radius as isize) {
            for dx in -(radius as isize)..=(radius as isize) {
                let px = cx as isize + dx;
                let py = cy as isize + dy;

                if px >= 0 && px < WIDTH as isize && py >= 0 && py < HEIGHT as isize {
                    let rx = dx as f32;
                    let ry = dy as f32;
                    let dist_sq = rx * rx + ry * ry;
                    let dist = dist_sq.sqrt();

                    if dist > 0.1 && dist <= radius as f32 {
                        // Tangential velocity vector for rotational curl (vorticity)
                        let v_tangent_x = -ry / dist;
                        let v_tangent_y = rx / dist;
                        
                        let falloff = (-dist_sq / (2.0 * (radius as f32 * 0.5).powi(2))).exp();
                        let v_strength = strength * falloff;

                        self.add_velocity(px as usize, py as usize, v_tangent_x * v_strength, v_tangent_y * v_strength);
                        self.add_density(px as usize, py as usize, v_strength.abs() * 2.5);
                    }
                }
            }
        }
    }

    /// Diffusion step solver (Gauss-Seidel relaxation)
    fn diffuse(b: usize, x: &mut [f32], x0: &[f32], diff: f32, dt: f32) {
        let a = dt * diff * ((WIDTH - 2) * (HEIGHT - 2)) as f32;
        Self::lin_solve(b, x, x0, a, 1.0 + 6.0 * a);
    }

    fn lin_solve(b: usize, x: &mut [f32], x0: &[f32], a: f32, c: f32) {
        let c_recip = 1.0 / c;
        for _ in 0..ITERATIONS {
            for j in 1..HEIGHT - 1 {
                for i in 1..WIDTH - 1 {
                    let idx = Self::ix(i, j);
                    x[idx] = (x0[idx]
                        + a * (x[Self::ix(i + 1, j)]
                            + x[Self::ix(i - 1, j)]
                            + x[Self::ix(i, j + 1)]
                            + x[Self::ix(i, j - 1)]))
                        * c_recip;
                }
            }
            Self::set_bnd(b, x);
        }
    }

    /// Enforces fluid incompressibility (divergence-free velocity field)
    fn project(vx: &mut [f32], vy: &mut [f32], p: &mut [f32], div: &mut [f32]) {
        for j in 1..HEIGHT - 1 {
            for i in 1..WIDTH - 1 {
                let idx = Self::ix(i, j);
                div[idx] = -0.5
                    * (vx[Self::ix(i + 1, j)] - vx[Self::ix(i - 1, j)]
                        + vy[Self::ix(i, j + 1)] - vy[Self::ix(i, j - 1)])
                    / WIDTH as f32;
                p[idx] = 0.0;
            }
        }

        Self::set_bnd(0, div);
        Self::set_bnd(0, p);
        Self::lin_solve(0, p, div, 1.0, 6.0);

        for j in 1..HEIGHT - 1 {
            for i in 1..WIDTH - 1 {
                let idx = Self::ix(i, j);
                vx[idx] -= 0.5 * (p[Self::ix(i + 1, j)] - p[Self::ix(i - 1, j)]) * WIDTH as f32;
                vy[idx] -= 0.5 * (p[Self::ix(i, j + 1)] - p[Self::ix(i, j - 1)]) * HEIGHT as f32;
            }
        }

        Self::set_bnd(1, vx);
        Self::set_bnd(2, vy);
    }

    /// Advection solver moving quantities through velocity field
    fn advect(b: usize, d: &mut [f32], d0: &[f32], vx: &[f32], vy: &[f32], dt: f32) {
        let dtx = dt * (WIDTH - 2) as f32;
        let dty = dt * (HEIGHT - 2) as f32;

        for j in 1..HEIGHT - 1 {
            for i in 1..WIDTH - 1 {
                let idx = Self::ix(i, j);
                let x = (i as f32 - dtx * vx[idx]).clamp(0.5, WIDTH as f32 - 1.5);
                let y = (j as f32 - dty * vy[idx]).clamp(0.5, HEIGHT as f32 - 1.5);

                let i0 = x.floor() as usize;
                let i1 = i0 + 1;
                let j0 = y.floor() as usize;
                let j1 = j0 + 1;

                let s1 = x - i0 as f32;
                let s0 = 1.0 - s1;
                let t1 = y - j0 as f32;
                let t0 = 1.0 - t1;

                d[idx] = s0 * (t0 * d0[Self::ix(i0, j0)] + t1 * d0[Self::ix(i0, j1)])
                    + s1 * (t0 * d0[Self::ix(i1, j0)] + t1 * d0[Self::ix(i1, j1)]);
            }
        }

        Self::set_bnd(b, d);
    }

    /// Sets boundary conditions for fluid domain edge reflections
    fn set_bnd(b: usize, x: &mut [f32]) {
        for i in 1..WIDTH - 1 {
            x[Self::ix(i, 0)] = if b == 2 { -x[Self::ix(i, 1)] } else { x[Self::ix(i, 1)] };
            x[Self::ix(i, HEIGHT - 1)] = if b == 2 { -x[Self::ix(i, HEIGHT - 2)] } else { x[Self::ix(i, HEIGHT - 2)] };
        }
        for j in 1..HEIGHT - 1 {
            x[Self::ix(0, j)] = if b == 1 { -x[Self::ix(1, j)] } else { x[Self::ix(1, j)] };
            x[Self::ix(WIDTH - 1, j)] = if b == 1 { -x[Self::ix(WIDTH - 2, j)] } else { x[Self::ix(WIDTH - 2, j)] };
        }

        x[Self::ix(0, 0)] = 0.5 * (x[Self::ix(1, 0)] + x[Self::ix(0, 1)]);
        x[Self::ix(0, HEIGHT - 1)] = 0.5 * (x[Self::ix(1, HEIGHT - 1)] + x[Self::ix(0, HEIGHT - 2)]);
        x[Self::ix(WIDTH - 1, 0)] = 0.5 * (x[Self::ix(WIDTH - 2, 0)] + x[Self::ix(WIDTH - 1, 1)]);
        x[Self::ix(WIDTH - 1, HEIGHT - 1)] = 0.5 * (x[Self::ix(WIDTH - 2, HEIGHT - 1)] + x[Self::ix(WIDTH - 1, HEIGHT - 2)]);
    }

    /// Advances fluid physics simulation state
    fn step(&mut self) {
        let dt = self.dt;
        let visc = self.visc;
        let diff = self.diff;

        // Velocity step
        Self::diffuse(1, &mut self.vx0, &self.vx, visc, dt);
        Self::diffuse(2, &mut self.vy0, &self.vy, visc, dt);

        Self::project(&mut self.vx0, &mut self.vy0, &mut self.vx, &mut self.vy);

        Self::advect(1, &mut self.vx, &self.vx0, &self.vx0, &self.vy0, dt);
        Self::advect(2, &mut self.vy, &self.vy0, &self.vx0, &self.vy0, dt);

        Self::project(&mut self.vx, &mut self.vy, &mut self.vx0, &mut self.vy0);

        // Density step
        Self::diffuse(0, &mut self.s, &self.density, diff, dt);
        Self::advect(0, &mut self.density, &self.s, &self.vx, &self.vy, dt);

        // Dissipate density slowly to prevent infinite saturation
        for d in self.density.iter_mut() {
            *d *= 0.985;
        }
    }
}

/// Visual Synthesizer Engine mapping GC events to Fluid Domain and Rendering Output
struct VisualSynthesizer {
    fluid: FluidGrid,
    log_stream: GcLogStream,
    active_leaks: Vec<(usize, usize, f32)>, // (x, y, age)
    frame: u64,
}

impl VisualSynthesizer {
    fn new() -> Self {
        Self {
            fluid: FluidGrid::new(0.15, 0.0001, 0.00005),
            log_stream: GcLogStream::new(),
            active_leaks: Vec::new(),
            frame: 0,
        }
    }

    /// Process incoming logs and inject corresponding energy/vorticity fields
    fn process_gc_telemetry(&mut self) -> String {
        let (log, event) = self.log_stream.next_event();

        if let Some(gc_event) = event {
            match gc_event {
                GcEvent::Allocation { size_kb } => {
                    // Small allocations inject subtle local density near the top border
                    let x = 10 + (self.frame as usize * 7) % (WIDTH - 20);
                    let y = 3;
                    self.fluid.add_density(x, y, (size_kb as f32) * 0.15);
                    self.fluid.add_velocity(x, y, 0.0, 0.5);
                }
                GcEvent::MinorGc { freed_kb, duration_ms } => {
                    // Minor GC creates outward radial burst impulses
                    let cx = WIDTH / 2 + ((self.frame as f32 * 0.1).sin() * 15.0) as usize;
                    let cy = HEIGHT / 2 + ((self.frame as f32 * 0.1).cos() * 8.0) as usize;
                    let power = (freed_kb as f32 * 0.01) * duration_ms;

                    for angle in [0.0, PI / 2.0, PI, 3.0 * PI / 2.0] {
                        let vx = angle.cos() * power;
                        let vy = angle.sin() * power;
                        self.fluid.add_velocity(cx, cy, vx, vy);
                    }
                    self.fluid.add_density(cx, cy, power * 2.0);
                }
                GcEvent::MajorGc { reclaimed_kb, duration_ms } => {
                    // Major GC creates sweeping horizontal wave compaction
                    let intensity = (reclaimed_kb as f32 * 0.005) + duration_ms;
                    for x in 2..WIDTH - 2 {
                        let y = HEIGHT / 2;
                        self.fluid.add_velocity(x, y, 0.0, -intensity * 0.3);
                        self.fluid.add_density(x, y, intensity * 0.8);
                    }
                }
                GcEvent::MemoryLeak { address, leak_size_kb } => {
                    // Leaks form expanding topological vortex centers on canvas
                    let vx = 15 + (address % (WIDTH - 30));
                    let vy = 10 + ((address / 16) % (HEIGHT - 20));
                    let strength = 8.0 + (leak_size_kb as f32 * 0.02);
                    
                    self.fluid.inject_topological_vortex(vx, vy, strength, 8);
                    self.active_leaks.push((vx, vy, 0.0));
                }
            }
        }

        log
    }

    /// Renders frame to terminal using ANSI color palette and density glyphs
    fn render(&mut self, log_line: &str) {
        let mut stdout = io::stdout();
        let glyphs = [" ", ".", ":", "-", "=", "+", "*", "#", "%", "@"];

        // Move cursor to top-left of canvas terminal viewport
        print!("\x1B[H");

        // Header and log display bar
        println!("\x1B[1;36m=== REAL-TIME GC LOG FLUID SYNTHESIZER ===\x1B[0m");
        println!("\x1B[1;33mLOG:\x1B[0m {:<70}", log_line);
        println!("+{}-----+", "-".repeat(WIDTH));

        // Render fluid canvas grid
        for y in 0..HEIGHT {
            print!("|");
            for x in 0..WIDTH {
                let idx = FluidGrid::ix(x, y);
                let d = self.fluid.density[idx];
                let vx = self.fluid.vx[idx];
                let vy = self.fluid.vy[idx];
                let vel_sq = vx * vx + vy * vy;

                let glyph_idx = ((d * 0.25).clamp(0.0, (glyphs.len() - 1) as f32)) as usize;
                let symbol = glyphs[glyph_idx];

                // Determine ANSI spectral color based on fluid vorticity/energy & leak proximity
                if vel_sq > 2.0 {
                    // High vorticity / leak core -> Bright Magenta/Red
                    print!("\x1B[1;35m{}\x1B[0m", symbol);
                } else if d > 12.0 {
                    // Dense fluid -> Bright Cyan
                    print!("\x1B[1;36m{}\x1B[0m", symbol);
                } else if d > 5.0 {
                    // Medium fluid -> Blue
                    print!("\x1B[0;34m{}\x1B[0m", symbol);
                } else if d > 1.0 {
                    // Low fluid -> Dark Green
                    print!("\x1B[0;32m{}\x1B[0m", symbol);
                } else {
                    print!("{}", symbol);
                }
            }
            println!("|");
        }

        println!("+{}-----+", "-".repeat(WIDTH));
        println!("\x1B[1;32mActive Leak Vortices:\x1B[0m {} | \x1B[1;34mGrid Resolution:\x1B[0m {}x{}", 
                 self.active_leaks.len(), WIDTH, HEIGHT);
        stdout.flush().unwrap();
    }

    /// Main loop updating physics, handling leak lifecycle, and driving rendering
    fn run(&mut self) {
        // Clear terminal screen and hide cursor
        print!("\x1B[2J\x1B[?25l");

        loop {
            self.frame += 1;

            let log_line = self.process_gc_telemetry();

            // Re-stimulate active leak vortices to sustain expanding topological spin
            for leak in self.active_leaks.iter_mut() {
                leak.2 += 0.1;
                if leak.2 < 15.0 {
                    let radius = 4 + (leak.2 as usize % 5);
                    self.fluid.inject_topological_vortex(leak.0, leak.1, 2.5, radius);
                }
            }

            self.fluid.step();
            self.render(&log_line);

            sleep(Duration::from_millis(50));
        }
    }
}

fn main() {
    // Graceful terminal restoration on exit handle
    let _ = ctrlc_handler();

    let mut synthesizer = VisualSynthesizer::new();
    synthesizer.run();
}

fn ctrlc_handler() {
    // Ensures terminal cursor is unhidden if terminated
    std::panic::set_hook(Box::new(|_| {
        print!("\x1B[?25h");
        let _ = io::stdout().flush();
    }));
}