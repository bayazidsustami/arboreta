use opencv::{
    core::{self, Mat, Scalar, Vector},
    imgproc,
    prelude::*,
    videoio,
    Result,
};
use std::{fs, io::Write, path::Path, process::Command, thread, time::Duration};

/// Simple mapping from hue (0..360) to a frequency in a microtonal scale.
/// Here we just linearly map hue to a frequency between 220Hz and 880Hz.
fn hue_to_freq(hue: f32) -> f32 {
    220.0 + (hue / 360.0) * (880.0 - 220.0)
}

/// Generate Rust source code that visualizes the given frequencies as a fractal.
/// The geometry is derived from the intervals between successive frequencies.
fn generate_source(freqs: &[f32]) -> String {
    // Compute intervals (ratio) between consecutive frequencies.
    let mut intervals = Vec::new();
    for w in freqs.windows(2) {
        intervals.push(w[1] / w[0]);
    }

    // Build a simple fractal drawing using the macroquad crate.
    // The intervals control the rotation angle and scaling factor.
    let mut src = String::new();
    src.push_str(r#"
use macroquad::prelude::*;

#[macroquad::main("Self‑Modifying Fractal")]
async fn main() {
    let mut angle = 0.0;
    loop {
        clear_background(BLACK);
        draw_fractal(vec2(screen_width() / 2.0, screen_height() / 2.0), 200.0, 0.0, 5);
        next_frame().await;
    }

    fn draw_fractal(pos: Vec2, size: f32, rot: f32, depth: i32) {
        if depth == 0 { return; }
        let col = Color::new(0.2 + depth as f32 * 0.15, 0.4, 0.6, 1.0);
        draw_circle(pos.x, pos.y, size, col);
        // Intervals from the generated code (filled below)
        let intervals: [f32; INTERVAL_COUNT] = [INTERVALS];
        let scale = intervals.get(depth as usize % intervals.len()).cloned().unwrap_or(1.0);
        let new_size = size * 0.5 * scale;
        let new_rot = rot + 0.3 * scale;
        let offset = vec2(new_size * new_rot.cos(), new_size * new_rot.sin());
        draw_fractal(pos + offset, new_size, new_rot, depth - 1);
        draw_fractal(pos - offset, new_size, -new_rot, depth - 1);
    }
}
"#);

    // Insert the intervals constants.
    let intervals_str = intervals
        .iter()
        .map(|v| format!("{:.5}", v))
        .collect::<Vec<_>>()
        .join(", ");
    src = src.replace("INTERVAL_COUNT", &intervals.len().to_string());
    src = src.replace("INTERVALS", &intervals_str);
    src
}

/// Overwrite the current source file with new code.
fn self_modify(new_source: &str) -> std::io::Result<()> {
    let path = std::env::current_exe()?;
    let src_path = path
        .parent()
        .unwrap()
        .join(Path::new("self_mod.rs"));
    let mut file = fs::File::create(&src_path)?;
    file.write_all(new_source.as_bytes())?;
    // Optionally recompile the new version (requires `cargo` and a Cargo.toml).
    // Here we just print a hint.
    println!("Wrote new source to {}", src_path.display());
    Ok(())
}

fn main() -> Result<()> {
    // Open default webcam.
    let mut cam = videoio::VideoCapture::new(0, videoio::CAP_ANY)?; // 0 = default camera
    if !videoio::VideoCapture::is_opened(&cam)? {
        panic!("Unable to open default camera!");
    }

    loop {
        let mut frame = Mat::default();
        cam.read(&mut frame)?;
        if frame.empty()? {
            continue;
        }

        // Convert to HSV and compute average hue.
        let mut hsv = Mat::default();
        imgproc::cvt_color(&frame, &mut hsv, imgproc::COLOR_BGR2HSV, 0)?;
        let mut hue_channel = Mat::default();
        core::extract_channel(&hsv, &mut hue_channel, 0)?;
        let mean = core::mean(&hue_channel, &core::no_array()?)?.0[0] as f32; // average hue

        // Map hue to frequency.
        let freq = hue_to_freq(mean);
        println!("Average hue: {:.2}, frequency: {:.2} Hz", mean, freq);

        // Accumulate a short history of frequencies.
        static mut HISTORY: Vec<f32> = Vec::new();
        unsafe {
            HISTORY.push(freq);
            if HISTORY.len() > 8 {
                HISTORY.remove(0);
            }
            // When we have enough data, generate new source and self‑modify.
            if HISTORY.len() == 8 {
                let src = generate_source(&HISTORY);
                // Write to a sibling file; the original source can be replaced manually.
                let _ = self_modify(&src);
                // Reset history to avoid spamming writes.
                HISTORY.clear();
            }
        }

        // Slow down a bit.
        thread::sleep(Duration::from_millis(200));
    }
}