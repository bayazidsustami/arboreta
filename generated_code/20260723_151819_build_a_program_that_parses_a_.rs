//! Git Origami Crumple Generator
//! Parses a Git repository's history, analyzes sentiment and code churn,
//! and translates each commit into a procedural ASCII/ANSI origami folding pattern.
//! High technical debt crumples and distorts the crease pattern into chaotic entropy.

use std::env;
use std::process::Command;

/// Holds analysis metrics for a single commit.
#[derive(Debug, Clone)]
struct CommitAnalysis {
    hash: String,
    author: String,
    message: String,
    insertions: usize,
    deletions: usize,
    churn: usize,
    sentiment: f32,       // -1.0 (very negative/frustrated) to +1.0 (positive)
    debt_score: f32,      // 0.0 (pristine crease pattern) to 1.0+ (heavily crumpled)
}

/// Represents a geometric point on the origami canvas.
#[derive(Debug, Clone, Copy)]
struct Point {
    x: f32,
    y: f32,
}

/// Represents an origami crease fold line.
#[derive(Debug, Clone)]
struct Crease {
    start: Point,
    end: Point,
    is_mountain: bool, // true = Mountain fold (/\), false = Valley fold (\/)
}

impl CommitAnalysis {
    /// Estimates sentiment based on keyword patterns in the commit message.
    fn analyze_sentiment(msg: &str) -> f32 {
        let lower = msg.to_lower_case();
        let positive_words = ["feat", "add", "clean", "refactor", "improve", "fix", "nice", "easy", "speed", "smooth"];
        let negative_words = ["hack", "dirty", "ugly", "panic", "broken", "oops", "wip", "todo", "fixme", "sigh", "curse", "bloat", "debt"];

        let mut score = 0.0f32;
        for word in positive_words {
            if lower.contains(word) { score += 0.25; }
        }
        for word in negative_words {
            if lower.contains(word) { score -= 0.35; }
        }

        score.clamp(-1.0, 1.0)
    }

    /// Calculates technical debt using churn and sentiment heuristics.
    fn calculate_debt(&mut self) {
        let churn_factor = (self.churn as f32 / 100.0).min(2.0);
        let negative_sentiment_penalty = if self.sentiment < 0.0 { -self.sentiment * 0.8 } else { 0.0 };
        self.debt_score = (churn_factor * 0.6 + negative_sentiment_penalty).clamp(0.0, 2.5);
    }
}

/// Simple pseudo-random number generator for deterministic geometric noise.
fn prng(seed: u32) -> f32 {
    let mut x = seed.wrapping_mul(1103515245).wrapping_add(12345);
    x = (x >> 16) & 0x7FFF;
    (x as f32) / (0x7FFF as f32)
}

/// Generates a base procedural origami pattern (Crane-inspired geometry).
fn generate_origami_creases() -> Vec<Crease> {
    vec![
        // Outer square border
        Crease { start: Point { x: 0.0, y: 0.0 }, end: Point { x: 1.0, y: 0.0 }, is_mountain: true },
        Crease { start: Point { x: 1.0, y: 0.0 }, end: Point { x: 1.0, y: 1.0 }, is_mountain: true },
        Crease { start: Point { x: 1.0, y: 1.0 }, end: Point { x: 0.0, y: 1.0 }, is_mountain: true },
        Crease { start: Point { x: 0.0, y: 1.0 }, end: Point { x: 0.0, y: 0.0 }, is_mountain: true },
        // Main diagonals (Mountain folds)
        Crease { start: Point { x: 0.0, y: 0.0 }, end: Point { x: 1.0, y: 1.0 }, is_mountain: true },
        Crease { start: Point { x: 1.0, y: 0.0 }, end: Point { x: 0.0, y: 1.0 }, is_mountain: true },
        // Bisectors / Valley folds
        Crease { start: Point { x: 0.5, y: 0.0 }, end: Point { x: 0.5, y: 1.0 }, is_mountain: false },
        Crease { start: Point { x: 0.0, y: 0.5 }, end: Point { x: 1.0, y: 0.5 }, is_mountain: false },
        // Inner diamond / preliminary base folds
        Crease { start: Point { x: 0.5, y: 0.0 }, end: Point { x: 1.0, y: 0.5 }, is_mountain: true },
        Crease { start: Point { x: 1.0, y: 0.5 }, end: Point { x: 0.5, y: 1.0 }, is_mountain: true },
        Crease { start: Point { x: 0.5, y: 1.0 }, end: Point { x: 0.0, y: 0.5 }, is_mountain: true },
        Crease { start: Point { x: 0.0, y: 0.5 }, end: Point { x: 0.5, y: 0.0 }, is_mountain: true },
    ]
}

