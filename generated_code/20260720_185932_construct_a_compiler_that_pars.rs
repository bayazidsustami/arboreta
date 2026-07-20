// Requires the following dependencies in Cargo.toml:
// git2 = "0.19"
// rodio = "0.17"

use git2::{Repository, DiffOptions};
use rodio::{Decoder, OutputStream, Sink, Source};
use rodio::source::SineWave;
use std::time::Duration;
use std::collections::VecDeque;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Compile Git History into a "Synthesizer Patch" (AST of musical parameters)
    let repo = Repository::open(".")?;
    let mut revwalk = repo.revwalk()?;
    revwalk.push_head()?;
    revwalk.set_sorting(git2::Sort::TOPOLOGICAL | git2::Sort::REVERSE)?;

    let mut synth_patch = Vec::new();
    let mut prev_commit = None;

    for id in revwalk {
        let id = id?;
        let commit = repo.find_commit(id)?;
        
        let mut base_frequency = 220.0; // Default A3
        let mut dissonance_factor = 1.0;
        let mut echo_decay = 0.0;

        // Map commit hash bytes to musical scales/base frequency
        let hash_bytes = commit.id().as_bytes();
        if !hash_bytes.is_empty() {
            let scale_degree = (hash_bytes[0] % 12) as f32;
            base_frequency = 110.0 * f32::powf(2.0, scale_degree / 12.0); // Pentatonic/Chromatic step
        }

        if let Some(prev) = prev_commit {
            let tree = commit.tree()?;
            let prev_tree = repo.find_commit(prev)?.tree()?;
            let mut opts = DiffOptions::new();
            let diff = repo.diff_tree_to_tree(Some(&prev_tree), Some(&tree), Some(&mut opts))?;
            let stats = diff.stats()?;

            let added = stats.insertions() as f32;
            let deleted = stats.deletions() as f32;
            let total_churn = added + deleted;

            if total_churn > 0.0 {
                // Code churn dictates musical dissonance (frequency ratio warping)
                dissonance_factor = 1.0 + (added / (total_churn + 1.0)) * 0.15;
                // Deleted lines manifest as echoing reverberation (decay trail)
                echo_decay = (deleted / (total_churn + 1.0)).min(0.9);
            }
        }

        synth_patch.push((base_frequency, dissonance_factor, echo_decay));
        prev_commit = Some(id);
    }

    // 2. Playable Web-Audio-style Engine (using Rodio for local audio synthesis)
    let (_stream, stream_handle) = OutputStream::try_default()?;
    let sink = Sink::try_new(&stream_handle)?;
    
    let note_duration = Duration::from_millis(250);
    let mut echo_buffer: VecDeque<(f32, f32)> = VecDeque::new(); // Holds (frequency, amplitude) for reverb

    println!("Synthesizing git history into audio: {} commits...", synth_patch.len());

    for (freq, dissonance, echo) in synth_patch {
        // Construct dissonant chords using the churn factor
        let tone1 = SineWave::new(freq).take_duration(note_duration).amplify(0.2);
        let tone2 = SineWave::new(freq * dissonance).take_duration(note_duration).amplify(0.15);
        let mixed = tone1.mix(tone2);

        // Inject current tone into the echo buffer if there is a deletion/reverb trail
        if echo > 0.1 {
            echo_buffer.push_back((freq, echo * 0.25));
            if echo_buffer.len() > 4 {
                echo_buffer.pop_front();
            }
        }

        // Layer the active echoing reverberations
        let mut final_signal = mixed.amplify(1.0).boxed();
        for &(echo_freq, echo_amp) in echo_buffer.iter() {
            let echo_tone = SineWave::new(echo_freq * 0.99) // Slight pitch shift for space
                .take_duration(note_duration)
                .amplify(echo_amp);
            final_signal = final_signal.mix(echo_tone).boxed();
        }

        sink.append(final_signal);
        
        // Simulating immediate web-audio node connection decay by controlling queue depth
        while sink.len() > 2 {
            std::thread::sleep(Duration::from_millis(50));
        }
    }

    sink.sleep_until_end();
    Ok(())
}