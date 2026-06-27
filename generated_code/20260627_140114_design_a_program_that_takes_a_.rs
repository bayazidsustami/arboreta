// cargo-deps: opencv="0.88", palette="0.7", rodio="0.17", eframe="0.24", crossbeam-channel="0.5"
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use crossbeam_channel::{unbounded, Receiver};
use eframe::{egui, epi};
use opencv::prelude::*;
use opencv::{core, imgproc, videoio};
use palette::{FromColor, Hsv, Srgb};
use rodio::{source::SineWave, OutputStream, Sink, Source};

/// Holds the latest dominant hue value extracted from the webcam.
struct SharedState {
    hue: f32, // 0..360
}

fn main() {
    // Start audio output
    let (_stream, stream_handle) = OutputStream::try_default().unwrap();
    let sink = Sink::try_new(&stream_handle).unwrap();
    // Shared state between threads
    let state = Arc::new(Mutex::new(SharedState { hue: 0.0 }));
    // Channel to signal new hue
    let (tx, rx) = unbounded();

    // Spawn webcam thread
    {
        let state = Arc::clone(&state);
        thread::spawn(move || webcam_loop(state, tx));
    }

    // Spawn audio thread that reacts to hue changes
    {
        let rx = rx.clone();
        thread::spawn(move || audio_loop(rx));
    }

    // Launch egui window for visual mandala
    let options = eframe::NativeOptions::default();
    eframe::run_native(
        "Audio‑Visual Mandala",
        options,
        Box::new(|_| Box::new(MandalaApp { state }),
    );
}

// Capture frames, compute average hue, send updates.
fn webcam_loop(state: Arc<Mutex<SharedState>>, tx: crossbeam_channel::Sender<f32>) {
    let mut cam = videoio::VideoCapture::new(0, videoio::CAP_ANY).unwrap();
    cam.set(videoio::CAP_PROP_FRAME_WIDTH, 320.0).unwrap();
    cam.set(videoio::CAP_PROP_FRAME_HEIGHT, 240.0).unwrap();

    loop {
        let mut frame = Mat::default();
        if !cam.read(&mut frame).unwrap() || frame.empty().unwrap() {
            continue;
        }
        // Convert to HSV and compute mean hue
        let mut hsv = Mat::default();
        imgproc::cvt_color(&frame, &mut hsv, imgproc::COLOR_BGR2HSV, 0).unwrap();
        let mut hue_channel = Mat::default();
        core::extract_channel(&hsv, &mut hue_channel, 0).unwrap();
        let mean = core::mean(&hue_channel, &core::no_array().unwrap()).0[0];
        let hue = mean as f32 * 2.0; // OpenCV hue range 0..180 -> 0..360

        // Update shared state
        {
            let mut s = state.lock().unwrap();
            s.hue = hue;
        }
        // Notify audio thread
        let _ = tx.send(hue);
        thread::sleep(Duration::from_millis(30));
    }
}

// Convert hue to frequency (C4 = 261.63 Hz) and play as a continuous sine.
fn audio_loop(rx: Receiver<f32>) {
    let (_stream, stream_handle) = OutputStream::try_default().unwrap();
    let sink = Sink::try_new(&stream_handle).unwrap();
    let mut current_freq = 440.0;
    let mut source = SineWave::new(current_freq as u32).amplify(0.0);
    sink.append(source);
    sink.sleep_until_end();

    loop {
        if let Ok(hue) = rx.recv_timeout(Duration::from_millis(100)) {
            // Map hue (0..360) to a note in a chromatic scale over two octaves
            let note_index = ((hue / 360.0) * 24.0).round() as i32;
            // A4 = 440 Hz, each semitone ratio = 2^(1/12)
            let freq = 440.0 * 2f32.powf(note_index as f32 / 12.0 - 9.0);
            current_freq = freq;
            // Replace source with new frequency and small volume fade-in
            sink.stop();
            let new_src = SineWave::new(current_freq as u32)
                .amplify(0.2)
                .fade_in(Duration::from_millis(100))
                .fade_out(Duration::from_millis(200));
            sink.append(new_src);
        }
    }
}

// Visual part: draws a rotating mandala whose petals count follows the hue.
struct MandalaApp {
    state: Arc<Mutex<SharedState>>,
}

impl epi::App for MandalaApp {
    fn name(&self) -> &str {
        "Mandala"
    }

    fn update(&mut self, ctx: &egui::CtxRef, _: &epi::Frame) {
        // Pull current hue
        let hue = {
            let s = self.state.lock().unwrap();
            s.hue
        };
        // Convert hue to color
        let rgb: Srgb = Hsv::new(hue, 0.6, 0.9).into();
        let egui_color = egui::Color32::from_rgb(
            (rgb.red * 255.0) as u8,
            (rgb.green * 255.0) as u8,
            (rgb.blue * 255.0) as u8,
        );

        // Parameters for mandala
        let petals = 4 + ((hue / 30.0).floor() as usize % 12);
        let time = Instant::now().elapsed().as_secs_f32();

        egui::CentralPanel::default().show(ctx, |ui| {
            let (rect, _) = ui.allocate_at_least(
                ui.available_size(),
                egui::Sense::hover(),
            );
            let painter = ui.painter();

            let center = rect.center();
            let radius = rect.width().min(rect.height()) * 0.4;

            // Draw rotating petals
            for i in 0..petals {
                let angle = time * 0.5 + i as f32 * std::f32::consts::TAU / petals as f32;
                let dir = egui::vec2(angle.cos(), angle.sin());
                let p1 = center + dir * radius;
                let p2 = center - dir * radius * 0.3;
                painter.line_segment([p1, p2], (2.0, egui_color));
                // small circles at ends
                painter.circle_filled(p1, 5.0, egui_color);
                painter.circle_filled(p2, 3.0, egui_color);
            }
        });

        ctx.request_repaint();
    }
}