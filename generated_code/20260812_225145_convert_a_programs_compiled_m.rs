use std::f32::consts::PI;
use std::io::{self, Write};
use std::thread::sleep;
use std::time::Duration;

const GRID_W: usize = 70;
const GRID_H: usize = 35;
const ITERATIONS: usize = 4;

struct FluidGrid {
    u: Vec<f32>,
    v: Vec<f32>,
    u_prev: Vec<f32>,
    v_prev: Vec<f32>,
    r: Vec<f32>,
    g: Vec<f32>,
    b: Vec<f32>,
    r_prev: Vec<f32>,
    g_prev: Vec<f32>,
    b_prev: Vec<f32>,
}

impl FluidGrid {
    fn new() -> Self {
        let size = GRID_W * GRID_H;
        Self {
            u: vec![0.0; size],
            v: vec![0.0; size],
            u_prev: vec![0.0; size],
            v_prev: vec![0.0; size],
            r: vec![0.0; size],
            g: vec![0.0; size],
            b: vec![0.0; size],
            r_prev: vec![0.0; size],
            g_prev: vec![0.0; size],
            b_prev: vec![0.0; size],
        }
    }

    fn idx(x: usize, y: usize) -> usize {
        y * GRID_W + x
    }

    // Add velocity force at a grid coordinate
    fn add_force(&mut self, x: usize, y: usize, fx: f32, fy: f32) {
        if x < GRID_W && y < GRID_H {
            let i = Self::idx(x, y);
            self.u[i] += fx;
            self.v[i] += fy;
        }
    }

    // Inject colored dye into the fluid
    fn add_dye(&mut self, x: usize, y: usize, cr: f32, cg: f32, cb: f32) {
        if x < GRID_W && y < GRID_H {
            let i = Self::idx(x, y);
            self.r[i] = (self.r[i] + cr).min(1.0);
            self.g[i] = (self.g[i] + cg).min(1.0);
            self.b[i] = (self.b[i] + cb).min(1.0);
        }
    }

    // Generate rotational force (vortex) for conditional branch opcodes
    fn add_vortex(&mut self, cx: usize, cy: usize, radius: usize, strength: f32) {
        let min_x = cx.saturating_sub(radius);
        let max_x = (cx + radius).min(GRID_W - 1);
        let min_y = cy.saturating_sub(radius);
        let max_y = (cy + radius).min(GRID_H - 1);

        for y in min_y..=max_y {
            for x in min_x..=max_x {
                let dx = x as f32 - cx as f32;
                let dy = y as f32 - cy as f32;
                let dist = (dx * dx + dy * dy).sqrt();
                if dist > 0.1 && dist <= radius as f32 {
                    let falloff = 1.0 - (dist / radius as f32);
                    let fx = -dy / dist * strength * falloff;
                    let fy = dx / dist * strength * falloff;
                    self.add_force(x, y, fx, fy);
                }
            }
        }
    }

    // Advect quantities through velocity field
    fn advect(&mut self, dt: f32) {
        let mut new_r = vec![0.0; GRID_W * GRID_H];
        let mut new_g = vec![0.0; GRID_W * GRID_H];
        let mut new_b = vec![0.0; GRID_W * GRID_H];
        let mut new_u = vec![0.0; GRID_W * GRID_H];
        let mut new_v = vec![0.0; GRID_W * GRID_H];

        for y in 1..GRID_H - 1 {
            for x in 1..GRID_W - 1 {
                let i = Self::idx(x, y);
                let src_x = (x as f32 - self.u[i] * dt).clamp(0.5, GRID_W as f32 - 1.5);
                let src_y = (y as f32 - self.v[i] * dt).clamp(0.5, GRID_H as f32 - 1.5);

                let x0 = src_x as usize;
                let y0 = src_y as usize;
                let x1 = x0 + 1;
                let y1 = y0 + 1;

                let sx = src_x - x0 as f32;
                let sy = src_y - y0 as f32;

                let sample = |field: &[f32]| {
                    let i00 = field[Self::idx(x0, y0)];
                    let i10 = field[Self::idx(x1, y0)];
                    let i01 = field[Self::idx(x0, y1)];
                    let i11 = field[Self::idx(x1, y1)];
                    (1.0 - sx) * ((1.0 - sy) * i00 + sy * i01) + sx * ((1.0 - sy) * i10 + sy * i11)
                };

                new_r[i] = sample(&self.r) * 0.985; // slight decay
                new_g[i] = sample(&self.g) * 0.985;
                new_b[i] = sample(&self.b) * 0.985;
                new_u[i] = sample(&self.u) * 0.97; // velocity damping
                new_v[i] = sample(&self.v) * 0.97;
            }
        }

        self.r = new_r;
        self.g = new_g;
        self.b = new_b;
        self.u = new_u;
        self.v = new_v;
    }