/// Distorts point coordinates based on technical debt noise to simulate crumpling.
fn crumple_point(p: Point, debt: f32, seed_offset: u32) -> Point {
    if debt < 0.05 {
        return p; // Clean code yields crisp, pristine geometric lines
    }

    let rx = prng(seed_offset.wrapping_add((p.x * 1000.0) as u32)) - 0.5;
    let ry = prng(seed_offset.wrapping_add((p.y * 1000.0) as u32 + 5555)) - 0.5;

    // Nonlinear displacement simulating folded/crushed paper stress
    let intensity = debt.powf(1.4) * 0.25;
    Point {
        x: (p.x + rx * intensity).clamp(0.0, 1.0),
        y: (p.y + ry * intensity).clamp(0.0, 1.0),
    }
}

/// Rasterizes the origami crease pattern into ASCII text with ANSI coloration.
fn render_origami(analysis: &CommitAnalysis, width: usize, height: usize) -> String {
    let mut grid = vec![vec![' '; width]; height];
    let mut color_grid = vec![vec!["\x1b[0m"; width]; height];

    let base_creases = generate_origami_creases();
    let seed = u32::from_str_radix(&analysis.hash[0..6], 16).unwrap_or(42);

    // Apply debt-based crumpling distortion to crease lines
    for (idx, crease) in base_creases.iter().enumerate() {
        let p1 = crumple_point(crease.start, analysis.debt_score, seed + idx as u32);
        let p2 = crumple_point(crease.end, analysis.debt_score, seed + idx as u32 + 100);

        // Draw line using Bresenham's algorithm on grid canvas
        let x0 = (p1.x * (width - 1) as f32).round() as i32;
        let y0 = (p1.y * (height - 1) as f32).round() as i32;
        let x1 = (p2.x * (width - 1) as f32).round() as i32;
        let y1 = (p2.y * (height - 1) as f32).round() as i32;

        let dx = (x1 - x0).abs();
        let dy = -(y1 - y0).abs();
        let sx = if x0 < x1 { 1 } else { -1 };
        let sy = if y0 < y1 { 1 } else { -1 };
        let mut err = dx + dy;

        let mut cx = x0;
        let mut cy = y0;

        let char_symbol = if crease.is_mountain { '/' } else { '\\' };
        let color_code = if analysis.debt_score > 1.0 {
            "\x1b[31;1m" // High Debt: Violent Red
        } else if analysis.debt_score > 0.4 {
            "\x1b[33m"   // Moderate Debt: Warning Yellow
        } else if analysis.sentiment >= 0.0 {
            "\x1b[36m"   // Positive/Clean: Pristine Cyan
        } else {
            "\x1b[35m"   // Negative: Deep Magenta
        };

        loop {
            if cx >= 0 && cx < width as i32 && cy >= 0 && cy < height as i32 {
                let ux = cx as usize;
                let uy = cy as usize;
                grid[uy][ux] = char_symbol;
                color_grid[uy][ux] = color_code;
            }
            if cx == x1 && cy == y1 { break; }
            let e2 = 2 * err;
            if e2 >= dy { err += dy; cx += sx; }
            if e2 <= dx { err += dx; cy += sy; }
        }
    }

    // Add extra random crease noise lines if the paper is severely crumpled
    if analysis.debt_score > 0.5 {
        let noise_count = ((analysis.debt_score - 0.5) * 30.0) as usize;
        for i in 0..noise_count {
            let rx = (prng(seed + i as u32 * 7) * (width - 1) as f32) as usize;
            let ry = (prng(seed + i as u32 * 13) * (height - 1) as f32) as usize;
            if grid[ry][rx] == ' ' {
                grid[ry][rx] = if i % 2 == 0 { '*' } else { '#' };
                color_grid[ry][rx] = "\x1b[31m";
            }
        }
    }

    // Assembly output buffer
    let mut output = String::new();
    output.push_str(&format!(
        "\x1b[1mCommit:\x1b[0m {} | \x1b[1mAuthor:\x1b[0m {}\n",
        &analysis.hash[..7], analysis.author
    ));
    output.push_str(&format!(
        "\x1b[1mMessage:\x1b[0m \"{}\"\n",
        analysis.message
    ));
    output.push_str(&format!(
        "\x1b[1mChurn:\x1b[0m +{}/-{} | \x1b[1mSentiment:\x1b[0m {:.2} | \x1b[1mDebt Level:\x1b[0m {:.2}\n",
        analysis.insertions, analysis.deletions, analysis.sentiment, analysis.debt_score
    ));
    output.push_str("┌" );
    output.push_str(&"─".repeat(width));
    output.push_str("┐\n");

    for y in 0..height {
        output.push('│');
        for x in 0..width {
            let ch = grid[y][x];
            let col = color_grid[y][x];
            if ch != ' ' {
                output.push_str(&format!("{}{}\x1b[0m", col, ch));
            } else {
                output.push(' ');
            }
        }
        output.push_str("│\n");
    }

    output.push_str("└");
    output.push_str(&"─".repeat(width));
    output.push_str("┘\n");
    output
}

