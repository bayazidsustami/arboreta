use std::fs::{OpenOptions, read_to_string};
use std::io::Write;
use std::path::Path;
use std::sync::mpsc::{self, TryRecvError};
use std::thread;
use std::time::{Duration, Instant};

use opencv::{
    core::{Scalar, Mat, Size, CV_8UC3},
    highgui,
    imgproc,
    prelude::*,
    videoio,
};

use rodio::{OutputStream, Sink, source::SineWave};

/// Map a color component (0..255) to a MIDI note (0..127) and then to a frequency.
fn color_to_freq(r: u8, g: u8, b: u8) -> f32 {
    // Simple weighted sum -> MIDI note
    let midi = ((r as u16 + g as u16 + b as u16) / 3) as u8;
    // MIDI note 69 = A440Hz
    440.0 * 2_f32.powf((midi as i32 - 69) as f32 / 12.0)
}

/// Append a hidden comment with the generated frequency to the source file.
fn self_modify(freq: f32) {
    // locate source file – assume it's the same file that was compiled
    if let Ok(path) = std::env::current_exe() {
        // turn ".../target/debug/<name>" into "<name>.rs"
        if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
            let src = format!("src/{}.rs", stem);
            if Path::new(&src).exists() {
                let mut file = OpenOptions::new()
                    .append(true)
                    .open(&src)
                    .unwrap();
                // hidden comment block
                writeln!(file, "\n/*#freq:{:.2}*/", freq).unwrap();
            }
        }
    }
}

fn main() -> opencv::Result<()> {
    // start audio output
    let (_stream, stream_handle) = OutputStream::try_default().unwrap();
    let sink = Sink::try_new(&stream_handle).unwrap();

    // open webcam
    let mut cam = videoio::VideoCapture::new(0, videoio::CAP_ANY)?; // 0 = default camera
    cam.set(videoio::CAP_PROP_FRAME_WIDTH, 320.0)?;
    cam.set(videoio::CAP_PROP_FRAME_HEIGHT, 240.0)?;

    // create display window
    highgui::named_window("Mandala", highgui::WINDOW_AUTOSIZE)?;

    // channel to stop audio thread
    let (tx, rx) = mpsc::channel();

    // audio thread: plays the last frequency received
    thread::spawn(move || {
        let mut current_freq = 440.0;
        loop {
            match rx.try_recv() {
                Ok(f) => current_freq = f,
                Err(TryRecvError::Empty) => {}
                Err(TryRecvError::Disconnected) => break,
            }
            // generate short sine wave and play
            let source = SineWave::new(current_freq).take_duration(Duration::from_millis(100));
            sink.append(source);
            thread::sleep(Duration::from_millis(100));
        }
    });

    loop {
        let mut frame = Mat::default();
        cam.read(&mut frame)?;
        if frame.empty()? {
            continue;
        }

        // compute average color
        let mut avg = Scalar::default();
        imgproc::mean(&frame, &Mat::default()?, &mut avg, &Mat::default()?)?;
        let (b, g, r, _) = (avg[0] as u8, avg[1] as u8, avg[2] as u8, avg[3] as u8);

        // map to frequency
        let freq = color_to_freq(r, g, b);
        tx.send(freq).ok();

        // self‑modify source with hidden comment
        self_modify(freq);

        // draw a simple mandala: concentric circles using the average color
        let mut mandala = Mat::zeros(Size::new(480, 480), CV_8UC3)?.to_mat()?;
        let center = (240, 240);
        for i in (20..240).step_by(20) {
            let color = Scalar::new(
                (b as f64 * i as f64 / 240.0) as f64,
                (g as f64 * i as f64 / 240.0) as f64,
                (r as f64 * i as f64 / 240.0) as f64,
                0.0,
            );
            imgproc::circle(
                &mut mandala,
                center,
                i,
                color,
                2,
                imgproc::LINE_8,
                0,
            )?;
        }

        highgui::imshow("Mandala", &mandala)?;
        // break on ESC
        if highgui::wait_key(10)? == 27 {
            break;
        }
    }

    // clean up
    tx.send(0.0).ok(); // stop audio thread
    sink.stop();
    Ok(())
}