use std::fmt::Write as FmtWrite;
use std::fs::File;
use std::io::Write as IoWrite;

// --- AST Representation ---

#[derive(Debug, Clone)]
pub enum AstNode {
    Module {
        name: String,
        children: Vec<AstNode>,
    },
    Function {
        name: String,
        cyclomatic_complexity: usize,
        is_dead_code: bool,
        has_merge_conflict: bool,
    },
    Struct {
        name: String,
        field_count: usize,
    },
}

// --- 3D Geometry Framework ---

#[derive(Debug, Clone, Copy)]
pub struct Vec3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

impl Vec3 {
    pub fn new(x: f32, y: f32, z: f32) -> Self {
        Self { x, y, z }
    }
}

pub struct Mesh {
    pub vertices: Vec<Vec3>,
    pub faces: Vec<[usize; 3]>, // 1-based indices for Wavefront OBJ format
}

impl Mesh {
    pub fn new() -> Self {
        Self {
            vertices: Vec::new(),
            faces: Vec::new(),
        }
    }

    // Constructs cuboids with optional vertex jitter to represent structural decay
    pub fn add_cuboid(&mut self, min: Vec3, max: Vec3, jitter: f32) {
        let base_idx = self.vertices.len() + 1;

        // Pseudo-random deterministic noise function to warp vertex positions near conflicts
        let apply_jitter = |val: f32, seed: f32| -> f32 {
            if jitter == 0.0 { val } else { val + (seed.sin() * jitter) }
        };

        let corners = [
            Vec3::new(apply_jitter(min.x, 1.1), apply_jitter(min.y, 2.2), apply_jitter(min.z, 3.3)),
            Vec3::new(apply_jitter(max.x, 4.4), apply_jitter(min.y, 5.5), apply_jitter(min.z, 6.6)),
            Vec3::new(apply_jitter(max.x, 7.7), apply_jitter(max.y, 8.8), apply_jitter(min.z, 9.9)),
            Vec3::new(apply_jitter(min.x, 10.0), apply_jitter(max.y, 11.1), apply_jitter(min.z, 12.2)),
            Vec3::new(apply_jitter(min.x, 13.3), apply_jitter(min.y, 14.4), apply_jitter(max.z, 15.5)),
            Vec3::new(apply_jitter(max.x, 16.6), apply_jitter(min.y, 17.7), apply_jitter(max.z, 18.8)),
            Vec3::new(apply_jitter(max.x, 19.9), apply_jitter(max.y, 20.0), apply_jitter(max.z, 21.1)),
            Vec3::new(apply_jitter(min.x, 22.2), apply_jitter(max.y, 23.3), apply_jitter(max.z, 24.4)),
        ];

        for v in corners {
            self.vertices.push(v);
        }

        let face_indices = [
            [0, 1, 2], [0, 2, 3], // Front
            [5, 4, 7], [5, 7, 6], // Back
            [4, 0, 3], [4, 3, 7], // Left
            [1, 5, 6], [1, 6, 2], // Right
            [3, 2, 6], [3, 6, 7], // Top
            [4, 5, 1], [4, 1, 0], // Bottom
        ];

        for f in face_indices {
            self.faces.push([base_idx + f[0], base_idx + f[1], base_idx + f[2]]);
        }
    }

    pub fn export_to_obj(&self) -> String {
        let mut buffer = String::new();
        buffer.push_str("# Gothic Cathedral Generated from Codebase AST\n");
        for v in &self.vertices {
            let _ = writeln!(buffer, "v {:.4} {:.4} {:.4}", v.x, v.y, v.z);
        }
        for f in &self.faces {
            let _ = writeln!(buffer, "f {} {} {}", f[0], f[1], f[2]);
        }
        buffer
    }
}

// --- Procedural Cathedral Generator ---

pub struct CathedralGenerator {
    mesh: Mesh,
    current_z: f32,
    crypt_depth: f32,
}

impl CathedralGenerator {
    pub fn new() -> Self {
        Self {
            mesh: Mesh::new(),
            current_z: 0.0,
            crypt_depth: -5.0,
        }
    }