    // Solve pressure projection to make velocity incompressible
    fn project(&mut self) {
        let mut p = vec![0.0; GRID_W * GRID_H];
        let mut div = vec![0.0; GRID_W * GRID_H];

        for y in 1..GRID_H - 1 {
            for x in 1..GRID_W - 1 {
                let i = Self::idx(x, y);
                div[i] = -0.5
                    * ((self.u[Self::idx(x + 1, y)] - self.u[Self::idx(x - 1, y)])
                        + (self.v[Self::idx(x, y + 1)] - self.v[Self::idx(x, y - 1)]));
            }
        }

        for _ in 0..ITERATIONS {
            for y in 1..GRID_H - 1 {
                for x in 1..GRID_W - 1 {
                    let i = Self::idx(x, y);
                    p[i] = (div[i]
                        + p[Self::idx(x - 1, y)]
                        + p[Self::idx(x + 1, y)]
                        + p[Self::idx(x, y - 1)]
                        + p[Self::idx(x, y + 1)])
                        / 4.0;
                }
            }
        }

        for y in 1..GRID_H - 1 {
            for x in 1..GRID_W - 1 {
                let i = Self::idx(x, y);
                self.u[i] -= 0.5 * (p[Self::idx(x + 1, y)] - p[Self::idx(x - 1, y)]);
                self.v[i] -= 0.5 * (p[Self::idx(x, y + 1)] - p[Self::idx(x, y - 1)]);
            }
        }
    }

    fn step(&mut self, dt: f32) {
        self.project();
        self.advect(dt);
    }
}

fn render_terminal(grid: &FluidGrid, opcode_info: &str) {
    let mut out = String::with_capacity(GRID_W * GRID_H * 20);
    out.push_str("\x1b[H"); // Cursor home

    // Double-height rendering using upper block character '▀'
    for y in (0..GRID_H).step_by(2) {
        for x in 0..GRID_W {
            let top_i = FluidGrid::idx(x, y);
            let bot_i = if y + 1 < GRID_H {
                FluidGrid::idx(x, y + 1)
            } else {
                top_i
            };

            let tr = (grid.r[top_i] * 255.0) as u8;
            let tg = (grid.g[top_i] * 255.0) as u8;
            let tb = (grid.b[top_i] * 255.0) as u8;

            let br = (grid.r[bot_i] * 255.0) as u8;
            let bg = (grid.g[bot_i] * 255.0) as u8;
            let bb = (grid.b[bot_i] * 255.0) as u8;

            out.push_str(&format!(
                "\x1b[38;2;{};{};{}m\x1b[48;2;{};{};{}m▀",
                tr, tg, tb, br, bg, bb
            ));
        }
        out.push_str("\x1b[0m\n");
    }

    out.push_str(&format!(
        "\x1b[36mMachine Code Stream:\x1b[0m {:<60}\n",
        opcode_info
    ));
    print!("{}", out);
    let _ = io::stdout().flush();
}

fn main() {
    // Obtain binary code: self-disassembly of executable or fallback stream
    let machine_code = std::env::current_exe()
        .and_then(|p| std::fs::read(p))
        .unwrap_or_else(|_| {
            (0..2048)
                .map(|i| ((i * 37 + 13) % 256) as u8)
                .collect()
        });

    let mut grid = FluidGrid::new();
    let mut pc = 0; // Program counter index

    // Hide cursor and clear terminal
    print!("\x1b[?25l\x1b[2J");

    loop {
        let chunk_size = 8;
        if pc + chunk_size >= machine_code.len() {
            pc = 0;
        }

        let slice = &machine_code[pc..pc + chunk_size];
        let mut info = String::new();

        for (offset, &byte) in slice.iter().enumerate() {
            let px = (pc * 7 + offset * 11) % (GRID_W - 10) + 5;
            let py = (pc * 3 + offset * 13) % (GRID_H - 10) + 5;

            // 1. Opcode Byte -> Directional force vector
            let angle = (byte as f32 / 255.0) * 2.0 * PI;
            let force_mag = 2.5;
            grid.add_force(px, py, angle.cos() * force_mag, angle.sin() * force_mag);

            // Heuristics for machine code instructions
            let is_mem_read = matches!(byte, 0x8B | 0x8A | 0xA0..=0xA3 | 0x48 | 0x8E);
            let is_cond_branch = matches!(byte, 0x70..=0x7F | 0x0F | 0xEB | 0xE9);

            if is_mem_read {
                // 2. Memory Read -> Inject vibrant dye (Cyan / Magenta / Gold based on byte)
                let cr = ((byte as u32 * 3) % 255) as f32 / 255.0;
                let cg = ((byte as u32 * 7) % 255) as f32 / 255.0;
                let cb = 1.0;
                grid.add_dye(px, py, cr, cg, cb);
                info.push_str(&format!("[READ 0x{:02X}] ", byte));
            } else if is_cond_branch {
                // 3. Conditional Branch -> Create turbulent vortex
                let direction = if byte % 2 == 0 { 1.5 } else { -1.5 };
                grid.add_vortex(px, py, 6, direction);
                grid.add_dye(px, py, 1.0, 0.2, 0.1); // Crimson vortex core
                info.push_str(&format!("[BRANCH 0x{:02X}] ", byte));
            } else {
                // Generic opcode force
                grid.add_dye(px, py, 0.1, (byte as f32 / 255.0) * 0.5, 0.3);
                info.push_str(&format!("0x{:02X} ", byte));
            }
        }

        // Step fluid dynamics simulation
        grid.step(0.4);
        render_terminal(&grid, &info);

        pc += chunk_size;
        sleep(Duration::from_millis(33)); // ~30 FPS
    }
}