// N-Body Gravitational Heap Interpreter
// Interprets memory allocations as celestial bodies governed by gravitational physics.
// Leaked allocations transform into expanding Supernovas; Garbage Collection collapses
// orphaned masses into an accretive Black Hole singularity.

use std::f64::consts::TAU;

#[derive(Clone, Debug)]
pub enum CelestialState {
    ActiveAllocation,
    LeakedSupernova { radius: f64, expansion_rate: f64 },
    BlackHoleSingularity { event_horizon: f64 },
}

#[derive(Clone, Debug)]
pub struct CelestialAllocation {
    pub id: usize,
    pub x: f64,
    pub y: f64,
    pub vx: f64,
    pub vy: f64,
    pub mass: f64,
    pub state: CelestialState,
}

pub struct GravitationalHeap {
    pub bodies: Vec<CelestialAllocation>,
    next_id: usize,
    gravitational_constant: f64,
}

impl GravitationalHeap {
    pub fn new() -> Self {
        Self {
            bodies: Vec::new(),
            next_id: 1,
            gravitational_constant: 1.2,
        }
    }

    /// Allocates memory by spawning a massive celestial body in the gravitational system.
    pub fn alloc(&mut self, bytes: usize) -> usize {
        let id = self.next_id;
        self.next_id += 1;

        // Position initial allocations in an orbital distribution based on allocation ID
        let angle = (id as f64) * 1.375 * TAU;
        let distance = 6.0 + (bytes as f64).sqrt() * 0.5;

        self.bodies.push(CelestialAllocation {
            id,
            x: distance * angle.cos(),
            y: distance * angle.sin(),
            vx: -angle.sin() * 1.5,
            vy: angle.cos() * 1.5,
            mass: bytes as f64,
            state: CelestialState::ActiveAllocation,
        });

        id
    }

    /// Simulates a memory leak: the allocation loses containment and expands into a Supernova.
    pub fn mark_leaked(&mut self, id: usize) {
        if let Some(body) = self.bodies.iter_mut().find(|b| b.id == id) {
            body.state = CelestialState::LeakedSupernova {
                radius: 1.0,
                expansion_rate: 1.5,
            };
        }
    }

    /// Triggers Garbage Collection: collects all leaked supernova masses into a collapsing Black Hole.
    pub fn collect_garbage(&mut self) {
        let mut total_leaked_mass = 0.0;
        let (mut sum_x, mut sum_y) = (0.0, 0.0);
        let mut leaked_indices = Vec::new();

        for (idx, body) in self.bodies.iter().enumerate() {
            if matches!(body.state, CelestialState::LeakedSupernova { .. }) {
                sum_x += body.x * body.mass;
                sum_y += body.y * body.mass;
                total_leaked_mass += body.mass;
                leaked_indices.push(idx);
            }
        }

        if total_leaked_mass > 0.0 {
            let center_x = sum_x / total_leaked_mass;
            let center_y = sum_y / total_leaked_mass;

            // Remove leaked bodies from the heap
            for idx in leaked_indices.into_iter().rev() {
                self.bodies.swap_remove(idx);
            }

            // Spawn the GC Black Hole Singularity at the center of mass
            self.bodies.push(CelestialAllocation {
                id: 0, // Special ID reserved for GC Singularity
                x: center_x,
                y: center_y,
                vx: 0.0,
                vy: 0.0,
                mass: total_leaked_mass * 3.0,
                state: CelestialState::BlackHoleSingularity {
                    event_horizon: (total_leaked_mass * 0.15).max(2.5),
                },
            });
        }
    }

