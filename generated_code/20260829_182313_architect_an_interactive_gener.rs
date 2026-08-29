use macroquad::prelude::*;
use std::collections::VecDeque;

// Raymarching Fragment Shader written in GLSL
// It renders an evolving 3D topological map based on cadence, emotional state, and typing force.
const FRAGMENT_SHADER: &str = r#"
#version 100
precision highp float;

varying vec2 uv;

uniform float u_time;
uniform vec2 u_resolution;
uniform float u_cadence;
uniform float u_valence;
uniform float u_arousal;
uniform float u_force;

// Smooth minimum for organic topological blending
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// 2D Rotation matrix
mat2 rot(float a) {
    float s = sin(a), c = cos(a);
    return mat2(c, -s, s, c);
}

// Signed Distance Function representing the evolving emotional topology
float map(vec3 p) {
    vec3 q = p;
    q.xz *= rot(u_time * 0.15 + u_cadence * 0.05);

    // Dynamic sine-wave terrain layered with emotional valence and arousal
    float wave1 = sin(q.x * (1.5 + u_arousal * 2.0) + u_time * 2.0) * cos(q.z * (1.5 + u_arousal * 2.0));
    float wave2 = cos(q.x * 3.0 - u_time) * sin(q.z * 3.0 + u_time * 1.5) * 0.5;
    
    // Base landscape plane modified by keypress force pulse
    float terrain = q.y + 0.8 + (wave1 + wave2) * (0.3 + u_valence * 0.5) - u_force * 0.2;

    // Central topological core sphere representing emotional resonance
    vec3 spherePos = q - vec3(0.0, 0.2 + sin(u_time * 2.0) * 0.1, 0.0);
    float sphereRadius = 0.5 + u_force * 0.4 + u_cadence * 0.1;
    float core = length(spherePos) - sphereRadius;

    // Add high-frequency displacement texture to the core based on typing speed
    core += sin(spherePos.x * 12.0 + u_time * 4.0) * sin(spherePos.y * 12.0) * sin(spherePos.z * 12.0) * (0.05 + u_cadence * 0.08);

    // Smoothly blend the central core into the topological terrain
    return smin(terrain, core, 0.6);
}

// Estimate surface normal using finite differences
vec3 calcNormal(vec3 p) {
    vec2 e = vec2(0.002, 0.0);
    return normalize(vec3(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)
    ));
}

void main() {
    vec2 st = (gl_FragCoord.xy - u_resolution * 0.5) / min(u_resolution.x, u_resolution.y);

    // Ray setup
    vec3 ro = vec3(0.0, 1.2, -3.0); // Camera origin
    vec3 rd = normalize(vec3(st, 1.2)); // Ray direction
    rd.yz *= rot(-0.35); // Look down slightly at the terrain

    // Raymarching loop
    float t = 0.0;
    float tMax = 15.0;
    for (int i = 0; i < 70; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        if (d < 0.001 || t > tMax) break;
        t += d * 0.65; // Relaxed step size for smooth SDF surfaces
    }

    // Color palette based on emotional state (Arousal = Warm/Red vs Cool/Blue, Valence = Vibrancy)
    vec3 coolTone = vec3(0.1, 0.4, 0.8);
    vec3 warmTone = vec3(0.9, 0.2, 0.4);
    vec3 energeticTone = vec3(1.0, 0.7, 0.1);
    
    vec3 baseColor = mix(coolTone, warmTone, u_arousal);
    baseColor = mix(baseColor, energeticTone, u_valence * 0.5);

    vec3 finalColor = vec3(0.02, 0.02, 0.05); // Background atmospheric fog

    if (t < tMax) {
        vec3 p = ro + rd * t;
        vec3 normal = calcNormal(p);
        vec3 lightDir = normalize(vec3(0.5, 1.0, -0.8));

        // Diffuse lighting + Specular highlights
        float diff = max(dot(normal, lightDir), 0.0);
        float spec = pow(max(dot(reflect(-lightDir, normal), -rd), 0.0), 16.0);
        
        // Grid lines to enhance topological map visual aesthetics
        float grid = abs(sin(p.x * 10.0)) * abs(sin(p.z * 10.0));
        grid = smoothstep(0.1, 0.9, grid);

        vec3 surfaceColor = mix(baseColor, vec3(1.0), grid * 0.2);
        finalColor = surfaceColor * (diff * 0.8 + 0.2) + vec3(0.8, 0.9, 1.0) * spec * (u_force + 0.2);

        // Distance fog effect
        float fog = 1.0 - exp(-t * 0.15);
        finalColor = mix(finalColor, vec3(0.02, 0.02, 0.05), fog);
    }

    // Add subtle force-driven glow vignette
    float dist = length(st);
    finalColor += baseColor * (u_force * 0.3) * (1.0 - smoothstep(0.0, 0.8, dist));

    gl_FragColor = vec4(finalColor, 1.0);
}
"#;

// Struct tracking user typing dynamics to compute emotional dimensions
struct EmotionalCadenceTracker {
    keypress_timestamps: VecDeque<f64>,
    valence: f32, // -1.0 (Calm/Steady) to 1.0 (Excited/Chaotic)
    arousal: f32, // 0.0 (Low intensity) to 1.0 (High intensity)
    force: f32,   // Simulated keypress force burst
}

impl EmotionalCadenceTracker {
    fn new() -> Self {
        Self {
            keypress_timestamps: VecDeque::new(),
            valence: 0.5,
            arousal: 0.2,
            force: 0.0,
        }
    }

