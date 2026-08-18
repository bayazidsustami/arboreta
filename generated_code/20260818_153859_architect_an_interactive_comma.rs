use std::io::{self, Write};
use std::thread;
use std::time::Duration;

// --- Weather Data Simulation (Fluid Dynamics & Atmosphere) ---
#[derive(Clone, Copy)]
struct WindVector {
    dx: f32,
    dy: f32,
    speed: f32,
}

struct Atmosphere {
    wind: WindVector,
    humidity: f32,
    temperature: f32,
    tick: u64,
}

impl Atmosphere {
    fn new() -> Self {
        Self {
            wind: WindVector { dx: 1.0, dy: 0.2, speed: 1.5 },
            humidity: 0.6,
            temperature: 22.0,
            tick: 0,
        }
    }

    // Mutates atmospheric fluid dynamics over time (simulating real-time weather changes)
    fn update(&mut self) {
        self.tick += 1;
        let time = self.tick as f32 * 0.1;
        
        // Fluid dynamics: oscillating vector fields driven by atmospheric wave functions
        self.wind.dx = (time.sin() * 1.5) + (time * 0.3).cos();
        self.wind.dy = (time.cos() * 0.8) + (time * 0.5).sin();
        self.wind.speed = (self.wind.dx.powi(2) + self.wind.dy.powi(2)).sqrt();

        // Temperature & Humidity fluctuate based on wind pressure
        self.humidity = (0.5 + (time * 0.05).sin() * 0.4).clamp(0.1, 1.0);
        self.temperature = 15.0 + (time * 0.08).cos() * 10.0;
    }
}

// --- Digital Ecosystem Entities ---
#[derive(Clone, Copy, PartialEq)]
enum EntityType {
    Spore,
    FloraStem,
    FloraBloom,
    Fauna,
    Decay,
}

#[derive(Clone)]
struct Organism {
    x: f32,
    y: f32,
    entity_type: EntityType,
    energy: f32,
    age: u32,
    glyph: char,
}

impl Organism {
    fn new_spore(x: f32, y: f32) -> Self {
        Self {
            x,
            y,
            entity_type: EntityType::Spore,
            energy: 10.0,
            age: 0,
            glyph: '.',
        }
    }

    // Ecosystem logic: Entities mutate, drift with wind, grow, or decay into energy
    fn step(&mut self, atmos: &Atmosphere, width: usize, height: usize) -> Option<Organism> {
        self.age += 1;
        let mut child = None;

        match self.entity_type {
            EntityType::Spore => {
                // Drift heavily with fluid wind dynamics
                self.x += atmos.wind.dx * atmos.wind.speed * 0.5;
                self.y += atmos.wind.dy * atmos.wind.speed * 0.3;
                self.glyph = if atmos.wind.speed > 1.2 { '~' } else { '.' };

                // Mutation into Flora when landing on fertile ground (low wind speed, high humidity)
                if atmos.humidity > 0.4 && atmos.wind.speed < 1.8 && self.age > 5 {
                    self.entity_type = EntityType::FloraStem;
                    self.glyph = '|';
                    self.energy = 20.0;
                }
            }
            EntityType::FloraStem => {
                self.energy -= 0.2;
                // High temperature drives blooming mutation
                if self.age > 10 && atmos.temperature > 18.0 {
                    self.entity_type = EntityType::FloraBloom;
                    self.glyph = '*';
                    // Spawns Fauna or Spores dependent on high energy
                    if atmos.humidity > 0.6 {
                        child = Some(Organism {
                            x: self.x + 1.0,
                            y: self.y,
                            entity_type: EntityType::Fauna,
                            energy: 15.0,
                            age: 0,
                            glyph: '&',
                        });
                    }
                }
            }
            EntityType::FloraBloom => {
                self.energy -= 0.5;
                // Strong wind strips seeds away from blooming flora
                if atmos.wind.speed > 1.5 && self.age % 4 == 0 {
                    child = Some(Organism::new_spore(self.x, self.y));
                }
            }
            EntityType::Fauna => {
                // Fauna moves semi-autonomously against/with atmospheric forces
                self.x += (self.age as f32 * 0.2).cos() + (atmos.wind.dx * 0.2);
                self.y += (self.age as f32 * 0.2).sin() + (atmos.wind.dy * 0.2);
                self.energy -= 0.8;
                self.glyph = match self.age % 4 {
                    0 => 'v',
                    1 => '>',
                    2 => '^',
                    _ => '<',
                };
            }
            EntityType::Decay => {
                self.energy -= 1.0;
                self.glyph = '#';
            }
        }

        // Severe weather forces decay
        if self.energy <= 0.0 || self.age > 100 || atmos.wind.speed > 3.0 {
            if self.entity_type != EntityType::Decay {
                self.entity_type = EntityType::Decay;
                self.energy = 5.0; // Decay lasts a few frames
                self.glyph = 'x';
            }
        }

        // Screen boundary wrapping
        self.x = (self.x + width as f32) % width as f32;
        self.y = (self.y + height as f32) % height as f32;

        child
    }
}

// --- Renderer & Ecosystem Canvas ---
struct World {
    width: usize,
    height: usize,
    atmos: Atmosphere,
    organisms: Vec<Organism>,
}

impl World {
    fn new(width: usize, height: usize) -> Self {
        let mut organisms = Vec::new();
        // Seed initial spores
        for i in 0..15 {
            organisms.push(Organism::new_spore(
                (i * 5 % width) as f32,
                (i * 3 % height) as f32,
            ));
        }

        Self {
            width,
            height,
            atmos: Atmosphere::new(),
            organisms,
        }
    }

    fn update(&mut self) {
        self.atmos.update();

        let mut children = Vec::new();
        for org in self.organisms.iter_mut() {
            if let Some(child) = org.step(&self.atmos, self.width, self.height) {
                children.push(child);
            }
        }

        self.organisms.extend(children);
        // Purge dead energy elements
        self.organisms.retain(|o| o.energy > 0.0);

        // Cap population for stability
        if self.organisms.len() > 120 {
            self.organisms.drain(0..30);
        }
    }

    fn render(&self) {
        let mut grid = vec![vec![' '; self.width]; self.height];

        // Draw organisms onto grid
        for org in &self.organisms {
            let cx = org.x as usize % self.width;
            let cy = org.y as usize % self.height;
            grid[cy][cx] = org.glyph;
        }

        // Clear terminal frame
        print!("\x1B[2J\x1B[1;1H");

        // Display atmospheric diagnostics dashboard
        println!("+=== ATMOSPHERIC ECOSYSTEM ENGINE ===================================+");
        println!(
            "| Temp: {:4.1}°C | Humid: {:3.0}% | Wind Vector: ({:5.2}, {:5.2}) Speed: {:4.2}m/s |",
            self.atmos.temperature,
            self.atmos.humidity * 100.0,
            self.atmos.wind.dx,
            self.atmos.wind.dy,
            self.atmos.wind.speed
        );
        println!("+====================================================================+");

        // Render ecosystem view
        for row in grid {
            let line: String = row.into_iter().collect();
            println!("|{}|", line);
        }
        println!("+--------------------------------------------------------------------+");
        println!(" Entity Key: . Spore | | Stem | * Bloom | v/& Fauna | x/# Decay");

        io::stdout().flush().unwrap();
    }
}

fn main() {
    let width = 68;
    let height = 18;
    let mut world = World::new(width, height);

    // Main real-time simulation loop
    loop {
        world.update();
        world.render();
        thread::sleep(Duration::from_millis(150));
    }
}