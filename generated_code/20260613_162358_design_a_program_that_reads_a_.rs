use std::sync::{Arc, Mutex};
use std::f32::consts::PI;
use std::thread;
use std::time::{Duration, Instant};

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use rustfft::{FftPlanner, num_complex::Complex};
use pixels::{Pixels, SurfaceTexture};
use winit::{
    event::{Event, WindowEvent},
    event_loop::{ControlFlow, EventLoop},
    window::WindowBuilder,
};

/// Simple structure to hold the latest spectrum magnitude data.
#[derive(Default, Clone)]
struct Spectrum {
    mags: Vec<f32>,
    beat: bool,
}

/// Shared state between audio thread and graphics thread.
struct SharedState {
    spectrum: Mutex<Spectrum>,
    // painting buffer accumulates colors over time
    painting: Mutex<Vec<u8>>, // RGBA for each pixel
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // ---------- audio setup ----------
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .expect("no input device available");
    let config = device.default_input_config()?;

    // We will use a fixed FFT size
    const FFT_SIZE: usize = 1024;
    let mut fft_input: Vec<f32> = vec![0.0; FFT_SIZE];
    let mut fft_planner = FftPlanner::<f32>::new();
    let fft = fft_planner.plan_fft_forward(FFT_SIZE);
    let mut fft_output: Vec<Complex<f32>> = vec![Complex::zero(); FFT_SIZE];

    // Shared state
    let state = Arc::new(SharedState {
        spectrum: Mutex::new(Spectrum::default()),
        painting: Mutex::new(vec![0; (WIDTH * HEIGHT * 4) as usize]),
    });

    // Audio callback
    let state_clone = Arc::clone(&state);
    let err_fn = |err| eprintln!("an error occurred on stream: {}", err);
    let stream = match config.sample_format() {
        cpal::SampleFormat::F32 => device.build_input_stream(
            &config.into(),
            move |data: &[f32], _: &_| {
                audio_callback(data, &mut fft_input, &fft, &mut fft_output, &state_clone)
            },
            err_fn,
        )?,
        cpal::SampleFormat::I16 => device.build_input_stream(
            &config.into(),
            move |data: &[i16], _: &_| {
                let f32_data: Vec<f32> = data.iter().map(|&s| s as f32 / i16::MAX as f32).collect();
                audio_callback(&f32_data, &mut fft_input, &fft, &mut fft_output, &state_clone)
            },
            err_fn,
        )?,
        cpal::SampleFormat::U16 => device.build_input_stream(
            &config.into(),
            move |data: &[u16], _: &_| {
                let f32_data: Vec<f32> = data.iter().map(|&s| s as f32 / u16::MAX as f32 - 1.0).collect();
                audio_callback(&f32_data, &mut fft_input, &fft, &mut fft_output, &state_clone)
            },
            err_fn,
        )?,
    };
    stream.play()?;

    // ---------- graphics setup ----------
    const WIDTH: u32 = 800;
    const HEIGHT: u32 = 600;
    let event_loop = EventLoop::new();
    let window = WindowBuilder::new()
        .with_title("Audio‑Reactive Generative Painting")
        .with_inner_size(winit::dpi::LogicalSize::new(WIDTH, HEIGHT))
        .build(&event_loop)?;

    let mut pixels = Pixels::new(WIDTH, HEIGHT, SurfaceTexture::new(WIDTH, HEIGHT, &window))?;

