use std::f32::consts::PI;
use std::io::{stdout, Write};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use opencv::core::{self, Mat, Vec3b};
use opencv::prelude::*;
use opencv::videoio::{VideoCapture, CAP_ANY};

use palette::{FromColor, Hsv, Srgb};

use rodio::{source::SineWave, OutputStream, Sink, Source};

use rustfft::{FftPlanner, num_complex::Complex};

use termion::{clear, cursor};

fn dominant_hue(frame: &Mat) -> f32 {
    // Resize for speed
    let mut small = Mat::default();
    let _ = opencv::imgproc::resize(
        frame,
        &mut small,
        core::Size { width: 40, height: 30 },
        0.0,
        0.0,
        opencv::imgproc::INTER_LINEAR,
    );
    // Compute average hue
    let mut sum_hue = 0.0f32;
    let mut count = 0usize;
    for y in 0..small.rows() {
        for x in 0..small.cols() {
            let pixel = small.at_2d::<Vec3b>(y, x).unwrap();
            let rgb = Srgb::new(
                pixel[2] as f32 / 255.0,
                pixel[1] as f32 / 255.0,
                pixel[0] as f32 / 255.0,
            );
            let hsv: Hsv = Hsv::from_color(rgb);
            sum_hue += hsv.hue.to_degrees();
            count += 1;
        }
    }
    if count == 0 {
        0.0
    } else {
        sum_hue / count as f32
    }
}

// Map hue (0..360) to a 12‑tone frequency (C4 = 261.63 Hz)
fn hue_to_freq(hue: f32) -> f32 {
    let note = ((hue / 30.0).round() as i32).rem_euclid(12);
    let c4 = 261.63;
    c4 * 2f32.powf(note as f32 / 12.0)
}

// Generate a short waveform for FFT analysis
fn synth_wave(freq: f32, sample_rate: u32, len: usize) -> Vec<f32> {
    (0..len)
        .map(|i| (2.0 * PI * freq * i as f32 / sample_rate as f32).sin())
        .collect()
}

// Render an ASCII mandala based on FFT magnitudes
fn render_mandala(mags: &[f32]) {
    let (w, h) = (80, 24);
    let radius = (h / 2 - 2) as f32;
    let mut buf = vec![b' '; w * h];
    for (i, &mag) in mags.iter().enumerate() {
        let angle = i as f32 / mags.len() as f32 * 2.0 * PI;
        let r = radius * (mag * 0.5).min(1.0);
        let cx = (w as f32 / 2.0 + r * angle.cos()) as i32;
        let cy = (h as f32 / 2.0 + r * angle.sin()) as i32;
        if cx >= 0 && cx < w as i32 && cy >= 0 && cy < h as i32 {
            let idx = (cy as usize) * w + (cx as usize);
            let glyph = if mag > 0.5 { b'*' } else { b'.' };
            buf[idx] = glyph;
        }
    }
    print!("{}{}", clear::All, cursor::Goto(1, 1));
    stdout().flush().unwrap();
    for y in 0..h {
        let start = y * w;
        let line = &buf[start..start + w];
        stdout().write_all(line).unwrap();
        stdout().write_all(b"\n").unwrap();
    }
    stdout().flush().unwrap();
}

fn main() -> opencv::Result<()> {
    // Open default webcam
    let mut cam = VideoCapture::new(0, CAP_ANY)?; // 0 = primary camera
    cam.set(opencv::videoio::CAP_PROP_FRAME_WIDTH, 320.0)?;
    cam.set(opencv::videoio::CAP_PROP_FRAME_HEIGHT, 240.0)?;

    // Audio output
    let (_stream, stream_handle) = OutputStream::try_default().unwrap();

    // Shared buffer for FFT (filled by audio thread)
    let fft_buf = Arc::new(Mutex::new(Vec::<f32>::new()));
    let fft_buf_clone = Arc::clone(&fft_buf);

    // Audio thread: continually plays the last generated tone
    thread::spawn(move || {
        let mut sink = Sink::try_new(&stream_handle).unwrap();
        loop {
            // Wait until a new tone is pushed
            thread::sleep(Duration::from_millis(30));
            let buf = {
                let guard = fft_buf_clone.lock().unwrap();
                guard.clone()
            };
            if !buf.is_empty() {
                sink.stop();
                sink = Sink::try_new(&stream_handle).unwrap();
                let source = rodio::buffer::SamplesBuffer::new(1, 44100, buf);
                sink.append(source);
                sink.play();
            }
        }
    });

    // FFT planner
    let mut planner = FftPlanner::<f32>::new();
    let fft = planner.plan_fft_forward(256);
    let mut input: Vec<Complex<f32>> = vec![Complex::zero(); 256];
    let mut output: Vec<Complex<f32>> = vec![Complex::zero(); 256];

    loop {
        let start = Instant::now();

        // Capture frame
        let mut frame = Mat::default();
        cam.read(&mut frame)?;
        if frame.empty()? {
            continue;
        }

        // Extract dominant hue and map to frequency
        let hue = dominant_hue(&frame);
        let freq = hue_to_freq(hue);
        let sample_rate = 44100;
        let wave = synth_wave(freq, sample_rate, 256);

        // Feed audio buffer to playback thread
        {
            let mut guard = fft_buf.lock().unwrap();
            *guard = wave.clone();
        }

        // FFT analysis for visualisation
        for (i, &s) in wave.iter().enumerate() {
            input[i] = Complex::new(s, 0.0);
        }
        fft.process(&mut input, &mut output);
        let mags: Vec<f32> = output.iter().map(|c| c.norm()).collect();

        // Render mandala
        render_mandala(&mags);

        // Keep ~30 fps
        let elapsed = start.elapsed();
        if elapsed < Duration::from_millis(33) {
            thread::sleep(Duration::from_millis(33) - elapsed);
        }
    }
}