// Shell History Microtonal Ambient Synthesizer
// Parses terminal command history into microtonal frequencies to generate a WAV audio composition.
// Synthesizes ambient microtonal chords for standard commands and dramatic percussion crashes for failed commands.

use std::collections::hash_map::DefaultHasher;
use std::env;
use std::fs::{self, File};
use std::hash::{Hash, Hasher};
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;

/// Represents a command translated into musical attributes.
struct CommandEvent {
    command: String,
    frequency: f32, // Microtonal fundamental pitch in Hz
    duration: f32,  // Duration in seconds
    is_failure: bool,
}

/// Pseudo-random number generator for synthesizing white noise in percussion crashes.
struct NoiseGen {
    state: u32,
}

impl NoiseGen {
    fn new(seed: u32) -> Self {
        Self {
            state: if seed == 0 { 0xACE1 } else { seed },
        }
    }

    fn next_float(&mut self) -> f32 {
        self.state ^= self.state << 13;
        self.state ^= self.state >> 17;
        self.state ^= self.state << 5;
        (self.state as f32 / u32::MAX as f32) * 2.0 - 1.0
    }
}

fn main() {
    println!("--- Parsing Shell History into Ambient Microtonal Score ---");
    let events = load_shell_history();

    println!("Loaded {} history events. Rendering composition...", events.len());
    for (i, ev) in events.iter().enumerate().take(12) {
        let status = if ev.is_failure { "CRASH (Failed Command)" } else { "Harmonic Pad (Success)" };
        println!(" [{:02}] {:<30} | {:6.1} Hz | {}", i + 1, ev.command, ev.frequency, status);
    }
    if events.len() > 12 {
        println!(" ... and {} additional commands.", events.len() - 12);
    }

    let output_file = "shell_ambient_composition.wav";
    match render_audio_wav(&events, output_file) {
        Ok(()) => println!("\nComposition generated successfully: '{}'", output_file),
        Err(err) => eprintln!("Error generating audio: {}", err),
    }
}

/// Locates standard history files (~/.zsh_history, ~/.bash_history).
/// Uses a built-in history sample if no history file is found.
fn load_shell_history() -> Vec<CommandEvent> {
    let mut raw_lines = Vec::new();

    if let Some(home) = env::var_os("HOME").map(PathBuf::from) {
        let history_paths = vec![
            home.join(".zsh_history"),
            home.join(".bash_history"),
            home.join(".history"),
        ];

        for path in history_paths {
            if path.exists() {
                if let Ok(file) = File::open(path) {
                    let reader = BufReader::new(file);
                    for line in reader.lines().flatten() {
                        if !line.trim().is_empty() {
                            raw_lines.push(line);
                        }
                    }
                    if !raw_lines.is_empty() {
                        break;
                    }
                }
            }
        }
    }

    // Fallback demonstration history with mixed success and failed commands
    if raw_lines.is_empty() {
        raw_lines = vec![
            "git status".into(),
            ": 1600000000:1;gti statos".into(),
            "cargo check --release".into(),
            ": 1600000000:127;unknown_command --flag".into(),
            "vim src/main.rs".into(),
            "cd .. && ls -la".into(),
            ": 1600000000:1;python3 broken_script.py".into(),
            "docker run hello-world".into(),
            ": 1600000000:2;make build".into(),
            "curl -I [https://example.com](https://example.com)".into(),
            "echo 'Composition complete'".into(),
        ];
    }

    let recent_lines: Vec<_> = raw_lines.into_iter().rev().take(35).collect();
    recent_lines.into_iter().rev().map(|line| parse_command(&line)).collect()
}

/// Parses command strings and metadata (e.g. zsh timestamp/exit code) into pitch and status.
fn parse_command(line: &str) -> CommandEvent {
    let mut is_failure = false;
    let clean_cmd: String;

    // Zsh extended history format: `: timestamp:exit_code;command`
    if line.starts_with(':') {
        if let Some(semicolon_idx) = line.find(';') {
            let metadata = &line[1..semicolon_idx];
            clean_cmd = line[semicolon_idx + 1..].trim().to_string();

            if let Some(colon_idx) = metadata.find(':') {
                if let Ok(exit_code) = metadata[colon_idx + 1..].trim().parse::<i32>() {
                    if exit_code != 0 {
                        is_failure = true;
                    }
                }
            }
        } else {
            clean_cmd = line.to_string();
        }
    } else {
        clean_cmd = line.trim().to_string();
    }

    // Heuristics for non-zero exit indicators or typos
    if !is_failure {
        let lower = clean_cmd.to_lowercase();
        if lower.contains("error") || lower.contains("fail") || lower.starts_with("gti") || lower.starts_with("sl") || lower.contains("cd..") {
            is_failure = true;
        }
    }

    // Map command string hash into a 24-TET (quarter-tone) microtonal scale frequency
    let mut hasher = DefaultHasher::new();
    clean_cmd.hash(&mut hasher);
    let hash_val = hasher.finish();

    let microtone_step = (hash_val % 48) as f32; // 48 quarter-tones spanning 2 octaves
    let frequency = 220.0 * 2.0_f32.powf(microtone_step / 24.0); // Microtonal scale relative to A3 (220Hz)
    let duration = 0.7 + ((clean_cmd.len() % 15) as f32 * 0.12);

    CommandEvent {
        command: clean_cmd,
        frequency,
        duration,
        is_failure,
    }
}

