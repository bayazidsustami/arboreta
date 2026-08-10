// Esoteric Compiler: Transforms Brainfuck-like code into a printable maze
// where the unique solution path encodes the exact memory/execution trace.

use std::collections::{HashSet, VecDeque};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Instruction {
    Inc,
    Dec,
    Right,
    Left,
    LoopStart(usize),
    LoopEnd(usize),
}

/// Parses source code into instruction bytecode with jump targets.
fn compile(source: &str) -> Vec<Instruction> {
    let mut code = Vec::new();
    let mut stack = Vec::new();

    for ch in source.chars() {
        match ch {
            '+' => code.push(Instruction::Inc),
            '-' => code.push(Instruction::Dec),
            '>' => code.push(Instruction::Right),
            '<' => code.push(Instruction::Left),
            '[' => {
                let pos = code.len();
                code.push(Instruction::LoopStart(0));
                stack.push(pos);
            }
            ']' => {
                if let Some(start) = stack.pop() {
                    let end = code.len();
                    code.push(Instruction::LoopEnd(start));
                    code[start] = Instruction::LoopStart(end);
                }
            }
            _ => {}
        }
    }
    code
}

/// Executes bytecode on a tape and records execution trace coordinates (step, ptr).
fn trace_execution(code: &[Instruction]) -> Vec<(usize, usize)> {
    let mut tape = vec![0u8; 32];
    let mut ptr = 0usize;
    let mut ip = 0usize;
    let mut trace = Vec::new();
    let mut step = 0usize;

    trace.push((step, ptr));

    while ip < code.len() && step < 100 {
        match code[ip] {
            Instruction::Inc => tape[ptr] = tape[ptr].wrapping_add(1),
            Instruction::Dec => tape[ptr] = tape[ptr].wrapping_sub(1),
            Instruction::Right => ptr = (ptr + 1) % tape.len(),
            Instruction::Left => ptr = if ptr == 0 { tape.len() - 1 } else { ptr - 1 },
            Instruction::LoopStart(target) => {
                if tape[ptr] == 0 {
                    ip = target;
                }
            }
            Instruction::LoopEnd(target) => {
                if tape[ptr] != 0 {
                    ip = target;
                }
            }
        }
        ip += 1;
        step += 1;
        trace.push((step, ptr));
    }
    trace
}

/// Generates a printable ASCII maze where the solution path corresponds to execution steps.
fn render_maze(trace: &[(usize, usize)], grid_w: usize, grid_h: usize) -> String {
    let mut maze = vec![vec!['#'; grid_w * 2 + 1]; grid_h * 2 + 1];
    let mut visited = HashSet::new();

    // Map trace steps onto grid path
    let mut path_cells = Vec::new();
    for (i, &(step, ptr)) in trace.iter().enumerate() {
        let gx = (ptr * 2) % (grid_w * 2);
        let gy = (step * 2) % (grid_h * 2);
        let cell = (gx / 2, gy / 2);

        path_cells.push((cell.0 * 2 + 1, cell.1 * 2 + 1));
        visited.insert((cell.0, cell.1));

        if i > 0 {
            let prev = path_cells[i - 1];
            let curr = path_cells[i];
            let mid_x = (prev.0 + curr.0) / 2;
            let mid_y = (prev.1 + curr.1) / 2;
            maze[mid_y][mid_x] = ' ';
        }
    }

    // Carve main path spaces
    for &(cx, cy) in &path_cells {
        maze[cy][cx] = ' ';
    }

    // Add entry and exit markers along the solution path
    if let (Some(&start), Some(&end)) = (path_cells.first(), path_cells.last()) {
        maze[start.1][start.0] = 'S';
        maze[end.1][end.0] = 'E';
    }

    // Convert maze grid to string
    maze.into_iter()
        .map(|row| row.into_iter().collect::<String>())
        .collect::<Vec<_>>()
        .join("\n")
}

fn main() {
    // Esoteric program: Simple increment and move loop
    let source_code = "++[>+<-]";

    println!("=== ESOTERIC MAZE COMPILER ===");
    println!("Source Code: {}\n", source_code);

    let bytecode = compile(source_code);
    let trace = trace_execution(&bytecode);

    println!("Execution Trace Steps: {}", trace.len());
    println!("Generating Execution-Path Vector Maze...\n");

    let maze_ascii = render_maze(&trace, 10, 10);
    println!("{}", maze_ascii);
}