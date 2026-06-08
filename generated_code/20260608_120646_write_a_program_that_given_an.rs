use std::fs::File;
use std::io::Read;
use std::path::Path;
use std::process::Command;

extern crate midi; // midi parsing crate (placeholder)
extern crate image; // for bitmap frames
extern crate printpdf; // PDF generation
extern crate rand; // randomness for fractal
extern crate rustfft; // rhythm analysis (placeholder)

use midi::SMF;
use image::{RgbImage, Rgb};
use rand::Rng;
use printpdf::*;

/// Simple representation of a note event.
#[derive(Clone, Copy, Debug)]
struct Note {
    pitch: u8,
    start_tick: u64,
    duration_ticks: u64,
}

/// Load a MIDI file and extract a vector of Note events.
fn read_midi<P: AsRef<Path>>(path: P) -> Vec<Note> {
    let mut f = File::open(path).expect("cannot open midi");
    let mut buf = Vec::new();
    f.read_to_end(&mut buf).unwrap();
    // Use a placeholder parser; replace with real crate calls.
    let smf = SMF::from_bytes(&buf).expect("invalid midi");
    let mut notes = Vec::new();
    for track in smf.tracks.iter() {
        let mut ongoing = std::collections::HashMap::new();
        let mut tick = 0u64;
        for ev in track.iter() {
            tick += ev.delta_time as u64;
            match ev.kind {
                midi::EventKind::NoteOn { channel: _, key, vel } if vel > 0 => {
                    ongoing.insert(key, tick);
                }
                midi::EventKind::NoteOff { channel: _, key, vel: _ }
                | midi::EventKind::NoteOn { channel: _, key, vel: 0 } => {
                    if let Some(start) = ongoing.remove(&key) {
                        notes.push(Note {
                            pitch: key,
                            start_tick: start,
                            duration_ticks: tick - start,
                        });
                    }
                }
                _ => {}
            }
        }
    }
    notes
}

/// Compute pitch intervals and map each to a hue (0..360).
fn pitch_to_hues(notes: &[Note]) -> Vec<(f32, f32)> {
    let mut hues = Vec::new();
    for w in notes.windows(2) {
        let interval = w[1].pitch as i16 - w[0].pitch as i16;
        // Map interval range [-12,12] to hue [0,360]
        let hue = ((interval + 12) as f32 / 24.0) * 360.0;
        // Use duration as weight for thickness later
        let weight = w[0].duration_ticks as f32;
        hues.push((hue, weight));
    }
    hues
}

/// Estimate rhythm density per time slice (ticks).
fn rhythm_density(notes: &[Note], slice_ticks: u64) -> Vec<f32> {
    let max_tick = notes.iter().map(|n| n.start_tick + n.duration_ticks).max().unwrap_or(0);
    let mut density = vec![0f32; (max_tick / slice_ticks + 1) as usize];
    for n in notes {
        let start = n.start_tick / slice_ticks;
        let end = (n.start_tick + n.duration_ticks) / slice_ticks;
        for i in start..=end {
            density[i as usize] += 1.0;
        }
    }
    // Normalize
    let max = density.iter().cloned().fold(0./0., f32::max);
    if max > 0.0 {
        for d in &mut density { *d /= max; }
    }
    density
}

/// Draw a single frame of the fractal tree.
fn draw_frame(
    img: &mut RgbImage,
    hue_weight: &[(f32, f32)],
    rhythm: f32,
    depth: u32,
    x: i32,
    y: i32,
    length: f32,
    angle: f32,
) {
    if depth == 0 { return; }
    let rad = angle.to_radians();
    let nx = x + (rad.cos() * length) as i32;
    let ny = y - (rad.sin() * length) as i32;

    // color based on first hue, thickness on rhythm
    let (hue, weight) = hue_weight.get(0).cloned().unwrap_or((0.0, 1.0));
    let sat = 0.7;
    let val = 0.9;
    let rgb = hsv_to_rgb(hue, sat, val);
    let thickness = ((rhythm * 5.0) + 1.0) as u32;

    draw_line(img, x, y, nx, ny, thickness, rgb);

    // Recurse with shifted hue list
    let next = if hue_weight.len() > 1 { &hue_weight[1..] } else { hue_weight };
    let new_len = length * 0.7;
    draw_frame(img, next, rhythm * 0.9, depth - 1, nx, ny, new_len, angle - 20.0);
    draw_frame(img, next, rhythm * 0.9, depth - 1, nx, ny, new_len, angle + 20.0);
}

