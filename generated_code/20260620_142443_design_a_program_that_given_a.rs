use nannou::prelude::*;
use nannou::video::{self, Codec, Encoder, EncoderSettings};
use rodio::{OutputStream, Sink, Source};
use std::f32::consts::PI;
use std::io::{self, Read};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

/// Simple heuristic syllable counter: count vowel groups.
fn count_syllables(word: &str) -> usize {
    let vowels = "aeiouyAEIOUY";
    let mut count = 0;
    let mut prev_vowel = false;
    for c in word.chars() {
        let is_vowel = vowels.contains(c);
        if is_vowel && !prev_vowel {
            count += 1;
        }
        prev_vowel = is_vowel;
    }
    if count == 0 { 1 } else { count }
}

/// Map a word index to a pitch (MIDI note) within one octave.
fn word_to_pitch(idx: usize) -> u8 {
    60 + ((idx * 5) % 12) as u8 // start at middle C
}

/// Map syllable count to note duration (seconds).
fn syllables_to_duration(syl: usize) -> f32 {
    match syl {
        1 => 0.25,
        2 => 0.5,
        3 => 0.75,
        _ => 1.0,
    }
}

/// Generate a simple sine wave for a given frequency and duration.
fn synth_note(freq: f32, dur: f32) -> impl Source<Item = f32> + Send {
    let sample_rate = 44100;
    let total_samples = (dur * sample_rate as f32) as usize;
    rodio::source::SineWave::new(freq as u32)
        .take_duration(Duration::from_secs_f32(dur))
        .amplify(0.2)
        .convert_samples()
}

/// Data shared between audio thread and visual thread.
struct SharedState {
    // each entry: (pitch_hz, duration, time_offset)
    notes: Vec<(f32, f32, f32)>,
    start_instant: std::time::Instant,
}

fn main() {
    // ---- INPUT ----
    println!("Enter your poem (end with Ctrl+D):");
    let mut input = String::new();
    io::stdin().read_to_string(&mut input).unwrap();

    // ---- PROCESS POEM ----
    let words: Vec<String> = input
        .split_whitespace()
        .map(|s| s.trim_matches(|c: char| !c.is_alphanumeric()).to_string())
        .filter(|s| !s.is_empty())
        .collect();

    let mut notes = Vec::new();
    let mut time_cursor = 0.0;
    for (i, w) in words.iter().enumerate() {
        let syl = count_syllables(w);
        let pitch = word_to_pitch(i) as f32;
        let freq = 440.0 * 2_f32.powf((pitch - 69.0) / 12.0); // MIDI to Hz
        let dur = syllables_to_duration(syl);
        notes.push((freq, dur, time_cursor));
        time_cursor += dur;
    }

    let shared = Arc::new(Mutex::new(SharedState {
        notes,
        start_instant: std::time::Instant::now(),
    }));

    // ---- AUDIO THREAD ----
    let audio_shared = Arc::clone(&shared);
    thread::spawn(move || {
        let (_stream, stream_handle) = OutputStream::try_default().unwrap();
        let sink = Sink::try_new(&stream_handle).unwrap();

        let st = audio_shared.lock().unwrap();
        for (freq, dur, offset) in &st.notes {
            // schedule by sleeping until offset
            let now = std::time::Instant::now();
            let target = st.start_instant + Duration::from_secs_f32(*offset);
            if target > now {
                thread::sleep(target - now);
            }
            sink.append(synth_note(*freq, *dur));
        }
        sink.sleep_until_end();
    });

    // ---- VISUALS ----
    nannou::app(model).update(update).run();
}

struct Model {
    encoder: Encoder,
    shared: Arc<Mutex<SharedState>>,
    frame_count: u64,
}

fn model(app: &App) -> Model {
    let window_id = app
        .new_window()
        .size(800, 800)
        .view(view)
        .raw_event(raw_window_event)
        .build()
        .unwrap();

    // video encoder (MP4, H264)
    let path = std::path::Path::new("output.mp4");
    let codec = Codec::H264;
    let settings = EncoderSettings::default();
    let encoder = Encoder::new(path, codec, settings).unwrap();

    Model {
        encoder,
        shared: Arc::new(Mutex::new(SharedState {
            notes: vec![],
            start_instant: std::time::Instant::now(),
        })),
        frame_count: 0,
    }
}

/// Capture raw window events to forward to video encoder.
fn raw_window_event(_app: &App, model: &mut Model, _event: nannou::winit::event::WindowEvent<()>) {
    // No special handling needed for this demo.
}

fn update(app: &App, model: &mut Model) {
    let dt = app.duration.since_prev_update.as_secs_f32();

    // Record frame for video
    if let Some(frame) = app.main_window().capture_frame() {
        model.encoder.encode(&frame).unwrap();
        model.frame_count += 1;
    }

    // Stop after all notes have played + a buffer
    let elapsed = app.time;
    let total_duration = {
        let st = model.shared.lock().unwrap();
        st.notes.last().map(|(_, d, o)| o + d).unwrap_or(0.0)
    };
    if elapsed > total_duration + 2.0 {
        model.encoder.finish().unwrap();
        std::process::exit(0);
    }
}

/// Draw a mandala where each petal corresponds to a note.
fn view(app: &App, model: &Model, frame: Frame) {
    let draw = app.draw();
    draw.background().color(BLACK);

    let now = app.time;
    let st = model.shared.lock().unwrap();

    for (i, (freq, dur, offset)) in st.notes.iter().enumerate() {
        let age = now - offset;
        if age < 0.0 || age > *dur {
            continue; // not active
        }

        // Map pitch to angle & radius
        let angle = map_range(i as f32, 0.0, st.notes.len() as f32, 0.0, TAU);
        let radius = map_range(*freq, 200.0, 800.0, 100.0, 350.0);
        let progress = age / dur;

        // Color gradient based on timbre (here just frequency)
        let hue = map_range(*freq, 200.0, 800.0, 0.0, 1.0);
        let col = hsla(hue, 0.7, 0.5 + 0.5 * progress, 0.8);

        // Petal shape
        let petal = Ellipse::new()
            .x_y(radius * angle.cos(), radius * angle.sin())
            .w_h(30.0, 100.0 * (1.0 - progress))
            .rotate(angle + PI / 2.0)
            .color(col);
        draw.ellipse().xy(petal.x_y()).w_h(petal.w(), petal.h()).rotate(petal.rotation()).color(petal.color());
    }

    draw.to_frame(app, &frame).unwrap();
}