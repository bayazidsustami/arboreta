use std::collections::HashMap;
use std::env;
use std::fs::File;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use std::thread;
use std::time::Duration;

// Characters representing elevation from deepest river canyons (~) to towering mountain peaks (▲)
const ALTITUDE_CHARS: &[char] = &['~', '≈', '░', '.', ':', '-', '=', '+', '*', '#', '%', '@', '^', '▲'];
const MAP_WIDTH: usize = 70;
const MAP_HEIGHT: usize = 22;

// Locate standard shell history files across various shells (.bash_history, .zsh_history)
fn find_history_file() -> Option<PathBuf> {
    let home = env::var("HOME").ok()?;
    let candidate_paths = [
        format!("{}/.bash_history", home),
        format!("{}/.zsh_history", home),
        format!("{}/.history", home),
    ];
    for path_str in candidate_paths {
        let path = PathBuf::from(path_str);
        if path.exists() {
            return Some(path);
        }
    }
    None
}

// Detect command syntax errors (unmatched quotes, invalid syntax constructs, unbalanced brackets)
fn is_syntax_error(cmd: &str) -> bool {
    let clean = if let Some(idx) = cmd.find(';') {
        &cmd[idx + 1..]
    } else {
        cmd
    }.trim();

    if clean.is_empty() {
        return false;
    }

    let mut single_q = false;
    let mut double_q = false;
    let mut parens = 0i32;
    let mut braces = 0i32;

    for c in clean.chars() {
        match c {
            '\'' if !double_q => single_q = !single_q,
            '"' if !single_q => double_q = !double_q,
            '(' if !single_q && !double_q => parens += 1,
            ')' if !single_q && !double_q => parens -= 1,
            '{' if !single_q && !double_q => braces += 1,
            '}' if !single_q && !double_q => braces -= 1,
            _ => {}
        }
    }

    single_q || double_q || parens != 0 || braces != 0 || clean.contains("syntax error") || clean.contains("command not found")
}

// Simple hash function to map commands to deterministic grid coordinates
fn hash_command(s: &str) -> u64 {
    let mut hash: u64 = 5381;
    for b in s.bytes() {
        hash = hash.wrapping_mul(33).wrapping_add(b as u64);
    }
    hash
}

fn main() {
    // Clear screen and hide terminal cursor for continuous rendering
    print!("\x1B[2J\x1B[H\x1B[?25l");

    let history_file = find_history_file();
    let mut elevations = vec![vec![0.0f32; MAP_WIDTH]; MAP_HEIGHT];

    loop {
        let mut command_frequencies: HashMap<String, usize> = HashMap::new();
        let mut syntax_errors: HashMap<String, usize> = HashMap::new();

        // Parse history file and categorize commands
        if let Some(ref path) = history_file {
            if let Ok(file) = File::open(path) {
                let reader = BufReader::new(file);
                for line in reader.lines().flatten() {
                    let cmd = line.trim().to_string();
                    if cmd.is_empty() {
                        continue;
                    }

                    if is_syntax_error(&cmd) {
                        *syntax_errors.entry(cmd).or_insert(0) += 1;
                    } else {
                        let base_cmd = cmd.split_whitespace().next().unwrap_or(&cmd).to_string();
                        *command_frequencies.entry(base_cmd).or_insert(0) += 1;
                    }
                }
            }
        }

        // Reset landscape heightmap before accumulating current history state
        for row in &mut elevations {
            for val in row {
                *val = 0.0;
            }
        }

        // Raise mountain ranges from frequent commands
        for (cmd, count) in &command_frequencies {
            let h = hash_command(cmd);
            let cx = (h as usize) % MAP_WIDTH;
            let cy = ((h >> 16) as usize) % MAP_HEIGHT;
            let radius = ((*count as f32).sqrt() * 1.5).clamp(2.0, 12.0);
            let peak = (*count as f32 * 0.8).clamp(2.0, 25.0);

            for y in 0..MAP_HEIGHT {
                for x in 0..MAP_WIDTH {
                    let dx = x as f32 - cx as f32;
                    let dy = y as f32 - cy as f32;
                    let dist = (dx * dx + dy * dy).sqrt();
                    if dist < radius {
                        let elevation = peak * (1.0 - dist / radius).powf(1.5);
                        elevations[y][x] += elevation;
                    }
                }
            }
        }

        // Erode river canyons from syntax errors
        for (cmd, count) in &syntax_errors {
            let h = hash_command(cmd);
            let start_x = (h as usize) % MAP_WIDTH;
            let start_y = ((h >> 16) as usize) % MAP_HEIGHT;
            let erosion_depth = (*count as f32 * 2.0).clamp(2.0, 15.0);

            // Carve a meandering river path across the map
            for step in 0..MAP_WIDTH {
                let x = (start_x + step) % MAP_WIDTH;
                let offset = ((step as f32 * 0.3).sin() * 2.5) as i32;
                let y = ((start_y as i32 + offset).rem_euclid(MAP_HEIGHT as i32)) as usize;

                elevations[y][x] -= erosion_depth;
                if y > 0 { elevations[y - 1][x] -= erosion_depth * 0.5; }
                if y + 1 < MAP_HEIGHT { elevations[y + 1][x] -= erosion_depth * 0.5; }
            }
        }

        // Render Topographic Map to Terminal
        print!("\x1B[H");
        println!("╔══════════════════════════════════════════════════════════════════════╗");
        println!("║               EVOLVING SHELL TOPOGRAPHIC MAP                         ║");
        println!("║  ▲ Peaks = Frequent Commands  |  ~ Deep Canyons = Syntax Errors    ║");
        println!("╚══════════════════════════════════════════════════════════════════════╝");

        for y in 0..MAP_HEIGHT {
            let mut line = String::with_capacity(MAP_WIDTH);
            for x in 0..MAP_WIDTH {
                let height = elevations[y][x];
                // Map elevation value to ASCII density scale
                let idx = ((height + 6.0) / 2.0) as i32;
                let clamped_idx = idx.clamp(0, (ALTITUDE_CHARS.len() - 1) as i32) as usize;
                line.push(ALTITUDE_CHARS[clamped_idx]);
            }
            println!("  {}", line);
        }

        // Update interval for continuous topographic evolution
        thread::sleep(Duration::from_millis(1500));
    }
}