/// Parses local repository history via standard `git log` output.
fn fetch_git_commits(limit: usize) -> Vec<CommitAnalysis> {
    let output = Command::new("git")
        .args(&[
            "log",
            &format!("-n{}", limit),
            "--numstat",
            "--pretty=format:COMMIT_START%n%H%n%an%n%s",
        ])
        .output();

    let mut commits = Vec::new();

    let output_str = match output {
        Ok(out) if out.status.success() => String::from_utf8_lossy(&out.stdout).into_owned(),
        _ => return fallback_mock_commits(), // Graceful fallback if not inside a valid Git repo
    };

    let blocks = output_str.split("COMMIT_START\n").skip(1);

    for block in blocks {
        let lines: Vec<&str> = block.lines().collect();
        if lines.len() < 3 { continue; }

        let hash = lines[0].to_string();
        let author = lines[1].to_string();
        let message = lines[2].to_string();

        let mut insertions = 0;
        let mut deletions = 0;

        for line in lines.iter().skip(3) {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                let ins = parts[0].parse::<usize>().unwrap_or(0);
                let del = parts[1].parse::<usize>().unwrap_or(0);
                insertions += ins;
                deletions += del;
            }
        }

        let churn = insertions + deletions;
        let sentiment = CommitAnalysis::analyze_sentiment(&message);

        let mut commit_info = CommitAnalysis {
            hash,
            author,
            message,
            insertions,
            deletions,
            churn,
            sentiment,
            debt_score: 0.0,
        };

        commit_info.calculate_debt();
        commits.push(commit_info);
    }

    if commits.is_empty() {
        fallback_mock_commits()
    } else {
        commits
    }
}

/// Fallback demo commits demonstrating state changes when running outside a git repo.
fn fallback_mock_commits() -> Vec<CommitAnalysis> {
    let mut samples = vec![
        CommitAnalysis {
            hash: "a1b2c3d4e5f67890".to_string(),
            author: "Ada Lovelace".to_string(),
            message: "feat: add elegant modular crease architecture".to_string(),
            insertions: 45,
            deletions: 2,
            churn: 47,
            sentiment: 0.5,
            debt_score: 0.0,
        },
        CommitAnalysis {
            hash: "f6e5d4c3b2a10987".to_string(),
            author: "Alan Turing".to_string(),
            message: "refactor: simplify valley folds and reduce complexity".to_string(),
            insertions: 12,
            deletions: 30,
            churn: 42,
            sentiment: 0.25,
            debt_score: 0.0,
        },
        CommitAnalysis {
            hash: "9876543210abcdef".to_string(),
            author: "Dev Panic".to_string(),
            message: "fix: quick dirty hack to patch unexpected state bug, panic everywhere".to_string(),
            insertions: 420,
            deletions: 180,
            churn: 600,
            sentiment: -0.7,
            debt_score: 0.0,
        },
    ];

    for commit in &mut samples {
        commit.calculate_debt();
    }

    samples
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let limit = args.get(1).and_then(|s| s.parse::<usize>().ok()).unwrap_or(5);

    println!("\x1b[1;32m=== GIT COMMIT ORIGAMI CRUMPLE TRANSLATOR ===\x1b[0m\n");

    let commits = fetch_git_commits(limit);

    for (idx, commit) in commits.iter().enumerate() {
        println!("\x1b[1;34m--- Origami Pattern #{} ---\x1b[0m", idx + 1);
        let pattern = render_origami(commit, 40, 16);
        println!("{}", pattern);
    }
}