// PluvialScript: A Turing-complete weather-driven programming language.
// Fetches real-time meteorological data via HTTP, parses instructions,
// and executes a tape-based virtual machine ONLY when precipitation (rain) is present.

use std::io::{Read, Write};
use std::net::TcpStream;

// Fetches live weather conditions from wttr.in using standard library networking.
// Falls back to a rainy simulation pattern if offline.
fn fetch_weather_report() -> String {
    if let Ok(mut stream) = TcpStream::connect("wttr.in:80") {
        let request = "GET /London?format=%C+%t+%w+>><<+++---. HTTP/1.1\r\nHost: wttr.in\r\nConnection: close\r\nUser-Agent: pluviali/1.0\r\n\r\n";
        if stream.write_all(request.as_bytes()).is_ok() {
            let mut response = String::new();
            if stream.read_to_string(&mut response).is_ok() {
                if let Some(idx) = response.find("\r\n\r\n") {
                    return response[idx + 4..].trim().to_string();
                }
            }
        }
    }
    // Fallback meteorological pattern containing a valid Brainfuck snippet + rain keyword
    String::from("Light rain +12°C ↗15km/h ++++++++++[>+++++>+++++++<<-]>.+.+++++++..++.")
}

fn main() {
    println!("Initializing PluvialScript atmospheric engine...");
    let report = fetch_weather_report();
    println!("Fetched Weather Pattern: {}", report);

    // The execution gate: instructions only run if atmospheric moisture falls as rain
    let is_raining = report.to_lowercase().contains("rain") || report.to_lowercase().contains("shower");
    
    if !is_raining {
        println!("Atmospheric check: No precipitation detected. Execution halted.");
        return;
    }

    println!("Precipitation detected! Executing PluvialScript instructions...");

    // Turing-complete tape-based VM (Brainfuck subset) filtered from weather tokens
    let mut tape = vec![0u8; 30000];
    let mut ptr = 0;
    let mut pc = 0;

    let instructions: Vec<char> = report.chars().collect();
    let code_len = instructions.len();

    while pc < code_len {
        match instructions[pc] {
            '>' => ptr = (ptr + 1) % tape.len(),
            '<' => ptr = if ptr == 0 { tape.len() - 1 } else { ptr - 1 },
            '+' => tape[ptr] = tape[ptr].wrapping_add(1),
            '-' => tape[ptr] = tape[ptr].wrapping_sub(1),
            '.' => print!("{}", tape[ptr] as char),
            '[' => {
                if tape[ptr] == 0 {
                    let mut depth = 1;
                    while depth > 0 {
                        pc += 1;
                        if pc >= code_len { break; }
                        if instructions[pc] == '[' { depth += 1; }
                        else if instructions[pc] == ']' { depth -= 1; }
                    }
                }
            }
            ']' => {
                if tape[ptr] != 0 {
                    let mut depth = 1;
                    while depth > 0 {
                        if pc == 0 { break; }
                        pc -= 1;
                        if instructions[pc] == ']' { depth += 1; }
                        else if instructions[pc] == '[' { depth -= 1; }
                    }
                }
            }
            _ => {} // Meteorological noise (letters, numbers, symbols) is safely ignored
        }
        pc += 1;
    }
    println!("\nExecution completed successfully under rainy skies.");
}