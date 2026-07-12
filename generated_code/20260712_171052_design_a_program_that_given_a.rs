use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Sample, SampleFormat};
use rustfft::{FftPlanner, num_complex::Complex};
use image::{RgbImage, Rgb};
use gif::{Encoder, Frame, Repeat, SetParameter};

const SAMPLE_RATE: u32 = 44_100;
const FRAME_RATE: u32 = 10;
const WIDTH: u32 = 320;
const HEIGHT: u32 = 240;
const ASCII_DIM: usize = 80;

fn main() {
    // shared audio buffer (mono)
    let audio_buf = Arc::new(Mutex::new(Vec::<f32>::new()));
    // start microphone capture
    start_input(audio_buf.clone());

    // GIF encoder (writes to file on drop)
    let mut gif_file = std::fs::File::create("mandala.gif").unwrap();
    let mut encoder = Encoder::new(&mut gif_file, WIDTH as u8, HEIGHT as u8, &[]).unwrap();
    encoder.set(Repeat::Infinite).unwrap();

    // time loop producing frames
    let frame_dur = Duration::from_millis(1000 / FRAME_RATE as u64);
    let start = Instant::now();
    loop {
        let now = Instant::now();
        // retrieve a copy of recent audio
        let audio = {
            let mut lock = audio_buf.lock().unwrap();
            let copy = lock.clone();
            lock.clear();
            copy
        };
        // analyse audio -> parameters
        let (bass, mid, high) = analyse(&audio);
        // generate ASCII mandala
        let ascii = generate_ascii(bass, mid, high);
        // render to image
        let img = render_ascii(&ascii);
        // push frame to GIF
        let mut frame = Frame::from_rgba_speed(WIDTH as u16, HEIGHT as u16, &mut img.into_raw(), 10);
        frame.delay = (FRAME_RATE as u16) as u16; // 1/100 sec units; approximate
        encoder.write_frame(&frame).unwrap();

        // sleep until next frame
        let elapsed = now.elapsed();
        if elapsed < frame_dur {
            thread::sleep(frame_dur - elapsed);
        }

        // stop after 30 seconds for demo
        if start.elapsed() > Duration::from_secs(30) {
            break;
        }
    }
}

// start microphone input thread, filling shared buffer
fn start_input(buf: Arc<Mutex<Vec<f32>>>) {
    let host = cpal::default_host();
    let device = host.default_input_device().expect("no input device");
    let config = device.default_input_config().unwrap();

    let err_fn = |err| eprintln!("stream error: {}", err);
    match config.sample_format() {
        SampleFormat::F32 => run_stream::<f32>(&device, &config.into(), buf, err_fn),
        SampleFormat::I16 => run_stream::<i16>(&device, &config.into(), buf, err_fn),
        SampleFormat::U16 => run_stream::<u16>(&device, &config.into(), buf, err_fn),
    };
}

// generic stream runner
fn run_stream<T>(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    buf: Arc<Mutex<Vec<f32>>>,
    err_fn: fn(cpal::StreamError),
) where
    T: Sample,
{
    let channels = config.channels as usize;
    let stream = device
        .build_input_stream(
            config,
            move |data: &[T], _: &cpal::InputCallbackInfo| {
                let mut lock = buf.lock().unwrap();
                for frame in data.chunks(channels) {
                    // take first channel, convert to f32
                    lock.push(frame[0].to_f32());
                }
            },
            err_fn,
        )
        .unwrap();
    stream.play().unwrap();
    // keep stream alive
    thread::spawn(move || {
        loop {
            thread::park();
        }
    });
}

// simple spectral analysis returning three band energies
fn analyse(samples: &[f32]) -> (f32, f32, f32) {
    if samples.is_empty() {
        return (0.0, 0.0, 0.0);
    }
    // pad to power of two
    let n = samples.len().next_power_of_two();
    let mut input: Vec<Complex<f32>> = samples.iter().cloned().take(n).map(|s| Complex{ re: s, im: 0.0 }).collect();
    input.resize(n, Complex{ re: 0.0, im: 0.0 });

    let mut planner = FftPlanner::new();
    let fft = planner.plan_fft_forward(n);
    fft.process(&mut input);

    // magnitude spectrum
    let mags: Vec<f32> = input.iter().map(|c| (c.re * c.re + c.im * c.im).sqrt()).collect();

    // split into three bands
    let len = mags.len() / 2; // ignore mirrored half
    let bass = mags[0..len/3].iter().copied().sum::<f32>() / (len/3) as f32;
    let mid = mags[len/3..2*len/3].iter().copied().sum::<f32>() / (len/3) as f32;
    let high = mags[2*len/3..len].iter().copied().sum::<f32>() / (len/3) as f32;
    (bass, mid, high)
}

// generate an ASCII mandala string based on parameters
fn generate_ascii(bass: f32, mid: f32, high: f32) -> Vec<String> {
    let mut rows = Vec::new();
    let radius = (ASCII_DIM as f32 / 2.0 * (1.0 + bass * 0.5)).min(ASCII_DIM as f32 / 2.0);
    let chars = ['.', '-', '=', '*', '#', '@'];
    for y in 0..ASCII_DIM {
        let mut line = String::new();
        for x in 0..ASCII_DIM {
            let dx = x as f32 - ASCII_DIM as f32 / 2.0;
            let dy = y as f32 - ASCII_DIM as f32 / 2.0;
            let dist = (dx*dx + dy*dy).sqrt();
            let angle = dy.atan2(dx) + high * std::f32::consts::PI;
            // pattern based on polar coordinates, modulated by mid
            let val = ((dist / radius) + angle * 3.0 * (1.0 + mid)).sin();
            let idx = ((val + 1.0) / 2.0 * (chars.len() - 1) as f32).round() as usize;
            line.push(chars[idx]);
        }
        rows.push(line);
    }
    rows
}

// render ASCII rows onto an image (simple monospaced font approximation)
fn render_ascii(lines: &[String]) -> RgbImage {
    let mut img = RgbImage::new(WIDTH, HEIGHT);
    let char_w = WIDTH as f32 / ASCII_DIM as f32;
    let char_h = HEIGHT as f32 / ASCII_DIM as f32;
    // map characters to brightness
    let brightness = |c: char| -> u8 {
        match c {
            '.' => 30,
            '-' => 60,
            '=' => 120,
            '*' => 180,
            '#' => 220,
            '@' => 255,
            _ => 0,
        }
    };
    for (row_idx, line) in lines.iter().enumerate() {
        for (col_idx, ch) in line.chars().enumerate() {
            let b = brightness(ch);
            let x0 = (col_idx as f32 * char_w) as u32;
            let y0 = (row_idx as f32 * char_h) as u32;
            for y in y0..(y0 + char_h as u32).min(HEIGHT) {
                for x in x0..(x0 + char_w as u32).min(WIDTH) {
                    img.put_pixel(x, y, Rgb([b, b, b]));
                }
            }
        }
    }
    img
}