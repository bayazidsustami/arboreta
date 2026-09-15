use std::io::{self, Write};
use std::thread;
use std::time::Duration;

// Defines extinct species that can temporarily manifest within the terrarium
#[derive(Clone)]
enum ExtinctSpecies {
    Dodo,
    Ammonite,
    Mammoth,
}

impl ExtinctSpecies {
    fn name(&self) -> &str {
        match self {
            ExtinctSpecies::Dodo => "Dodo Bird (Resurrected via Humidity Spike)",
            ExtinctSpecies::Ammonite => "Ammonite (Resurrected via Pressure Flux)",
            ExtinctSpecies::Mammoth => "Woolly Mammoth (Resurrected via Thermal Drop)",
        }
    }
}

// Represents a temporary phantom entity wandering the ASCII grid
struct Spirit {
    species: ExtinctSpecies,
    x: usize,
    y: usize,
    lifespan: usize,
}

fn main() {
    let width = 60;
    let height = 14;
    let mut spirits: Vec<Spirit> = Vec::new();
    let mut step = 0;

    // Hide terminal cursor and clear screen for a clean simulation loop
    print!("\x1B[?25l\x1B[2J");

    loop {
        // Simulate real-time weather fluctuation using wave functions
        let humidity = 50.0 + (step as f64 * 0.25).sin() * 35.0 + ((step * 3) % 10) as f64 - 5.0;
        let acoustic_threshold_crossed = humidity > 75.0 || humidity < 25.0 || (step % 8 == 0);

        // Trigger resurrection events when humidity/acoustic thresholds shift
        if acoustic_threshold_crossed && spirits.len() < 3 {
            let species = match step % 3 {
                0 => ExtinctSpecies::Dodo,
                1 => ExtinctSpecies::Ammonite,
                _ => ExtinctSpecies::Mammoth,
            };
            spirits.push(Spirit {
                species,
                x: 8 + (step * 5) % (width - 16),
                y: height - 3,
                lifespan: 10, // Fades after 10 ticks
            });
        }

        // Age spirits and apply gentle wandering motion
        for s in &mut spirits {
            s.lifespan = s.lifespan.saturating_sub(1);
            if step % 2 == 0 && s.x > 2 {
                s.x -= 1;
            }
        }
        spirits.retain(|s| s.lifespan > 0);

        // Reset cursor to top-left for smooth terminal rendering
        print!("\x1B[H");
        println!("=================== LIVING ASCII TERRARIUM ===================");
        println!("Weather Report -> Humidity: {:+.1}% | Active Echoes: {}", humidity, spirits.len());
        println!("{}", "-".repeat(width + 2));

        // Build grid canvas
        let mut grid = vec![vec![' '; width]; height];

        // Render baseline soil and bedrock
        for x in 0..width {
            grid[height - 1][x] = '=';
            grid[height - 2][x] = '.';
        }

        // Render permanent terrarium flora (ferns/moss)
        let flora_positions = vec![12, 28, 45];
        for &fx in &flora_positions {
            if fx < width {
                grid[height - 3][fx] = 'Ψ';
            }
        }

        // Render resurrected extinct species onto the grid
        let mut current_spectacle = String::from("Ecosystem dormant. Awaiting threshold breach...");
        for s in &spirits {
            if s.y < height && s.x < width {
                let symbol = match s.species {
                    ExtinctSpecies::Dodo => 'd',
                    ExtinctSpecies::Ammonite => '@',
                    ExtinctSpecies::Mammoth => 'M',
                };
                grid[s.y][s.x] = symbol;
                current_spectacle = format!("✨ PHANTOM MANIFESTATION: {}", s.species.name());
            }
        }

        // Output grid rows to terminal
        for row in &grid {
            let line: String = row.iter().collect();
            println!("|{}|", line);
        }
        println!("{}", "-".repeat(width + 2));
        println!("{}", current_spectacle);
        println!("Legend: 'd' = Dodo, '@' = Ammonite, 'M' = Mammoth, 'Ψ' = Flora");

        io::stdout().flush().unwrap();
        
        thread::sleep(Duration::from_millis(350));
        step += 1;

        // Graceful exit condition after 90 steps
        if step > 90 {
            break;
        }
    }

    // Restore terminal cursor on exit
    print!("\x1B[?25h\n");
}