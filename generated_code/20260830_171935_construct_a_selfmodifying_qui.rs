use std::{thread, time::Duration};

fn main() {
    // 1. The esoteric array-language program (our initial quine source).
    // Operations: R=reshape, !=rev, '=rot90, +=add, *=mul, |=join, $=eval
    let esolang_src = "A←{R[30 80](!'A+|A)}";

    // 2. Lorenz Attractor parameters (dx/dt = σ(y-x), dy/dt = x(ρ-z)-y, dz/dt = xy-βz)
    let (sigma, rho, beta) = (10.0, 28.0, 8.3333333333);
    let (mut x, mut y, mut z) = (0.1, 0.0, 0.0);
    let dt = 0.01;

    let (width, height) = (80, 30);
    let mut step = 0;

    print!("\x1b[2J\x1b[?25l"); // Clear screen and hide cursor

    loop {
        // Step 1: Self-Modify the Esolang Array Source (Mutate seed value over time)
        step += 1;
        let mutated_val = (step % 99) as u8;
        let current_quine_src = format!("A←{{R[30 80](!'A+|A)}} # state:0x{:02x}", mutated_val);
        let src_chars: Vec<char> = current_quine_src.chars().collect();

        // Step 2: Integrate Lorenz System (Runge-Kutta / Euler method)
        for _ in 0..10 {
            let dx = sigma * (y - x);
            let dy = x * (rho - z) - y;
            let dz = x * y - beta * z;
            x += dx * dt;
            y += dy * dt;
            z += dz * dt;
        }

        // Step 3: Compute morphing 3D rotation angles
        let angle_y = (step as f64) * 0.03;
        let angle_x = (step as f64) * 0.015;
        let (cos_y, sin_y) = (angle_y.cos(), angle_y.sin());
        let (cos_x, sin_x) = (angle_x.cos(), angle_x.sin());

        // Transform Lorenz point to 3D space and project to 2D screen
        let rx = x * cos_y + z * sin_y;
        let ry = y * cos_x - (z * cos_y - x * sin_y) * sin_x;
        let rz = y * sin_x + (z * cos_y - x * sin_y) * cos_x;

        let scale = 1.2;
        let cx = (width as f64 / 2.0) + rx * scale;
        let cy = (height as f64 / 2.0) + ry * scale * 0.5;

        // Step 4: Render Quine Source Code onto the 3D Lorenz Projection Frame
        let mut frame = vec![' '; width * height];

        for i in 0..src_chars.len() {
            let offset = (i as f64) * 0.15;
            let px = (cx + offset.cos() * (rz * 0.1)) as i32;
            let py = (cy + offset.sin() * (rz * 0.1)) as i32;

            if px >= 0 && px < width as i32 && py >= 0 && py < height as i32 {
                let idx = (py as usize) * width + (px as usize);
                frame[idx] = src_chars[i % src_chars.len()];
            }
        }

        // Step 5: Output Frame to Terminal (ANSI Buffer Flush)
        let mut buffer = String::with_capacity((width + 1) * height + 10);
        buffer.push_str("\x1b[H"); // Reset cursor position
        for r in 0..height {
            let start = r * width;
            let line: String = frame[start..start + width].iter().collect();
            buffer.push_str(&line);
            buffer.push('\n');
        }

        print!("{}", buffer);
        thread::sleep(Duration::from_millis(33)); // ~30 FPS
    }
}