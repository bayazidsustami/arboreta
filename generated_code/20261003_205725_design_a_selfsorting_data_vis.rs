// A self-sorting Victorian mosaic visualizer for system error logs.
// It categorizes incoming logs by severity, sorts them deterministically, 
// and blooms them into an ornate ASCII/Unicode botanical mosaic.

use std::cmp::Ordering;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Severity {
    Info,
    Warning,
    Error,
    Critical,
}

#[derive(Debug, Clone)]
struct LogEntry {
    id: usize,
    message: &'static str,
    severity: Severity,
    timestamp: u64,
}

impl Ord for LogEntry {
    fn cmp(&self, other: &Self) -> Ordering {
        // Sort primarily by severity (Critical -> Info), then chronologically by timestamp
        other.severity.cmp(&self.severity)
            .then_with(|| self.timestamp.cmp(&other.timestamp))
    }
}

impl PartialOrd for LogEntry {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl PartialEq for LogEntry {
    fn eq(&self, other: &Self) -> bool {
        self.severity == other.severity && self.timestamp == other.timestamp
    }
}

impl Eq for LogEntry {}

impl Severity {
    fn color_code(&self) -> &'static str {
        match self {
            Severity::Info => "\x1b[38;5;39m",     // Victorian Blue
            Severity::Warning => "\x1b[38;5;220m",  // Ornate Gold
            Severity::Error => "\x1b[38;5;208m",    // Deep Amber
            Severity::Critical => "\x1b[38;5;196m", // Crimson
        }
    }

    fn symbol(&self) -> char {
        match self {
            Severity::Info => '❀',
            Severity::Warning => '✿',
            Severity::Error => '❁',
            Severity::Critical => '✾',
        }
    }
}

fn main() {
    // Incoming unstructured system error log stream
    let mut logs = vec![
        LogEntry { id: 1, message: "Connection timeout on socket", severity: Severity::Warning, timestamp: 102 },
        LogEntry { id: 2, message: "Null pointer exception in core", severity: Severity::Critical, timestamp: 105 },
        LogEntry { id: 3, message: "User session initialized", severity: Severity::Info, timestamp: 100 },
        LogEntry { id: 4, message: "Disk partition capacity low", severity: Severity::Error, timestamp: 103 },
        LogEntry { id: 5, message: "Cache hit ratio degraded", severity: Severity::Warning, timestamp: 101 },
        LogEntry { id: 6, message: "Segmentation fault in worker", severity: Severity::Critical, timestamp: 104 },
    ];

    println!("\x1b[1m┌────────────────────────────────────────────────────────┐\x1b[0m");
    println!("\x1b[1m│  Victorian Mosaic Initializing: Sorting Log Stream...  │\x1b[0m");
    println!("\x1b[1m└────────────────────────────────────────────────────────┘\x1b[0m\n");

    // Apply self-sorting algorithm based on severity hierarchy and temporal order
    logs.sort();

    // Render the evolving mosaic arrangement
    let width = 2;
    for (i, log) in logs.iter().enumerate() {
        if i > 0 && i % width == 0 {
            println!("  ────────────────────────────────────────────────────────");
        }
        let color = log.severity.color_code();
        let sym = log.severity.symbol();
        
        print!("  {color}{sym}\x1b[0m [ID:{:02} {:<8}] ", log.id, format!("{:?}", log.severity));
        
        // Blooming petaled aesthetic proportional to severity depth
        let bloom_intensity = match log.severity {
            Severity::Info => 1,
            Severity::Warning => 2,
            Severity::Error => 3,
            Severity::Critical => 5,
        };
        
        for _ in 0..bloom_intensity {
            print!("*");
        }
        println!();
    }

    println!("\n\x1b[1m[Mosaic Bloom Complete: All systemic anomalies harmonized.]\x1b[0m");
}