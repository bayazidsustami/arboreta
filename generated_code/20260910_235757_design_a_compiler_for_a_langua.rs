use std::fs::File;
use std::io::{Read, Write};

// MIDI Opcode mappings derived from pitch classes (C, D, E, F, G, A, B)
#[derive(Debug, PartialEq)]
enum Opcode {
    Push(i32),    // Note C: Push value to stack
    Add,          // Note D: Add top two stack elements
    Sub,          // Note E: Subtract top two stack elements
    Mul,          // Note F: Multiply top two stack elements
    EmitSignal,   // Note G: Signal fractal trigger
    JumpIfZero,   // Note A: Control flow jump
    Halt,         // Note B: Halt execution
}

// Memory structure and hardware state representation
struct MidiCompilerVM {
    stack: Vec<i32>,
    pc: usize,
    program: Vec<(Opcode, u8)>, // Opcode and associated pitch key
    interrupt_triggered: bool,
    fractal_buffer: Vec<char>,
}

impl MidiCompilerVM {
    fn new() -> Self {
        Self {
            stack: Vec::new(),
            pc: 0,
            program: Vec::new(),
            interrupt_triggered: false,
            fractal_buffer: vec![' '; 1600],
        }
    }

    // Parses a simple binary MIDI stream into bytecode based on pitch classes
    fn compile_midi_bytes(&mut self, bytes: &[u8]) {
        let mut idx = 0;
        while idx < bytes.len() {
            // Locate MIDI "Note On" events (status byte 0x90 to 0x9F)
            if bytes[idx] & 0xF0 == 0x90 && idx + 2 < bytes.len() {
                let note = bytes[idx + 1];
                let velocity = bytes[idx + 2];
                if velocity > 0 {
                    let pitch_class = note % 12;
                    let opcode = match pitch_class {
                        0 => Opcode::Push(note as i32),
                        2 => Opcode::Add,
                        4 => Opcode::Sub,
                        5 => Opcode::Mul,
                        7 => Opcode::EmitSignal,
                        9 => Opcode::JumpIfZero,
                        11 => Opcode::Halt,
                        _ => Opcode::Push(1),
                    };
                    self.program.push((opcode, note));
                }
                idx += 3;
            } else {
                idx += 1;
            }
        }
    }

    // Calculates harmonic dissonance between adjacent active notes to trigger hardware interrupts
    fn calculate_dissonance(pitch1: u8, pitch2: u8) -> f32 {
        let diff = (pitch1 as i16 - pitch2 as i16).abs();
        match diff {
            1 | 6 | 11 => 1.0, // Tritones, minor 2nds, major 7ths create maximum dissonance
            2 | 10 => 0.6,
            3 | 4 | 8 | 9 => 0.3,
            _ => 0.0,
        }
    }

    // Hardware Interrupt Handler: Renders ASCII Julia Set Fractal Landscape
    fn trigger_fractal_interrupt(&mut self, intensity: f32) {
        println!("\n*** HARDWARE INTERRUPT: HARMONIC DISSONANCE DETECTED (Dissonance Score: {:.2}) ***", intensity);
        let width = 80;
        let height = 20;
        let c_re = -0.7 + (intensity * 0.1) as f64;
        let c_im = 0.27015;

        for y in 0..height {
            for x in 0..width {
                let mut zx = 1.5 * (x as f64 - width as f64 / 2.0) / (0.5 * width as f64);
                let mut zy = (y as f64 - height as f64 / 2.0) / (0.5 * height as f64);
                let mut i = 255;
                while zx * zx + zy * zy < 4.0 && i > 0 {
                    let tmp = zx * zx - zy * zy + c_re;
                    zy = 2.0 * zx * zy + c_im;
                    zx = tmp;
                    i -= 1;
                }
                let char_map = [' ', '.', ':', '-', '=', '+', '*', '%', '@', '#'];
                self.fractal_buffer[y * width + x] = char_map[i % char_map.len()];
            }
        }

        // Render buffer to terminal output
        for row in self.fractal_buffer.chunks(width) {
            let line: String = row.iter().collect();
            println!("{}", line);
        }
    }

    // Execute compiled VM program instructions
    fn execute(&mut self) {
        let mut prev_pitch: Option<u8> = None;

        while self.pc < self.program.len() {
            let (ref op, pitch) = self.program[self.pc];

            // Evaluate dissonance hardware interrupt check
            if let Some(last_p) = prev_pitch {
                let dissonance = Self::calculate_dissonance(last_p, pitch);
                if dissonance > 0.5 {
                    self.interrupt_triggered = true;
                    self.trigger_fractal_interrupt(dissonance);
                }
            }
            prev_pitch = Some(pitch);

            match op {
                Opcode::Push(val) => self.stack.push(*val),
                Opcode::Add => {
                    let b = self.stack.pop().unwrap_or(0);
                    let a = self.stack.pop().unwrap_or(0);
                    self.stack.push(a + b);
                }
                Opcode::Sub => {
                    let b = self.stack.pop().unwrap_or(0);
                    let a = self.stack.pop().unwrap_or(0);
                    self.stack.push(a - b);
                }
                Opcode::Mul => {
                    let b = self.stack.pop().unwrap_or(1);
                    let a = self.stack.pop().unwrap_or(1);
                    self.stack.push(a * b);
                }
                Opcode::EmitSignal => {
                    let val = self.stack.last().cloned().unwrap_or(0);
                    println!("[VM Output Stream] Signal Value emitted: {}", val);
                }
                Opcode::JumpIfZero => {
                    if let Some(&top) = self.stack.last() {
                        if top == 0 {
                            self.pc += 2;
                            continue;
                        }
                    }
                }
                Opcode::Halt => break,
            }
            self.pc += 1;
        }
    }
}

fn main() {
    // Generate an in-memory MIDI sequence containing harmonic dissonance and operations
    let synth_midi_data: Vec<u8> = vec![
        0x4D, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x01, 0x00, 0x60,
        0x4D, 0x54, 0x72, 0x6B, 0x00, 0x00, 0x00, 0x1B,
        0x00, 0x90, 0x3C, 0x64, // C4: Push(60)
        0x00, 0x90, 0x3D, 0x64, // C#4: Push(61) -> Dissonance Minor 2nd triggers interrupt
        0x00, 0x90, 0x3E, 0x64, // D4: Add
        0x00, 0x90, 0x43, 0x64, // G4: EmitSignal
        0x00, 0x90, 0x49, 0x64, // C#5 -> Tritone Dissonant jump
        0x00, 0x90, 0x47, 0x64, // B4: Halt
        0x00, 0xFF, 0x2F, 0x00,
    ];

    let mut vm = MidiCompilerVM::new();
    println!("Parsing MIDI binary stream and compiling to bytecode ops...");
    vm.compile_midi_bytes(&synth_midi_data);

    println!("Starting MIDI Bytecode Execution Unit...");
    vm.execute();
    println!("\nVM Execution Completed Successfully.");
}