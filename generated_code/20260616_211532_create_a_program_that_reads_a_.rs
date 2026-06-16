// Cargo.toml
// [package]
// name = "audio_visualizer"
// version = "0.1.0"
// edition = "2021"
// 
// [dependencies]
// cpal = "0.15"
// dasp_signal = "0.11"
// dasp_interpolate = "0.11"
// bincode = "1.3"
// serde = { version = "1.0", features = ["derive"] }

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Sample, SampleFormat};
use dasp_signal::{self as signal, Signal};
use dasp_interpolate::sinc::Sinc;
use serde::{Serialize, Deserialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

/// Simple event representing a note with timing and velocity.
#[derive(Serialize, Deserialize, Debug, Clone)]
struct NoteEvent {
    timestamp_ms: u128,
    pitch_hz: f32,
    velocity: f32,
    glyph: char,
}

/// Visual canvas that wraps both horizontally and vertically.
struct ToroidalCanvas {
    width: usize,
    height: usize,
    cells: Vec<Vec<char>>,
    x: usize,
    y: usize,
}

impl ToroidalCanvas {
    fn new(w: usize, h: usize) -> Self {
        Self {
            width: w,
            height: h,
            cells: vec![vec![' '; w]; h],
            x: 0,
            y: 0,
        }
    }

    fn put(&mut self, glyph: char) {
        self.cells[self.y][self.x] = glyph;
        self.x = (self.x + 1) % self.width;
        if self.x == 0 {
            self.y = (self.y + 1) % self.height;
        }
    }

    fn render(&self) {
        // Clear terminal
        print!("\x1B[2J\x1B[H");
        for row in &self.cells {
            let line: String = row.iter().collect();
            println!("{}", line);
        }
    }
}

/// Very naive zero‑crossing pitch estimator (for demonstration only).
fn estimate_pitch(samples: &[f32], sample_rate: f32) -> Option<f32> {
    let mut zero_crossings = 0;
    for w in samples.windows(2) {
        if w[0] <= 0.0 && w[1] > 0.0 {
            zero_crossings += 1;
        }
    }
    if zero_crossings < 2 {
        return None;
    }
    let period = (samples.len() as f32) / zero_crossings as f32;
    Some(sample_rate / period)
}

/// Maps a pitch (Hz) to a Unicode glyph (simple deterministic mapping).
fn pitch_to_glyph(pitch: f32, map: &HashMap<u8, char>) -> char {
    // Convert to MIDI note number (approx)
    let midi = (69.0 + 12.0 * (pitch / 440.0).log2()).round() as i32;
    let index = ((midi % 128 + 128) % 128) as u8;
    *map.get(&index).unwrap_or(&'✱')
}

fn main() {
    // Build a deterministic glyph map.
    let mut glyph_map = HashMap::new();
    let glyphs: Vec<char> = vec![
        '𝄞','♫','♩','♪','♬','♭','♯','𝄢','𝄡','𝄠','𝄣','𝄤','𝄥','𝄦','𝄧','𝄨',
        '𐍈','☀','☁','★','✦','✧','❖','✪','✫','✬','✭','✮','✯','✰','✱','✲',
        // fill up to 128 entries
    ];
    for i in 0..128u8 {
        glyph_map.insert(i, glyphs[(i as usize) % glyphs.len()]);
    }

    // Shared state for events and canvas.
    let events: Arc<Mutex<Vec<NoteEvent>>> = Arc::new(Mutex::new(Vec::new()));
    let canvas = Arc::new(Mutex::new(ToroidalCanvas::new(64, 16)));

    // Set up audio input.
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .expect("No input device available");
    let config = device
        .default_input_config()
        .expect("Failed to get default input config");
    let sample_rate = config.sample_rate().0 as f32;
    let err_fn = |err| eprintln!("Stream error: {}", err);

    // Buffer for a short analysis window.
    let buffer_len = (sample_rate * 0.05) as usize; // 50 ms window
    let shared_buf = Arc::new(Mutex::new(Vec::<f32>::with_capacity(buffer_len)));

    // Clone handles for the audio thread.
    let events_cloned = Arc::clone(&events);
    let canvas_cloned = Arc::clone(&canvas);
    let glyph_map_cloned = glyph_map.clone();
    let buf_cloned = Arc::clone(&shared_buf);

    let stream = match config.sample_format() {
        SampleFormat::F32 => device.build_input_stream(
            &config.into(),
            move |data: &[f32], _: &cpal::InputCallbackInfo| {
                let mut buf = buf_cloned.lock().unwrap();
                for &sample in data {
                    if buf.len() < buffer_len {
                        buf.push(sample);
                    }
                }
                if buf.len() == buffer_len {
                    let pitch = estimate_pitch(&buf, sample_rate);
                    if let Some(p) = pitch {
                        let now = Instant::now();
                        let glyph = pitch_to_glyph(p, &glyph_map_cloned);
                        let velocity = buf.iter().map(|s| s.abs()).sum::<f32>() / buf.len() as f32;
                        let event = NoteEvent {
                            timestamp_ms: now.elapsed().as_millis(),
                            pitch_hz: p,
                            velocity,
                            glyph,
                        };
                        {
                            let mut ev = events_cloned.lock().unwrap();
                            ev.push(event.clone());
                        }
                        {
                            let mut cv = canvas_cloned.lock().unwrap();
                            cv.put(glyph);
                        }
                    }
                    buf.clear();
                }
            },
            err_fn,
        ),
        SampleFormat::I16 => device.build_input_stream(
            &config.into(),
            move |data: &[i16], _: &cpal::InputCallbackInfo| {
                let mut buf = buf_cloned.lock().unwrap();
                for &sample in data {
                    if buf.len() < buffer_len {
                        buf.push(sample.to_f32());
                    }
                }
                if buf.len() == buffer_len {
                    let pitch = estimate_pitch(&buf, sample_rate);
                    if let Some(p) = pitch {
                        let now = Instant::now();
                        let glyph = pitch_to_glyph(p, &glyph_map_cloned);
                        let velocity = buf.iter().map(|s| s.abs()).sum::<f32>() / buf.len() as f32;
                        let event = NoteEvent {
                            timestamp_ms: now.elapsed().as_millis(),
                            pitch_hz: p,
                            velocity,
                            glyph,
                        };
                        {
                            let mut ev = events_cloned.lock().unwrap();
                            ev.push(event.clone());
                        }
                        {
                            let mut cv = canvas_cloned.lock().unwrap();
                            cv.put(glyph);
                        }
                    }
                    buf.clear();
                }
            },
            err_fn,
        ),
        SampleFormat::U16 => device.build_input_stream(
            &config.into(),
            move |data: &[u16], _: &cpal::InputCallbackInfo| {
                let mut buf = buf_cloned.lock().unwrap();
                for &sample in data {
                    if buf.len() < buffer_len {
                        // Convert unsigned to signed float in [-1.0, 1.0]
                        let s = (sample as i32 - 32768) as f32 / 32768.0;
                        buf.push(s);
                    }
                }
                if buf.len() == buffer_len {
                    let pitch = estimate_pitch(&buf, sample_rate);
                    if let Some(p) = pitch {
                        let now = Instant::now();
                        let glyph = pitch_to_glyph(p, &glyph_map_cloned);
                        let velocity = buf.iter().map(|s| s.abs()).sum::<f32>() / buf.len() as f32;
                        let event = NoteEvent {
                            timestamp_ms: now.elapsed().as_millis(),
                            pitch_hz: p,
                            velocity,
                            glyph,
                        };
                        {
                            let mut ev = events_cloned.lock().unwrap();
                            ev.push(event.clone());
                        }
                        {
                            let mut cv = canvas_cloned.lock().unwrap();
                            cv.put(glyph);
                        }
                    }
                    buf.clear();
                }
            },
            err_fn,
        ),
    }
    .expect("Failed to build input stream");

    stream.play().expect("Failed to start audio stream");

    // Rendering loop.
    loop {
        {
            let cv = canvas.lock().unwrap();
            cv.render();
        }
        thread::sleep(Duration::from_millis(100));
    }

    // (Unreachable) When terminating you could serialize `events`:
    // let ev = events.lock().unwrap();
    // let encoded = bincode::serialize(&*ev).unwrap();
    // std::fs::write("performance.bin", encoded).unwrap();
}