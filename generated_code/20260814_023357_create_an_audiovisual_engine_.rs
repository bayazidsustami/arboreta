// Audio-Visual Memory & Stack Spectrum Engine
//
// Translates real-time memory allocations and stack trace dynamics into:
// 1. Ambient pentatonic harmonic synthesis (Raw PCM S16LE audio stream).
// 2. Dynamic 24-bit ANSI color spectrum visualizer rendered to stderr.
//
// Usage:
//   cargo run | aplay -f S16_LE -r 44100 -c 1 (Linux/ALSA)
//   cargo run | ffplay -f s16le -ar 44100 -ac 1 -i pipe:0 (Cross-platform)

use std::alloc::{GlobalAlloc, Layout, System};
use std::backtrace::Backtrace;
use std::io::{self, Write};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

// -----------------------------------------------------------------------------
// 1. Memory Tracker Allocator
// -----------------------------------------------------------------------------

struct MonitoredAlloc;

static ALLOCATED_BYTES: AtomicUsize = AtomicUsize::new(0);
static ALLOC_COUNT: AtomicUsize = AtomicUsize::new(0);
static LAST_ALLOC_SIZE: AtomicUsize = AtomicUsize::new(0);

unsafe impl GlobalAlloc for MonitoredAlloc {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let ptr = System.alloc(layout);
        if !ptr.is_null() {
            ALLOCATED_BYTES.fetch_add(layout.size(), Ordering::Relaxed);
            ALLOC_COUNT.fetch_add(1, Ordering::Relaxed);
            LAST_ALLOC_SIZE.store(layout.size(), Ordering::Relaxed);
        }
        ptr
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        System.dealloc(ptr, layout);
        ALLOCATED_BYTES.fetch_sub(layout.size(), Ordering::Relaxed);
    }
}

#[global_allocator]
static A: MonitoredAlloc = MonitoredAlloc;

// Simple LCG pseudo-random generator to remain self-contained
static SEED: AtomicUsize = AtomicUsize::new(1337);
fn fast_rand() -> usize {
    let mut current = SEED.load(Ordering::Relaxed);
    current = current.wrapping_mul(1103515245).wrapping_add(12345);
    SEED.store(current, Ordering::Relaxed);
    current
}

// -----------------------------------------------------------------------------
// 2. Workload Generator (Simulates evolving execution stack & dynamic memory)
// -----------------------------------------------------------------------------

fn recursive_memory_workload(depth: usize, max_depth: usize) {
    if depth >= max_depth {
        let size = (fast_rand() % 8192) + 128;
        let dynamic_buffer: Vec<u8> = vec![0u8; size];
        thread::sleep(Duration::from_millis((size % 30 + 10) as u64));
        drop(dynamic_buffer);
        return;
    }

    // Allocate on stack trace path
    let _stack_heap_node = Box::new([depth as u8; 64]);
    recursive_memory_workload(depth + 1, max_depth);
}

// -----------------------------------------------------------------------------
// 3. Audio Synth & Color Spectrum Synthesizer
// -----------------------------------------------------------------------------

// Pentatonic Scale Frequencies (A Minor Pentatonic across octaves)
const SCALE: [f32; 10] = [
    110.00, 130.81, 146.83, 164.81, 196.00, // Octave 2
    220.00, 261.63, 293.66, 329.63, 392.00, // Octave 3
];

fn hsv_to_rgb(h: f32, s: f32, v: f32) -> (u8, u8, u8) {
    let c = v * s;
    let x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
    let m = v - c;

    let (r, g, b) = match h as u32 {
        0..=59 => (c, x, 0.0),
        60..=119 => (x, c, 0.0),
        120..=179 => (0.0, c, x),
        180..=239 => (0.0, x, c),
        240..=299 => (x, 0.0, c),
        _ => (c, 0.0, x),
    };

    (
        ((r + m) * 255.0) as u8,
        ((g + m) * 255.0) as u8,
        ((b + m) * 255.0) as u8,
    )
}

