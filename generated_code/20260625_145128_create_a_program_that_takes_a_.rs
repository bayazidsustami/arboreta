use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use rand::Rng;

// --- Crate imports ---------------------------------------------------------
use opencv::{
    core::{Mat, Vector, Scalar},
    imgproc,
    prelude::*,
    videoio,
};
use rodio::{OutputStream, Sink, source::SineWave};
use palette::{FromColor, Hsv, Srgb};
use tiny_skia::{Pixmap, Transform, PathBuilder, Paint, Stroke};

// ---------------------------------------------------------------------------
// Helper: map a hue (0..360) to a MIDI note (0..127) on a custom chromatic circle
fn hue_to_midi(hue: f32) -> u8 {
    // 12‑tone equal temperament, C = 60 (middle C)
    // map 0‑360 to 12 semitones, then shift by 60
    let semitone = ((hue / 30.0).round() as i32) % 12;
    (60 + semitone) as u8
}

// Helper: extract the dominant hue of a frame via k‑means (very simplified)
fn dominant_hue(frame: &Mat) -> f32 {
    // Convert to HSV and flatten hue channel
    let mut hsv = Mat::default();
    imgproc::cvt_color(&frame, &mut hsv, imgproc::COLOR_BGR2HSV, 0).unwrap();
    let hue = hsv
        .reshape(1, hsv.total() as i32)
        .unwrap()
        .data_typed::<u8>()
        .unwrap()
        .iter()
        .map(|v| *v as f32 * 2.0) // OpenCV hue is 0‑180
        .collect::<Vec<_>>();
    // Simple histogram peak
    let mut bins = [0usize; 360];
    for h in hue {
        let idx = h as usize % 360;
        bins[idx] += 1;
    }
    let (max_idx, _) = bins
        .iter()
        .enumerate()
        .max_by_key(|(_, cnt)| *cnt)
        .unwrap();
    max_idx as f32
}

// L‑system state
#[derive(Clone)]
struct LSystem {
    axiom: String,
    rules: std::collections::HashMap<char, String>,
    angle: f32,
    step: f32,
}

impl LSystem {
    fn new() -> Self {
        let mut rules = std::collections::HashMap::new();
        rules.insert('F', "F[+F]F[-F]F".to_string());
        Self {
            axiom: "F".to_string(),
            rules,
            angle: 25.0_f32.to_radians(),
            step: 5.0,
        }
    }

    // Generate next string
    fn iterate(&self, input: &str) -> String {
        let mut out = String::new();
        for ch in input.chars() {
            if let Some(rep) = self.rules.get(&ch) {
                out.push_str(rep);
            } else {
                out.push(ch);
            }
        }
        out
    }

    // Render current string to a pixmap
    fn render(&self, commands: &str, width: u32, height: u32) -> Pixmap {
        let mut pix = Pixmap::new(width, height).unwrap();
        let mut x = width as f32 / 2.0;
        let mut y = height as f32 - 10.0;
        let mut angle = -std::f32::consts::FRAC_PI_2;
        let mut stack = Vec::new();

        for cmd in commands.chars() {
            match cmd {
                'F' => {
                    let nx = x + self.step * angle.cos();
                    let ny = y + self.step * angle.sin();

                    let mut pb = PathBuilder::new();
                    pb.move_to(x, y);
                    pb.line_to(nx, ny);
                    let path = pb.finish().unwrap();

                    let mut paint = Paint::default();
                    paint.set_color_rgba8(255, 255, 255, 255);
                    pix.stroke_path(&path, &paint, &Stroke::default(), Transform::identity(), None);
                    x = nx;
                    y = ny;
                }
                '+' => angle += self.angle,
                '-' => angle -= self.angle,
                '[' => stack.push((x, y, angle)),
                ']' => {
                    if let Some((sx, sy, sa)) = stack.pop() {
                        x = sx;
                        y = sy;
                        angle = sa;
                    }
                }
                _ => {}
            }
        }
        pix
    }
}

// ---------------------------------------------------------------------------
// Main: capture webcam, generate audio, evolve L‑system, and write HTML output
fn main() {
    // Spawn audio output thread
    let (audio_tx, audio_rx) = std::sync::mpsc::channel::<u8>();
    thread::spawn(move || {
        let (_stream, stream_handle) = OutputStream::try_default().unwrap();
        let sink = Sink::try_new(&stream_handle).unwrap();

        while let Ok(note) = audio_rx.recv() {
            let freq = 440.0 * 2f32.powf((note as f32 - 69.0) / 12.0);
            sink.append(SineWave::new(freq));
            sink.sleep_until_end();
        }
    });

    // Initialise webcam
    let mut cam = videoio::VideoCapture::new(0, videoio::CAP_ANY).unwrap();
    cam.set(videoio::CAP_PROP_FRAME_WIDTH, 320.0).unwrap();
    cam.set(videoio::CAP_PROP_FRAME_HEIGHT, 240.0).unwrap();

    // L‑system setup
    let mut lsys = LSystem::new();
    let mut current = lsys.axiom.clone();

    // Collect frames for HTML export
    let mut frames: Vec<Vec<u8>> = Vec::new();

    // Main loop (run for ~10 seconds)
    let start = Instant::now();
    while start.elapsed() < Duration::from_secs(10) {
        let mut frame = Mat::default();
        cam.read(&mut frame).unwrap();
        if frame.empty().unwrap() {
            continue;
        }

        // Dominant hue → MIDI note → play
        let hue = dominant_hue(&frame);
        let midi = hue_to_midi(hue);
        audio_tx.send(midi).unwrap();

        // Modify L‑system rule based on note frequency
        let freq = 440.0 * 2f32.powf((midi as f32 - 69.0) / 12.0);
        let factor = (freq / 440.0).round() as i32;
        let new_rule = format!("F[+{}F]F[-{}F]F", "F".repeat(factor as usize), "F".repeat(factor as usize));
        lsys.rules.insert('F', new_rule);

        // Iterate and render
        current = lsys.iterate(&current);
        let pix = lsys.render(&current, 256, 256);
        let png = pix.encode_png().unwrap();
        frames.push(png);

        thread::sleep(Duration::from_millis(100));
    }

    // Write HTML with embedded canvas animation and audio (simplified)
    let html = generate_html(&frames);
    std::fs::write("kaleidoscope.html", html).unwrap();
    println!("Saved kaleidoscope.html");
}

// ---------------------------------------------------------------------------
// Generate a minimal HTML page that cycles through PNG frames on a canvas
fn generate_html(frames: &[Vec<u8>]) -> String {
    let mut data_urls = String::new();
    for (i, img) in frames.iter().enumerate() {
        let b64 = base64::encode(img);
        data_urls.push_str(&format!("\"data:image/png;base64,{}\",", b64));
    }
    // Trim trailing comma
    if data_urls.ends_with(',') {
        data_urls.pop();
    }

    format!(r#"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Audio‑Reactive L‑System Kaleidoscope</title>
</head>
<body style="margin:0;background:#000;overflow:hidden;">
<canvas id="c" width="256" height="256"></canvas>
<script>
let frames=[{data_urls}];
let ctx=document.getElementById('c').getContext('2d');
let idx=0;
function draw(){{
    let img=new Image();
    img.onload=()=>{{ctx.clearRect(0,0,256,256);ctx.drawImage(img,0,0);}};
    img.src=frames[idx];
    idx=(idx+1)%frames.length;
}}
setInterval(draw,100);
</script>
</body>
</html>
"#)
}