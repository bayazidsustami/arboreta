use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use rustfft::{FftPlanner, num_complex::Complex};
use rand::Rng;
use std::fs::File;
use std::io::Write;

// Simple L‑system definition
#[derive(Clone)]
struct LSystem {
    axiom: String,
    rules: Vec<(char, String)>,
    angle: f64,
    step: f64,
}

// Generate next iteration of the L‑system string
fn lsystem_expand(ls: &LSystem, input: &str) -> String {
    let mut result = String::new();
    for ch in input.chars() {
        if let Some((_c, repl)) = ls.rules.iter().find(|(c, _)| *c == ch) {
            result.push_str(repl);
        } else {
            result.push(ch);
        }
    }
    result
}

// Render the L‑system string to SVG path data
fn render_to_svg(ls: &LSystem, commands: &str, width: f64, height: f64) -> String {
    let mut x = width / 2.0;
    let mut y = height / 2.0;
    let mut angle = -90.0_f64.to_radians();
    let mut path = format!("M {} {}", x, y);
    let rad = ls.angle.to_radians();

    for cmd in commands.chars() {
        match cmd {
            'F' => {
                x += ls.step * angle.cos();
                y += ls.step * angle.sin();
                path.push_str(&format!(" L {} {}", x, y));
            }
            '+' => angle += rad,
            '-' => angle -= rad,
            '[' => {} // push state (omitted for brevity)
            ']' => {} // pop state
            _ => {}
        }
    }
    format!(
        r#"<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}">
<path d="{d}" stroke="lime" fill="none" stroke-width="0.5"/>
</svg>"#,
        w = width,
        h = height,
        d = path
    )
}

// Map frequency band to an L‑system rule mutation
fn mutate_lsystem(ls: &mut LSystem, band: usize, magnitude: f32) {
    let mut rng = rand::thread_rng();
    // Very simple mutation: change step size based on magnitude
    let factor = 1.0 + (magnitude as f64) * 0.5;
    ls.step *= factor;
    // Randomly add a rule for this band
    if rng.gen_bool(0.05) {
        let pred = (b'A' + (band % 26) as u8) as char;
        let repl_len = rng.gen_range(1..=3);
        let repl: String = (0..repl_len)
            .map(|_| if rng.gen_bool(0.5) { 'F' } else { '+' })
            .collect();
        ls.rules.push((pred, repl));
    }
}

fn main() {
    // Set up audio input
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .expect("No input device available");
    let config = device.default_input_config().unwrap();

    // Shared buffer for audio samples
    let samples: Arc<Mutex<Vec<f32>>> = Arc::new(Mutex::new(Vec::new()));
    let samples_clone = samples.clone();

    // Build audio stream
    let err_fn = |err| eprintln!("Stream error: {}", err);
    let stream = match config.sample_format() {
        cpal::SampleFormat::F32 => device.build_input_stream(
            &config.into(),
            move |data: &[f32], _: &_| {
                let mut buf = samples_clone.lock().unwrap();
                buf.extend_from_slice(data);
            },
            err_fn,
        ),
        cpal::SampleFormat::I16 => device.build_input_stream(
            &config.into(),
            move |data: &[i16], _: &_| {
                let mut buf = samples_clone.lock().unwrap();
                buf.extend(data.iter().map(|&s| s as f32 / i16::MAX as f32));
            },
            err_fn,
        ),
        cpal::SampleFormat::U16 => device.build_input_stream(
            &config.into(),
            move |data: &[u16], _: &_| {
                let mut buf = samples_clone.lock().unwrap();
                buf.extend(data.iter().map(|&s| s as f32 / u16::MAX as f32 - 1.0));
            },
            err_fn,
        ),
    }
    .expect("Failed to build stream");

    stream.play().expect("Failed to start stream");

    // Initialise L‑system
    let mut lsys = LSystem {
        axiom: "F".to_string(),
        rules: vec![('F', "F+F-F".to_string())],
        angle: 45.0,
        step: 5.0,
    };
    let mut current_string = lsys.axiom.clone();

    // FFT setup
    let mut planner = FftPlanner::<f32>::new();
    let fft = planner.plan_fft_forward(1024);
    let mut fft_input = vec![Complex::zero(); 1024];
    let mut fft_output = vec![Complex::zero(); 1024];

    // Main loop: process audio, mutate L‑system, render SVG
    let start = Instant::now();
    loop {
        // Grab a chunk of audio
        let mut buf = {
            let mut lock = samples.lock().unwrap();
            if lock.len() < 1024 {
                drop(lock);
                thread::sleep(Duration::from_millis(10));
                continue;
            }
            lock.drain(0..1024).collect::<Vec<f32>>()
        };

        // Apply window (simple Hann)
        for i in 0..1024 {
            let w = 0.5 * (1.0 - (2.0 * std::f32::consts::PI * i as f32 / 1024.0).cos());
            fft_input[i] = Complex::new(buf[i] * w, 0.0);
        }

        // Execute FFT
        fft.process(&mut fft_input, &mut fft_output);

        // Compute magnitudes per band (e.g., 8 bands)
        let bands = 8;
        let mut mags = vec![0f32; bands];
        for (i, c) in fft_output.iter().enumerate().take(512) {
            let band = i * bands / 512;
            mags[band] += c.norm();
        }

        // Mutate L‑system based on bands
        for (i, &mag) in mags.iter().enumerate() {
            mutate_lsystem(&mut lsys, i, mag);
        }

        // Expand L‑system a few steps depending on elapsed time
        let elapsed = start.elapsed().as_secs_f64();
        let steps = (elapsed * 0.5) as usize;
        current_string = lsys.axiom.clone();
        for _ in 0..steps.min(5) {
            current_string = lsystem_expand(&lsys, &current_string);
        }

        // Render to SVG
        let svg = render_to_svg(&lsys, &current_string, 800.0, 600.0);
        let mut file = File::create("garden.svg").expect("Unable to create file");
        file.write_all(svg.as_bytes()).expect("Write failed");

        // Simple frame rate control
        thread::sleep(Duration::from_millis(100));
    }
}