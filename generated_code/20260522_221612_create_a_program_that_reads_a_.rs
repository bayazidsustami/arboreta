use std::f32::consts::PI;
use std::io::Write;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use rand::Rng;

// simplistic sentiment analyzer (placeholder for a real neural net)
fn dummy_sentiment(_samples: &[f32]) -> f32 {
    // returns a value between -1.0 (negative) and 1.0 (positive)
    rand::thread_rng().gen_range(-1.0..1.0)
}

// generate a colour based on sentiment intensity
fn sentiment_color(sent: f32) -> [u8; 3] {
    let t = ((sent + 1.0) / 2.0).clamp(0.0, 1.0);
    let r = (255.0 * t) as u8;
    let b = (255.0 * (1.0 - t)) as u8;
    [r, 128, b]
}

// simple 3‑D fractal height function (Mandelbulb‑like stub)
fn fractal_height(x: f32, y: f32, z: f32, power: f32) -> f32 {
    let mut zx = x;
    let mut zy = y;
    let mut zz = z;
    let mut dr = 1.0;
    let mut r = 0.0;
    for _ in 0..8 {
        r = (zx * zx + zy * zy + zz * zz).sqrt();
        if r > 2.0 {
            break;
        }
        // convert to polar coordinates
        let theta = (zz / r).acos();
        let phi = zy.atan2(zx);
        // scale and rotate the point
        let zr = r.powf(power);
        dr = dr * power * r.powf(power - 1.0) + 1.0;
        let sin_theta = (theta * power).sin();
        let cos_theta = (theta * power).cos();
        let sin_phi = (phi * power).sin();
        let cos_phi = (phi * power).cos();
        zx = zr * sin_theta * cos_phi + x;
        zy = zr * sin_theta * sin_phi + y;
        zz = zr * cos_theta + z;
    }
    0.5 * r.ln() * r / dr
}

// render a single frame into an ImageBuffer
fn render_frame(width: u16, height: u16, sentiment: f32, time: f32) -> image::RgbImage {
    let mut img = image::RgbImage::new(width.into(), height.into());
    let palette = sentiment_color(sentiment);
    let power = 8.0 + sentiment * 2.0; // curvature modulation
    for y in 0..height {
        for x in 0..width {
            // map pixel to world space
            let nx = (x as f32 / width as f32 - 0.5) * 4.0;
            let ny = (y as f32 / height as f32 - 0.5) * 4.0;
            let nz = (time.sin() * 0.5) as f32;
            // height value influences brightness
            let h = fractal_height(nx, ny, nz, power);
            let brightness = ((h + 0.5).clamp(0.0, 1.0) * 255.0) as u8;
            // particle density simulated by random speckles
            let mut rng = rand::thread_rng();
            let particle = if rng.gen::<f32>() < sentiment.abs() * 0.05 {
                255
            } else {
                0
            };
            let r = ((palette[0] as f32 * brightness as f32 / 255.0) as u8).saturating_add(particle);
            let g = ((palette[1] as f32 * brightness as f32 / 255.0) as u8);
            let b = ((palette[2] as f32 * brightness as f32 / 255.0) as u8).saturating_add(particle);
            img.put_pixel(x.into(), y.into(), image::Rgb([r, g, b]));
        }
    }
    img
}

// audio capture thread – fills a shared buffer with recent samples
fn start_audio_capture(buffer: Arc<Mutex<Vec<f32>>>) {
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .expect("no input device available");
    let config = device.default_input_config().unwrap();

    let err_fn = |err| eprintln!("Audio error: {}", err);
    let buffer_clone = buffer.clone();

    let stream = match config.sample_format() {
        cpal::SampleFormat::F32 => device.build_input_stream(
            &config.into(),
            move |data: &[f32], _: &_| {
                let mut buf = buffer_clone.lock().unwrap();
                buf.extend_from_slice(data);
                if buf.len() > 48000 {
                    buf.drain(0..buf.len() - 48000);
                }
            },
            err_fn,
            None,
        ),
        cpal::SampleFormat::I16 => device.build_input_stream(
            &config.into(),
            move |data: &[i16], _: &_| {
                let mut buf = buffer_clone.lock().unwrap();
                buf.extend(data.iter().map(|&s| s as f32 / i16::MAX as f32));
                if buf.len() > 48000 {
                    buf.drain(0..buf.len() - 48000);
                }
            },
            err_fn,
            None,
        ),
        cpal::SampleFormat::U16 => device.build_input_stream(
            &config.into(),
            move |data: &[u16], _: &_| {
                let mut buf = buffer_clone.lock().unwrap();
                buf.extend(data.iter().map(|&s| s as f32 / u16::MAX as f32 - 1.0));
                if buf.len() > 48000 {
                    buf.drain(0..buf.len() - 48000);
                }
            },
            err_fn,
            None,
        ),
    }
    .expect("failed to build stream");

    stream.play().unwrap();
    // keep the stream alive
    std::thread::sleep(Duration::from_secs(3600));
}

// main loop – renders frames, builds GIF, and syncs to mock audio rhythm
fn main() {
    // shared audio sample buffer
    let audio_buf = Arc::new(Mutex::new(Vec::<f32>::new()));
    let audio_thread = {
        let buf = audio_buf.clone();
        thread::spawn(move || start_audio_capture(buf))
    };

    // GIF encoder setup
    let mut out = std::fs::File::create("output.gif").expect("cannot create gif");
    let mut encoder = gif::Encoder::new(&mut out, 320, 240, &[]).expect("gif encoder");
    encoder.set_repeat(gif::Repeat::Infinite).unwrap();

    let frame_rate = 30;
    let frame_delay = (100f32 / frame_rate as f32) as u16; // in 1/100 sec

    let start = Instant::now();
    for i in 0..(frame_rate * 10) {
        // obtain recent audio slice
        let samples = {
            let buf = audio_buf.lock().unwrap();
            buf.clone()
        };
        // compute sentiment (placeholder)
        let sentiment = dummy_sentiment(&samples);
        // time parameter for animation
        let t = (i as f32) * (2.0 * PI / frame_rate as f32);
        // render
        let img = render_frame(320, 240, sentiment, t);
        // convert to GIF frame
        let mut frame = gif::Frame::default();
        frame.width = 320;
        frame.height = 240;
        frame.delay = frame_delay;
        // flatten RGB to indexed colour (simple approach)
        let mut indexed = Vec::with_capacity((320 * 240) as usize);
        let palette: Vec<u8> = (0..256).flat_map(|i| vec![i, i, i]).collect();
        for pixel in img.pixels() {
            // naïve nearest palette entry (grayscale)
            indexed.push(pixel[0]);
        }
        frame.buffer = indexed.into();
        frame.palette = Some(palette);
        encoder.write_frame(&frame).expect("write frame");
        // keep real‑time pace
        let elapsed = start.elapsed();
        let target = Duration::from_secs_f32(i as f32 / frame_rate as f32);
        if target > elapsed {
            thread::sleep(target - elapsed);
        }
    }

    // clean up
    drop(encoder);
    // terminate audio thread (in practice you'd signal it)
    audio_thread.thread().unpark();
}