use std::env;
use std::fs;
use std::io::{self, Write};

const MARKER_START: &str = "/*IMAGE_START*/";
const MARKER_END: &str = "/*IMAGE_END*/";
const WIDTH: usize = 8;
const HEIGHT: usize = 8;

// Decode a whitespace string (space = 0, tab = 1) into a vector of bytes.
// Every 8 bits form one pixel (0..255).
fn decode_whitespace(ws: &str) -> Vec<u8> {
    let bits: Vec<u8> = ws
        .chars()
        .filter(|c| *c == ' ' || *c == '\t')
        .map(|c| if c == '\t' { 1 } else { 0 })
        .collect();

    bits.chunks(8)
        .map(|chunk| {
            let mut val = 0u8;
            for &b in chunk {
                val = (val << 1) | b;
            }
            val
        })
        .collect()
}

// Encode a pixel buffer back into whitespace (space = 0, tab = 1).
fn encode_whitespace(pixels: &[u8]) -> String {
    let mut ws = String::new();
    for &pix in pixels {
        for i in (0..8).rev() {
            if (pix >> i) & 1 == 1 {
                ws.push('\t');
            } else {
                ws.push(' ');
            }
        }
    }
    ws
}

// Simple cellular automaton: each cell becomes the average of its 8 neighbours.
fn evolve(frame: &[u8]) -> Vec<u8> {
    let mut next = vec![0u8; WIDTH * HEIGHT];
    for y in 0..HEIGHT {
        for x in 0..WIDTH {
            let mut sum = 0u32;
            let mut count = 0u32;
            for dy in [-1i32, 0, 1].iter() {
                for dx in [-1i32, 0, 1].iter() {
                    if *dx == 0 && *dy == 0 {
                        continue;
                    }
                    let nx = x as i32 + dx;
                    let ny = y as i32 + dy;
                    if nx >= 0 && nx < WIDTH as i32 && ny >= 0 && ny < HEIGHT as i32 {
                        sum += frame[ny as usize * WIDTH + nx as usize] as u32;
                        count += 1;
                    }
                }
            }
            next[y * WIDTH + x] = (sum / count) as u8;
        }
    }
    next
}

// Swap the bodies of the two helper functions to "rearrange the syntax tree".
fn rearrange_source(src: &str) -> String {
    // Very crude: locate the two function signatures and swap the whole blocks.
    let func_a_start = src.find("fn helper_a").unwrap();
    let func_b_start = src.find("fn helper_b").unwrap();

    let a_end = src[func_a_start..].find('}').unwrap() + func_a_start + 1;
    let b_end = src[func_b_start..].find('}').unwrap() + func_b_start + 1;

    let (first, second) = if func_a_start < func_b_start {
        ( (func_a_start, a_end), (func_b_start, b_end) )
    } else {
        ( (func_b_start, b_end), (func_a_start, a_end) )
    };

    let mut result = String::new();
    result.push_str(&src[..first.0]);
    result.push_str(&src[second.0..second.1]);
    result.push_str(&src[first.1..second.0]);
    result.push_str(&src[first.0..first.1]);
    result.push_str(&src[second.1..]);
    result
}

// Helper functions kept simple; their order will be swapped by rearrange_source.
fn helper_a(val: u8) -> u8 {
    // invert grayscale
    255 - val
}
fn helper_b(val: u8) -> u8 {
    // threshold
    if val > 128 { 255 } else { 0 }
}

fn main() -> io::Result<()> {
    // Determine source file path (assumes the first argument is the .rs file).
    let src_path = env::args().nth(1).expect("pass source .rs file as first argument");
    let src = fs::read_to_string(&src_path)?;

    // Extract hidden whitespace between markers.
    let start = src.find(MARKER_START).expect("no start marker");
    let end = src.find(MARKER_END).expect("no end marker");
    let hidden_section = &src[start + MARKER_START.len()..end];
    let ws: String = hidden_section.lines().next().unwrap_or("").to_string();

    // Decode, evolve, and re‑encode.
    let mut frame = decode_whitespace(&ws);
    assert_eq!(frame.len(), WIDTH * HEIGHT, "image size mismatch");
    frame = evolve(&frame);
    let new_ws = encode_whitespace(&frame);

    // Build new source: replace the whitespace line.
    let mut new_src = src.clone();
    let replace_range_start = start + MARKER_START.len();
    let replace_range_end = end;
    new_src.replace_range(replace_range_start..replace_range_end, &format!("\n{}\n", new_ws));

    // Rearrange function order to reflect “syntax‑tree rearrangement”.
    new_src = rearrange_source(&new_src);

    // Overwrite the source file.
    let mut file = fs::File::create(&src_path)?;
    file.write_all(new_src.as_bytes())?;
    Ok(())
}