    fn register_keypress(&mut self, current_time: f64) {
        self.keypress_timestamps.push_back(current_time);
        
        // Spike simulated force on keypress, capped at maximum 1.0
        self.force = (self.force + 0.4).min(1.0);

        // Keep timestamps within a rolling 3-second window
        while let Some(&t) = self.keypress_timestamps.front() {
            if current_time - t > 3.0 {
                self.keypress_timestamps.pop_front();
            } else {
                break;
            }
        }
    }

    fn update(&mut self, current_time: f64, delta_time: f32) {
        // Prune old timestamps
        while let Some(&t) = self.keypress_timestamps.front() {
            if current_time - t > 3.0 {
                self.keypress_timestamps.pop_front();
            } else {
                break;
            }
        }

        // Calculate Typing Cadence (keys per second over rolling window)
        let count = self.keypress_timestamps.len();
        let cadence = (count as f32) / 3.0; // Normalized active frequency

        // Target emotional metrics derived from typing rhythm
        let target_arousal = (cadence / 6.0).min(1.0); // High CPS = high arousal
        
        // Evaluate inter-key delay variance to infer emotional valence (regular rhythm = high valence)
        let mut variance = 0.0;
        if count > 2 {
            let intervals: Vec<f64> = self
                .keypress_timestamps
                .iter()
                .zip(self.keypress_timestamps.iter().skip(1))
                .map(|(a, b)| b - a)
                .collect();
            let avg: f64 = intervals.iter().sum::<f64>() / intervals.len() as f64;
            let var_sum: f64 = intervals.iter().map(|&i| (i - avg).powi(2)).sum();
            variance = (var_sum / intervals.len() as f64) as f32;
        }

        let target_valence = (1.0 - (variance * 5.0).min(1.0)).max(0.0);

        // Smoothly interpolate emotional dimensions towards targets
        self.arousal += (target_arousal - self.arousal) * delta_time * 2.0;
        self.valence += (target_valence - self.valence) * delta_time * 2.0;

        // Decay impulse force over time
        self.force = (self.force - delta_time * 2.5).max(0.0);
    }

    fn get_cadence(&self) -> f32 {
        (self.keypress_timestamps.len() as f32) / 3.0
    }
}

fn window_conf() -> Conf {
    Conf {
        window_title: "Topological Map of Emotional Resonance".to_string(),
        window_width: 1024,
        window_height: 768,
        high_dpi: true,
        ..Default::default()
    }
}

#[macroquad::main(window_conf)]
async fn main() {
    // Compile raymarching material from GLSL fragment shader
    let material = load_material(
        ShaderSource::Glsl {
            vertex: VERTEX_SHADER,
            fragment: FRAGMENT_SHADER,
        },
        MaterialParams {
            uniforms: vec![
                UniformDesc::new("u_time", UniformType::Float),
                UniformDesc::new("u_resolution", UniformType::Float2),
                UniformDesc::new("u_cadence", UniformType::Float),
                UniformDesc::new("u_valence", UniformType::Float),
                UniformDesc::new("u_arousal", UniformType::Float),
                UniformDesc::new("u_force", UniformType::Float),
            ],
            ..Default::default()
        },
    )
    .expect("Failed to compile Shader");

    let mut tracker = EmotionalCadenceTracker::new();

    loop {
        let current_time = get_time();
        let delta_time = get_frame_time();

        // Capture keyboard events
        if get_last_key_pressed().is_some() {
            tracker.register_keypress(current_time);
        }

        // Update internal emotional topological state
        tracker.update(current_time, delta_time);

        // Pass dynamic state parameters to raymarching shader uniforms
        material.set_uniform("u_time", current_time as f32);
        material.set_uniform("u_resolution", vec2(screen_width(), screen_height()));
        material.set_uniform("u_cadence", tracker.get_cadence());
        material.set_uniform("u_valence", tracker.valence);
        material.set_uniform("u_arousal", tracker.arousal);
        material.set_uniform("u_force", tracker.force);

        // Render full-screen generative canvas
        clear_background(BLACK);
        gl_use_material(&material);
        draw_rectangle(0.0, 0.0, screen_width(), screen_height(), WHITE);
        gl_use_default_material();

        // Overlay Real-Time Analytics UI
        draw_rectangle(15.0, 15.0, 320.0, 120.0, Color::new(0.0, 0.0, 0.0, 0.7));
        draw_text("Type on your keyboard to deform topology...", 25.0, 35.0, 18.0, WHITE);
        draw_text(&format!("Cadence: {:.2} keys/s", tracker.get_cadence()), 25.0, 60.0, 16.0, GREEN);
        draw_text(&format!("Emotional Arousal: {:.2}", tracker.arousal), 25.0, 80.0, 16.0, ORANGE);
        draw_text(&format!("Emotional Valence: {:.2}", tracker.valence), 25.0, 100.0, 16.0, SKYBLUE);
        draw_text(&format!("Impulse Force:     {:.2}", tracker.force), 25.0, 120.0, 16.0, MAGENTA);

        next_frame().await;
    }
}

// Default Vertex Shader passes normalized screen coordinates to GLSL fragment shader
const VERTEX_SHADER: &str = r#"
#version 100
attribute vec3 position;
attribute vec2 texcoord;

varying vec2 uv;

uniform mat4 Model;
uniform mat4 Projection;

void main() {
    vec4 res = Projection * Model * vec4(position, 1.0);
    uv = texcoord;
    gl_Position = res;
}
"#;