use std::collections::HashMap;
use std::env;
use std::fs::File;
use std::io::{self, Read, Write};

use image::{DynamicImage, GenericImage, GenericImageView, Pixel, RgbaImage};
use palette::{FromColor, Hsv, Srgb};

/// Map hue intervals to Brainfuck commands.
fn hue_to_cmd(hue: f32) -> Option<char> {
    // 8 equal slices of the hue circle.
    let slice = (hue / 45.0).floor() as u8;
    match slice % 8 {
        0 => Some('>'),
        1 => Some('<'),
        2 => Some('+'),
        3 => Some('-'),
        4 => Some('.'),
        5 => Some(','),
        6 => Some('['),
        7 => Some(']'),
        _ => None,
    }
}

/// Extract commands from an image by reading hue of each pixel left‑to‑right, top‑to‑bottom.
fn image_to_program(img: &DynamicImage) -> Vec<char> {
    let (w, h) = img.dimensions();
    let mut prog = Vec::new();
    for y in 0..h {
        for x in 0..w {
            let rgba = img.get_pixel(x, y).to_rgba();
            // Convert RGBA to HSV.
            let srgb = Srgb::new(
                rgba[0] as f32 / 255.0,
                rgba[1] as f32 / 255.0,
                rgba[2] as f32 / 255.0,
            );
            let hsv: Hsv = Hsv::from_color(srgb);
            if let Some(cmd) = hue_to_cmd(hsv.hue.to_degrees()) {
                prog.push(cmd);
            }
        }
    }
    prog
}

/// Simple Brainfuck interpreter that also mutates the backing image to visualise execution.
fn run_program(program: &[char], img: &mut RgbaImage) {
    // Pre‑compute bracket map.
    let mut bracket_map = HashMap::new();
    let mut stack = Vec::new();
    for (i, &c) in program.iter().enumerate() {
        if c == '[' {
            stack.push(i);
        } else if c == ']' {
            if let Some(j) = stack.pop() {
                bracket_map.insert(j, i);
                bracket_map.insert(i, j);
            }
        }
    }

    let (img_w, img_h) = img.dimensions();
    let mut data = vec![0u8; 30000];
    let mut dp: usize = 0; // data pointer
    let mut ip: usize = 0; // instruction pointer
    let mut step: usize = 0;

    // Helper to overlay a gradient on the pixel corresponding to the data pointer.
    let mut paint_pointer = |dp: usize, step: usize| {
        let x = (dp as u32) % img_w;
        let y = (dp as u32) / img_w;
        if y >= img_h {
            return;
        }
        // Cycle hue based on step count.
        let hue = ((step * 7) % 360) as f32;
        let sat = 0.8;
        let val = 0.8;
        let hsv = Hsv::new(palette::rgb::RgbHue::from_degrees(hue), sat, val);
        let rgb: Srgb = Srgb::from_color(hsv);
        let pixel = image::Rgba([
            (rgb.red * 255.0) as u8,
            (rgb.green * 255.0) as u8,
            (rgb.blue * 255.0) as u8,
            255,
        ]);
        img.put_pixel(x, y, pixel);
    };

    while ip < program.len() && step < 10_000 {
        match program[ip] {
            '>' => {
                dp = (dp + 1) % data.len();
            }
            '<' => {
                dp = (dp + data.len() - 1) % data.len();
            }
            '+' => {
                data[dp] = data[dp].wrapping_add(1);
            }
            '-' => {
                data[dp] = data[dp].wrapping_sub(1);
            }
            '.' => {
                // Output as character – also colour the pixel brighter.
                print!("{}", data[dp] as char);
                io::stdout().flush().ok();
                let (x, y) = ((dp as u32) % img_w, (dp as u32) / img_w);
                if y < img_h {
                    let mut p = img.get_pixel(x, y);
                    p[0] = p[0].saturating_add(50);
                    p[1] = p[1].saturating_add(50);
                    p[2] = p[2].saturating_add(50);
                    img.put_pixel(x, y, p);
                }
            }
            ',' => {
                // Read a single byte from stdin.
                let mut buf = [0u8];
                if io::stdin().read_exact(&mut buf).is_ok() {
                    data[dp] = buf[0];
                } else {
                    data[dp] = 0;
                }
            }
            '[' => {
                if data[dp] == 0 {
                    ip = *bracket_map.get(&ip).unwrap();
                }
            }
            ']' => {
                if data[dp] != 0 {
                    ip = *bracket_map.get(&ip).unwrap();
                }
            }
            _ => {}
        }
        // Visual feedback for pointer & tape.
        paint_pointer(dp, step);
        // Save intermediate frame every 100 steps.
        if step % 100 == 0 {
            let fname = format!("frame_{:05}.png", step);
            img.save(&fname).ok();
        }
        ip += 1;
        step += 1;
    }
    // Final image.
    img.save("output.png").ok();
}

fn main() {
    // Expect a PNG file as first argument.
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: {} <image.png>", args[0]);
        return;
    }
    let path = &args[1];
    let dyn_img = image::open(path).expect("Failed to open image");
    let program = image_to_program(&dyn_img);
    let mut img = dyn_img.to_rgba8();
    run_program(&program, &mut img);
}