    // Main loop
    let start = Instant::now();
    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::Poll;
        match event {
            Event::RedrawRequested(_) => {
                // draw based on current spectrum
                if let Ok(mut frame) = pixels.get_frame().chunks_exact_mut(4).enumerate() {
                    let mut painting = state.painting.lock().unwrap();
                    let spectrum = state.spectrum.lock().unwrap();
                    // simple mapping: each frequency band creates a brushstroke
                    for (i, pixel) in frame {
                        let x = (i as u32) % WIDTH;
                        let y = (i as u32) / WIDTH;

                        // radial distance from center
                        let cx = WIDTH as f32 / 2.0;
                        let cy = HEIGHT as f32 / 2.0;
                        let dx = x as f32 - cx;
                        let dy = y as f32 - cy;
                        let dist = (dx * dx + dy * dy).sqrt();
                        let angle = dy.atan2(dx);

                        // pick a band based on angle
                        let band = ((angle + PI) / (2.0 * PI) * spectrum.mags.len() as f32) as usize % spectrum.mags.len();
                        let amp = spectrum.mags.get(band).copied().unwrap_or(0.0);

                        // compute color from amplitude and position
                        let hue = (band as f32 / spectrum.mags.len() as f32) * 360.0;
                        let sat = (amp * 5.0).min(1.0);
                        let val = ((dist / (WIDTH as f32).max(HEIGHT as f32)) * 0.5 + 0.5).min(1.0);
                        let (r, g, b) = hsv_to_rgb(hue, sat, val);

                        // blend with existing painting (self‑evolving)
                        let idx = i * 4;
                        let pr = painting[idx] as f32 / 255.0;
                        let pg = painting[idx + 1] as f32 / 255.0;
                        let pb = painting[idx + 2] as f32 / 255.0;

                        let new_r = (pr + r) / 2.0;
                        let new_g = (pg + g) / 2.0;
                        let new_b = (pb + b) / 2.0;

                        painting[idx] = (new_r * 255.0) as u8;
                        painting[idx + 1] = (new_g * 255.0) as u8;
                        painting[idx + 2] = (new_b * 255.0) as u8;
                        painting[idx + 3] = 255;

                        pixel[0] = painting[idx];
                        pixel[1] = painting[idx + 1];
                        pixel[2] = painting[idx + 2];
                        pixel[3] = 255;
                    }
                }
                if pixels.render().is_err() {
                    *control_flow = ControlFlow::Exit;
                    return;
                }
            }
            Event::MainEventsCleared => {
                // request redraw at 60 Hz
                window.request_redraw();

                // Poetic stanza synchronisation (once per beat)
                let now = Instant::now();
                if now.duration_since(start).as_secs_f32() > 0.2 {
                    let beat = {
                        let s = state.spectrum.lock().unwrap();
                        s.beat
                    };
                    if beat {
                        let line = generate_poem_line();
                        println!("{}", line);
                    }
                }
            }
            Event::WindowEvent { event, .. } => match event {
                WindowEvent::CloseRequested => *control_flow = ControlFlow::Exit,
                _ => {}
            },
            _ => {}
        }
    });
}

/// Audio processing callback: fills a ring buffer, runs FFT, updates shared spectrum.
fn audio_callback(
    data: &[f32],
    buffer: &mut [f32],
    fft: &std::sync::Arc<dyn rustfft::Fft<f32>>,
    output: &mut [Complex<f32>],
    state: &Arc<SharedState>,
) {
    // simple sliding window: copy newest samples over old ones
    let len = buffer.len();
    let copy_len = data.len().min(len);
    buffer.rotate_left(copy_len);
    buffer[len - copy_len..].copy_from_slice(&data[..copy_len]);

    // apply a Hann window
    let mut windowed: Vec<Complex<f32>> = buffer
        .iter()
        .enumerate()
        .map(|(i, &x)| {
            let w = 0.5 * (1.0 - (2.0 * PI * i as f32 / (len as f32 - 1.0)).cos());
            Complex::new(x * w, 0.0)
        })
        .collect();

    fft.process(&mut windowed);
    // compute magnitude spectrum
    let mags: Vec<f32> = windowed.iter().map(|c| c.norm()).collect();

    // simple beat detection: compare energy to a moving average
    let energy: f32 = mags.iter().map(|&m| m * m).sum();
    static mut ENERGY_HISTORY: [f32; 43] = [0.0; 43];
    unsafe {
        ENERGY_HISTORY.rotate_left(1);
        ENERGY_HISTORY[42] = energy;
        let avg_energy = ENERGY_HISTORY.iter().sum::<f32>() / ENERGY_HISTORY.len() as f32;
        let beat = energy > avg_energy * 1.5;

        let mut spec = state.spectrum.lock().unwrap();
        spec.mags = mags;
        spec.beat = beat;
    }
}

/// Convert HSV (0‑360,0‑1,0‑1) to RGB (0‑1).
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> (f32, f32, f32) {
    let c = v * s;
    let hh = h / 60.0;
    let x = c * (1.0 - ((hh % 2.0) - 1.0).abs());
    let (r1, g1, b1) = match hh as u32 {
        0 => (c, x, 0.0),
        1 => (x, c, 0.0),
        2 => (0.0, c, x),
        3 => (0.0, x, c),
        4 => (x, 0.0, c),
        _ => (c, 0.0, x),
    };
    let m = v - c;
    (r1 + m, g1 + m, b1 + m)
}

/// Very small pseudo‑poetic generator using dominant frequency band.
fn generate_poem_line() -> String {
    // dummy words per beat intensity
    let adjectives = ["brassy", "silken", "trembling", "glimmering", "rumbling"];
    let nouns = ["pulse", "wave", "echo", "shadow", "flare"];
    let verbs = ["whispers", "shouts", "drifts", "dances", "collides"];
    use rand::{seq::SliceRandom, thread_rng};
    let mut rng = thread_rng();
    format!(
        "The {} {} {} the night.",
        adjectives.choose(&mut rng).unwrap(),
        nouns.choose(&mut rng).unwrap(),
        verbs.choose(&mut rng).unwrap()
    )
}

// Cargo dependencies (add to Cargo.toml):
// cpal = "0.15"
// rustfft = "6.1"
// pixels = "0.12"
// winit = "0.28"
// rand = "0.8"