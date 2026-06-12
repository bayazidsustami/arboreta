use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use ansi_term::Colour;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use rustfft::{num_complex::Complex, FftPlanner};

fn main() {
    // Set up audio input device
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .expect("No input audio device available");
    let config = device.default_input_config().unwrap();

    // Shared buffer for audio samples
    let samples = Arc::new(Mutex::new(Vec::<f32>::new()));
    let samples_clone = Arc::clone(&samples);

    // Build input stream
    let stream = device
        .build_input_stream(
            &config.into(),
            move |data: &[f32], _: &cpal::InputCallbackInfo| {
                let mut buf = samples_clone.lock().unwrap();
                buf.extend_from_slice(data);
                // Keep only the latest 2048 samples
                if buf.len() > 2048 {
                    let excess = buf.len() - 2048;
                    buf.drain(0..excess);
                }
            },
            |err| eprintln!("Stream error: {}", err),
            None,
        )
        .unwrap();
    stream.play().unwrap();

    // Prepare FFT
    let mut planner = FftPlanner::new();
    let fft = planner.plan_fft_forward(1024);
    let mut temp_buf = vec![Complex::zero(); 1024];

    // Poem vocabulary
    let words = [
        "echo", "silence", "pulse", "whisper", "storm", "dream", "glint", "void", "flare", "hush",
    ];

    // Main rendering loop
    loop {
        // Grab a fresh copy of samples
        let mut input = {
            let mut guard = samples.lock().unwrap();
            if guard.len() < 1024 {
                // Not enough data yet
                drop(guard);
                thread::sleep(Duration::from_millis(20));
                continue;
            }
            // Use the newest 1024 samples
            let slice = &guard[guard.len() - 1024..];
            slice.to_vec()
        };

        // Apply a simple Hann window
        for (i, v) in input.iter_mut().enumerate() {
            let w = 0.5 * (1.0 - (2.0 * std::f32::consts::PI * i as f32 / 1023.0).cos());
            *v *= w;
        }

        // Prepare complex buffer for FFT
        for (i, sample) in input.iter().enumerate() {
            temp_buf[i] = Complex::new(*sample, 0.0);
        }

        // Perform FFT
        fft.process(&mut temp_buf);

        // Compute magnitude and phase for each frequency band
        let mut mags = Vec::new();
        let mut phases = Vec::new();
        for c in &temp_buf[0..temp_buf.len() / 2] {
            mags.push(c.norm());
            phases.push(c.arg());
        }

        // Normalize magnitudes
        let max_mag = mags.iter().cloned().fold(0.0_f32, f32::max).max(1e-6);
        for m in &mut mags {
            *m /= max_mag;
        }

        // Build a line of poetic output
        let mut line = String::new();
        for (i, (mag, phase)) in mags.iter().zip(phases.iter()).enumerate() {
            // Choose a word based on band index
            let word = words[i % words.len()];
            // Determine number of diacritics (0..3) from magnitude
            let diacritics = (mag * 3.0).round() as usize;
            let mut decorated = word.to_string();
            // Append combining diacritics (̃, ̅, ̩) to each character
            for _ in 0..diacritics {
                for ch in decorated.clone().chars() {
                    decorated.push_str(&format!("{}\u{0303}", ch)); // tilde combining
                }
            }
            // Choose a colour from phase
            let hue = ((phase / (2.0 * std::f32::consts::PI)) + 1.0) % 1.0;
            let colour = Colour::RGB(
                (hue * 255.0) as u8,
                ((1.0 - hue) * 255.0) as u8,
                128,
            );
            line.push_str(&colour.paint(decorated).to_string());
            line.push(' ');
        }

        // Clear line and print
        print!("\r\x1b[2K{}", line);
        std::io::Write::flush(&mut std::io::stdout()).unwrap();

        // Limit refresh rate
        thread::sleep(Duration::from_millis(30));
    }
}