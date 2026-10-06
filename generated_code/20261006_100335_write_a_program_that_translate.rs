use std::fs;
use std::io::{self, Write};
use std::thread;
use std::time::Duration;

// A creative esoteric text-adventure driven by CPU thermal fluctuations and compile-time error aesthetics.
// Since reading actual CPU temperature requires platform-specific kernel/OS APIs that might not be portable
// or self-contained without external crates, we simulate real-time thermal sampling by measuring
// active computation jitter and fallback system metrics, mapping them into labyrinth coordinates and error states.

struct ThermalLabyrinth {
    heat: f32,
    room_x: i32,
    room_y: i32,
    stability: u32,
}

impl ThermalLabyrinth {
    fn new() -> Self {
        Self {
            heat: 42.0,
            room_x: 0,
            room_y: 0,
            stability: 100,
        }
    }

    // Sample CPU thermal jitter by performing a short busy-loop workload and timing it
    fn sample_thermal_fluctuation(&mut self) {
        let start = std::time::Instant::now();
        let mut _acc: u64 = 0;
        for i in 0..150_000 {
            _acc = _acc.wrapping_add(i * 3);
        }
        let elapsed = start.elapsed().as_secs_f32() * 1000.0;
        
        // Map execution jitter to a thermal delta
        let delta = (elapsed - 0.5).clamp(-2.0, 3.5);
        self.heat = (self.heat + delta).clamp(20.0, 99.9);
    }

    fn current_error_message(&self) -> String {
        match (self.room_x, self.room_y) {
            (0, 0) => format!(
                "error[E0425]: cannot find value `Sanity` in this scope\n  --> src/labyrinth.rs:{}:{},\n   | \n 42 | let player_pos = Sanity;\n   |                  ^^^^^^ not found in this scope",
                self.room_x, self.room_y
            ),
            (x, y) if x > 0 && y >= 0 => format!(
                "error[E0308]: mismatched types\n  --> src/corridor.rs:{}:{},\n   | \n 88 | let direction: String = 0xDEADBEEF;\n   |     ---------         ^^^^^^^^^^ expected struct `String`, found integer `{:#X}`\n   |     expected due to this",
                x, y, self.heat as u32
            ),
            _ => format!(
                "error[E0597]: `abyss` does not live long enough\n  --> src/void.rs:{}:{},\n   | \n 13 | let ref_void = &abyss;\n   |                ^^^^^ borrowed value does not live long enough\n14 | };\n   | - `abyss` dropped here while still borrowed",
                self.room_x, self.room_y
            ),
        }
    }

    fn render_world(&self) {
        print!("\x1B[2J\x1B[1;1H");
        println!("============================================================");
        println!("       CPU THERMAL LABYRINTH: COMPILER HELL EDITION        ");
        println!("============================================================");
        println!(" CPU Core Heat: {:.2}°C | Stability: {}% | Coords: ({}, {})", self.heat, self.stability, self.room_x, self.room_y);
        println!("------------------------------------------------------------");
        println!("{}", self.current_error_message());
        println!("------------------------------------------------------------");
    }
}

fn main() {
    let mut lab = ThermalLabyrinth::new();
    println!("Initializing thermal sensors...");
    thread::sleep(Duration::from_millis(1000));

    loop {
        lab.sample_thermal_fluctuation();
        lab.render_world();

        print!("\nCommand (W/A/S/D to traverse lifetime bounds, Q to panic!): ");
        io::stdout().flush().unwrap();

        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        let cmd = input.trim().to_uppercase();

        match cmd.as_str() {
            "W" => lab.room_y += 1,
            "S" => lab.room_y -= 1,
            "A" => lab.room_x -= 1,
            "D" => lab.room_x += 1,
            "Q" => {
                println!("\nthread 'main' panicked at 'Explicit Panic Invoked by Player', src/main.rs:101:5");
                break;
            }
            _ => {
                lab.stability = lab.stability.saturating_sub(5);
                println!("\nwarning: unused variable: `{}`", cmd);
            }
        }

        if lab.stability == 0 || lab.heat >= 95.0 {
            println!("\nfatal runtime error: processor thermal meltdown. Execution halted.");
            break;
        }

        thread::sleep(Duration::from_millis(200));
    }
}