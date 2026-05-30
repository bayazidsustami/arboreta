// cargo-deps: cpal="0.15", rustfft="6", lyon="0.17", anyhow="1", itertools="0.12"
// A minimal live‑audio → SVG visualizer.
// Captures the default input device, computes a short‑time FFT,
// maps frequency bins to brush strokes and accumulates them in an SVG
// document that is written out every second.

use anyhow::Result;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use rustfft::{FftPlanner, num_complex::Complex};
use std::sync::{Arc, Mutex};
use std::f32::consts::PI;
use std::time::{Instant, Duration};
use lyon::path::builder::*;
use lyon::tessellation::*;
use lyon::geom::euclid::default::Point2D;
use itertools::Itertools;

type Stroke = (String, f32, f32, f32); // (path data, opacity, stroke-width, hue)

fn main() -> Result<()> {
    // Shared state for the SVG strokes.
    let strokes: Arc<Mutex<Vec<Stroke>>> = Arc::new(Mutex::new(Vec::new()));
    // Audio configuration.
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .expect("No input device available");
    let config = device.default_input_config()?;
    let sample_rate = config.sample_rate().0 as f32;
    let channels = config.channels() as usize;

    // FFT preparation.
    let fft_size = 1024usize;
    let mut planner = FftPlanner::<f32>::new();
    let fft = planner.plan_fft_forward(fft_size);
    let mut input_buf = vec![Complex::zero(); fft_size];
    let mut out_buf = vec![Complex::zero(); fft_size];
    let mut ring = vec![0f32; fft_size];
    let mut ring_pos = 0usize;

    // Clone for audio callback.
    let strokes_clone = Arc::clone(&strokes);
    let err_fn = |err| eprintln!("Stream error: {}", err);
    let stream = match config.sample_format() {
        cpal::SampleFormat::F32 => device.build_input_stream(
            &config.into(),
            move |data: &[f32], _: &_| process_input(data, channels, &mut ring, &mut ring_pos, &mut input_buf, &fft, &strokes_clone, sample_rate),
            err_fn,
        )?,
        cpal::SampleFormat::I16 => device.build_input_stream(
            &config.into(),
            move |data: &[i16], _: &_| {
                let fdata: Vec<f32> = data.iter().map(|s| *s as f32 / i16::MAX as f32).collect();
                process_input(&fdata, channels, &mut ring, &mut ring_pos, &mut input_buf, &fft, &strokes_clone, sample_rate)
            },
            err_fn,
        )?,
        cpal::SampleFormat::U16 => device.build_input_stream(
            &config.into(),
            move |data: &[u16], _: &_| {
                let fdata: Vec<f32> = data.iter().map(|s| *s as f32 / u16::MAX as f32 - 0.5).collect();
                process_input(&fdata, channels, &mut ring, &mut ring_pos, &mut input_buf, &fft, &strokes_clone, sample_rate)
            },
            err_fn,
        )?,
    };
    stream.play()?;

    // Main loop: every second we dump the accumulated strokes to an SVG file.
    let start = Instant::now();
    let mut frame = 0usize;
    loop {
        std::thread::sleep(Duration::from_secs(1));
        let elapsed = start.elapsed().as_secs_f32();
        let mut guard = strokes.lock().unwrap();
        if guard.is_empty() { continue; }
        let svg = generate_svg(&guard, elapsed);
        std::fs::write(format!("frame_{:03}.svg", frame), svg)?;
        guard.clear();
        frame += 1;
    }
}