/// Simple Bresenham line with thickness.
fn draw_line(img: &mut RgbImage, x0: i32, y0: i32, x1: i32, y1: i32, thickness: u32, color: Rgb<u8>) {
    let dx = (x1 - x0).abs();
    let dy = -(y1 - y0).abs();
    let sx = if x0 < x1 { 1 } else { -1 };
    let sy = if y0 < y1 { 1 } else { -1 };
    let mut err = dx + dy;
    let mut x = x0;
    let mut y = y0;

    loop {
        // draw a square around the pixel for thickness
        for tx in -((thickness/2) as i32)..=(thickness/2) as i32 {
            for ty in -((thickness/2) as i32)..=(thickness/2) as i32 {
                let ix = x + tx;
                let iy = y + ty;
                if ix >= 0 && iy >= 0 && (ix as u32) < img.width() && (iy as u32) < img.height() {
                    img.put_pixel(ix as u32, iy as u32, color);
                }
            }
        }
        if x == x1 && y == y1 { break; }
        let e2 = 2 * err;
        if e2 >= dy {
            err += dy;
            x += sx;
        }
        if e2 <= dx {
            err += dx;
            y += sy;
        }
    }
}

/// Convert HSV to RGB (0..255).
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> Rgb<u8> {
    let c = v * s;
    let x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
    let m = v - c;
    let (r1, g1, b1) = match h as i32 {
        0..=59 => (c, x, 0.0),
        60..=119 => (x, c, 0.0),
        120..=179 => (0.0, c, x),
        180..=239 => (0.0, x, c),
        240..=299 => (x, 0.0, c),
        _ => (c, 0.0, x),
    };
    Rgb([
        ((r1 + m) * 255.0) as u8,
        ((g1 + m) * 255.0) as u8,
        ((b1 + m) * 255.0) as u8,
    ])
}

/// Generate a sequence of PNG frames.
fn render_animation(notes: &[Note], out_dir: &str) {
    let hues = pitch_to_hues(notes);
    let density = rhythm_density(notes, 480);
    let frame_count = density.len();

    std::fs::create_dir_all(out_dir).unwrap();
    for i in 0..frame_count {
        let mut img = RgbImage::new(800, 600);
        let bg = Rgb([10, 10, 30]);
        for p in img.pixels_mut() { *p = bg; }

        let rhythm = density[i];
        draw_frame(
            &mut img,
            &hues,
            rhythm,
            8,
            400,
            580,
            120.0,
            -90.0,
        );
        let path = format!("{}/frame_{:04}.png", out_dir, i);
        img.save(&path).unwrap();
    }

    // Use ffmpeg (must be installed) to turn frames into a video with the original midi as audio.
    let _ = Command::new("ffmpeg")
        .args(&[
            "-y",
            "-framerate", "30",
            "-i", &format!("{}/frame_%04d.png", out_dir),
            "-i", "input.mid",
            "-c:v", "libx264",
            "-pix_fmt", "yuv420p",
            &format!("{}/animation.mp4", out_dir),
        ])
        .status();
}

/// Generate a printable PDF poster with tessellated glyphs.
fn render_poster(notes: &[Note], out_path: &str) {
    let (doc, page1, layer1) = PdfDocument::new("MIDI Poster", Mm(210.0), Mm(297.0), "Layer 1");
    let current_layer = doc.get_page(page1).get_layer(layer1);

    // Simple glyph: a rotated, colored rectangle per note.
    let mut x = Mm(20.0);
    let mut y = Mm(20.0);
    for n in notes.iter().take(200) {
        let hue = ((n.pitch as i16 - 60) as f32 + 12.0) / 24.0 * 360.0;
        let rgb = hsv_to_rgb(hue, 0.6, 0.8);
        let color = Color::Rgb(Rgb::new(
            rgb[0] as f64 / 255.0,
            rgb[1] as f64 / 255.0,
            rgb[2] as f64 / 255.0,
            None,
        ));

        let w = Mm(5.0 + (n.duration_ticks as f64 % 20.0));
        let h = Mm(10.0);
        let rotation = ((n.pitch as f64 - 60.0) * 3.0).to_radians();

        // Draw rectangle
        let points = vec![
            (Point::new(x, y), false),
            (Point::new(x + w, y), false),
            (Point::new(x + w, y + h), false),
            (Point::new(x, y + h), false),
        ];
        let path = Line {
            points,
            is_closed: true,
            has_fill: true,
            has_stroke: false,
            is_clipping_path: false,
        };
        current_layer.set_fill_color(color);
        current_layer.add_shape(path);

        // advance position
        x += w + Mm(2.0);
        if x.0 > 190.0 {
            x = Mm(20.0);
            y += h + Mm(2.0);
        }
    }

    doc.save(&mut File::create(out_path).unwrap()).unwrap();
}

fn main() {
    // Input MIDI file path (hard‑coded for brevity)
    let midi_path = "input.mid";

    // Parse notes
    let notes = read_midi(midi_path);

    // Create animation frames and assemble video
    render_animation(&notes, "frames");

    // Produce PDF poster
    render_poster(&notes, "poster.pdf");
}