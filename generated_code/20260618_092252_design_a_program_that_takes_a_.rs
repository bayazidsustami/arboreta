use std::error::Error;
use std::f32::consts::PI;
use std::thread;
use std::time::{Duration, Instant};

use opencv::{
    core::{self, Mat, MatTrait, Scalar, Vec3b, CV_32F},
    imgproc,
    prelude::*,
    videoio,
    types,
};
use rodio::{source::Source, OutputStream, Sink};

fn dominant_colors(frame: &Mat, k: i32) -> Result<Vec<Scalar>, Box<dyn Error>> {
    // reshape to N x 3 float matrix
    let mut samples = Mat::default();
    frame.convert_to(&mut samples, CV_32F, 1.0, 0.0)?;
    let samples = samples.reshape(1, frame.total() as i32)?;
    let criteria = core::TermCriteria::new(core::TermCriteria_Type::COUNT + core::TermCriteria_Type::EPS, 10, 1.0)?;
    let mut labels = Mat::default();
    let mut centers = Mat::default();
    core::kmeans(
        &samples,
        k,
        &mut labels,
        criteria,
        3,
        core::KMEANS_PP_CENTERS,
        &mut centers,
    )?;
    let mut colors = Vec::new();
    for i in 0..k {
        let c = centers.at_2d::<f32>(i, 0)?;
        let d = centers.at_2d::<f32>(i, 1)?;
        let e = centers.at_2d::<f32>(i, 2)?;
        colors.push(Scalar::new(*c as f64, *d as f64, *e as f64, 0.0));
    }
    Ok(colors)
}

// simple mapping: hue -> midi note (C4=60) -> frequency
fn color_to_freq(color: &Scalar) -> f32 {
    // convert BGR to HSV to get hue
    let b = color[0] as f32 / 255.0;
    let g = color[1] as f32 / 255.0;
    let r = color[2] as f32 / 255.0;
    let max = r.max(g.max(b));
    let min = r.min(g.min(b));
    let delta = max - min;
    let hue = if delta == 0.0 {
        0.0
    } else if max == r {
        60.0 * ((g - b) / delta % 6.0)
    } else if max == g {
        60.0 * ((b - r) / delta + 2.0)
    } else {
        60.0 * ((r - g) / delta + 4.0)
    };
    let hue = if hue < 0.0 { hue + 360.0 } else { hue };
    // map hue (0..360) to MIDI note 48..72
    let midi = 48.0 + (hue / 360.0) * 24.0;
    // midi to frequency
    440.0 * 2_f32.powf((midi - 69.0) / 12.0)
}

// generate a short sine wave for a given frequency
fn sine_wave(freq: f32, dur: Duration) -> impl Source<Item = f32> + Send {
    let sample_rate = 44100.0;
    let total_samples = (dur.as_secs_f32() * sample_rate) as usize;
    rodio::source::Buffered::new(
        (0..total_samples).map(move |i| {
            let t = i as f32 / sample_rate;
            (2.0 * PI * freq * t).sin() * 0.2
        })
    )
}

// create a simple SVG using the colors
fn write_svg(colors: &[Scalar], width: u32, height: u32) -> Result<(), Box<dyn Error>> {
    let mut svg = String::new();
    svg.push_str(&format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<svg width="{w}" height="{h}" viewBox="0 0 {w} {h}" xmlns="http://www.w3.org/2000/svg">"#,
        w = width,
        h = height
    ));
    for (i, col) in colors.iter().enumerate() {
        let cx = (i as f32 + 0.5) * (width as f32) / (colors.len() as f32);
        let cy = height as f32 / 2.0;
        let r = 30.0 + (col[0] + col[1] + col[2]) / 3.0;
        let hex = format!(
            "#{:02X}{:02X}{:02X}",
            col[2] as u8, col[1] as u8, col[0] as u8
        );
        svg.push_str(&format!(
            r#"<circle cx="{cx}" cy="{cy}" r="{r}" fill="{hex}" stroke="black" stroke-width="2"/>"#
        ));
    }
    svg.push_str("</svg>");
    std::fs::write("output.svg", svg)?;
    Ok(())
}

fn main() -> Result<(), Box<dyn Error>> {
    // open default camera
    let mut cam = videoio::VideoCapture::new(0, videoio::CAP_ANY)?; // 0 = default device
    cam.set(videoio::CAP_PROP_FRAME_WIDTH, 320.0)?;
    cam.set(videoio::CAP_PROP_FRAME_HEIGHT, 240.0)?;
    if !videoio::VideoCapture::is_opened(&cam)? {
        return Err("Cannot open webcam".into());
    }

    let (_stream, stream_handle) = OutputStream::try_default()?;
    let sink = Sink::try_new(&stream_handle)?;

    loop {
        let start = Instant::now();
        let mut frame = Mat::default();
        cam.read(&mut frame)?;
        if frame.empty()? {
            continue;
        }

        // resize for speed
        let mut small = Mat::default();
        imgproc::resize(
            &frame,
            &mut small,
            core::Size::new(80, 60),
            0.0,
            0.0,
            imgproc::INTER_LINEAR,
        )?;
        let colors = dominant_colors(&small, 3)?;

        // play chords (simultaneous)
        for col in &colors {
            let freq = color_to_freq(col);
            sink.append(sine_wave(freq, Duration::from_millis(300)));
        }

        // write SVG
        write_svg(&colors, 800, 200)?;

        // limit loop to ~30 FPS
        let elapsed = start.elapsed();
        if elapsed < Duration::from_millis(33) {
            thread::sleep(Duration::from_millis(33) - elapsed);
        }
    }
}