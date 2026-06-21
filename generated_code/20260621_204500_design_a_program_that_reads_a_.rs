// Cargo.toml dependencies (add these to your Cargo.toml):
// cpal = "0.15"
// rustfft = "6.0"
// minifb = "0.27"
// rand = "0.8"

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use rustfft::{FftPlanner, num_complex::Complex};
use minifb::{Key, Window, WindowOptions};
use rand::Rng;
use std::sync::{Arc, Mutex};
use std::f32::consts::PI;

// Dimensions of the cellular automata grid.
const WIDTH: usize = 256;
const HEIGHT: usize = 256;

// Number of frequency bands we will analyse (also number of rules).
const BANDS: usize = 8;

// Mapping of band index to a simple 2‑D cellular automaton rule.
// Each rule is a 9‑bit mask describing which neighbour counts cause a cell to be alive.
fn rule_mask(band: usize) -> u16 {
    // Generate a deterministic pseudo‑random mask from the band index.
    // Bits 0..8 correspond to neighbour count = 0..8.
    let mut rng = rand::rngs::StdRng::seed_from_u64(band as u64);
    rng.gen::<u16>() & 0x1FF
}

// Update the automata grid using the rule masks.
fn step(grid: &mut [u8], next: &mut [u8], masks: &[u16]) {
    for y in 0..HEIGHT {
        for x in 0..WIDTH {
            // Count alive neighbours (toroidal wrap).
            let mut count = 0u8;
            for dy in -1i32..=1 {
                for dx in -1i32..=1 {
                    if dx == 0 && dy == 0 { continue; }
                    let nx = ((x as i32 + dx + WIDTH as i32) % WIDTH as i32) as usize;
                    let ny = ((y as i32 + dy + HEIGHT as i32) % HEIGHT as i32) as usize;
                    count += grid[ny * WIDTH + nx];
                }
            }
            // Choose a rule according to the horizontal position (maps frequency band).
            let band = x * BANDS / WIDTH;
            let mask = masks[band];
            // Apply rule: the (count)th bit of mask decides the next state.
            let alive = ((mask >> count) & 1) as u8;
            next[y * WIDTH + x] = alive;
        }
    }
}

// Convert grid to RGB buffer for display.
fn render(grid: &[u8], buffer: &mut [u32], amplitude: f32, tempo: f32) {
    for i in 0..grid.len() {
        let state = grid[i];
        // Hue cycles with tempo, brightness with amplitude.
        let hue = ((i as f32 / grid.len() as f32) * 360.0 + tempo * 30.0) % 360.0;
        let sat = 0.7;
        let val = 0.3 + 0.7 * (state as f32) * amplitude;
        buffer[i] = hsv_to_rgb(hue, sat, val);
    }
}

// Simple HSV → RGB conversion packed as 0xRRGGBB.
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> u32 {
    let c = v * s;
    let h_prime = h / 60.0;
    let x = c * (1.0 - ((h_prime % 2.0) - 1.0).abs());
    let (r1, g1, b1) = match h_prime as u32 {
        0 => (c, x, 0.0),
        1 => (x, c, 0.0),
        2 => (0.0, c, x),
        3 => (0.0, x, c),
        4 => (x, 0.0, c),
        _ => (c, 0.0, x),
    };
    let m = v - c;
    let r = ((r1 + m) * 255.0) as u32;
    let g = ((g1 + m) * 255.0) as u32;
    let b = ((b1 + m) * 255.0) as u32;
    (r << 16) | (g << 8) | b
}

// Simple beat detector based on amplitude envelope.
fn detect_tempo(amplitudes: &[f32]) -> f32 {
    // Approximate BPM from zero‑crossings of the amplitude derivative.
    let mut crossings = 0;
    for w in amplitudes.windows(2) {
        if w[0] < 0.1 && w[1] > 0.1 { crossings += 1; }
    }
    // Assume buffer length ~0.1 s; convert to beats per minute.
    let seconds = amplitudes.len() as f32 * 0.0001;
    let beats_per_sec = crossings as f32 / seconds;
    beats_per_sec * 60.0
}

// Poem generator: prints rule masks and a short motif.
fn generate_poem(masks: &[u16], tempo: f32) {
    let motifs = ["whisper", "pulse", "glimmer", "thrum", "cascade"];
    let mut rng = rand::thread_rng();
    let motif = motifs[rng.gen_range(0..motifs.len())];
    println!("---");
    for (i, &mask) in masks.iter().enumerate() {
        println!("Band {} rule {:09b}", i, mask);
    }
    println!("Tempo {:.1} BPM, motif: {}", tempo, motif);
    println!("---");
}

