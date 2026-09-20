use std::fmt;
use std::thread;
use std::time::Duration;

const WIDTH: usize = 40;
const HEIGHT: usize = 20;

#[derive(Clone, Copy, PartialEq)]
enum CellState {
    Lead,    // Dark borders like stained glass
    Ruby,    // Encoded bit 1
    Azure,   // Encoded bit 0
    Gold,    // Control/Metadata
    Fracture,// Damaged by memory leak
}

impl fmt::Display for CellState {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let symbol = match self {
            CellState::Lead => "█",
            CellState::Ruby => "♦",
            CellState::Azure => "◆",
            CellState::Gold => "✦",
            CellState::Fracture => "╱",
        };
        write!(f, "{}", symbol)
    }
}

struct StainedGlassCA {
    grid: [[CellState; WIDTH]; HEIGHT],
    leak_active: bool,
    generation: usize,
}

impl StainedGlassCA {
    // Encodes arbitrary text into the initial CA grid state simulating stained glass panels
    fn new(text: &str) -> Self {
        let mut grid = [[CellState::Lead; WIDTH]; HEIGHT];
        let bytes = text.as_bytes();
        
        let mut byte_idx = 0;
        for y in 1..HEIGHT-1 {
            for x in 1..WIDTH-1 {
                // Create geometric lead partitions for the window
                if x % 8 == 0 || y % 5 == 0 {
                    grid[y][x] = CellState::Lead;
                } else if byte_idx < bytes.len() {
                    let b = bytes[byte_idx];
                    grid[y][x] = if (b & (1 << (byte_idx % 8))) != 0 {
                        CellState::Ruby
                    } else {
                        CellState::Azure
                    };
                    if x % 7 == 0 { byte_idx += 1; }
                } else {
                    grid[y][x] = CellState::Gold;
                }
            }
        }

        Self {
            grid,
            leak_active: false,
            generation: 0,
        }
    }

    // Simulate a memory leak event causing structural fractures across the glass
    fn trigger_memory_leak(&mut self) {
        self.leak_active = true;
        let mut leaked_cells = 0;
        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                if (x + y + self.generation) % 11 == 0 {
                    self.grid[y][x] = CellState::Fracture;
                    leaked_cells += 1;
                }
            }
        }
        // Allocate unmanaged memory dynamically to visually substantiate the leak
        let _leak_simulation: Vec<Vec<u8>> = vec![vec![0; 1024 * 1024]; leaked_cells.max(1)];
    }

    // Advance cellular automaton rules (stained glass crystallization dynamics)
    fn step(&mut self) {
        let mut next_grid = self.grid;
        for y in 1..HEIGHT-1 {
            for x in 1..WIDTH-1 {
                if self.grid[y][x] == CellState::Fracture {
                    continue; 
                }
                
                let mut ruby_count = 0;
                let mut azure_count = 0;
                for dy in -1..=1 {
                    for dx in -1..=1 {
                        if dx == 0 && dy == 0 { continue; }
                        let ny = (y as isize + dy) as usize;
                        let nx = (x as isize + dx) as usize;
                        match self.grid[ny][nx] {
                            CellState::Ruby => ruby_count += 1,
                            CellState::Azure => azure_count += 1,
                            _ => {}
                        }
                    }
                }

                // Stress propagation rule
                if self.leak_active && (ruby_count + azure_count > 6) {
                    next_grid[y][x] = CellState::Fracture;
                }
            }
        }
        self.grid = next_grid;
        self.generation += 1;
    }

    // Render the stained glass window grid to standard output
    fn render(&self) {
        print!("\x1B[2J\x1B[1;1H");
        println!("=== STAINED GLASS CA COMPRESSION & MEMORY LEAK MONITOR ===");
        println!("Generation: {} | Leak Status: {}", self.generation, if self.leak_active { "ACTIVE (FRACTURING)" } else { "STABLE" });
        println!("{}", "═".repeat(WIDTH * 2));
        
        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                print!("{} ", self.grid[y][x]);
            }
            println!();
        }
        println!("{}", "═".repeat(WIDTH * 2));
    }
}

fn main() {
    let secret_message = "Rust memory safety meets cellular automata and stained glass aesthetics!";
    let mut window = StainedGlassCA::new(secret_message);

    for gen in 1..=12 {
        window.render();
        window.step();
        
        // Induce a memory leak halfway through execution
        if gen == 6 {
            window.trigger_memory_leak();
        }
        
        thread::sleep(Duration::from_millis(300));
    }
    
    println!("Compression and structural integrity test complete.");
}