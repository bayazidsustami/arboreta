use eframe::egui;
use rodio::{OutputStream, Sink, source::Source};
use std::collections::HashMap;
use std::f32::consts::PI;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

// ============================================================================
// 1. Ecosystem Code Representation & AST Parser Simulation
// ============================================================================

#[derive(Clone, Debug)]
struct FunctionNode {
    name: String,
    cyclomatic_complexity: usize,
    memory_allocation_bytes: usize,
    is_leaking: bool,
    calls: Vec<FunctionNode>,
}

impl FunctionNode {
    /// Generates a synthetic "living ecosystem" function execution tree.
    fn generate_ecosystem_tree() -> Self {
        FunctionNode {
            name: "root_ecosystem_kernel".into(),
            cyclomatic_complexity: 4,
            memory_allocation_bytes: 512,
            is_leaking: false,
            calls: vec![
                FunctionNode {
                    name: "photosynthesis_pipeline".into(),
                    cyclomatic_complexity: 8,
                    memory_allocation_bytes: 2048,
                    is_leaking: false,
                    calls: vec![
                        FunctionNode {
                            name: "photon_absorption".into(),
                            cyclomatic_complexity: 3,
                            memory_allocation_bytes: 128,
                            is_leaking: false,
                            calls: vec![],
                        },
                        FunctionNode {
                            name: "chlorophyll_synth_loop".into(),
                            cyclomatic_complexity: 12, // High complexity -> High fractal mutation
                            memory_allocation_bytes: 8192,
                            is_leaking: true, // Memory leak causes visible decay!
                            calls: vec![],
                        },
                    ],
                },
                FunctionNode {
                    name: "nutrient_transport".into(),
                    cyclomatic_complexity: 6,
                    memory_allocation_bytes: 1024,
                    is_leaking: false,
                    calls: vec![
                        FunctionNode {
                            name: "xylem_flow_pump".into(),
                            cyclomatic_complexity: 15,
                            memory_allocation_bytes: 4096,
                            is_leaking: false,
                            calls: vec![],
                        },
                        FunctionNode {
                            name: "unbounded_caching_layer".into(),
                            cyclomatic_complexity: 2,
                            memory_allocation_bytes: 32768,
                            is_leaking: true, // Leaking branch
                            calls: vec![],
                        },
                    ],
                },
            ],
        }
    }
}

// ============================================================================
// 2. Procedural Audio Synthesis Engine
// ============================================================================

#[derive(Clone)]
struct SharedAudioState {
    frequencies: Vec<f32>,
    decay_noise: f32,
}

struct EcosystemAudioSource {
    sample_rate: u32,
    phase: f32,
    state: Arc<Mutex<SharedAudioState>>,
}

impl EcosystemAudioSource {
    fn new(state: Arc<Mutex<SharedAudioState>>) -> Self {
        Self {
            sample_rate: 44100,
            phase: 0.0,
            state,
        }
    }
}

impl Iterator for EcosystemAudioSource {
    type Item = f32;

    fn next(&mut self) -> Option<Self::Item> {
        self.phase += 1.0 / self.sample_rate as f32;
        let state = self.state.lock().unwrap();
        
        let mut sample = 0.0;
        let count = state.frequencies.len().max(1) as f32;
        
        for (i, &freq) in state.frequencies.iter().enumerate() {
            let mod_freq = freq + (self.phase * 2.0 * PI * 0.5).sin() * 5.0;
            let wave = (self.phase * 2.0 * PI * mod_freq).sin();
            let harmonic = ((self.phase * 2.0 * PI * mod_freq * 1.5).sin()) * 0.3;
            sample += (wave + harmonic) / count;
        }

        // Add crackle noise for decay/memory leaks
        if state.decay_noise > 0.0 {
            let noise = ((self.phase * 123456.789).sin() * 43758.5453).fract();
            sample += noise * state.decay_noise * 0.15;
        }

        Some(sample * 0.2) // Master gain
    }
}

impl Source for EcosystemAudioSource {
    fn current_frame_len(&self) -> Option<usize> { None }
    fn channels(&self) -> u16 { 1 }
    fn sample_rate(&self) -> u32 { self.sample_rate }
    fn total_duration(&self) -> Option<Duration> { None }
}

// ============================================================================
// 3. Organic Growing Fractal Visualizer Engine
// ============================================================================

struct VisualizerApp {
    ast_root: FunctionNode,
    growth_progress: f32,
    start_time: Instant,
    audio_state: Arc<Mutex<SharedAudioState>>,
    _stream: Option<OutputStream>,
    _sink: Option<Sink>,
}

impl VisualizerApp {
    fn new(_cc: &eframe::CreationContext) -> Self {
        let ast_root = FunctionNode::generate_ecosystem_tree();
        let audio_state = Arc::new(Mutex::new(SharedAudioState {
            frequencies: vec![220.0],
            decay_noise: 0.0,
        }));

        // Initialize Audio System
        let (stream, sink) = match OutputStream::try_default() {
            Ok((stream, handle)) => {
                let sink = Sink::try_new(&handle).ok();
                if let Some(ref s) = sink {
                    s.append(EcosystemAudioSource::new(audio_state.clone()));
                    s.play();
                }
                (Some(stream), sink)
            }
            Err(_) => (None, None),
        };

        Self {
            ast_root,
            growth_progress: 0.0,
            start_time: Instant::now(),
            audio_state,
            _stream: stream,
            _sink: sink,
        }
    }

