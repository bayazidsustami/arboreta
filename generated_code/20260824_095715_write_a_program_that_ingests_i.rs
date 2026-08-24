use std::cell::RefCell;
use std::fs::File;
use std::io::{BufRead, BufReader, Write};
use std::rc::Rc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;
use fltk::{app, draw, frame::Frame, prelude::*, window::Window};

// Canvas dimensions and fractal generation parameters
const WIDTH: i32 = 800;
const HEIGHT: i32 = 600;
const MAX_ITER: usize = 64;

// Structure representing simulated "decaying digital flora" caused by memory leaks
#[derive(Clone, Copy)]
struct MemoryLeakFlora {
    x: f64,
    y: f64,
    life: f32, // Health/opacity of the flora (1.0 = full growth, 0.0 = decayed)
    size: f64,
}

// Global execution log writer path
const LOG_FILE: &str = "binary_exec.log";

// Log execution events (simulating spatial coordinate generation from binary activity)
fn log_execution_event(event_type: &str, x: f64, y: f64) {
    if let Ok(mut file) = std::fs::OpenOptions::new().create(true).append(true).open(LOG_FILE) {
        let _ = writeln!(file, "{}:{:.4}:{:.4}", event_type, x, y);
    }
}

// Intentionally allocate memory without freeing to simulate "memory leak" flora triggers
fn trigger_simulated_leak(flora_list: &mut Vec<MemoryLeakFlora>, x: f64, y: f64) {
    let leaked_box = Box::new(vec![0u8; 1024 * 128]); // 128KB uncollected allocation
    Box::leak(leaked_box); // Deliberately leak memory
    
    flora_list.push(MemoryLeakFlora {
        x,
        y,
        life: 1.0,
        size: 15.0,
    });
    
    log_execution_event("LEAK", x, y);
}

fn main() {
    // Clear previous execution log
    let _ = File::create(LOG_FILE);

    // Track state: view coordinates driven by ingested binary log streams
    let center_x = Rc::new(RefCell::new(-0.75f64));
    let center_y = Rc::new(RefCell::new(0.1f64));
    let zoom = Rc::new(RefCell::new(1.0f64));
    let flora = Rc::new(RefCell::new(Vec::<MemoryLeakFlora>::new()));

    // Background thread simulating continuous execution logging & memory leaks
    let running = Arc::new(AtomicBool::new(true));
    let r_clone = running.clone();
    thread::spawn(move || {
        let mut step = 0;
        while r_clone.load(Ordering::Relaxed) {
            let angle = step as f64 * 0.1;
            let rx = angle.cos() * 0.5;
            let ry = angle.sin() * 0.5;
            
            log_execution_event("EXEC_STEP", rx, ry);

            // Periodically trigger a memory leak event
            if step % 25 == 0 {
                // Shared spatial point calculation
                let leak_x = (rx + 1.0) * (WIDTH as f64) / 2.0;
                let leak_y = (ry + 1.0) * (HEIGHT as f64) / 2.0;
                log_execution_event("LEAK_GEN", leak_x, leak_y);
            }

            step += 1;
            thread::sleep(Duration::from_millis(100));
        }
    });

    // Initialize UI Window & Canvas
    let app = app::App::default();
    let mut window = Window::default().with_size(WIDTH, HEIGHT).with_label("Fractal Landscape - Binary Log & Memory Flora");
    let mut frame = Frame::default().with_size(WIDTH, HEIGHT);

    let cx_draw = center_x.clone();
    let cy_draw = center_y.clone();
    let zoom_draw = zoom.clone();
    let flora_draw = flora.clone();

    // Redraw loop rendering the Julia/Mandelbrot hybrid fractal based on log coordinates
    frame.draw(move |_| {
        let cx = *cx_draw.borrow();
        let cy = *cy_draw.borrow();
        let z = *zoom_draw.borrow();

        // 1. Render fractal landscape base
        for py in 0..HEIGHT {
            for px in 0..WIDTH {
                let mut x0 = (px as f64 - WIDTH as f64 / 2.0) / (0.5 * z * WIDTH as f64) + cx;
                let mut y0 = (py as f64 - HEIGHT as f64 / 2.0) / (0.5 * z * HEIGHT as f64) + cy;
                
                let mut iter = 0;
                while x0 * x0 + y0 * y0 <= 4.0 && iter < MAX_ITER {
                    let xtemp = x0 * x0 - y0 * y0 - 0.7; // Hybrid fractal constant
                    y0 = 2.0 * x0 * y0 + 0.27015;
                    x0 = xtemp;
                    iter += 1;
                }

                if iter < MAX_ITER {
                    let r = (iter * 4 % 255) as u8;
                    let g = (iter * 8 % 255) as u8;
                    let b = (iter * 12 % 255) as u8;
                    draw::set_draw_color(fltk::enums::Color::from_rgb(r, g, b));
                } else {
                    draw::set_draw_color(fltk::enums::Color::from_rgb(10, 5, 20));
                }
                draw::draw_point(px, py);
            }
        }

        // 2. Render decaying digital flora (memory leaks)
        let mut flora_list = flora_draw.borrow_mut();
        for f in flora_list.iter_mut() {
            if f.life > 0.0 {
                // Color degrades from bright neon green to withered dark red/gray
                let green = (255.0 * f.life) as u8;
                let red = (200.0 * (1.0 - f.life)) as u8;
                let blue = (50.0 * f.life) as u8;

                draw::set_draw_color(fltk::enums::Color::from_rgb(red, green, blue));
                let radius = (f.size * f.life as f64) as i32;
                
                // Draw digital branch/flora motif
                draw::draw_rect(f.x as i32 - radius / 2, f.y as i32 - radius / 2, radius, radius);
                draw::draw_line(f.x as i32, f.y as i32, f.x as i32 + radius, f.y as i32 - radius);
                draw::draw_line(f.x as i32, f.y as i32, f.x as i32 - radius, f.y as i32 - radius);

                // Decay flora gradually over time
                f.life -= 0.015;
            }
        }
        // Filter out fully decayed flora
        flora_list.retain(|f| f.life > 0.0);
    });

    window.end();
    window.show();

    // Log Reader & Ingestion loop to modify scene dynamically
    let cx_main = center_x.clone();
    let cy_main = center_y.clone();
    let zoom_main = zoom.clone();
    let flora_main = flora.clone();

    app::add_idle(move || {
        if let Ok(file) = File::open(LOG_FILE) {
            let reader = BufReader::new(file);
            for line in reader.lines().flatten() {
                let parts: Vec<&str> = line.split(':').collect();
                if parts.len() == 3 {
                    let event = parts[0];
                    if let (Ok(x), Ok(y)) = (parts[1].parse::<f64>(), parts[2].parse::<f64>()) {
                        match event {
                            "EXEC_STEP" => {
                                // Pan camera based on binary execution stream coordinates
                                *cx_main.borrow_mut() += x * 0.001;
                                *cy_main.borrow_mut() += y * 0.001;
                                *zoom_main.borrow_mut() *= 1.0005;
                            }
                            "LEAK_GEN" => {
                                // Spawn decaying flora when a memory leak is ingested from binary logs
                                trigger_simulated_leak(&mut flora_main.borrow_mut(), x, y);
                            }
                            _ => {}
                        }
                    }
                }
            }
        }
        
        // Truncate ingested log to simulate streaming stream consumption
        let _ = File::create(LOG_FILE);

        app::sleep(0.03);
        app::redraw();
    });

    app.run().unwrap();
    running.store(false, Ordering::Relaxed);
}