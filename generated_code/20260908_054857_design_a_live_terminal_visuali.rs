use std::collections::{HashMap, VecDeque};
use std::env;
use std::io::{self, Write};
use std::process::Command;
use std::thread;
use std::time::Duration;

// Represents a branch/tip of growing ASCII coral
struct CoralBranch {
    x: f32,
    y: f32,
    angle: f32,
    length: usize,
    max_length: usize,
    glyph: char,
    color_code: &'static str,
    active: bool,
}

// Floating skeletal debris from deleted lines
struct Debris {
    x: f32,
    y: f32,
    vx: f32,
    vy: f32,
    glyph: char,
    life: usize,
}

// Parsed Git commit data
struct Commit {
    author: String,
    additions: usize,
    deletions: usize,
    parents: usize,
}

fn main() -> io::Result<()> {
    let repo_path = env::args().nth(1).unwrap_or_else(|| ".".to_string());
    let commits = fetch_git_history(&repo_path)?;

    if commits.is_empty() {
        eprintln!("No git commit history found in: {}", repo_path);
        return Ok(());
    }

    let (width, height) = (80, 24);
    let mut grid = vec![vec![(' ', "\x1b[0m"); width]; height];
    let mut branches: Vec<CoralBranch> = Vec::new();
    let mut debris_particles: Vec<Debris> = Vec::new();

    // Color palette driven by code churn / environmental conditions
    let colors = [
        "\x1b[38;5;206m", // Coral pink
        "\x1b[38;5;81m",  // Cyan ocean
        "\x1b[38;5;119m", // Neon green (high churn)
        "\x1b[38;5;215m", // Warm orange
        "\x1b[38;5;141m", // Deep purple
    ];

    let glyphs = ['|', '/', '\\', '{', '}', '~', '*', 'v', '^', '&'];
    let debris_glyphs = ['x', '•', '°', '+', '†', '‡'];

    // Seed initial central coral root
    branches.push(CoralBranch {
        x: (width / 2) as f32,
        y: (height - 2) as f32,
        angle: -std::f32::consts::FRAC_PI_2,
        length: 0,
        max_length: 15,
        glyph: '|',
        color_code: colors[0],
        active: true,
    });

    print!("\x1b[2J\x1b[?25l"); // Clear screen and hide cursor

    let mut commit_idx = 0;
    let mut frame = 0;

    loop {
        // Ingest next commit periodically to drive growth
        if frame % 3 == 0 && commit_idx < commits.len() {
            let commit = &commits[commit_idx];
            commit_idx += 1;

            let churn = commit.additions + commit.deletions;
            let color = colors[churn % colors.len()];

            // High deletions spawn floating skeletal debris
            if commit.deletions > 0 {
                let num_debris = (commit.deletions / 5).clamp(1, 10);
                for _ in 0..num_debris {
                    debris_particles.push(Debris {
                        x: (frame * 7 % width) as f32,
                        y: (height - 3) as f32,
                        vx: ((frame % 3) as f32 - 1.0) * 0.3,
                        vy: -0.4 - (commit.deletions as f32 * 0.02).min(0.8),
                        glyph: debris_glyphs[commit.deletions % debris_glyphs.len()],
                        life: 20 + commit.deletions.min(30),
                    });
                }
            }

            // Merges or new branches split the coral network
            if commit.parents > 1 || commit.additions > 20 {
                let active_count = branches.iter().filter(|b| b.active).count();
                if active_count < 25 {
                    let parent_x = branches.last().map(|b| b.x).unwrap_or((width / 2) as f32);
                    let spread = (commit.additions as f32 * 0.1).sin() * 0.8;
                    branches.push(CoralBranch {
                        x: parent_x,
                        y: (height - 2) as f32,
                        angle: -std::f32::consts::FRAC_PI_2 + spread,
                        length: 0,
                        max_length: 8 + (commit.additions % 12),
                        glyph: glyphs[commit.additions % glyphs.len()],
                        color_code: color,
                        active: true,
                    });
                }
            }
        }

        // Advance growing coral branches
        let mut new_branches = Vec::new();
        for b in branches.iter_mut() {
            if !b.active {
                continue;
            }

            let cx = b.x.round() as usize;
            let cy = b.y.round() as usize;

            if cx < width && cy < height {
                grid[cy][cx] = (b.glyph, b.color_code);
            }

            b.x += b.angle.cos() * 0.8;
            b.y += b.angle.sin() * 0.6;
            b.length += 1;

            // Curving stems simulating ocean currents
            b.angle += ((frame as f32 * 0.1).sin() * 0.15);

            if b.length >= b.max_length || b.y <= 2.0 || b.x <= 1.0 || b.x >= (width - 2) as f32 {
                b.active = false;
                // Branching off tip
                if b.max_length > 4 {
                    new_branches.push(CoralBranch {
                        x: b.x,
                        y: b.y,
                        angle: b.angle - 0.5,
                        length: 0,
                        max_length: b.max_length / 2 + 2,
                        glyph: '~',
                        color_code: b.color_code,
                        active: true,
                    });
                    new_branches.push(CoralBranch {
                        x: b.x,
                        y: b.y,
                        angle: b.angle + 0.5,
                        length: 0,
                        max_length: b.max_length / 2 + 2,
                        glyph: '*',
                        color_code: b.color_code,
                        active: true,
                    });
                }
            }
        }
        branches.extend(new_branches);

        // Render buffer
        let mut stdout = io::stdout();
        print!("\x1b[H"); // Move cursor to top-left

        // Copy grid for rendering debris overlay
        let mut display_grid = grid.clone();

        // Update and render skeletal debris floating upwards
        debris_particles.retain_mut(|p| {
            p.x += p.vx + ((frame as f32 * 0.2).cos() * 0.2);
            p.y += p.vy;
            p.life = p.life.saturating_sub(1);

            let dx = p.x.round() as i32;
            let dy = p.y.round() as i32;

            if dx >= 0 && dx < width as i32 && dy >= 0 && dy < height as i32 && p.life > 0 {
                display_grid[dy as usize][dx as usize] = (p.glyph, "\x1b[38;5;242m"); // Dim bone-gray
                true
            } else {
                false
            }
        });

        // Draw header and display buffer
        println!("\x1b[1;36m=== GIT CORAL REEF VISUALIZER ===\x1b[0m Commits Processed: {}/{}", commit_idx, commits.len());
        for y in 0..height {
            for x in 0..width {
                let (ch, col) = display_grid[y][x];
                print!("{}{}", col, ch);
            }
            println!("\x1b[0m");
        }

        stdout.flush()?;
        thread::sleep(Duration::from_millis(80));
        frame += 1;

        if commit_idx >= commits.len() && debris_particles.is_empty() && !branches.iter().any(|b| b.active) {
            break;
        }
    }

    print!("\x1b[?25h\nReef ecosystem stabilized.\n");
    Ok(())
}

