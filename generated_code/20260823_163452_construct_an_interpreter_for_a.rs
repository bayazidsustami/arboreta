use std::collections::HashSet;

/// Represents an instruction derived from a color spectrum in the painting.
#[derive(Debug, Clone, PartialEq)]
enum Instruction {
    Push(i64),
    Add,
    Sub,
    Mul,
    Print,
    Dup,
    JumpIfZero(usize),
}

/// Node representing a topological feature (e.g., a connected region of interest or "island").
#[derive(Debug)]
struct RegionNode {
    id: usize,
    avg_color: (u8, u8, u8),
    area: usize,
    neighbors: Vec<usize>,
}

/// Simulated painting image: 2D array of RGB tuples (width, height, pixels).
struct Canvas {
    width: usize,
    height: usize,
    pixels: Vec<(u8, u8, u8)>,
}

impl Canvas {
    fn new(width: usize, height: usize, pixels: Vec<(u8, u8, u8)>) -> Self {
        Self { width, height, pixels }
    }

    fn get(&self, x: usize, y: usize) -> (u8, u8, u8) {
        self.pixels[y * self.width + x]
    }
}

/// Abstract representation of the painting's topology.
struct CanvasGraph {
    nodes: Vec<RegionNode>,
}

impl CanvasGraph {
    /// Extracts topological regions (connected components of similar color intensity)
    /// to form an execution graph.
    fn extract_from_canvas(canvas: &Canvas, threshold: i32) -> Self {
        let mut visited = vec![false; canvas.width * canvas.height];
        let mut regions = Vec::new();

        for y in 0..canvas.height {
            for x in 0..canvas.width {
                let idx = y * canvas.width + x;
                if visited[idx] {
                    continue;
                }

                // Flood fill to identify a connected topological region
                let target_color = canvas.get(x, y);
                let target_lum = luminance(target_color);
                let mut queue = vec![(x, y)];
                visited[idx] = true;

                let mut region_pixels = Vec::new();
                let mut r_sum = 0u64;
                let mut g_sum = 0u64;
                let mut b_sum = 0u64;

                while let Some((cx, cy)) = queue.pop() {
                    let c = canvas.get(cx, cy);
                    region_pixels.push((cx, cy));
                    r_sum += c.0 as u64;
                    g_sum += c.1 as u64;
                    b_sum += c.2 as u64;

                    // Check 4-directional neighbors
                    let neighbors = [
                        (cx.wrapping_sub(1), cy),
                        (cx + 1, cy),
                        (cx, cy.wrapping_sub(1)),
                        (cx, cy + 1),
                    ];

                    for &(nx, ny) in &neighbors {
                        if nx < canvas.width && ny < canvas.height {
                            let nidx = ny * canvas.width + nx;
                            if !visited[nidx] {
                                let ncolor = canvas.get(nx, ny);
                                let nlum = luminance(ncolor);
                                if (nlum as i32 - target_lum as i32).abs() <= threshold {
                                    visited[nidx] = true;
                                    queue.push((nx, ny));
                                }
                            }
                        }
                    }
                }

                let area = region_pixels.len();
                let avg_color = (
                    (r_sum / area as u64) as u8,
                    (g_sum / area as u64) as u8,
                    (b_sum / area as u64) as u8,
                );

                regions.push((region_pixels, avg_color, area));
            }
        }

        // Build region adjacency graph
        let mut nodes: Vec<RegionNode> = regions
            .iter()
            .enumerate()
            .map(|(id, (_, avg_color, area))| RegionNode {
                id,
                avg_color: *avg_color,
                area: *area,
                neighbors: Vec::new(),
            })
            .collect();

        // Connect regions that are adjacent in canvas space
        for i in 0..nodes.len() {
            for j in (i + 1)..nodes.len() {
                // If regions are topologically close or share size relationships, create a loop edge
                if (nodes[i].area as i64 - nodes[j].area as i64).abs() < 20 {
                    nodes[i].neighbors.push(j);
                    nodes[j].neighbors.push(i);
                }
            }
        }

        CanvasGraph { nodes }
    }
}

/// Maps color spectrum features (Hue/Luminance) to virtual machine instructions.
fn map_color_to_instruction(color: (u8, u8, u8), region_area: usize) -> Instruction {
    let (r, g, b) = (color.0 as f32, color.1 as f32, color.2 as f32);
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let delta = max - min;

    // Calculate Hue in degrees [0, 360)
    let hue = if delta == 0.0 {
        0.0
    } else if max == r {
        60.0 * (((g - b) / delta) % 6.0)
    } else if max == g {
        60.0 * (((b - r) / delta) + 2.0)
    } else {
        60.0 * (((r - g) / delta) + 4.0)
    };
    let hue = if hue < 0.0 { hue + 360.0 } else { hue };

    // Dominant color bands determine the program's algorithmic semantics
    match hue {
        h if h < 45.0 => Instruction::Push(region_area as i64), // Red/Orange spectrum: Data injection
        h if h < 90.0 => Instruction::Add,                     // Yellow spectrum: Synthesis
        h if h < 160.0 => Instruction::Sub,                    // Green spectrum: Reduction
        h if h < 240.0 => Instruction::Mul,                    // Cyan/Blue spectrum: Amplification
        h if h < 300.0 => Instruction::Dup,                    // Purple spectrum: Replication
        _ => Instruction::Print,                               // Magenta/Pink spectrum: Output
    }
}

