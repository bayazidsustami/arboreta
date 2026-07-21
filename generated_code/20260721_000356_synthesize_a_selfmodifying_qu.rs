// Visual Memory Garden Quine
// Synthesizes a self-reproducing source program while simulating a dynamic
// memory landscape where decaying pointer addresses blossom into procedural flowers.

use std::fmt;

struct Flower {
    addr: usize,
    age: u8,
    petals: &'static str,
}

impl Flower {
    fn bloom(addr: usize) -> Self {
        let petals = match addr % 4 {
            0 => "❀",
            1 => "✿",
            2 => "❁",
            _ => "🪷",
        };
        Flower { addr, age: 0, petals }
    }

    fn wither(&mut self) {
        self.age = self.age.saturating_add(1);
    }
}

impl fmt::Display for Flower {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if self.age > 1 {
            write!(f, "🥀")
        } else {
            write!(f, "{}", self.petals)
        }
    }
}

fn main() {
    let source = r#"// Visual Memory Garden Quine
// Synthesizes a self-reproducing source program while simulating a dynamic
// memory landscape where decaying pointer addresses blossom into procedural flowers.

use std::fmt;

struct Flower {
    addr: usize,
    age: u8,
    petals: &'static str,
}

impl Flower {
    fn bloom(addr: usize) -> Self {
        let petals = match addr % 4 {
            0 => "❀",
            1 => "✿",
            2 => "❁",
            _ => "🪷",
        };
        Flower { addr, age: 0, petals }
    }

    fn wither(&mut self) {
        self.age = self.age.saturating_add(1);
    }
}

impl fmt::Display for Flower {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if self.age > 1 {
            write!(f, "🥀")
        } else {
            write!(f, "{}", self.petals)
        }
    }
}

fn main() {
    let source = %q;

    let heap_alloc = Box::new(42);
    let ptr_val = &*heap_alloc as *const i32 as usize;

    println!("=== MEMORY GARDEN LAYOUT ===");
    let mut garden = vec![
        Flower::bloom(ptr_val),
        Flower::bloom(ptr_val ^ 0x0100),
        Flower::bloom(ptr_val ^ 0x0500),
    ];

    for flower in garden.iter_mut() {
        println!("Address 0x{:x} -> {}", flower.addr, flower);
        flower.wither();
    }

    println!("\n--- Garbage Collection Triggered ---");
    garden.retain(|f| f.age <= 1);
    println!("Active memory nodes remaining: {}\n", garden.len());

    print!("{}", source.replace("%q", &format!("{:?}", source)));
}
"#;

    let heap_alloc = Box::new(42);
    let ptr_val = &*heap_alloc as *const i32 as usize;

    println!("=== MEMORY GARDEN LAYOUT ===");
    let mut garden = vec![
        Flower::bloom(ptr_val),
        Flower::bloom(ptr_val ^ 0x0100),
        Flower::bloom(ptr_val ^ 0x0500),
    ];

    for flower in garden.iter_mut() {
        println!("Address 0x{:x} -> {}", flower.addr, flower);
        flower.wither();
    }

    println!("\n--- Garbage Collection Triggered ---");
    garden.retain(|f| f.age <= 1);
    println!("Active memory nodes remaining: {}\n", garden.len());

    print!("{}", source.replace("%q", &format!("{:?}", source)));
}