    /// Renders recursive fractal flora from the AST nodes.
    fn render_branch(
        &self,
        painter: &egui::Painter,
        node: &FunctionNode,
        origin: egui::Pos2,
        angle: f32,
        length: f32,
        depth: usize,
        time: f32,
        active_freqs: &mut Vec<f32>,
        total_decay: &mut f32,
    ) {
        if length < 2.0 || self.growth_progress < (depth as f32 * 0.15) {
            return;
        }

        // Map node properties to visual mutation parameters
        let complexity_factor = node.cyclomatic_complexity as f32;
        let mutation_wobble = (time * 2.0 + depth as f32).sin() * (complexity_factor * 0.03);
        let final_angle = angle + mutation_wobble;

        // Calculate branch length based on memory allocation and current growth
        let effective_length = length * (1.0 + (node.memory_allocation_bytes as f32 / 10000.0)).min(1.8);
        let target_pos = origin + egui::vec2(final_angle.cos(), final_angle.sin()) * effective_length;

        // Audio pitch mapped from depth and complexity
        let base_freq = 110.0 * (1.3333f32).powi(depth as i32) + (complexity_factor * 12.0);
        active_freqs.push(base_freq);

        // Visual Decay derived from Memory Leaks
        let decay_factor = if node.is_leaking {
            let d = ((time * 3.0 + depth as f32).sin() * 0.5 + 0.5) * 0.8 + 0.2;
            *total_decay += d;
            d
        } else {
            0.0
        };

        // Organic Palette Selection
        let base_color = if node.is_leaking {
            // Sickly yellow/brown rot
            egui::Color32::from_rgb(
                (180.0 * (1.0 - decay_factor)) as u8 + 50,
                (140.0 * (1.0 - decay_factor)) as u8,
                30,
            )
        } else {
            // Lush bio-luminescent flora greens and cyans
            egui::Color32::from_rgb(
                (40.0 + depth as f32 * 30.0) as u8,
                (200.0 - depth as f32 * 20.0) as u8,
                (120.0 + (time * 2.0).sin() * 40.0) as u8,
            )
        };

        let stroke_width = (8.0 / (depth as f32 + 1.0)) * (1.0 - decay_factor * 0.5);

        // Draw current branch
        painter.line_segment(
            [origin, target_pos],
            egui::Stroke::new(stroke_width, base_color),
        );

        // Draw node execution leaf/blossom
        let leaf_radius = (complexity_factor * 0.8).clamp(3.0, 12.0);
        let leaf_color = if node.is_leaking {
            egui::Color32::from_rgb(220, 60, 40) // Pulsing memory leak alert
        } else {
            egui::Color32::from_rgb(100, 240, 180)
        };

        painter.circle_filled(target_pos, leaf_radius * (1.0 - decay_factor * 0.3), leaf_color);

        // Recursively branch out to call sub-trees
        let num_calls = node.calls.len();
        if num_calls > 0 {
            let spread_angle = PI / (num_calls as f32 + 1.0) * (1.0 + complexity_factor * 0.05);
            let start_angle = final_angle - (spread_angle * (num_calls as f32 - 1.0) / 2.0);

            for (i, child) in node.calls.iter().enumerate() {
                let child_angle = start_angle + (i as f32 * spread_angle);
                self.render_branch(
                    painter,
                    child,
                    target_pos,
                    child_angle,
                    effective_length * 0.68,
                    depth + 1,
                    time,
                    active_freqs,
                    total_decay,
                );
            }
        }
    }
}

impl eframe::App for VisualizerApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        let time = self.start_time.elapsed().as_secs_f32();
        self.growth_progress = (time * 0.4).min(1.0); // Smooth growth animation

        egui::CentralPanel::default()
            .frame(egui::Frame::dark_canvas().fill(egui::Color32::from_rgb(10, 12, 18)))
            .show(ctx, |ui| {
                let rect = ui.max_rect();
                let painter = ui.painter_at(rect);
                let root_origin = egui::pos2(rect.center().x, rect.bottom() - 60.0);

                let mut active_freqs = Vec::new();
                let mut total_decay = 0.0f32;

                // Render the living AST flora
                self.render_branch(
                    &painter,
                    &self.ast_root,
                    root_origin,
                    -PI / 2.0, // Growing upwards
                    110.0,
                    0,
                    time,
                    &mut active_freqs,
                    &mut total_decay,
                );

                // Synchronize audio synthesis state with ecosystem render
                if let Ok(mut audio) = self.audio_state.lock() {
                    audio.frequencies = active_freqs;
                    audio.decay_noise = total_decay;
                }

                // Display HUD Overlay
                painter.text(
                    egui::pos2(20.0, 20.0),
                    egui::Align2::LEFT_TOP,
                    format!("Ecosystem Code Visualizer\nGrowth Phase: {:.1}%\nDecay Intensity: {:.2}", 
                        self.growth_progress * 100.0, total_decay),
                    egui::FontId::proportional(16.0),
                    egui::Color32::from_rgb(180, 220, 200),
                );
            });

        // Request continuous rendering for real-time visualization
        ctx.request_repaint();
    }
}

fn main() -> Result<(), eframe::Error> {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1024.0, 768.0])
            .with_title("Living Ecosystem Code Audio Visualizer"),
        ..Default::default()
    };

    eframe::run_native(
        "Organic Code Visualizer",
        options,
        Box::new(|cc| Box::new(VisualizerApp::new(cc))),
    )
}