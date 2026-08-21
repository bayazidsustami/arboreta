// Self-Synthesizing Operational State Audio Engine
// Dependencies: `cpal` for cross-platform audio output.
// Run with: `cargo run`

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{SampleFormat, StreamConfig};
use std::env;
use std::fs;
use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

#[cfg(target_os = "linux")]
fn get_memory_footprint() -> u64 {
    fs::read_to_string("/proc/self/statm")
        .ok()
        .and_then(|s| s.split_whitespace().next()?.parse::<u64>().ok())
        .map(|pages| pages * 4096)
        .unwrap_or(10_000_000)
}

#[cfg(not(target_os = "linux"))]
fn get_memory_footprint() -> u64 {
    // Basic fallback simulation for non-Linux platforms
    use std::alloc::{alloc, Layout};
    let l = Layout::from_size_align(1024, 8).unwrap();
    let ptr = unsafe { alloc(l) };
    let addr = ptr as u64;
    unsafe { std::alloc::dealloc(ptr, l) };
    (addr % 10_000_000) + 5_000_000
}

struct Synthesizer {
    binary_size: Arc<AtomicU64>,
    memory_footprint: Arc<AtomicU64>,
    phase_sub: f32,
    phase_mid: f32,
    phase_high: f32,
    lfo_phase: f32,
}

impl Synthesizer {
    fn new(binary_size: Arc<AtomicU64>, memory_footprint: Arc<AtomicU64>) -> Self {
        Self {
            binary_size,
            memory_footprint,
            phase_sub: 0.0,
            phase_mid: 0.0,
            phase_high: 0.0,
            lfo_phase: 0.0,
        }
    }

    fn next_sample(&mut self, sample_rate: f32) -> f32 {
        let bin_size = self.binary_size.load(Ordering::Relaxed) as f32;
        let mem_size = self.memory_footprint.load(Ordering::Relaxed) as f32;

        // Map binary size and memory footprint into musical frequency bands
        let base_freq = 55.0 + (bin_size % 110.0); // Sub-bass drone (A1 range)
        let mid_freq = 220.0 + (mem_size / 1024.0) % 440.0; // Mid harmonic texture
        let high_freq = mid_freq * 1.5; // Harmonic fifth above mid

        // Slow LFO driven by dynamic state ratios
        let lfo_rate = 0.1 + ((mem_size / (bin_size + 1.0)) % 2.0);
        self.lfo_phase += (2.0 * std::f32::consts::PI * lfo_rate) / sample_rate;
        if self.lfo_phase > 2.0 * std::f32::consts::PI {
            self.lfo_phase -= 2.0 * std::f32::consts::PI;
        }
        let lfo = (self.lfo_phase.sin() + 1.0) * 0.5;

        // Advance phases
        self.phase_sub += (2.0 * std::f32::consts::PI * base_freq) / sample_rate;
        self.phase_mid += (2.0 * std::f32::consts::PI * (mid_freq + lfo * 5.0)) / sample_rate;
        self.phase_high += (2.0 * std::f32::consts::PI * high_freq) / sample_rate;

        // Keep phases bounded
        if self.phase_sub > 2.0 * std::f32::consts::PI { self.phase_sub -= 2.0 * std::f32::consts::PI; }
        if self.phase_mid > 2.0 * std::f32::consts::PI { self.phase_mid -= 2.0 * std::f32::consts::PI; }
        if self.phase_high > 2.0 * std::f32::consts::PI { self.phase_high -= 2.0 * std::f32::consts::PI; }

        // Generate layered atmospheric voices
        let sub = self.phase_sub.sin() * 0.4;
        let mid = (self.phase_mid.sin() + 0.5 * (self.phase_mid * 2.0).sin()) * 0.25;
        let high = (self.phase_high.sin() * lfo) * 0.15;

        // Soft limit output
        (sub + mid + high).tanh()
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Read binary executable size
    let exe_path = env::current_exe()?;
    let exe_size = fs::metadata(&exe_path)?.len();

    let binary_size = Arc::new(AtomicU64::new(exe_size));
    let memory_footprint = Arc::new(AtomicU64::new(get_memory_footprint()));

    // Background thread continuously monitoring operational memory footprint
    let mem_clone = Arc::clone(&memory_footprint);
    thread::spawn(move || loop {
        let current_mem = get_memory_footprint();
        mem_clone.store(current_mem, Ordering::Relaxed);
        thread::sleep(Duration::from_millis(50));
    });

    // 2. Initialize Audio Stream via CPAL
    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .ok_or("No audio output device found")?;
    let config = device.default_output_config()?;

    let sample_rate = config.sample_rate().0 as f32;
    let channels = config.channels() as usize;

    let mut synth = Synthesizer::new(binary_size, memory_footprint);

    let stream = match config.sample_format() {
        SampleFormat::F32 => device.build_output_stream(
            &config.into(),
            move |data: &mut [f32], _: &cpal::OutputCallbackInfo| {
                for frame in data.chunks_mut(channels) {
                    let s = synth.next_sample(sample_rate);
                    for sample in frame.iter_mut() {
                        *sample = s;
                    }
                }
            },
            |err| eprintln!("Audio stream error: {}", err),
            None,
        )?,
        _ => return Err("Unsupported sample format".into()),
    };

    stream.play()?;

    println!("Synthesizing operational state landscape... Press Ctrl+C to stop.");
    loop {
        thread::sleep(Duration::from_secs(1));
    }
}