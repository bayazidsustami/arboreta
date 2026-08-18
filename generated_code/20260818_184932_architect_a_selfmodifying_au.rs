use std::f32::consts::PI;

/// Represents live system metrics used to drive generative rendering.
#[derive(Debug, Clone, Copy)]
pub struct SystemTelemetry {
    pub cpu_usage: f32,    // Range: 0.0 to 1.0
    pub memory_usage: f32, // Range: 0.0 to 1.0
    pub network_io: f32,   // Normalized scale
    pub audio_rms: f32,    // Audio amplitude reactive value (0.0 to 1.0)
}

/// Dynamic canvas configuration mutated by telemetry.
pub struct GenerativeCanvas {
    pub width: u32,
    pub height: u32,
    pub calligram_text: String,
}

impl GenerativeCanvas {
    pub fn new(width: u32, height: u32, text: &str) -> Self {
        Self {
            width,
            height,
            calligram_text: text.to_string(),
        }
    }

    /// Translates live telemetry into an evolving interactive SVG calligram.
    pub fn render_svg(&self, telemetry: &SystemTelemetry, time_step: f32) -> String {
        let center_x = self.width as f32 / 2.0;
        let center_y = self.height as f32 / 2.0;

        // Telemetry-driven parameters
        let spiral_expansion = 10.0 + telemetry.cpu_usage * 25.0;
        let font_base_size = 12.0 + telemetry.memory_usage * 16.0;
        let wave_frequency = 2.0 + telemetry.network_io * 8.0;
        let audio_pulse = 1.0 + telemetry.audio_rms * 2.5;

        // Color palette parameters dynamically driven by telemetry
        let hue_base = (time_step * 30.0 + telemetry.cpu_usage * 180.0) % 360.0;
        let sat = 70.0 + telemetry.audio_rms * 30.0;

        let chars: Vec<char> = self.calligram_text.chars().collect();
        let char_count = chars.len().max(1);

        let mut svg_elements = String::new();

        // Generate ASCII calligram placed along a parametric logarithmic spiral deformed by audio audio_rms
        for i in 0..120 {
            let ch = chars[i % char_count];
            let t = i as f32 * 0.15 + time_step * 0.5;

            // Parametric spiral path with wave modulation
            let radius = spiral_expansion * (0.8 * t).exp() * (1.0 + 0.2 * (t * wave_frequency).sin() * audio_pulse);
            let angle = t + (time_step * 0.2);

            let x = center_x + radius * angle.cos();
            let y = center_y + radius * angle.sin();

            // Skip rendering if point drifts out of bounds
            if x < 0.0 || x > self.width as f32 || y < 0.0 || y > self.height as f32 {
                continue;
            }

            // Self-modifying styling per character
            let local_font_size = font_base_size * (1.0 + 0.3 * (angle * 3.0).sin() * audio_pulse);
            let rotation_deg = angle * (180.0 / PI) + 90.0;
            let opacity = (1.0 - (radius / (self.width as f32 * 0.5))).clamp(0.1, 1.0);
            let char_hue = (hue_base + i as f32 * 3.0) % 360.0;

            svg_elements.push_str(&format!(
                r#"<text x="{:.2}" y="{:.2}" font-size="{:.2}" fill="hsl({:.1}, {:.1}%, 60%)" opacity="{:.2}" transform="rotate({:.2}, {:.2}, {:.2})" text-anchor="middle" dominant-baseline="middle">{}</text>"#,
                x, y, local_font_size, char_hue, sat, opacity, rotation_deg, x, y, ch
            ));
            svg_elements.push('\n');
        }

        // Return complete self-contained SVG with interactive CSS animations
        format!(
            r#"<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 {} {}" width="100%" height="100%" style="background:#0a0a12; font-family: monospace; font-weight: bold;">
<style>
    text {{ transition: all 0.05s ease-out; cursor: pointer; }}
    text:hover {{ fill: #ffffff !important; font-size: 24px !important; stroke: #00ffff; stroke-width: 0.5px; }}
</style>
<g id="calligram">
{}
</g>
</svg>"#,
            self.width, self.height, svg_elements
        )
    }
}

fn main() {
    // Instantiate the self-modifying canvas with ASCII text motif
    let canvas = GenerativeCanvas::new(1000, 1000, "01100101011000110110100001101111");

    // Simulated live telemetry feed (CPU, RAM, Net I/O, Audio RMS)
    let sample_telemetry = SystemTelemetry {
        cpu_usage: 0.42,
        memory_usage: 0.68,
        network_io: 0.85,
        audio_rms: 0.73,
    };

    // Render an SVG snapshot at time step 1.2
    let svg_output = canvas.render_svg(&sample_telemetry, 1.2);

    println!("{}", svg_output);
}