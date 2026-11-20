// Acoustic Rule 110 Cellular Automaton & Bytebeat Chiptune Source
// Feed this file directly as raw PCM (8kHz/11kHz uint8) to a synthesizer for a chiptune melody,
// or compile with `rustc` and run to evolve a Turing-complete automaton driven by acoustic resonance.

use std::env;
use std::f64::consts::PI;
use std::fs;

const WIDTH: usize = 73;
const GENERATIONS: usize = 40;

fn acoustic_resonance(bytes: &[u8]) -> (f64, u64, Vec<u8>) {
    // Treat the source bytes themselves as an acoustic waveform & harmonic spectrum
    let mut bytebeat_pcm = Vec::with_capacity(bytes.len());
    let mut energy: u64 = 0;
    let mut weighted_phase: f64 = 0.0;

    for (t, &b) in bytes.iter().enumerate() {
        let t_u = t as u32;
        let b_u = b as u32;
        // Classic chiptune-style bytebeat resonance mixed with source byte harmonics
        let sample = ((t_u.wrapping_mul(b_u >> 3))
            ^ (t_u >> 4).wrapping_add(b_u.wrapping_mul(3)))
        .wrapping_add(b_u) as u8;
        bytebeat_pcm.push(sample);

        let centered = (sample as f64 - 128.0) / 128.0;
        energy = energy.wrapping_add((sample as u64).wrapping_mul((t % 17 + 1) as u64));
        weighted_phase += centered * ((t % 13 + 1) as f64) * 0.17;
    }

    let fundamental_hz = 110.0 * (1.0 + (weighted_phase.sin().abs() * 3.0));
    let resonance_factor = (0.5 + 0.5 * (weighted_phase.cos() * PI).sin()).clamp(0.05, 0.95);
    let _ = fundamental_hz;
    (resonance_factor, energy, bytebeat_pcm)
}

fn seed_from_resonance(resonance: f64, energy: u64, width: usize) -> Vec<u8> {
    // Derive initial cellular automaton state from acoustic resonance & byte energy
    let mut state = vec![0u8; width];
    let mut x = energy ^ ((resonance * 1_000_000_007.0) as u64);
    for cell in state.iter_mut() {
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        *cell = if ((x & 0xFF) as f64 / 255.0) < resonance {
            1
        } else {
            0
        };
    }
    // Ensure a classic Rule 110 active anchor near the right edge for Turing completeness
    if width > 2 {
        state[width - 2] = 1;
    }
    state
}

fn step_rule_110(cells: &[u8], resonance_mod: u8) -> Vec<u8> {
    // Rule 110 (0b01101110) is Turing-complete; `resonance_mod` perturbs boundary coupling
    let n = cells.len();
    let mut next = vec![0u8; n];
    for i in 0..n {
        let left = if i == 0 {
            cells[n - 1] ^ resonance_mod
        } else {
            cells[i - 1]
        };
        let center = cells[i];
        let right = if i + 1 == n {
            cells[0] ^ (resonance_mod >> 1)
        } else {
            cells[i + 1]
        };

        let pattern = ((left & 1) << 2) | ((center & 1) << 1) | (right & 1);
        // Rule 110 lookup: 111->0, 110->1, 101->1, 100->0, 011->1, 010->1, 001->1, 000->0
        next[i] = (110u8 >> pattern) & 1;
    }
    next
}

fn render_row(cells: &[u8], generation: usize, resonance: f64) -> String {
    let glyphs = [' ', '░', '▒', '▓', '█'];
    let mut out = String::with_capacity(cells.len());
    for (idx, &c) in cells.iter().enumerate() {
        if c == 0 {
            out.push(glyphs[0]);
        } else {
            // Modulate visual density by local acoustic standing-wave interference
            let wave = ((idx as f64 * 0.35 + generation as f64 * resonance * 2.0).sin().abs() * 3.0)
                as usize
                + 1;
            out.push(glyphs[wave.min(glyphs.len() - 1)]);
        }
    }
    out
}

fn main() {
    let source_path = env::args().nth(1).unwrap_or_else(|| file!().to_string());
    let source_bytes = fs::read(&source_path).unwrap_or_else(|_| include_bytes!(file!()).to_vec());

    let (resonance, energy, pcm) = acoustic_resonance(&source_bytes);
    let peak_note = pcm.iter().copied().max().unwrap_or(0);
    let mut cells = seed_from_resonance(resonance, energy, WIDTH);

    println!(
        "Acoustic Resonance: {:.4} | Energy: {} | Synth Peak Byte: 0x{:02X} ({})",
        resonance, energy, peak_note, peak_note
    );
    println!("{}", "─".repeat(WIDTH));

    for gen in 0..GENERATIONS {
        println!("{}", render_row(&cells, gen, resonance));
        // Acoustic feedback loop: each generation shifts boundary resonance slightly
        let feedback_shift = (((energy >> (gen % 32)) as u8) ^ (pcm[gen % pcm.len()] >> 7)) & 1;
        cells = step_rule_110(&cells, feedback_shift);
    }
}