    // Recursively translates AST nodes into gothic architectural structures
    pub fn build_from_ast(&mut self, node: &AstNode) {
        match node {
            AstNode::Module { children, .. } => {
                for child in children {
                    self.build_from_ast(child);
                }
            }
            AstNode::Function {
                cyclomatic_complexity,
                is_dead_code,
                has_merge_conflict,
                ..
            } => {
                // Structural integrity weakens (vertex jitter) when merge conflicts exist
                let structural_instability = if *has_merge_conflict { 1.5 } else { 0.0 };

                if *is_dead_code {
                    // Dead code spawns subterranean dusty crypts beneath the ground plane
                    let crypt_size = 3.0 + (*cyclomatic_complexity as f32 * 0.4);
                    self.mesh.add_cuboid(
                        Vec3::new(-crypt_size / 2.0, self.crypt_depth - crypt_size, self.current_z),
                        Vec3::new(crypt_size / 2.0, self.crypt_depth, self.current_z + crypt_size),
                        structural_instability + 0.3, // Weathered crypt texture
                    );
                    self.crypt_depth -= crypt_size + 2.0;
                } else {
                    // Active code constructs cathedral hall sections
                    // Room volume scales proportionally to cyclomatic complexity
                    let scale = (*cyclomatic_complexity as f32).max(1.0);
                    let width = 6.0 * scale.sqrt();
                    let height = 10.0 * scale.log2().max(1.0);
                    let length = 8.0 * scale.sqrt();

                    // Main Nave section
                    self.mesh.add_cuboid(
                        Vec3::new(-width / 2.0, 0.0, self.current_z),
                        Vec3::new(width / 2.0, height, self.current_z + length),
                        structural_instability,
                    );

                    // Lofty Gothic Spire generated above highly complex modules
                    if *cyclomatic_complexity > 5 {
                        let spire_height = height + (scale * 3.0);
                        self.mesh.add_cuboid(
                            Vec3::new(-width / 4.0, height, self.current_z + length / 4.0),
                            Vec3::new(width / 4.0, spire_height, self.current_z + (3.0 * length / 4.0)),
                            structural_instability * 1.2,
                        );
                    }

                    // Flying Buttresses supporting the exterior walls
                    let buttress_w = 1.0;
                    self.mesh.add_cuboid(
                        Vec3::new(-width / 2.0 - 2.5, 0.0, self.current_z + length / 2.0 - buttress_w),
                        Vec3::new(-width / 2.0, height * 0.7, self.current_z + length / 2.0 + buttress_w),
                        structural_instability,
                    );
                    self.mesh.add_cuboid(
                        Vec3::new(width / 2.0, 0.0, self.current_z + length / 2.0 - buttress_w),
                        Vec3::new(width / 2.0 + 2.5, height * 0.7, self.current_z + length / 2.0 + buttress_w),
                        structural_instability,
                    );

                    self.current_z += length + 3.0;
                }
            }
            AstNode::Struct { field_count, .. } => {
                // Structs create decorative spires framing the perimeter
                let pillar_height = 5.0 + (*field_count as f32 * 1.5);
                self.mesh.add_cuboid(
                    Vec3::new(-10.0, 0.0, self.current_z),
                    Vec3::new(-8.5, pillar_height, self.current_z + 1.5),
                    0.0,
                );
            }
        }
    }

    pub fn finalize(self) -> String {
        self.mesh.export_to_obj()
    }
}

fn main() {
    // Construct a mock codebase AST
    let codebase_ast = AstNode::Module {
        name: "crate_root".to_string(),
        children: vec![
            AstNode::Function {
                name: "bootstrap".to_string(),
                cyclomatic_complexity: 2,
                is_dead_code: false,
                has_merge_conflict: false,
            },
            AstNode::Struct {
                name: "DatabasePool".to_string(),
                field_count: 6,
            },
            AstNode::Function {
                name: "legacy_auth_v1".to_string(),
                cyclomatic_complexity: 7,
                is_dead_code: true, // Subterranean crypt
                has_merge_conflict: false,
            },
            AstNode::Function {
                name: "evaluate_expression_tree".to_string(),
                cyclomatic_complexity: 16, // Towering main hall & tall spire
                is_dead_code: false,
                has_merge_conflict: true, // Structural degradation due to merge conflicts
            },
            AstNode::Function {
                name: "unused_experimental_feature".to_string(),
                cyclomatic_complexity: 5,
                is_dead_code: true, // Deep crypt
                has_merge_conflict: true,
            },
            AstNode::Function {
                name: "render_frame".to_string(),
                cyclomatic_complexity: 8,
                is_dead_code: false,
                has_merge_conflict: false,
            },
        ],
    };

    // Build cathedral mesh from AST
    let mut generator = CathedralGenerator::new();
    generator.build_from_ast(&codebase_ast);

    // Output model in 3D Wavefront OBJ format
    let obj_output = generator.finalize();
    let file_path = "cathedral.obj";

    let mut file = File::create(file_path).expect("Failed to create OBJ output file");
    file.write_all(obj_output.as_bytes()).expect("Failed to write mesh data");

    println!("Success: Generated 3D Cathedral mesh at '{}'.", file_path);
}