// Process a chunk of interleaved audio samples.
fn process_input(
    data: &[f32],
    channels: usize,
    ring: &mut [f32],
    ring_pos: &mut usize,
    fft_in: &mut [Complex<f32>],
    fft: &rustfft::Fft<f32>,
    strokes: &Arc<Mutex<Vec<Stroke>>>,
    sample_rate: f32,
) {
    // Mix down to mono and fill ring buffer.
    for chunk in data.chunks(channels) {
        let mono = chunk.iter().copied().sum::<f32>() / channels as f32;
        ring[*ring_pos] = mono;
        *ring_pos = (*ring_pos + 1) % ring.len();
    }

    // When we have enough samples, perform an FFT.
    if ring.iter().all(|&v| v != 0.0) {
        // copy ring into fft input (time reversed for better windowing)
        for i in 0..ring.len() {
            let idx = (*ring_pos + i) % ring.len();
            // Hann window
            let w = 0.5 * (1.0 - (2.0 * PI * i as f32 / (ring.len() as f32 - 1.0)).cos());
            fft_in[i] = Complex::new(ring[idx] * w, 0.0);
        }
        fft.process(fft_in, fft_in);
        // magnitude spectrum
        let mags: Vec<f32> = fft_in.iter().map(|c| c.norm()).collect();

        // Map frequency bands to visual parameters.
        let num_bands = 8;
        let band_size = mags.len() / num_bands;
        for (i, band) in mags.chunks(band_size).enumerate() {
            let avg = band.iter().copied().sum::<f32>() / band.len() as f32;
            // Stroke attributes
            let hue = (i as f32 / num_bands as f32) * 360.0; // colour wheel
            let opacity = (avg * 10.0).clamp(0.1, 0.9);
            let width = (avg * 200.0).clamp(0.5, 5.0);
            // Geometry: a sinusoidal brushstroke whose frequency follows the band index.
            let path = generate_path(i, avg, sample_rate);
            let mut guard = strokes.lock().unwrap();
            guard.push((path, opacity, width, hue));
        }
    }
}

// Generate an SVG path string for a single stroke.
fn generate_path(band_idx: usize, amp: f32, sample_rate: f32) -> String {
    // Simple sinusoid across the canvas width (800) height varies with amplitude.
    let width = 800.0;
    let height = 600.0;
    let points: Vec<Point2D<f32>> = (0..100)
        .map(|i| {
            let x = i as f32 / 99.0 * width;
            let y = height / 2.0
                + (band_idx as f32 + 1.0) * 20.0
                * (2.0 * PI * (i as f32 / 99.0) * (band_idx as f32 + 1.0)).sin()
                * amp * 5.0;
            Point2D::new(x, y)
        })
        .collect();

    // Use lyon to build a smooth path.
    let mut builder = Path::builder();
    builder.begin(points[0]);
    for w in points.windows(3) {
        let p0 = w[0];
        let p1 = w[1];
        let p2 = w[2];
        // quadratic Bézier approximation
        let c = p1;
        let end = Point2D::new((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0);
        builder.quadratic_bezier_to(c, end);
    }
    builder.end(false);
    let path = builder.build();
    // Serialize to SVG path data.
    use lyon::svg::path_utils::build_path;
    build_path(&path)
}

// Assemble the full SVG document from accumulated strokes.
fn generate_svg(strokes: &[Stroke], time: f32) -> String {
    let mut svg = String::new();
    svg.push_str(r#"<?xml version="1.0" encoding="UTF-8"?>"#);
    svg.push_str(r#"<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600">"#);
    // Optional background gradient based on time.
    let bg_hue = (time * 30.0 % 360.0) as i32;
    svg.push_str(&format!(
        r#"<defs><linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:hsl({bg_hue},70%,20%);"/><stop offset="100%" style="stop-color:hsl({bg_hue},70%,40%);"/></linearGradient></defs>"#
    ));
    svg.push_str(r#"<rect width="100%" height="100%" fill="url(#bg)" />"#);
    for (d, opacity, width, hue) in strokes {
        svg.push_str(&format!(
            r#"<path d="{}" fill="none" stroke="hsl({:.0},80%,60%)" stroke-width="{:.2}" stroke-linecap="round" opacity="{:.2}" />"#,
            d, hue, width, opacity
        ));
    }
    svg.push_str("</svg>");
    svg
}