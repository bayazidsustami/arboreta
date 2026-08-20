// Cargo.toml requirements:
// [dependencies]
// rodio = "0.17"
// reqwest = { version = "0.11", features = ["blocking", "json"] }
// serde = { version = "1.0", features = ["derive"] }
// ringbuf = "0.3"

use std::collections::{HashMap, HashSet};
use std::io::{stdout, Write};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use ringbuf::HeapRb;
use rodio::{OutputStream, Sink, Source};
use serde::Deserialize;

const SAMPLE_RATE: u32 = 44100;
const PENTATONIC_SCALE: [f32; 12] = [
    130.81, 146.83, 164.81, 196.00, 220.00, // C3, D3, E3, G3, A3
    261.63, 293.66, 329.63, 392.00, 440.00, // C4, D4, E4, G4, A4
    523.25, 587.33,                         // C5, D5
];

#[derive(Deserialize, Debug, Clone)]
struct CommitUser {
    login: Option<String>,
}

#[derive(Deserialize, Debug, Clone)]
struct CommitDetail {
    message: String,
}

#[derive(Deserialize, Debug, Clone)]
struct GithubCommit {
    sha: String,
    author: Option<CommitUser>,
    commit: CommitDetail,
}

#[derive(Clone, Copy, Debug)]
enum Waveform {
    Sine,
    Square,
    Sawtooth,
    Triangle,
}

impl Waveform {
    fn generate(self, phase: f32) -> f32 {
        match self {
            Waveform::Sine => (phase * 2.0 * std::f32::consts::PI).sin(),
            Waveform::Square => if (phase * 2.0 * std::f32::consts::PI).sin() >= 0.0 { 0.5 } else { -0.5 },
            Waveform::Sawtooth => 2.0 * (phase - (phase + 0.5).floor()),
            Waveform::Triangle => 2.0 * (2.0 * (phase - (phase + 0.5).floor())).abs() - 1.0,
        }
    }
}

// Custom synthesizer source generating algorithmic polyphonic counterpoint
struct GenerativeSynth {
    sample_rate: u32,
    phase: f32,
    freq: f32,
    waveform: Waveform,
    envelope: f32,
    decay: f32,
}

impl GenerativeSynth {
    fn new(freq: f32, waveform: Waveform, duration_secs: f32) -> Self {
        Self {
            sample_rate: SAMPLE_RATE,
            phase: 0.0,
            freq,
            waveform,
            envelope: 1.0,
            decay: 1.0 / (SAMPLE_RATE as f32 * duration_secs),
        }
    }
}

impl Iterator for GenerativeSynth {
    type Item = f32;

    fn next(&mut self) -> Option<Self::Item> {
        if self.envelope <= 0.0 {
            return None;
        }

        let raw_sample = self.waveform.generate(self.phase);
        let output = raw_sample * self.envelope * 0.25;

        self.phase = (self.phase + self.freq / self.sample_rate as f32) % 1.0;
        self.envelope = (self.envelope - self.decay).max(0.0);

        Some(output)
    }
}

impl Source for GenerativeSynth {
    fn current_frame_len(&self) -> Option<usize> { None }
    fn channels(&self) -> u16 { 1 }
    fn sample_rate(&self) -> u32 { self.sample_rate }
    fn total_duration(&self) -> Option<Duration> { None }
}

fn hash_string(s: &str) -> u64 {
    use std::hash::{Hash, Hasher};
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    s.hash(&mut hasher);
    hasher.finish()
}

fn fetch_commits(repo: &str) -> Result<Vec<GithubCommit>, Box<dyn std::error::Error>> {
    let url = format!("[https://api.github.com/repos/](https://api.github.com/repos/){}/commits?per_page=30", repo);
    let client = reqwest::blocking::Client::new();
    let res = client
        .get(&url)
        .header("User-Agent", "GitHarmonics-Generative-Synth")
        .send()?;

    if !res.status().is_success() {
        return Err(format!("GitHub API error: Status {}", res.status()).into());
    }

    let commits: Vec<GithubCommit> = res.json()?;
    Ok(commits)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let repo = "rust-lang/rust";
    println!("♪ ======================================================== ♪");
    println!("  GIT HARMONICS: Generative Audio Score from Code History");
    println!("  Repository: {}", repo);
    println!("♪ ======================================================== ♪\n");

    print!("[+] Fetching live commit history from GitHub...");
    stdout().flush()?;
    let commits = fetch_commits(repo)?;
    println!(" Done! (Loaded {} commits)\n", commits.len());

    let (_stream, stream_handle) = OutputStream::try_default()?;
    let sink = Sink::try_new(&stream_handle)?;

    let mut author_instruments: HashMap<String, (Waveform, usize)> = HashMap::new();
    let waveforms = [Waveform::Sine, Waveform::Triangle, Waveform::Sawtooth, Waveform::Square];

    for (i, commit) in commits.iter().enumerate().rev() {
        let author = commit
            .author
            .as_ref()
            .and_then(|a| a.login.clone())
            .unwrap_or_else(|| "anonymous".to_string());

        let author_hash = hash_string(&author);
        let commit_hash = hash_string(&commit.sha);

        // Map author identity to unique instrument timbre (Waveform) & Octave offset
        let (waveform, track_id) = author_instruments.entry(author.clone()).or_insert_with(|| {
            let wf = waveforms[(author_hash as usize) % waveforms.len()];
            let tid = author_instruments.len() + 1;
            (wf, tid)
        });

        // Determine pitch/harmonic from commit hash and message length counterpoint
        let note_idx = (commit_hash as usize + commit.commit.message.len()) % PENTATONIC_SCALE.len();
        let freq = PENTATONIC_SCALE[note_idx];

        // Harmonic counterpoint: create a secondary polyphonic overtone
        let harmony_idx = (note_idx + 2 + (commit_hash % 3) as usize) % PENTATONIC_SCALE.len();
        let harmony_freq = PENTATONIC_SCALE[harmony_idx];

        let msg_summary = commit.commit.message.lines().next().unwrap_or("").trim();
        let truncated_msg = if msg_summary.len() > 40 {
            format!("{}...", &msg_summary[..37])
        } else {
            msg_summary.to_string()
        };

        println!(
            "[{:02}/{:02}] Commit {:7} | Track {:02} <{}> | Author: {:15} | Note: {:6.1} Hz | \"{}\"",
            i + 1,
            commits.len(),
            &commit.sha[..7],
            track_id,
            format!("{:?}", waveform).to_lowercase(),
            author,
            freq,
            truncated_msg
        );

        // Synthesize primary voice
        let synth_primary = GenerativeSynth::new(freq, *waveform, 0.35);
        sink.append(synth_primary);

        // Synthesize harmonic counterpoint voice offset slightly in pitch
        let synth_harmony = GenerativeSynth::new(harmony_freq, Waveform::Sine, 0.25);
        sink.append(synth_harmony);

        sink.play();
        thread::sleep(Duration::from_millis(280));
    }

    sink.sleep_until_end();
    println!("\n♪ Performance finished. Algorithmic score complete. ♪");
    Ok(())
}

[Git Harmonics Rust Audio Guide](https://www.youtube.com/watch?v=7fNSV8XZHlc)
This video provides a complete walkthrough on generating, handling, and playing procedural synth audio and MIDI tracks using Rust sound libraries.