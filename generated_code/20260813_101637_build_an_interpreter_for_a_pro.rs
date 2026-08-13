// Contrapuntal Shader Compiler (CSC)
// Interprets MIDI voice leading according to strict species counterpoint rules,
// compiling valid harmonic progressions directly into GLSL fragment shaders.

use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Pitch {
    C = 0, Cs = 1, D = 2, Ds = 3, E = 4, F = 5,
    Fs = 6, G = 7, Gs = 8, A = 9, As = 10, B = 11,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Note {
    pub pitch: Pitch,
    pub octave: i8,
    pub duration_ticks: u32,
}

impl Note {
    pub fn midi_number(&self) -> i32 {
        (self.octave as i32 + 1) * 12 + (self.pitch as i32)
    }
}

#[derive(Debug, Clone)]
pub struct VerticalSlice {
    pub time_tick: u32,
    pub cantus_firmus: Note, // Lower voice
    pub counterpoint: Note,  // Upper voice
}

#[derive(Debug, PartialEq, Eq)]
pub enum IntervalQuality {
    PerfectUnison,
    MinorSecond,
    MajorSecond,
    MinorThird,
    MajorThird,
    PerfectFourth,
    Tritone,
    PerfectFifth,
    MinorSixth,
    MajorSixth,
    MinorSeventh,
    MajorSeventh,
    PerfectOctave,
    Compound,
}

impl VerticalSlice {
    pub fn interval_semitones(&self) -> i32 {
        (self.counterpoint.midi_number() - self.cantus_firmus.midi_number()).abs()
    }

    pub fn quality(&self) -> IntervalQuality {
        match self.interval_semitones() % 12 {
            0 => if self.interval_semitones() == 0 { IntervalQuality::PerfectUnison } else { IntervalQuality::PerfectOctave },
            1 => IntervalQuality::MinorSecond,
            2 => IntervalQuality::MajorSecond,
            3 => IntervalQuality::MinorThird,
            4 => IntervalQuality::MajorThird,
            5 => IntervalQuality::PerfectFourth,
            6 => IntervalQuality::Tritone,
            7 => IntervalQuality::PerfectFifth,
            8 => IntervalQuality::MinorSixth,
            9 => IntervalQuality::MajorSixth,
            10 => IntervalQuality::MinorSeventh,
            11 => IntervalQuality::MajorSeventh,
            _ => IntervalQuality::Compound,
        }
    }

    pub fn is_consonant(&self) -> bool {
        matches!(
            self.quality(),
            IntervalQuality::PerfectUnison
                | IntervalQuality::MinorThird
                | IntervalQuality::MajorThird
                | IntervalQuality::PerfectFifth
                | IntervalQuality::MinorSixth
                | IntervalQuality::MajorSixth
                | IntervalQuality::PerfectOctave
        )
    }
}

// GLSL AST Nodes derived from musical motion
#[derive(Debug)]
pub enum ShaderOp {
    ColorShift { r: f32, g: f32, b: f32 },
    DomainWarp { scale: f32 },
    RotateSpace { speed: f32 },
    RaymarchDistance { power: f32 },
    BlendLayer { weight: f32 },
}

pub struct CounterpointInterpreter {
    slices: Vec<VerticalSlice>,
}

impl CounterpointInterpreter {
    pub fn new(slices: Vec<VerticalSlice>) -> Self {
        Self { slices }
    }

    // Validates First & Second Species Counterpoint Rules
    pub fn validate_and_compile(&self) -> Result<Vec<ShaderOp>, String> {
        let mut ops = Vec::new();

        if self.slices.is_empty() {
            return Err("Empty composition".to_string());
        }

        for i in 0..self.slices.len() {
            let current = &self.slices[i];

            // Rule 1: No voice crossing
            if current.counterpoint.midi_number() < current.cantus_firmus.midi_number() {
                return Err(format!("Syntax Error at tick {}: Voice crossing detected.", current.time_tick));
            }

            // Rule 2: Harmonic Consonance check for harmonic stability
            if !current.is_consonant() {
                return Err(format!(
                    "Syntax Error at tick {}: Dissonant interval ({:?}) without proper species resolution.",
                    current.time_tick,
                    current.quality()
                ));
            }

            // Compile interval quality into visual transform
            let op = match current.quality() {
                IntervalQuality::PerfectUnison | IntervalQuality::PerfectOctave => ShaderOp::ColorShift {
                    r: 0.1,
                    g: 0.8,
                    b: 0.9,
                },
                IntervalQuality::MinorThird | IntervalQuality::MajorThird => ShaderOp::DomainWarp {
                    scale: (current.interval_semitones() as f32) * 0.2,
                },
                IntervalQuality::PerfectFifth => ShaderOp::RotateSpace {
                    speed: (current.cantus_firmus.midi_number() as f32) * 0.05,
                },
                IntervalQuality::MinorSixth | IntervalQuality::MajorSixth => ShaderOp::RaymarchDistance {
                    power: (current.counterpoint.midi_number() as f32) * 0.02,
                },
                _ => ShaderOp::BlendLayer { weight: 0.5 },
            };
            ops.push(op);

            // Rule 3: Consecutive Motion Checks (Parallel 5ths & Octaves)
            if i > 0 {
                let prev = &self.slices[i - 1];
                let prev_qual = prev.quality();
                let curr_qual = current.quality();

                let cf_motion = current.cantus_firmus.midi_number() - prev.cantus_firmus.midi_number();
                let cp_motion = current.counterpoint.midi_number() - prev.counterpoint.midi_number();

                let is_parallel = (cf_motion > 0 && cp_motion > 0) || (cf_motion < 0 && cp_motion < 0);

                if is_parallel {
                    if (prev_qual == IntervalQuality::PerfectFifth && curr_qual == IntervalQuality::PerfectFifth)
                        || (prev_qual == IntervalQuality::PerfectOctave && curr_qual == IntervalQuality::PerfectOctave)
                    {
                        return Err(format!(
                            "Syntax Error between ticks {} and {}: Forbidden parallel fifths/octaves.",
                            prev.time_tick, current.time_tick
                        ));
                    }
                }
            }
        }

        Ok(ops)
    }

    pub fn emit_glsl(&self, ops: &[ShaderOp]) -> String {
        let mut glsl = String::new();
        glsl.push_str("// Auto-generated GLSL Visualizer compiled from Counterpoint Syntax\n");
        glsl.push_str("#version 330 core\n");
        glsl.push_str("out vec4 FragColor;\n");
        glsl.push_str("uniform vec2 u_resolution;\n");
        glsl.push_str("uniform float u_time;\n\n");
        glsl.push_str("mat2 rotate2d(float angle) {\n");
        glsl.push_str("    return mat2(cos(angle), -sin(angle), sin(angle), cos(angle));\n");
        glsl.push_str("}\n\n");
        glsl.push_str("void main() {\n");
        glsl.push_str("    vec2 st = (gl_FragCoord.xy - 0.5 * u_resolution.xy) / u_resolution.y;\n");
        glsl.push_str("    vec3 col = vec3(0.0);\n");
        glsl.push_str("    float d = length(st);\n\n");

        for (idx, op) in ops.iter().enumerate() {
            glsl.push_str(&format!("    // Pass {}: Musical Transformation\n", idx + 1));
            match op {
                ShaderOp::ColorShift { r, g, b } => {
                    glsl.push_str(&format!("    col += vec3({:.2}, {:.2}, {:.2}) * sin(u_time + d * 4.0);\n", r, g, b));
                }
                ShaderOp::DomainWarp { scale } => {
                    glsl.push_str(&format!("    st += sin(st.yx * {:.2} + u_time) * 0.1;\n", scale));
                }
                ShaderOp::RotateSpace { speed } => {
                    glsl.push_str(&format!("    st *= rotate2d(u_time * {:.2});\n", speed));
                }
                ShaderOp::RaymarchDistance { power } => {
                    glsl.push_str(&format!("    d = pow(abs(sin(d * {:.2} - u_time)), 2.0);\n", power));
                }
                ShaderOp::BlendLayer { weight } => {
                    glsl.push_str(&format!("    col = mix(col, vec3(st.x, st.y, 0.5), {:.2});\n", weight));
                }
            }
        }

        glsl.push_str("\n    FragColor = vec4(col, 1.0);\n");
        glsl.push_str("}\n");
        glsl
    }
}

fn main() {
    println!("=== Counterpoint MIDI to GLSL Shader Compiler ===");

    // Mock polyphonic MIDI score meeting strict 1st species counterpoint rules
    let score = vec![
        VerticalSlice {
            time_tick: 0,
            cantus_firmus: Note { pitch: Pitch::C, octave: 4, duration_ticks: 480 },
            counterpoint: Note { pitch: Pitch::G, octave: 4, duration_ticks: 480 }, // Perfect 5th
        },
        VerticalSlice {
            time_tick: 480,
            cantus_firmus: Note { pitch: Pitch::D, octave: 4, duration_ticks: 480 },
            counterpoint: Note { pitch: Pitch::F, octave: 5, duration_ticks: 480 }, // Minor 10th (Compound 3rd)
        },
        VerticalSlice {
            time_tick: 960,
            cantus_firmus: Note { pitch: Pitch::E, octave: 4, duration_ticks: 480 },
            counterpoint: Note { pitch: Pitch::C, octave: 5, duration_ticks: 480 }, // Minor 6th
        },
        VerticalSlice {
            time_tick: 1440,
            cantus_firmus: Note { pitch: Pitch::C, octave: 4, duration_ticks: 480 },
            counterpoint: Note { pitch: Pitch::C, octave: 5, duration_ticks: 480 }, // Octave
        },
    ];

    let interpreter = CounterpointInterpreter::new(score);

    match interpreter.validate_and_compile() {
        Ok(ast) => {
            println!("[Success] Counterpoint rules validated. Compiling GLSL shader...\n");
            let glsl_code = interpreter.emit_glsl(&ast);
            println!("{}", glsl_code);
        }
        Err(err) => {
            println!("[Syntax Error] Failed counterpoint parsing:\n{}", err);
        }
    }
}