/// Synthesizes microtonal ambient pad tones and crash impacts into a standard PCM 16-bit WAV file.
fn render_audio_wav(events: &[CommandEvent], filename: &str) -> std::io::Result<()> {
    let sample_rate = 44100;
    let mut audio_samples: Vec<f32> = Vec::new();
    let mut rng = NoiseGen::new(0x42);

    for event in events {
        let num_samples = (event.duration * sample_rate as f32) as usize;

        let f0 = event.frequency;
        let f_sub = f0 * 0.5;
        let f_micro_fifth = f0 * 1.4983; // Slightly detuned harmonic fifth

        for i in 0..num_samples {
            let t = i as f32 / sample_rate as f32;

            // Envelope (Attack, Sustain, Decay)
            let attack = (t / 0.12).min(1.0);
            let release = ((event.duration - t) / 0.35).clamp(0.0, 1.0);
            let env = attack * release;

            // Ambient microtonal chord synthesis
            let wave_main = (2.0 * std::f32::consts::PI * f0 * t).sin();
            let wave_sub = (2.0 * std::f32::consts::PI * f_sub * t).sin() * 0.45;
            let wave_fifth = (2.0 * std::f32::consts::PI * f_micro_fifth * t).sin() * 0.25;

            let mut sample = (wave_main + wave_sub + wave_fifth) * 0.25 * env;

            // Synthesize dramatic percussion crash if command failed
            if event.is_failure {
                let crash_duration = 1.25;
                if t < crash_duration {
                    let crash_env = (-4.5 * (t / crash_duration)).exp();

                    // White noise cymbal/burst generator
                    let noise = rng.next_float() * crash_env * 0.65;

                    // Sub-bass pitch sweep impact punch (180 Hz -> 35 Hz)
                    let bass_freq = 180.0 * (-6.0 * t).exp() + 35.0;
                    let bass_impact = (2.0 * std::f32::consts::PI * bass_freq * t).sin() * crash_env * 0.85;

                    sample += noise + bass_impact;
                }
            }

            audio_samples.push(sample);
        }

        // Brief gap between notes
        let gap_samples = (sample_rate as f32 * 0.12) as usize;
        audio_samples.extend(std::iter::repeat(0.0).take(gap_samples));
    }

    // Peak normalization
    let max_amp = audio_samples.iter().map(|s| s.abs()).fold(0.0_f32, f32::max);
    if max_amp > 0.0 {
        let scale = 0.85 / max_amp;
        for s in &mut audio_samples {
            *s *= scale;
        }
    }

    // Format and output 16-bit PCM WAV File Header
    let mut file = File::create(filename)?;
    let num_channels: u16 = 1;
    let bits_per_sample: u16 = 16;
    let data_size = (audio_samples.len() * 2) as u32;

    file.write_all(b"RIFF")?;
    file.write_all(&(36 + data_size).to_le_bytes())?;
    file.write_all(b"WAVE")?;

    file.write_all(b"fmt ")?;
    file.write_all(&16u32.to_le_bytes())?;
    file.write_all(&1u16.to_le_bytes())?;
    file.write_all(&num_channels.to_le_bytes())?;
    file.write_all(&sample_rate.to_le_bytes())?;
    let byte_rate = sample_rate * num_channels as u32 * (bits_per_sample as u32 / 8);
    file.write_all(&byte_rate.to_le_bytes())?;
    let block_align = num_channels * (bits_per_sample / 8);
    file.write_all(&block_align.to_le_bytes())?;
    file.write_all(&bits_per_sample.to_le_bytes())?;

    file.write_all(b"data")?;
    file.write_all(&data_size.to_le_bytes())?;

    for &s in &audio_samples {
        let pcm_val = (s.clamp(-1.0, 1.0) * i16::MAX as f32) as i16;
        file.write_all(&pcm_val.to_le_bytes())?;
    }

    Ok(())
}