/// Calculate perceived brightness (luminance)
fn luminance(color: (u8, u8, u8)) -> u8 {
    (0.299 * color.0 as f32 + 0.587 * color.1 as f32 + 0.114 * color.2 as f32) as u8
}

/// Virtual machine state for interpreting painting-derived programs.
struct Interpreter {
    stack: Vec<i64>,
    instructions: Vec<Instruction>,
    pc: usize,
}

impl Interpreter {
    fn new(instructions: Vec<Instruction>) -> Self {
        Self {
            stack: Vec::new(),
            instructions,
            pc: 0,
        }
    }

    /// Executes the algorithmic program generated from the artwork topology.
    fn run(&mut self) {
        println!("--- Executing Artwork Algorithm ---");
        let mut steps = 0;
        let max_steps = 1000; // Guard against infinite loops

        while self.pc < self.instructions.len() && steps < max_steps {
            let instr = self.instructions[self.pc].clone();
            self.pc += 1;
            steps += 1;

            match instr {
                Instruction::Push(val) => self.stack.push(val),
                Instruction::Add => {
                    let b = self.stack.pop().unwrap_or(0);
                    let a = self.stack.pop().unwrap_or(0);
                    self.stack.push(a + b);
                }
                Instruction::Sub => {
                    let b = self.stack.pop().unwrap_or(0);
                    let a = self.stack.pop().unwrap_or(0);
                    self.stack.push(a - b);
                }
                Instruction::Mul => {
                    let b = self.stack.pop().unwrap_or(0);
                    let a = self.stack.pop().unwrap_or(1);
                    self.stack.push(a * b);
                }
                Instruction::Dup => {
                    if let Some(&val) = self.stack.last() {
                        self.stack.push(val);
                    }
                }
                Instruction::Print => {
                    if let Some(val) = self.stack.pop() {
                        println!("[Output Stream]: {}", val);
                    }
                }
                Instruction::JumpIfZero(target) => {
                    if let Some(val) = self.stack.last() {
                        if *val == 0 {
                            self.pc = target;
                        }
                    }
                }
            }
        }
        println!("--- Execution Finished (Stack State: {:?}) ---", self.stack);
    }
}

fn main() {
    // Generate a synthetic artwork pixel array representing topological regions/color gradients
    // (Simulates loading an iconic artwork like Mondrian's Composition or Starry Night)
    let width = 6;
    let height = 6;
    let mut pixels = vec![(0, 0, 0); width * height];

    // Paint region 1: Red dominant patch (Push values)
    for x in 0..2 {
        for y in 0..2 {
            pixels[y * width + x] = (255, 30, 30);
        }
    }
    // Paint region 2: Blue dominant patch (Multiply)
    for x in 2..4 {
        for y in 0..2 {
            pixels[y * width + x] = (30, 30, 255);
        }
    }
    // Paint region 3: Yellow patch (Add)
    for x printed in 0..2 {
        for y in 2..4 {
            pixels[y * width + printed] = (255, 235, 30);
        }
    }
    // Paint region 4: Magenta patch (Print)
    for x in 2..6 {
        for y in 2..6 {
            pixels[y * width + x] = (240, 30, 240);
        }
    }

    let canvas = Canvas::new(width, height, pixels);

    // 1. Extract topological graph from artwork
    let graph = CanvasGraph::extract_from_canvas(&canvas, 30);

    // 2. Convert topological features into instructions
    let mut program = Vec::new();
    let mut visited_nodes = HashSet::new();

    // Traverse the topological region graph to construct execution loops
    for node in &graph.nodes {
        if visited_nodes.contains(&node.id) {
            continue;
        }
        visited_nodes.insert(node.id);

        let instr = map_color_to_instruction(node.avg_color, node.area);
        program.push(instr);

        // Introduce back-references/jumping logic based on topological connections
        if !node.neighbors.is_empty() && node.area > 3 {
            // Conditional loop dynamic derived from region scale
            program.push(Instruction::Dup);
            program.push(Instruction::Push(1));
            program.push(Instruction::Sub);
            program.push(Instruction::JumpIfZero(0)); // Loop back to start
        }
    }

    println!("Compiled {} topological instructions from painting.", program.len());
    for (idx, inst) in program.iter().enumerate() {
        println!("{:02}: {:?}", idx, inst);
    }

    // 3. Execute the resulting painting algorithm
    let mut vm = Interpreter::new(program);
    vm.run();
}