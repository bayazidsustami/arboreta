use std::io::{self, Write};
use std::thread;
use std::time::Duration;

// Terminal dimensions for our watercolor grid canvas
const WIDTH: usize = 60;
const HEIGHT: usize = 20;

// Represents a single cell in our musical grid language
#[derive(Clone, Copy)]
struct Cell {
    moisture: f32,   // Watercolor wetness (0.0 to 1.0)
    pigment: f32,    // Storm cloud density/darkness (0.0 to 1.0)
    lightning: f32,  // Electric charge / flash intensity (0.0 to 1.0)
    frequency: f32,  // Musical frequency in Hz (e.g., 110.0 to 880.0)
}

struct Grid {
    cells: [[Cell; WIDTH]; HEIGHT],
    frame: usize,
}

impl Grid {
    fn new() -> Self {
        let mut cells = [[Cell {
            moisture: 0.1,
            pigment: 0.0,
            lightning: 0.0,
            frequency: 220.0,
        }; WIDTH]; HEIGHT];

        // Initialize grid with varying base frequencies (pentatonic scale seeds)
        let pentatonic = [130.81, 146.83, 164.81, 196.00, 220.00, 261.63, 293.66, 329.63];
        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                let note_idx = (x + y) % pentatonic.len();
                cells[y][x].frequency = pentatonic[note_idx];
            }
        }

        Grid { cells, frame: 0 }
    }

    // Step the simulation: watercolor diffusion + thunderstorm dynamics + frequency modulation
    fn update(&mut self) {
        self.frame += 1;
        let mut next_cells = self.cells;

        // Random lightning strike trigger
        let is_lightning_frame = self.frame % 18 == 0 || self.frame % 43 == 0;
        let strike_x = (self.frame * 17) % WIDTH;

        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                let mut c = self.cells[y][x];

                // 1. Watercolor Diffusion (blur moisture and pigment with neighbors)
                let mut avg_moisture = c.moisture;
                let mut avg_pigment = c.pigment;
                let mut count = 1.0;

                for dy in [-1, 0, 1] {
                    for dx in [-1, 0, 1] {
                        if dx == 0 && dy == 0 { continue; }
                        let ny = (y as isize + dy) as usize;
                        let nx = (x as isize + dx) as usize;
                        if ny < HEIGHT && nx < WIDTH {
                            avg_moisture += self.cells[ny][nx].moisture;
                            avg_pigment += self.cells[ny][nx].pigment;
                            count += 1.0;
                        }
                    }
                }

                c.moisture = (c.moisture * 0.6) + ((avg_moisture / count) * 0.4);
                c.pigment = (c.pigment * 0.7) + ((avg_pigment / count) * 0.3);

                // 2. Thunderstorm Rain & Wind Dynamics
                if y == 0 {
                    // Rain entering from the top
                    if (x + self.frame) % 5 == 0 {
                        c.moisture = 1.0;
                        c.pigment = 0.8;
                    }
                } else {
                    // Gravity pulling moisture down
                    let upper = self.cells[y - 1][x];
                    c.moisture += upper.moisture * 0.15;
                    c.pigment += upper.pigment * 0.1;
                }

                // Evaporation
                c.moisture = (c.moisture - 0.02).max(0.0);
                c.pigment = (c.pigment - 0.01).max(0.0);

                // 3. Lightning Flash Propagation
                if is_lightning_frame {
                    let dist = (x as isize - strike_x as isize).abs();
                    if dist < 4 {
                        c.lightning = 1.0 - (dist as f32 * 0.25);
                        c.frequency *= 1.5; // Frequency shift during strike
                    }
                } else {
                    c.lightning = (c.lightning - 0.25).max(0.0);
                }

                // 4. Musical Frequency Grid Instruction (Harmonic drift)
                c.frequency += ((c.moisture - 0.5) * 2.0).sin() * 2.0;
                c.frequency = c.frequency.clamp(80.0, 600.0);

                next_cells[y][x] = c;
            }
        }

        self.cells = next_cells;
    }

    // Render the watercolor thunderstorm grid to the terminal using 24-bit ANSI TrueColor
    fn render(&self) {
        let mut output = String::new();
        
        // Move cursor to top-left and clear
        output.push_str("\x1b[H");
        output.push_str("=== 🌩️ WATERCOLOR THUNDERSTORM FREQUENCY SYNTHESIZER 🌩️ ===\r\n");

        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                let c = self.cells[y][x];

                // Calculate RGB color based on lightning, pigment, and moisture
                let r = ((c.lightning * 255.0) + (c.pigment * 40.0)) as u8;
                let g = ((c.lightning * 255.0) + (c.pigment * 50.0) + (c.moisture * 30.0)) as u8;
                let b = ((c.lightning * 255.0) + (c.pigment * 120.0) + (c.moisture * 100.0)) as u8;

                // Pick an artistic watercolor glyph based on density
                let glyph = if c.lightning > 0.5 {
                    '*'
                } else if c.pigment > 0.6 {
                    '#'
                } else if c.pigment > 0.3 {
                    '%'
                } else if c.moisture > 0.4 {
                    '~'
                } else if c.moisture > 0.1 {
                    '.'
                } else {
                    ' '
                };

                // Apply ANSI 24-bit background/foreground color
                output.push_str(&format!("\x1b[38;2;{};{};{}m{}\x1b[0m", r, g, b, glyph));
            }
            output.push_str("\r\n");
        }

        // Display live musical grid instruction metrics
        let center_freq = self.cells[HEIGHT / 2][WIDTH / 2].frequency;
        output.push_str(&format!(
            "Frame: {:03} | Center Tone: {:.1} Hz | Status: Evolving Watercolor Storm\r\n",
            self.frame, center_freq
        ));

        print!("{}", output);
        io::stdout().flush().unwrap();
    }
}

fn main() {
    // Clear terminal screen at start
    print!("\x1b[2J");
    io::stdout().flush().unwrap();

    let mut grid = Grid::new();

    // Run simulation loop for 120 frames
    for _ in 0..120 {
        grid.update();
        grid.render();
        thread::sleep(Duration::from_millis(80));
    }

    println!("\nThunderstorm simulation complete.");
}