// Ingest git log data via CLI subprocess
fn fetch_git_history(repo_path: &str) -> io::Result<Vec<Commit>> {
    let output = Command::new("git")
        .arg("-C")
        .arg(repo_path)
        .arg("log")
        .arg("--numstat")
        .arg("--parents")
        .arg("--pretty=format:COMMIT|%an|%p")
        .output()?;

    if !output.status.success() {
        return Ok(Vec::new());
    }

    let text = String::from_utf8_lossy(&output.stdout);
    let mut commits = Vec::new();
    let mut current_author = String::new();
    let mut current_parents = 1;
    let mut additions = 0;
    let mut deletions = 0;

    for line in text.lines() {
        if line.starts_with("COMMIT|") {
            if !current_author.is_empty() {
                commits.push(Commit {
                    author: current_author.clone(),
                    additions,
                    deletions,
                    parents: current_parents,
                });
            }
            let parts: Vec<&str> = line.split('|').collect();
            current_author = parts.get(1).unwrap_or(&"Unknown").to_string();
            let parents_str = parts.get(2).unwrap_or(&"");
            current_parents = parents_str.split_whitespace().count();
            additions = 0;
            deletions = 0;
        } else {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                additions += parts[0].parse::<usize>().unwrap_or(0);
                deletions += parts[1].parse::<usize>().unwrap_or(0);
            }
        }
    }

    if !current_author.is_empty() {
        commits.push(Commit {
            author: current_author,
            additions,
            deletions,
            parents: current_parents,
        });
    }

    commits.reverse(); // Process chronologically from root
    Ok(commits)
}