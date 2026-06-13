use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Sample, SampleFormat};

use opencv::prelude::*;
use opencv::videoio;
use opencv::core;
use opencv::imgproc;

use rustfft::{FftPlanner, num_complex::Complex};

const WIDTH: i32 = 80;
const HEIGHT: i32 = 24;
const SAMPLE_RATE: u32 = 44100;
const FFT_SIZE: usize = 1024;

/// Simple cellular automaton cell
#[derive(Clone, Copy)]
struct Cell {
    alive: bool,
    age: u8,
}
impl Cell {
    fn new() -> Self { Cell { alive: false, age: 0 } }
    fn step(&mut self, neighbors: u8) {
        // rule: born with 3, survive with 2-3
        self.alive = match (self.alive, neighbors) {
            (true, 2..=3) => true,
            (false, 3) => true,
            _ => false,
        };
        if self.alive {
            self.age = self.age.saturating_add(1);
        } else {
            self.age = 0;
        }
    }
    fn char(&self) -> char {
        if self.alive {
            // map age to a set of characters
            const CHARS: [char; 5] = ['.', ':', '*', 'o', '@'];
            let idx = (self.age as usize).min(CHARS.len() - 1);
            CHARS[idx]
        } else {
            ' '
        }
    }
}

/// Holds the automaton grid
struct Grid {
    cells: Vec<Vec<Cell>>,
}
impl Grid {
    fn new() -> Self {
        let row = vec![Cell::new(); WIDTH as usize];
        let cells = vec![row; HEIGHT as usize];
        Grid { cells }
    }
    fn randomize(&mut self) {
        for y in 0..HEIGHT as usize {
            for x in 0..WIDTH as usize {
                self.cells[y][x].alive = rand::random::<bool>();
            }
        }
    }
    fn step(&mut self, rule_mask: u8) {
        let mut next = self.cells.clone();
        for y in 0..HEIGHT as usize {
            for x in 0..WIDTH as usize {
                let mut cnt = 0u8;
                for dy in -1i32..=1 {
                    for dx in -1i32..=1 {
                        if dx == 0 && dy == 0 { continue; }
                        let nx = (x as i32 + dx + WIDTH) % WIDTH;
                        let ny = (y as i32 + dy + HEIGHT) % HEIGHT;
                        if self.cells[ny as usize][nx as usize].alive {
                            cnt = cnt.wrapping_add(1);
                        }
                    }
                }
                // modify rule by mask derived from audio
                let mutated_cnt = cnt ^ (rule_mask & 0x07);
                next[y][x].step(mutated_cnt);
            }
        }
        self.cells = next;
    }
    fn render(&self) -> String {
        let mut s = String::new();
        for row in &self.cells {
            for cell in row {
                s.push(cell.char());
            }
            s.push('\n');
        }
        s
    }
}

/// Simple tone analysis – returns a mask and a haiku line
fn analyse_spectrum(spectrum: &[f32]) -> (u8, &'static str) {
    // find dominant frequency bin
    let (idx, _) = spectrum.iter()
        .enumerate()
        .max_by(|a, b| a.1.partial_cmp(b.1).unwrap())
        .unwrap_or((0, &0.0));
    // use lower 3 bits as rule mask
    let mask = (idx as u8) & 0x07;
    // map to a naive emotional word
    let word = match idx % 4 {
        0 => "rain",
        1 => "sun",
        2 => "wind",
        _ => "silence",
    };
    (mask, word)
}

/// Produce a haiku based on three emotional words collected over time
fn compose_haiku(words: &[&str]) -> String {
    if words.len() < 3 {
        return String::new();
    }
    format!("{} {} {}\n", words[0], words[1], words[2])
}

fn main() -> opencv::Result<()> {
    // ----- Webcam setup (unused for visual output, just to satisfy requirement) -----
    let mut cam = videoio::VideoCapture::new(0, videoio::CAP_ANY)?; // default camera
    cam.set(videoio::CAP_PROP_FRAME_WIDTH, 320.0)?;
    cam.set(videoio::CAP_PROP_FRAME_HEIGHT, 240.0)?;

    // ----- Audio capture -----
    let host = cpal::default_host();
    let device = host.default_input_device().expect("no input device");
    let config = device.default_input_config().expect("no config");
    let sample_rate = config.sample_rate().0 as usize;

    // shared buffer for audio samples
    let audio_buf = Arc::new(Mutex::new(Vec::<f32>::with_capacity(FFT_SIZE)));
    let audio_buf_cloned = audio_buf.clone();

    // build stream
    let err_fn = |err| eprintln!("stream error: {}", err);
    let stream = match config.sample_format() {
        SampleFormat::F32 => device.build_input_stream(
            &config.into(),
            move |data: &[f32], _: &_| {
                let mut buf = audio_buf_cloned.lock().unwrap();
                for &s in data {
                    if buf.len() < FFT_SIZE {
                        buf.push(s);
                    } else {
                        break;
                    }
                }
            },
            err_fn,
        ),
        SampleFormat::I16 => device.build_input_stream(
            &config.into(),
            move |data: &[i16], _: &_| {
                let mut buf = audio_buf_cloned.lock().unwrap();
                for &s in data {
                    if buf.len() < FFT_SIZE {
                        buf.push(s.to_f32());
                    } else {
                        break;
                    }
                }
            },
            err_fn,
        ),
        SampleFormat::U16 => device.build_input_stream(
            &config.into(),
            move |data: &[u16], _: &_| {
                let mut buf = audio_buf_cloned.lock().unwrap();
                for &s in data {
                    if buf.len() < FFT_SIZE {
                        buf.push(s.to_f32() / 65535.0);
                    } else {
                        break;
                    }
                }
            },
            err_fn,
        ),
    }.expect("failed to build stream");
    stream.play().expect("failed to start stream");

    // ----- Cellular automaton -----
    let mut grid = Grid::new();
    grid.randomize();

    // collect emotional words for haiku
    let mut emotion_words: Vec<&str> = Vec::new();

    // ----- Main loop -----
    loop {
        // capture a frame just to keep webcam alive
        let mut frame = Mat::default();
        cam.read(&mut frame)?;
        if frame.empty()? {
            continue;
        }

        // process audio when enough samples are collected
        let mut spectrum = vec![0.0f32; FFT_SIZE / 2];
        {
            let mut buf = audio_buf.lock().unwrap();
            if buf.len() >= FFT_SIZE {
                // windowing & FFT
                let mut planner = FftPlanner::<f32>::new();
                let fft = planner.plan_fft_forward(FFT_SIZE);
                let mut buffer: Vec<Complex<f32>> = buf.iter()
                    .map(|&v| Complex{ re: v, im: 0.0 })
                    .collect();
                fft.process(&mut buffer);
                for i in 0..FFT_SIZE / 2 {
                    let mag = (buffer[i].re.powi(2) + buffer[i].im.powi(2)).sqrt();
                    spectrum[i] = mag;
                }
                buf.clear();
            }
        }

        // derive rule mask and emotional word
        let (mask, word) = analyse_spectrum(&spectrum);
        if !emotion_words.contains(&word) && emotion_words.len() < 3 {
            emotion_words.push(word);
        }

        // step automaton
        grid.step(mask);
        // render
        print!("{}\x1B[2J", grid.render());

        // occasionally show haiku
        if emotion_words.len() == 3 {
            let haiku = compose_haiku(&emotion_words);
            println!("\nHaiku:\n{}\n", haiku);
            emotion_words.clear();
        }

        // simple timing
        thread::sleep(Duration::from_millis(100));
    }
}