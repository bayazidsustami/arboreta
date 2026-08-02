// Esoteric Image Encoder in Rust
// Converts photographs/PPM images into self-executing Python scripts.
// The generated Python script renders an ASCII-art representation of the image
// while synthesizing and playing its RGB color histogram as raw audio via system bells (\a).

use std::env;
use std::fs;

struct Rgb {
    r: u8,
    g: u8,
    b: u8,
}

struct Image {
    width: usize,
    height: usize,
    pixels: Vec<Rgb>,
}

impl Image {
    // Generates a procedural test image if no external PPM file is provided
    fn synthetic(width: usize, height: usize) -> Self {
        let mut pixels = Vec::with_capacity(width * height);
        for y in 0..height {
            for x in 0..width {
                let r = ((x * 255) / width) as u8;
                let g = ((y * 255) / height) as u8;
                let b = (((x + y) * 127) / (width + height)) as u8;
                pixels.push(Rgb { r, g, b });
            }
        }
        Image { width, height, pixels }
    }

    // Parses a binary PPM (P6) image file
    fn load_ppm(path: &str) -> Result<Self, String> {
        let bytes = fs::read(path).map_err(|e| e.to_string())?;
        if bytes.len() < 3 || &bytes[0..2] != b"P6" {
            return Err("Only binary PPM (P6) format is supported".into());
        }

        let mut pos = 2;
        let mut tokens = Vec::new();

        while pos < bytes.len() && tokens.len() < 3 {
            while pos < bytes.len() && (bytes[pos] == b' ' || bytes[pos] == b'\n' || bytes[pos] == b'\r' || bytes[pos] == b'\t') {
                pos += 1;
            }
            if pos < bytes.len() && bytes[pos] == b'#' {
                while pos < bytes.len() && bytes[pos] != b'\n' {
                    pos += 1;
                }
                continue;
            }
            let start = pos;
            while pos < bytes.len() && !bytes[pos].is_ascii_whitespace() {
                pos += 1;
            }
            if start < pos {
                let token_str = std::str::from_utf8(&bytes[start..pos]).map_err(|e| e.to_string())?;
                tokens.push(token_str.parse::<usize>().map_err(|e| e.to_string())?);
            }
        }

        if tokens.len() < 3 {
            return Err("Invalid PPM header".into());
        }

        let width = tokens[0];
        let height = tokens[1];
        pos += 1; // Skip single whitespace delimiter after maxval

        let pixel_bytes = &bytes[pos..];
        if pixel_bytes.len() < width * height * 3 {
            return Err("Truncated PPM pixel data".into());
        }

        let mut pixels = Vec::with_capacity(width * height);
        for chunk in pixel_bytes[..width * height * 3].chunks_exact(3) {
            pixels.push(Rgb {
                r: chunk[0],
                g: chunk[1],
                b: chunk[2],
            });
        }

        Ok(Image { width, height, pixels })
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    
    // Load provided PPM image or fall back to synthetic pattern
    let img = if args.len() > 1 {
        Image::load_ppm(&args[1]).unwrap_or_else(|err| {
            eprintln!("Warning: Failed to load PPM ({}), using fallback test pattern.", err);
            Image::synthetic(64, 32)
        })
    } else {
        Image::synthetic(64, 32)
    };

    // Calculate RGB Color Histogram across 16 intensity bins
    let mut hist_r = [0u32; 16];
    let mut hist_g = [0u32; 16];
    let mut hist_b = [0u32; 16];

    for p in &img.pixels {
        hist_r[(p.r / 16) as usize] += 1;
        hist_g[(p.g / 16) as usize] += 1;
        hist_b[(p.b / 16) as usize] += 1;
    }

    // Convert pixel luminance to ASCII characters
    let ascii_palette = [" ", ".", ":", "-", "=", "+", "*", "#", "%", "@"];
    let mut ascii_art = String::new();

    for y in 0..img.height {
        for x in 0..img.width {
            let p = &img.pixels[y * img.width + x];
            let luminance = (0.299 * p.r as f64 + 0.587 * p.g as f64 + 0.114 * p.b as f64) / 255.0;
            let idx = ((luminance * (ascii_palette.len() - 1) as f64).round() as usize).min(ascii_palette.len() - 1);
            ascii_art.push_str(ascii_palette[idx]);
        }
        ascii_art.push('\n');
    }

    // Embed ASCII matrix and RGB histogram data into a self-executing Python script payload
    let python_payload = format!(
r#"# Self-Executing Esoteric Image Script
import sys, time

ASCII_ART = """{}"""
HIST_R = {:?}
HIST_G = {:?}
HIST_B = {:?}

def play_histogram_audio():
    print("\n--- PLAYING RGB HISTOGRAM AUDIO STREAM (SYSTEM BELL) ---")
    channels = [("RED", HIST_R), ("GREEN", HIST_G), ("BLUE", HIST_B)]
    for name, hist in channels:
        print(f"\nSynthesizing {{name}} Channel Histogram Audio...")
        max_val = max(hist) or 1
        for i, val in enumerate(hist):
            pulses = int((val / max_val) * 8) + 1
            sys.stdout.write(f"\rBin {{i*16:03d}}-{{(i+1)*16-1:03d}} [{{'#'*pulses}}{{' '*(8-pulses)}}]")
            sys.stdout.flush()
            for _ in range(pulses):
                sys.stdout.write("\a")
                sys.stdout.flush()
                time.sleep(0.03)
            time.sleep(0.08)
    print("\n\nAudio stream output complete.")

def main():
    print("\x1b[2J\x1b[H", end="") # Clear terminal
    print("--- ASCII IMAGE RENDER ---")
    print(ASCII_ART)
    play_histogram_audio()

if __name__ == "__main__":
    main()
"#,
        ascii_art.trim_end(),
        hist_r.to_vec(),
        hist_g.to_vec(),
        hist_b.to_vec()
    );

    // Output payload to stdout or specified file path
    if args.len() > 2 {
        fs::write(&args[2], python_payload).expect("Failed to write output Python script");
        println!("Successfully generated esoteric Python script at '{}'", args[2]);
    } else {
        print!("{}", python_payload);
    }
}