fn main() {
    // Hide cursor & clear terminal
    eprint!("\x1b[?25l\x1b[2J");

    // Spawn background workload thread
    thread::spawn(|| loop {
        let target_depth = (fast_rand() % 12) + 2;
        recursive_memory_workload(0, target_depth);
        thread::sleep(Duration::from_millis(50));
    });

    let sample_rate = 44100.0;
    let mut phase: f32 = 0.0;
    let mut stderr = io::stderr();
    let mut stdout = io::stdout();

    let start_time = Instant::now();
    let mut frame_count: u64 = 0;

    loop {
        // Capture live heap telemetry & stack trace depth
        let active_bytes = ALLOCATED_BYTES.load(Ordering::Relaxed);
        let alloc_ops = ALLOC_COUNT.load(Ordering::Relaxed);
        let last_size = LAST_ALLOC_SIZE.load(Ordering::Relaxed);

        // Capture stack trace depth safely
        let backtrace = Backtrace::capture();
        let stack_depth = format!("{:?}", backtrace)
            .lines()
            .count()
            .max(1);

        // ---------------------------------------------------------------------
        // Audio Engine: Generate Harmonic Ambient Waveform
        // ---------------------------------------------------------------------
        // Map allocation size to fundamental scale pitch
        let pitch_idx = (last_size % SCALE.len()) as usize;
        let base_freq = SCALE[pitch_idx];

        // Map stack depth to ambient overtone modulation
        let overtone_mod = (stack_depth as f32 * 0.15).sin().abs();
        let target_freq = base_freq * (1.0 + overtone_mod * 0.5);

        // Generate 1/30th second worth of PCM audio samples
        let buffer_samples = (sample_rate / 30.0) as usize;
        let mut audio_buffer = Vec::with_capacity(buffer_samples * 2);

        for _ in 0..buffer_samples {
            phase += 2.0 * std::f32::consts::PI * target_freq / sample_rate;
            if phase > 2.0 * std::f32::consts::PI {
                phase -= 2.0 * std::f32::consts::PI;
            }

            // Synthesize primary sine + warm sub-harmonic + gentle shimmer
            let sample_val = (phase.sin() * 0.6
                + (phase * 0.5).sin() * 0.3
                + (phase * 2.01).sin() * 0.1)
                * 0.25;

            let pcm_sample = (sample_val * i16::MAX as f32) as i16;
            audio_buffer.extend_from_slice(&pcm_sample.to_le_bytes());
        }

        // Output raw PCM stream to stdout
        let _ = stdout.write_all(&audio_buffer);
        let _ = stdout.flush();

        // ---------------------------------------------------------------------
        // Visual Engine: Render Dynamic Color Spectrum Terminal Display
        // ---------------------------------------------------------------------
        let elapsed = start_time.elapsed().as_secs_f32();
        
        // Compute Spectrum Color Attributes
        let hue = ((active_bytes as f32 * 0.01 + elapsed * 40.0) % 360.0).abs();
        let saturation = ((stack_depth as f32 * 0.08).min(1.0)).max(0.4);
        let value = ((alloc_ops as f32 * 0.005).sin().abs() * 0.5 + 0.5).clamp(0.2, 1.0);

        let (r, g, b) = hsv_to_rgb(hue, saturation, value);

        // Build Visual Equalizer Bar
        let bar_len = ((last_size % 40) + 10) as usize;
        let bar_str = "█".repeat(bar_len);

        // Render Dashboard Frame to stderr
        eprint!(
            "\x1b[H\x1b[K\n\x1b[1;37m --- AUDIO-VISUAL MEMORY & STACK SPECTRUM --- \x1b[0m\n\n"
        );
        eprint!(
            "\x1b[K Memory Allocations : {:>8} KB | Total Alloc Ops: {}\n",
            active_bytes / 1024,
            alloc_ops
        );
        eprint!(
            "\x1b[K Stack Trace Depth : {:>8} frames | Synth Freq    : {:.2} Hz\n\n",
            stack_depth, target_freq
        );

        // Render Color Spectrum Visualizer Waves
        eprint!("\x1b[K Color Spectrum Vector:\n");
        for row in 0..6 {
            let row_hue = (hue + row as f32 * 25.0) % 360.0;
            let (rr, gg, bb) = hsv_to_rgb(row_hue, saturation, value);
            eprint!(
                "\x1b[48;2;{};{};{}m\x1b[38;2;255;255;255m {:<40} \x1b[0m\n",
                rr, gg, bb, if row == 2 { &bar_str } else { "" }
            );
        }

        eprint!(
            "\n\x1b[K \x1b[38;2;{};{};{}m● Harmonized Audio/Visual Pulse Active [{}]\x1b[0m\n",
            r, g, b, frame_count
        );
        let _ = stderr.flush();

        frame_count += 1;
        thread::sleep(Duration::from_millis(20));
    }
}