    /// Advances the N-body gravitational physics simulation across time delta `dt`.
    pub fn step_physics(&mut self, dt: f64) {
        let n = self.bodies.len();
        let mut force_x = vec![0.0; n];
        let mut force_y = vec![0.0; n];

        // Compute pairwise gravitational forces (G * m1 * m2 / r^2)
        for i in 0..n {
            for j in (i + 1)..n {
                let dx = self.bodies[j].x - self.bodies[i].x;
                let dy = self.bodies[j].y - self.bodies[i].y;
                let dist_sq = dx * dx + dy * dy + 0.2; // Softening parameter to avoid division by zero
                let dist = dist_sq.sqrt();

                let force = (self.gravitational_constant * self.bodies[i].mass * self.bodies[j].mass) / dist_sq;
                let fx = force * (dx / dist);
                let fy = force * (dy / dist);

                force_x[i] += fx;
                force_y[i] += fy;
                force_x[j] -= fx;
                force_y[j] -= fy;
            }
        }

        // Apply forces and update kinematics / celestial mechanics
        for i in 0..n {
            let body = &mut self.bodies[i];
            let ax = force_x[i] / body.mass;
            let ay = force_y[i] / body.mass;

            body.vx += ax * dt;
            body.vy += ay * dt;
            body.x += body.vx * dt;
            body.y += body.vy * dt;

            // Evolve specific memory state mechanics
            match &mut body.state {
                CelestialState::LeakedSupernova { radius, expansion_rate } => {
                    *radius += *expansion_rate * dt;
                    body.mass += 0.8 * dt; // Leaked memory footprint expands in visual space
                }
                CelestialState::BlackHoleSingularity { event_horizon } => {
                    *event_horizon += 0.1 * dt; // Black hole continues accreting surrounding gravity fields
                }
                CelestialState::ActiveAllocation => {}
            }
        }
    }

    /// Renders an ASCII map of the gravitational heap space.
    pub fn render_heap(&self) {
        const WIDTH: usize = 50;
        const HEIGHT: usize = 20;
        let mut grid = vec![vec!['.'; WIDTH]; HEIGHT];

        for body in &self.bodies {
            let map_x = ((body.x + 25.0) * (WIDTH as f64 / 50.0)) as isize;
            let map_y = ((body.y + 12.0) * (HEIGHT as f64 / 24.0)) as isize;

            if map_x >= 0 && map_x < WIDTH as isize && map_y >= 0 && map_y < HEIGHT as isize {
                let symbol = match body.state {
                    CelestialState::ActiveAllocation => 'o',
                    CelestialState::LeakedSupernova { .. } => '*',
                    CelestialState::BlackHoleSingularity { .. } => '@',
                };
                grid[map_y as usize][map_x as usize] = symbol;
            }
        }

        println!("+--------------------------------------------------+");
        for row in grid {
            let line: String = row.into_iter().collect();
            println!("|{}|", line);
        }
        println!("+--------------------------------------------------+");
        println!("Legend: [o] Active Heap Object  [*] Leaked Supernova  [@] GC Black Hole");
    }
}

fn main() {
    println!("=== GRAVITATIONAL HEAP INTERPRETER INITIATED ===");
    let mut heap = GravitationalHeap::new();

    println!("\n[1] Allocating active memory blocks (spawning celestial bodies)...");
    let ptr1 = heap.alloc(16);
    let ptr2 = heap.alloc(64);
    let ptr3 = heap.alloc(32);
    let ptr4 = heap.alloc(128);
    heap.render_heap();

    println!("\n[2] Memory Leaks Occurring: Pointer #{ptr2} & #{ptr4} expanding as Supernovas...");
    heap.mark_leaked(ptr2);
    heap.mark_leaked(ptr4);

    for step in 1..=3 {
        heap.step_physics(0.4);
        println!("\n-- Physics Step {} (Supernova Expansion) --", step);
        heap.render_heap();
    }

    println!("\n[3] Triggering Garbage Collector -> Collapsing Leaked Memory into Black Hole!");
    heap.collect_garbage();
    heap.step_physics(0.4);
    heap.render_heap();

    println!("\n[4] Evolving system gravitational orbit around Singularity...");
    for step in 4..=5 {
        heap.step_physics(0.4);
        println!("\n-- Physics Step {} (Singularity Accretion) --", step);
        heap.render_heap();
    }
}