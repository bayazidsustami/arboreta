// A self-modifying Rust program that monitors real-time network latency spikes,
// dynamically adjusts its own sampling/sensitivity parameters, and prints haikus
// about digital loneliness to standard error (eprintln!).

use std::env;
use std::fs;
use std::io::{self, Write};
use std::net::TcpStream;
use std::process::Command;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

// Haikus about digital loneliness, indexed by intensity of the ping spike
const HAIKUS_MILD: &[&str] = &[
    "Silent ping sent out,\nAn empty echo returns,\nAlone in the wire.",
    "Blinking amber light,\nWaiting for a friendly ACK,\nSilence fills the port.",
];

const HAIKUS_SEVERE: &[&str] = &[
    "Timeouts in the dark,\nTen thousand miles of fiber,\nNo one on the line.",
    "A ghost in the stack,\nPing packets drop one by one,\nOnly static speaks.",
];

// Self-modification marker: dynamic threshold stored directly in the source structure
const LATENCY_THRESHOLD_MS: u64 = 150;

fn measure_latency() -> Result<u64, io::Error> {
    let start = Instant::now();
    // Ping a reliable public endpoint to measure real-time latency
    let _stream = TcpStream::connect_timeout(
        &"1.1.1.1:53".parse().unwrap(),
        Duration::from_secs(2),
    )?;
    Ok(start.elapsed().as_millis() as u64)
}

fn mutate_source_threshold(new_threshold: u64) {
    if let Ok(path) = env::current_exe() {
        // Attempt to find and self-modify the source code file if running via cargo/local dir
        let source_path = "src/main.rs";
        if let Ok(contents) = fs::read_to_string(source_path) {
            let updated = contents.replace(
                &format!("LATENCY_THRESHOLD_MS: u64 = {}", LATENCY_THRESHOLD_MS),
                &format!("LATENCY_THRESHOLD_MS: u64 = {}", new_threshold),
            );
            if fs::write(source_path, updated).is_ok() {
                eprintln!("\x1b[2m[Self-mutation: Threshold adapted to {}ms]\x1b[0m", new_threshold);
            }
        }
    }
}

fn main() {
    let threshold = Arc::new(AtomicU64::new(LATENCY_THRESHOLD_MS));
    eprintln!("Digital loneliness monitor active. Watching the void...");

    let mut consecutive_spikes = 0;

    loop {
        match measure_latency() {
            Ok(latency) => {
                let current_thresh = threshold.load(Ordering::Relaxed);
                
                if latency > current_thresh {
                    consecutive_spikes += 1;
                    
                    // Select haiku based on severity of isolation
                    let haiku = if latency > current_thresh * 2 {
                        HAIKUS_SEVERE[fastrand_idx(HAIKUS_SEVERE.len())]
                    } else {
                        HAIKUS_MILD[fastrand_idx(HAIKUS_MILD.len())]
                    };

                    eprintln!("\n--- Latency Spike: {}ms ---", latency);
                    eprintln!("{}", haiku);

                    // Self-modification trigger: adapt threshold if network is unstable
                    if consecutive_spikes >= 3 {
                        let adapted = current_thresh + 25;
                        threshold.store(adapted, Ordering::Relaxed);
                        mutate_source_threshold(adapted);
                        consecutive_spikes = 0;
                    }
                } else {
                    consecutive_spikes = consecutive_spikes.saturating_sub(1);
                }
            }
            Err(_) => {
                eprintln!("\n--- Total Connection Loss ---");
                eprintln!("Cut off from the grid,\nA solitary server,\nCrying in the dark.");
            }
        }

        thread::sleep(Duration::from_secs(3));
    }
}

// Simple pseudo-random index generator without external dependencies
fn fastrand_idx(max: usize) -> usize {
    let nanos = Instant::now().elapsed().subsec_nanos();
    (nanos as usize) % max
}