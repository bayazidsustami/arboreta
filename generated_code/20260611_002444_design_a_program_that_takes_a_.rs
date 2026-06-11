use opencv::{
    core::{self, Mat, Scalar, Vector},
    imgproc,
    prelude::*,
    videoio,
};
use rodio::{source::SineWave, OutputStream, Sink, Source};
use minifb::{Key, Window, WindowOptions};
use serde::{Serialize, Serializer};
use serde_json::json;
use std::{thread, time::Duration};

/// Simple struct to log each frame's data as JSON‑L.
#[derive(Serialize)]
struct LogEntry {
    frame: usize,
    dominant_colors: Vec<[u8; 3]>,
    chord: String,
    timestamp_ms: u128,
}

fn main() -> opencv::Result<()> {
    // Open default camera.
    let mut cam = videoio::VideoCapture::new(0, videoio::CAP_ANY)?; // 0 = default device
    cam.set(videoio::CAP_PROP_FRAME_WIDTH, 320.0)?;
    cam.set(videoio::CAP_PROP_FRAME_HEIGHT, 240.0)?;

    // Audio output.
    let (_stream, stream_handle) = OutputStream::try_default().unwrap();
    let sink = Sink::try_new(&stream_handle).unwrap();

    // Create a simple window.
    let mut window = Window::new(
        "Color‑Music Visualizer",
        320,
        240,
        WindowOptions::default(),
    )
    .unwrap_or_else(|e| panic!("{}", e));

    let mut frame_idx = 0usize;

    loop {
        let mut frame = Mat::default();
        cam.read(&mut frame)?;
        if frame.empty()? {
            continue;
        }

        // Resize for faster processing.
        let mut small = Mat::default();
        imgproc::resize(
            &frame,
            &mut small,
            core::Size {
                width: 80,
                height: 80,
            },
            0.0,
            0.0,
            imgproc::INTER_LINEAR,
        )?;

        // Convert to Lab and run k‑means to get 3 dominant colors.
        let mut samples = Mat::default();
        small.convert_to(&mut samples, core::CV_32F, 1.0, 0.0)?;
        samples = samples.reshape(1, (small.rows() * small.cols()) as i32)?;

        let criteria = core::TermCriteria::new(
            core::TermCriteria_Type::COUNT + core::TermCriteria_Type::EPS,
            10,
            1.0,
        )?;
        let mut labels = Mat::default();
        let mut centers = Mat::default();
        core::kmeans(
            &samples,
            3,
            &mut labels,
            criteria,
            3,
            core::KMEANS_PP_CENTERS,
            &mut centers,
        )?;

        // Extract colors.
        let mut dominant = Vec::new();
        for i in 0..3 {
            let cx = *centers.at_2d::<core::Vec3f>(i, 0).unwrap();
            let bgr = core::Scalar::new(cx[0] as f64, cx[1] as f64, cx[2] as f64, 0.0);
            let mut rgb = Scalar::default();
            imgproc::cvt_color(
                &Mat::from_scalar(bgr, core::Size::new(1, 1), core::CV_8UC3)?,
                &mut Mat::from_scalar(rgb, core::Size::new(1, 1), core::CV_8UC3)?,
                imgproc::COLOR_BGR2RGB,
                0,
            )?;
            dominant.push([
                rgb[2] as u8, // R
                rgb[1] as u8, // G
                rgb[0] as u8, // B
            ]);
        }

        // Very simple harmonic mapping: sum of RGB determines a chord.
        let sum: u32 = dominant.iter().map(|c| c.iter().map(|&v| v as u32).sum::<u32>()).sum();
        let chord = match sum % 4 {
            0 => "Cmaj",
            1 => "Gmaj",
            2 => "Amin",
            _ => "Emin",
        };
        // Play a tone representing the chord (just a frequency stub).
        let freq = match chord {
            "Cmaj" => 261.6,
            "Gmaj" => 392.0,
            "Amin" => 440.0,
            "Emin" => 329.6,
            _ => 440.0,
        };
        // Generate a 0.2 s sine wave.
        let source = SineWave::new(freq as u32).take_duration(Duration::from_millis(200));
        sink.append(source);
        sink.sleep_until_end();

        // Render the dominant colors as vertical strips.
        let mut buffer = vec![0u32; 320 * 240];
        for (i, col) in dominant.iter().enumerate() {
            let start_x = i * 100;
            for y in 0..240 {
                for x in start_x..(start_x + 100) {
                    let idx = y * 320 + x.min(319);
                    buffer[idx] = ((col[0] as u32) << 16) | ((col[1] as u32) << 8) | (col[2] as u32);
                }
            }
        }
        window
            .update_with_buffer(&buffer, 320, 240)
            .unwrap();

        // Log JSON‑L entry.
        let log = LogEntry {
            frame: frame_idx,
            dominant_colors: dominant,
            chord: chord.to_string(),
            timestamp_ms: chrono::Utc::now().timestamp_millis() as u128,
        };
        println!("{}", serde_json::to_string(&log).unwrap());

        frame_idx += 1;

        // Exit on Escape.
        if window.is_key_down(Key::Escape) {
            break;
        }
        // Give the OS a breather.
        thread::sleep(Duration::from_millis(30));
    }

    Ok(())
}