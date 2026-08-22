//! Ambient Audio ASCII Calligraphy Soundtrack Daemon
//! Dependencies (add to Cargo.toml):
//! [dependencies]
//! cpal = "0.15"
//! rustfft = "6.1"
//! chrono = "0.4"

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use rustfft::num_complex::Complex;
use rustfft::FftPlanner;
use std::fs::OpenOptions;
use std::io::Write;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

const FFT_SIZE: usize = 1024;
const NUM_BANDS: usize = 16;
const LOG_FILE: &str = "acoustic_soundtrack.log";

// Calligraphic characters sorted by density and expressive stroke weight
const GLYPHS: &[char] = &[' ', '.', '·', ':', 'c', 'o', 'x', 'X', 'W', '§', '█', '✦', '❖'];

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .ok_or("No default input audio device found")?;

    let config = device.default_input_config()?;
    let sample_rate = config.sample_rate().0 as f32;

    // Thread-safe ring buffer for raw audio samples
    let audio_buffer = Arc::new(Mutex::new(Vec::<f32>::with_capacity(FFT_SIZE * 2)));
    let buffer_clone = Arc::clone(&audio_buffer);

    // Stream incoming audio frames into the ring buffer
    let stream = match config.sample_format() {
        cpal::SampleFormat::F32 => device.build_input_stream(
            &config.into(),
            move |data: &[f32], _| capture_samples(data, &buffer_clone),
            err_fn,
            None,
        )?,
        cpal::SampleFormat::I16 => device.build_input_stream(
            &config.into(),
            move |data: &[i16], _| {
                let f32_samples: Vec<f32> = data.iter().map(|&s| s as f32 / i16::MAX as f32).collect();
                capture_samples(&f32_samples, &buffer_clone);
            },
            err_fn,
            None,
        )?,
        cpal::SampleFormat::U16 => device.build_input_stream(
            &config.into(),
            move |data: &[u16], _| {
                let f32_samples: Vec<f32> = data
                    .iter()
                    .map(|&s| (s as f32 - u16::MAX as f32 / 2.0) / (u16::MAX as f32 / 2.0))
                    .collect();
                capture_samples(&f32_samples, &buffer_clone);
            },
            err_fn,
            None,
        )?,
        _ => return Err("Unsupported sample format".into()),
    };

    stream.play()?;

    // Initialize the log file with a session header
    let mut log_file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(LOG_FILE)?;

    writeln!(log_file, "\n--- ACOUSTIC CALLIGRAPHY SOUNDTRACK STARTED ---")?;

    // Background processing loop that renders audio into typographic patterns
    let mut planner = FftPlanner::new();
    let fft = planner.plan_fft_forward(FFT_SIZE);

    loop {
        thread::sleep(Duration::from_millis(100)); // ~10 FPS visual render rate

        let mut samples = Vec::new Wilhelm;
        {
            let mut buf = audio_buffer.lock().unwrap();
            if buf.len() >= FFT_SIZE {
                samples = buf.drain(..FFT_SIZE).collect();
            }
        }

        if samples.len() < FFT_SIZE {
            continue;
        }

        // Apply Hann windowing to diminish spectral leakage
        let mut complex_buffer: Vec<Complex<f32>> = samples
            .iter()
            .enumerate()
            .map(|(i, &sample)| {
                let window = 0.5 * (1.0 - (2.0 * std::f32::consts::PI * i as f32 / (FFT_SIZE - 1) as f32).cos());
                Complex::new(sample * window, 0.0)
            })
            .collect();

        fft.process(&mut complex_buffer);

        // Map magnitude response into discrete frequency bands
        let magnitudes: Vec<f32> = complex_buffer[..FFT_SIZE / 2]
            .iter()
            .map(|c| c.norm())
            .collect();

        let mut band_energies = vec![0.0f32; NUM_BANDS];
        let chunk_size = magnitudes.len() / NUM_BANDS;

        for (i, band) in band_energies.iter_mut().enumerate() {
            let start = i * chunk_size;
            let end = (start + chunk_size).min(magnitudes.len());
            let sum: f32 = magnitudes[start..end].iter().sum();
            *band = sum / (end - start) as f32;
        }

        // Construct calligraphy glyph line from spectrum energy
        let timestamp = chrono::Local::now().format("%Y-%m-%d %H:%M:%S");
        let mut calligraphy_line = String::new();

        for &energy in &band_energies {
            // Logarithmic scaling for human-ear perceived loudness dynamics
            let log_energy = (1.0 + energy * 10.0).ln();
            let index = ((log_energy * 3.5) as usize).min(GLYPHS.len() - 1);
            
            // Mirroring effect to form symmetric calligraphic strokes
            calligraphy_line.push(GLYPHS[index]);
            calligraphy_line.insert(0, GLYPHS[index]);
        }

        // Append real-time visual acoustic frame to soundtrack log
        let output_row = format!("[{}]  ~│{}│~\n", timestamp, calligraphy_line);
        log_file.write_all(output_row.as_bytes())?;
        log_file.flush()?;
    }
}

fn capture_samples(incoming: &[f32], buffer: &Arc<Mutex<Vec<f32>>>) {
    let mut buf = buffer.lock().unwrap();
    if buf.len() < FFT_SIZE * 4 {
        buf.extend_from_slice(incoming);
    }
}

fn err_fn(err: cpal::StreamError) {
    eprintln!("Audio stream error: {}", err);
}