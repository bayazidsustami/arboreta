// A living source file: Cellular Automaton + MIDI Fugue Generator
// Compiles and runs with standard Rust toolchain (no external dependencies).

use std::fs::File;
use std::io::{self, Write};

// Cellular Automaton representing mutating code/comment states
struct Automaton {
    grid: Vec<Vec<u8>>,
    width: usize,
    height: usize,
}

impl Automaton {
    fn new(width: usize, height: usize) -> Self {
        let mut grid = vec![vec![0; width]; height];
        let glider = [(0, 1), (1, 2), (2, 0), (2, 1), (2, 2)];
        for &(r, c) in &glider {
            if r < height && c < width {
                grid[r][c] = 1;
            }
        }
        Self { grid, width, height }
    }

    fn step(&mut self) {
        let mut next = self.grid.clone();
        for r in 0..self.height {
            for c in 0..self.width {
                let mut neighbors = 0;
                for dr in [-1, 0, 1] {
                    for dc in [-1, 0, 1] {
                        if dr == 0 && dc == 0 { continue; }
                        let nr = (r as i32 + dr).rem_euclid(self.height as i32) as usize;
                        let nc = (c as i32 + dc).rem_euclid(self.width as i32) as usize;
                        neighbors += self.grid[nr][nc] as usize;
                    }
                }
                if self.grid[r][c] == 1 {
                    next[r][c] = if neighbors == 2 || neighbors == 3 { 1 } else { 0 };
                } else {
                    next[r][c] = if neighbors == 3 { 1 } else { 0 };
                }
            }
        }
        self.grid = next;
    }

    fn render_to_comment(&self) -> String {
        let mut s = String::new();
        for row in &self.grid {
            s.push_str("// ");
            for &cell in row {
                s.push(if cell == 1 { '#' } else { '.' });
            }
            s.push('\n');
        }
        s
    }
}

fn write_var_len(mut value: u32, buf: &mut Vec<u8>) {
    let mut bytes = Vec::new();
    bytes.push((value & 0x7F) as u8);
    value >>= 7;
    while value > 0 {
        bytes.push(((value & 0x7F) | 0x80) as u8);
        value >>= 7;
    }
    bytes.reverse();
    buf.extend_from_slice(&bytes);
}

fn generate_fugue_midi() -> io::Result<()> {
    let mut events: Vec<(u32, u8, u8, u8)> = Vec::new();

    // 4-voice fugue subject motif
    let subject = vec![
        (60, 480), (62, 480), (63, 480), (60, 480),
        (67, 960), (65, 480), (63, 480), (62, 960),
    ];

    let mut add_voice = |start_tick: u32, transpose: i32, channel: u8| {
        let mut current_tick = start_tick;
        for &(pitch, dur) in &subject {
            let p = (pitch as i32 + transpose) as u8;
            events.push((current_tick, 0x90 | channel, p, 90));
            current_tick += dur;
            events.push((current_tick, 0x80 | channel, p, 0));
        }
    };

    add_voice(0, 0, 0);
    add_voice(960, 7, 1);
    add_voice(1920, 0, 2);
    add_voice(2880, 7, 3);

    events.sort_by_key(|e| e.0);

    let mut last_tick = 0;
    let mut encoded_track = Vec::new();
    
    // Tempo meta-event (120 BPM)
    encoded_track.push(0x00);
    encoded_track.extend_from_slice(&[0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20]);

    for &(tick, status, d1, d2) in &events {
        let delta = tick - last_tick;
        write_var_len(delta, &mut encoded_track);
        encoded_track.push(status);
        encoded_track.push(d1);
        encoded_track.push(d2);
        last_tick = tick;
    }

    encoded_track.extend_from_slice(&[0x00, 0xFF, 0x2F, 0x00]);

    let mut file = File::create("fugue.mid")?;
    file.write_all(b"MThd")?;
    file.write_all(&6u32.to_be_bytes())?;
    file.write_all(&0u16.to_be_bytes())?;
    file.write_all(&1u16.to_be_bytes())?;
    file.write_all(&480u16.to_be_bytes())?;

    file.write_all(b"MTrk")?;
    file.write_all(&(encoded_track.len() as u32).to_be_bytes())?;
    file.write_all(&encoded_track)?;

    Ok(())
}

fn main() {
    println!("=== Living Source Automaton & MIDI Fugue Synthesizer ===");
    
    let mut ca = Automaton::new(16, 8);
    println!("\n[Initial Cellular Automaton State / Comment Block]:");
    print!("{}", ca.render_to_comment());

    for i in 1..=3 {
        ca.step();
        println!("\n[Evolution Step {}]:", i);
        print!("{}", ca.render_to_comment());
    }

    match generate_fugue_midi() {
        Ok(_) => println!("\n[Success] Generated polyphonic 4-voice fugue MIDI file: 'fugue.mid'"),
        Err(e) => eprintln!("\n[Error] Failed to write MIDI file: {}", e),
    }
}