use std::collections::HashMap;

// A playable note in our stack-based musical compiler.
#[derive(Debug, Clone)]
struct Note {
    pitch_hz: f32,
    duration_ms: u64,
}

// Stack-based VM instruction set.
#[derive(Debug, Clone)]
enum Op {
    Push(i64),
    Add,
    Sub,
    Dup,
    EmitScore, // Mutates code score in real-time
    Nop,
}

struct MusicalCompilerVM {
    stack: Vec<i64>,
    code: Vec<String>,
    ip: usize,
    pitch_bend_cents: f32,
}

impl MusicalCompilerVM {
    fn new(source: &str) -> Self {
        Self {
            stack: Vec::new(),
            code: source.lines().map(|s| s.trim().to_string()).collect(),
            ip: 0,
            pitch_bend_cents: 0.0,
        }
    }

    // Maps tokens to musical pitches (Sheet Music Score aspect).
    fn token_to_note(&self, token: &str) -> Note {
        let base_freq = match token {
            "PUSH" => 261.63, // C4
            "ADD"  => 329.63, // E4
            "SUB"  => 392.00, // G4
            "DUP"  => 440.00, // A4
            "EMIT" => 523.25, // C5
            _      => 220.00, // A3 (Fallback/Error tone)
        };

        // Apply real-time pitch bending from accumulated syntax errors
        let bent_freq = base_freq * 2.0f32.powf(self.pitch_bend_cents / 1200.0);
        Note {
            pitch_hz: bent_freq,
            duration_ms: 200,
        }
    }

    // Play/playhead step: Play note corresponding to token, compile/execute token.
    fn step(&mut self) -> Option<Note> {
        if self.ip >= self.code.len() {
            return None;
        }

        let line = self.code[self.ip].clone();
        self.ip += 1;

        let tokens: Vec<&str> = line.split_whitespace().collect();
        if tokens.is_empty() {
            return Some(Note { pitch_hz: 0.0, duration_ms: 50 });
        }

        let first_token = tokens[0];
        let note = self.token_to_note(first_token);

        // Compile & Execute token; any syntax error bends pitch in real-time
        match first_token {
            "PUSH" => {
                if tokens.len() > 1 {
                    if let Ok(val) = tokens[1].parse::<i64>() {
                        self.stack.push(val);
                    } else {
                        self.bend_pitch(50.0); // Syntax error: invalid number
                    }
                } else {
                    self.bend_pitch(100.0); // Syntax error: missing argument
                }
            }
            "ADD" => {
                if let (Some(b), Some(a)) = (self.stack.pop(), self.stack.pop()) {
                    self.stack.push(a + b);
                } else {
                    self.bend_pitch(-75.0); // Runtime/Syntax error: stack underflow
                }
            }
            "SUB" => {
                if let (Some(b), Some(a)) = (self.stack.pop(), self.stack.pop()) {
                    self.stack.push(a - b);
                } else {
                    self.bend_pitch(-75.0);
                }
            }
            "DUP" => {
                if let Some(&top) = self.stack.last() {
                    self.stack.push(top);
                } else {
                    self.bend_pitch(120.0);
                }
            }
            "EMIT" => {
                // Self-modification: dynamically rewrite future score lines using stack values
                if let Some(val) = self.stack.pop() {
                    let new_instruction = format!("PUSH {}", val * 2);
                    self.code.push(new_instruction);
                    self.code.push("ADD".to_string());
                } else {
                    self.bend_pitch(-150.0);
                }
            }
            _ => {
                // Syntax Error: Unrecognized token bends pitch severely!
                self.bend_pitch(200.0);
            }
        }

        Some(note)
    }

    fn bend_pitch(&mut self, cents: f32) {
        self.pitch_bend_cents += cents;
        println!("  [!] Syntax/Execution Error! Note pitch bent by {:+} cents (Total Bend: {:.1} cents)", cents, self.pitch_bend_cents);
    }
}

fn main() {
    // Initial score/source code containing valid stack instructions, intentional syntax errors, and self-modifying triggers
    let initial_score = r#"
        PUSH 10
        PUSH 20
        ADD
        SYNTAX_ERROR_NOTE
        DUP
        EMIT
        SUB_BAD_ARG
    "#;

    println!("=== Self-Modifying Score Compiler Virtual Machine ===");
    println!("Source Code / Musical Score:\n{}\n", initial_score.trim());

    let mut vm = MusicalCompilerVM::new(initial_score);
    let mut step_count = 0;

    println!("--- Performing Real-time Score Compilation & Playback ---");
    while let Some(note) = vm.step() {
        step_count += 1;
        println!(
            "Step {:02} | Playing Note: {:6.2} Hz (Dur: {}ms) | Stack: {:?}",
            step_count, note.pitch_hz, note.duration_ms, vm.stack
        );
    }

    println!("\n=== Final Self-Modified Source Code / Score State ===");
    for (idx, line) in vm.code.iter().enumerate() {
        println!("{:02}: {}", idx + 1, line);
    }
}