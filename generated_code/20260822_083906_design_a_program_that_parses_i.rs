use std::{thread, time::Duration};

// Parses source code as terrain; organisms carve bioluminescent trails through ASCII space.
const SOURCE: &str = include_str!(file!());

struct Organism {
    x: usize,
    y: usize,
    energy: usize,
    dir: (isize, isize),
}

fn main() {
    let lines: Vec<Vec<char>> = SOURCE.lines().map(|l| l.chars().collect()).collect();
    let height = lines.len();
    let width = lines.iter().map(|l| l.len()).max().unwrap_or(0);

    // Grid tracking trail intensity/glow (0 = none, higher = brighter)
    let mut trail = vec![vec![0u8; width]; height];
    
    // Spawn initial organisms based on ASCII density
    let mut bugs: Vec<Organism> = Vec::new();
    for (y, line) in lines.iter().enumerate() {
        for (x, &ch) in line.iter().enumerate() {
            if ch as u8 % 17 == 0 {
                bugs.push(Organism { x, y, energy: 20, dir: (1, 0) });
            }
        }
    }

    print!("\x1B[2J\x1B[?25l"); // Clear screen, hide cursor

    for _tick in 0..300 {
        // Fade trails over time
        for row in &mut trail {
            for cell in row {
                *cell = cell.saturating_sub(1);
            }
        }

        // Simulate organisms
        let mut new_bugs = Vec::new();
        for bug in &mut bugs {
            if bug.energy == 0 { continue; }

            // Leave a glowing trail on current cell
            trail[bug.y][bug.x] = 5;

            // Terrain friction: denser ASCII characters cost more energy
            let current_char = lines.get(bug.y).and_then(|r| r.get(bug.x)).copied().unwrap_or(' ');
            let terrain_cost = if current_char.is_alphanumeric() { 2 } else { 1 };
            bug.energy = bug.energy.saturating_sub(terrain_cost);

            // Turn randomly or follow character density gradient
            let dirs = [(0, 1), (1, 0), (0, -1), (-1, 0), (1, 1), (-1, -1)];
            let (dx, dy) = dirs[(bug.x + bug.y + _tick) % dirs.len()];
            
            let nx = (bug.x as isize + dx).rem_euclid(width as isize) as usize;
            let ny = (bug.y as isize + dy).rem_euclid(height as isize) as usize;

            bug.x = nx;
            bug.y = ny;

            // Reproduce if standing on rare punctuation symbols
            if "!{}()[];,".contains(current_char) && bug.energy > 10 {
                bug.energy /= 2;
                new_bugs.push(Organism { x: nx, y: ny, energy: bug.energy, dir: (-dx, -dy) });
            }
        }

        bugs.retain(|b| b.energy > 0);
        bugs.append(&mut new_bugs);

        // Render frame
        print!("\x1B[1;1H"); // Move cursor home
        for y in 0..height {
            for x in 0..width {
                let ch = lines.get(y).and_then(|r| r.get(x)).copied().unwrap_or(' ');
                let glow = trail[y][x];
                let is_bug = bugs.iter().any(|b| b.x == x && b.y == y);

                if is_bug {
                    print!("\x1B[38;5;198m\x1B[1mo\x1B[0m"); // Vibrant magenta organism
                } else if glow > 3 {
                    print!("\x1B[38;5;82m{}\x1B[0m", ch); // Bright neon green trail
                } else if glow > 0 {
                    print!("\x1B[38;5;34m{}\x1B[0m", ch); // Dim teal trail
                } else {
                    print!("\x1B[38;5;239m{}\x1B[0m", ch); // Darkened unvisited code
                }
            }
            println!();
        }

        thread::sleep(Duration::from_millis(60));
    }

    print!("\x1B[?25h"); // Restore cursor
}