fn main() {
    // Shared audio analysis data.
    let fft_size = 1024;
    let audio_data = Arc::new(Mutex::new(vec![0f32; fft_size]));
    let amplitude = Arc::new(Mutex::new(0f32));
    let tempo = Arc::new(Mutex::new(0f32));

    // Set up audio input stream.
    let host = cpal::default_host();
    let device = host.default_input_device().expect("No input device");
    let config = device.default_input_config().unwrap();
    let sample_rate = config.sample_rate().0 as f32;
    let audio_clone = audio_data.clone();
    let amp_clone = amplitude.clone();

    let err_fn = |err| eprintln!("Stream error: {}", err);
    let stream = match config.sample_format() {
        cpal::SampleFormat::F32 => device.build_input_stream(
            &config.into(),
            move |data: &[f32], _: &_| {
                let mut buf = audio_clone.lock().unwrap();
                for (i, &sample) in data.iter().enumerate().take(buf.len()) {
                    buf[i] = sample;
                }
                // Simple RMS amplitude.
                let rms = (buf.iter().map(|v| v * v).sum::<f32>() / buf.len() as f32).sqrt();
                *amp_clone.lock().unwrap() = rms;
            },
            err_fn,
        ),
        cpal::SampleFormat::I16 => device.build_input_stream(
            &config.into(),
            move |data: &[i16], _: &_| {
                let mut buf = audio_clone.lock().unwrap();
                for (i, &sample) in data.iter().enumerate().take(buf.len()) {
                    buf[i] = sample as f32 / i16::MAX as f32;
                }
                let rms = (buf.iter().map(|v| v * v).sum::<f32>() / buf.len() as f32).sqrt();
                *amp_clone.lock().unwrap() = rms;
            },
            err_fn,
        ),
        cpal::SampleFormat::U16 => device.build_input_stream(
            &config.into(),
            move |data: &[u16], _: &_| {
                let mut buf = audio_clone.lock().unwrap();
                for (i, &sample) in data.iter().enumerate().take(buf.len()) {
                    buf[i] = sample as f32 / u16::MAX as f32 - 0.5;
                }
                let rms = (buf.iter().map(|v| v * v).sum::<f32>() / buf.len() as f32).sqrt();
                *amp_clone.lock().unwrap() = rms;
            },
            err_fn,
        ),
    }.unwrap();
    stream.play().unwrap();

    // Prepare automata.
    let mut grid = vec![0u8; WIDTH * HEIGHT];
    let mut next_grid = vec![0u8; WIDTH * HEIGHT];
    // Random initial state.
    for cell in grid.iter_mut() {
        *cell = if rand::random::<f32>() > 0.5 { 1 } else { 0 };
    }

    // Rule masks (one per band).
    let mut masks = vec![0u16; BANDS];
    for i in 0..BANDS {
        masks[i] = rule_mask(i);
    }

    // Window for rendering.
    let mut window = Window::new(
        "Audio‑Caotic Kaleidoscope",
        WIDTH,
        HEIGHT,
        WindowOptions {
            resize: false,
            ..WindowOptions::default()
        },
    ).unwrap_or_else(|e| panic!("{}", e));
    window.set_limit_update_rate(Some(std::time::Duration::from_millis(16)));

    // Buffer for pixel data.
    let mut buffer: Vec<u32> = vec![0; WIDTH * HEIGHT];

    // Main loop.
    while window.is_open() && !window.is_key_down(Key::Escape) {
        // Perform FFT on the latest audio chunk.
        let samples = {
            let lock = audio_data.lock().unwrap();
            lock.clone()
        };
        let mut planner = FftPlanner::<f32>::new();
        let fft = planner.plan_fft_forward(fft_size);
        let mut complex_buf: Vec<Complex<f32>> = samples.iter().map(|&s| Complex{re:s, im:0.0}).collect();
        fft.process(&mut complex_buf);
        // Compute magnitude per band.
        let mut band_amplitudes = vec![0f32; BANDS];
        for (i, c) in complex_buf.iter().enumerate().take(fft_size/2) {
            let mag = (c.re * c.re + c.im * c.im).sqrt();
            let band = i * BANDS / (fft_size/2);
            band_amplitudes[band] += mag;
        }
        // Normalize and possibly adjust rule masks.
        for (i, amp) in band_amplitudes.iter().enumerate() {
            if *amp > 0.5 {
                // Flip a random bit in the rule mask to keep things lively.
                let bit = 1 << (rand::random::<u8>() % 9);
                masks[i] ^= bit;
            }
        }

        // Update tempo estimator.
        {
            let mut amp_vec = vec![*amplitude.lock().unwrap(); 100];
            let est = detect_tempo(&amp_vec);
            *tempo.lock().unwrap() = est;
        }

        // Step automata.
        step(&grid, &mut next_grid, &masks);
        std::mem::swap(&mut grid, &mut next_grid);

        // Render.
        let amp = *amplitude.lock().unwrap();
        let cur_tempo = *tempo.lock().unwrap();
        render(&grid, &mut buffer, amp, cur_tempo);
        window.update_with_buffer(&buffer, WIDTH, HEIGHT).unwrap();

        // Occasionally emit a poetic line.
        if rand::random::<f32>() < 0.02 {
            generate_poem(&masks, cur_tempo);
        }
    }
}