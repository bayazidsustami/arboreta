use std::net::{UdpSocket, SocketAddr};
use std::sync::mpsc::{self, Receiver, Sender};
use std::thread;
use std::time::{Duration, Instant};

// Word banks categorized by syllable count for digital isolation theme
const 
SYLLABLE_1: &[&str] = &["void", "cold", "glass", "hum", "ping", "ghost", "dark", "wire", "loss", "byte"];
const 
SYLLABLE_2: &[&str] = &["echo", "silent", "server", "beacon", "static", "fading", "hidden", "empty", "signal", "sleep"];
const 
SYLLABLE_3: &[&str] = &["isolation", "disconnected", "null pointer", "packet lost", "infinite", "latency", "dark horizon"];

struct HaikuLine {
    words: Vec<String>,
    target_syllables: usize,
}

impl HaikuLine {
    fn new(target: usize) -> Self {
        Self {
            words: Vec::new(),
            target_syllables: target,
        }
    }

    fn current_syllables(&self) -> usize {
        self.words.iter().map(|w| get_syllables(w)).sum()
    }

    fn add_word(&mut self, word: &str) {
        if self.current_syllables() + get_syllables(word) <= self.target_syllables {
            self.words.push(word.to_string());
        }
    }

    fn dissolve(&mut self, amount: usize) {
        for _ in 0..amount {
            if !self.words.is_empty() {
                self.words.pop();
            }
        }
    }

    fn render(&self) -> String {
        if self.words.is_empty() {
            ".".repeat(self.target_syllables * 2)
        } else {
            self.words.join(" ")
        }
    }
}

struct PoetryEngine {
    line1: HaikuLine,
    line2: HaikuLine,
    line3: HaikuLine,
}

impl PoetryEngine {
    fn new() -> Self {
        Self {
            line1: HaikuLine::new(5),
            line2: HaikuLine::new(7),
            line3: HaikuLine::new(5),
        }
    }

    fn feed_packet(&mut self, byte: u8) {
        // Choose word bank based on byte entropy
        let word = match byte % 3 {
            0 => SYLLABLE_1[byte as usize % SYLLABLE_1.len()],
            1 => SYLLABLE_2[byte as usize % SYLLABLE_2.len()],
            _ => SYLLABLE_3[byte as usize % SYLLABLE_3.len()],
        };

        if self.line1.current_syllables() < 5 {
            self.line1.add_word(word);
        } else if self.line2.current_syllables() < 7 {
            self.line2.add_word(word);
        } else if self.line3.current_syllables() < 5 {
            self.line3.add_word(word);
        } else {
            // Reset and cycle if full
            self.line1 = HaikuLine::new(5);
            self.line2 = HaikuLine::new(7);
            self.line3 = HaikuLine::new(5);
            self.line1.add_word(word);
        }
    }

    fn drop_packet(&mut self) {
        // Dissolve parts of the poem due to network loss
        self.line3.dissolve(1);
        self.line2.dissolve(1);
        self.line1.dissolve(1);
    }

    fn display(&self) {
        print!("\x1B[2J\x1B[1;1H");
        println!("=== DIGITAL ISOLATION HAIKU ENGINE ===");
        println!("--------------------------------------");
        println!("  {0}", self.line1.render());
        println!("  {0}", self.line2.render());
        println!("  {0}", self.line3.render());
        println!("--------------------------------------");
        println!("(Listening to local network pulses...)");
    }
}

fn get_syllables(word: &str) -> usize {
    match word {
        w if SYLLABLE_1.contains(&w) => 1,
        w if SYLLABLE_2.contains(&w) => 2,
        w if SYLLABLE_3.contains(&w) => 3,
        _ => 1,
    }
}

fn main() -> std::io::Result<()> {
    // Setup local loopback socket for traffic simulation/capture
    let socket = UdpSocket::bind("127.0.0.1:0")?;
    let addr = socket.local_addr()?;
    socket.set_nonblocking(true)?;

    let sender_socket = UdpSocket::bind("127.0.0.1:0")?;
    
    // Spawn background thread to simulate live network traffic and drops
    thread::spawn(move || {
        let mut counter: u8 = 0;
        loop {
            counter = counter.wrapping_add(1);
            let payload = [counter];
            let _ = sender_socket.send_to(&payload, addr);
            
            // Periodically simulate a dropped packet event
            if counter % 7 == 0 {
                thread::sleep(Duration::from_millis(400)); // Simulate lag/drop
            } else {
                thread::sleep(Duration::from_millis(150));
            }
        }
    });

    let mut engine = PoetryEngine::new();
    let mut buf = [0; 1024];
    let mut last_packet_time = Instant::now();

    loop {
        match socket.recv_from(&mut buf) {
            Ok((amt, _)) => {
                last_packet_time = Instant::now();
                engine.feed_packet(buf[0]);
                engine.display();
            }
            Err(_) => {
                // If no packet arrives quickly, simulate network deterioration (packet drop)
                if last_packet_time.elapsed() > Duration::from_millis(300) {
                    engine.drop_packet();
                    engine.display();
                    last_packet_time = Instant::now();
                }
                thread::sleep(Duration::from_millis(50));
            }
        }
    }
}