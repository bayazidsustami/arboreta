use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use std::f32::consts::PI;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

/// Configuration for real-time video-to-audio analysis
const FRAME_WIDTH: usize = 32;
const FRAME_HEIGHT: usize = 24;
const NUM_PIXELS: usize = FRAME_WIDTH * FRAME_HEIGHT;
const SAMPLE_RATE: u32 = 44100;
const BASE_FREQ: f32 = 110.0; // A2 pitch anchor

/// State shared between the visual analyzer and the microtonal synth engine
struct ColonyState {
    /// Shannon entropy of spatial pixel intensities (0.0 to 8.0 bits)
    entropy: f32,
    /// Center of mass movement vector representing swarm velocity (dx, dy)
    spectral_motion: (f32, f32),
    /// Frame brightness energy (0.0 to 1.0)
    energy: f32,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let state = Arc::new(Mutex::new(ColonyState {
        entropy: 4.0,
        spectral_motion: (0.0, 0.0),
        energy: 0.5,
    }));

    // Spawn visual perception thread simulating real-time camera processing
    let perception_state = Arc::clone(&state);
    thread::spawn(move || {
        let mut frame_count: u64 = 0;
        let mut prev_frame = vec![0u8; NUM_PIXELS];

        loop {
            let mut current_frame = vec![0u8; NUM_PIXELS];
            let t = frame_count as f32 * 0.05;

            // Generate synthetic living ant feed: high-contrast moving particles
            let mut total_intensity: f32 = 0.0;
            let mut center_x: f32 = 0.0;
            let mut center_y: f32 = 0.0;

            for y in 0..FRAME_HEIGHT {
                for x in 0..FRAME_WIDTH {
                    let idx = y * FRAME_WIDTH + x;
                    let nx = x as f32 / FRAME_WIDTH as f32;
                    let ny = y as f32 / FRAME_HEIGHT as f32;

                    // Organic procedural swarm density field
                    let ant_density = ((nx * 12.0 + t).sin() * (ny * 10.0 - t * 0.7).cos()
                        + ((nx - 0.5).powi(2) + (ny - 0.5).powi(2) * 8.0 - t * 0.3).sin())
                    .max(0.0);

                    let pixel_val = (ant_density * 255.0).clamp(0.0, 255.0) as u8;
                    current_frame[idx] = pixel_val;

                    total_intensity += pixel_val as f32;
                    center_x += x as f32 * pixel_val as f32;
                    center_y += y as f32 * pixel_val as f32;
                }
            }

            // 1. Calculate Shannon Entropy over pixel intensity histogram
            let mut hist = [0u32; 256];
            for &val in &current_frame {
                hist[val as usize] += 1;
            }
            let entropy = hist.iter().fold(0.0, |acc, &count| {
                if count == 0 {
                    acc
                } else {
                    let p = count as f32 / NUM_PIXELS as f32;
                    acc - p * p.log2()
                }
            });

            // 2. Compute Spectral Motion (Center-of-Mass delta between frames)
            let curr_cx = if total_intensity > 0.0 { center_x / total_intensity } else { 0.0 };
            let curr_cy = if total_intensity > 0.0 { center_y / total_intensity } else { 0.0 };

            let mut prev_intensity = 0.0;
            let (mut prev_cx, mut prev_cy) = (0.0, 0.0);
            for y in 0..FRAME_HEIGHT {
                for x in 0..FRAME_WIDTH {
                    let val = prev_frame[y * FRAME_WIDTH + x] as f32;
                    prev_intensity += val;
                    prev_cx += x as f32 * val;
                    prev_cy += y as f32 * val;
                }
            }
            if prev_intensity > 0.0 {
                prev_cx /= prev_intensity;
                prev_cy /= prev_intensity;
            }

            let motion_x = curr_cx - prev_cx;
            let motion_y = curr_cy - prev_cy;
            let energy = (total_intensity / (NUM_PIXELS as f32 * 255.0)).clamp(0.0, 1.0);

            // Update cross-thread shared state
            if let Ok(mut lock) = perception_state.lock() {
                lock.entropy = entropy;
                lock.spectral_motion = (motion_x, motion_y);
                lock.energy = energy;
            }

            prev_frame = current_frame;
            frame_count += 1;
            thread::sleep(Duration::from_millis(33)); // ~30 FPS camera loop
        }
    });

    // Audio Initialization
    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .ok_or("No audio output device found")?;
    let config = device.default_output_config()?;

    // Microtonal additive synthesizer phases
    let mut phase_1 = 0.0f32;
    let mut phase_2 = 0.0f32;
    let mut phase_3 = 0.0f32;
    let mut filter_state = 0.0f32;

    let synth_state = Arc::clone(&state);

    let stream = device.build_output_stream(
        &config.into(),
        move |data: &mut [f32], _| {
            let (entropy, motion, energy) = {
                let lock = synth_state.lock().unwrap();
                (lock.entropy, lock.spectral_motion, lock.energy)
            };

            // Map visual parameters to microtonal interval mathematics (19-TET microtonal scale ratios)
            let microtonal_degree = (entropy * 3.0).floor();
            let step_ratio = 2.0f32.powf(microtonal_degree / 19.0);

            // Map motion vector to continuous frequency glide (portamento modulation)
            let motion_mag = (motion.0 * motion.0 + motion.1 * motion.1).sqrt();
            let target_freq_1 = BASE_FREQ * step_ratio * (1.0 + motion_mag * 0.1);
            let target_freq_2 = target_freq_1 * 1.503; // Microtonal non-standard fifth
            let target_freq_3 = target_freq_1 * 2.718; // Non-harmonic e-ratio partial

            for frame in data.chunks_mut(2) {
                // Oscillator increments
                let step_1 = target_freq_1 * 2.0 * PI / SAMPLE_RATE as f32;
                let step_2 = target_freq_2 * 2.0 * PI / SAMPLE_RATE as f32;
                let step_3 = target_freq_3 * 2.0 * PI / SAMPLE_RATE as f32;

                phase_1 = (phase_1 + step_1) % (2.0 * PI);
                phase_2 = (phase_2 + step_2) % (2.0 * PI);
                phase_3 = (phase_3 + step_3) % (2.0 * PI);

                // Complex additive timbre synthesis
                let sig_1 = phase_1.sin();
                let sig_2 = (phase_2.sin() * 0.5).tanh(); // Sub-harmonics saturation
                let sig_3 = (phase_3.cos() * 0.25) * (entropy / 8.0); // High-frequency shimmer scaled by visual complexity

                let raw_mix = (sig_1 + sig_2 + sig_3) * energy;

                // Dynamic low-pass resonant filter tracking swarm activity
                let cutoff = (0.05 + energy * 0.4).clamp(0.01, 0.99);
                filter_state += cutoff * (raw_mix - filter_state);

                let output = filter_state * 0.3; // Master output scaling

                frame[0] = output; // Left channel
                frame[1] = output; // Right channel
            }
        },
        move |err| eprintln!("Audio stream error: {}", err),
        None,
    )?;

    stream.play()?;

    println!("Ant Colony Visual Entropy Synthesizer online.");
    println!("Generating microtonal soundscape. Press Ctrl+C to exit.");

    thread::park(); // Keep main thread alive while streaming audio
    Ok(())
}