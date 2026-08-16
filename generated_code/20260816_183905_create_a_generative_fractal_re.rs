use std::f32::consts::PI;

// Structural sentiment metrics parsed from text input
#[derive(Debug, Clone, Copy)]
struct PoemMetrics {
    sentiment: f32,    // -1.0 (melancholic/dark) to +1.0 (vibrant/joyful)
    cadence: f32,      // Rhythmic variation in sentence/word lengths (0.0 to 1.0)
    density: f32,      // Average word length / complexity (0.0 to 1.0)
    complexity: u32,   // Recursion depth based on line count
}

impl PoemMetrics {
    fn parse(poem: &str) -> Self {
        let lines: Vec<&str> = poem.lines().map(|l| l.trim()).filter(|l| !l.is_empty()).collect();
        if lines.is_empty() {
            return Self { sentiment: 0.0, cadence: 0.5, density: 0.5, complexity: 4 };
        }

        let words: Vec<&str> = poem.split_whitespace().collect();
        let total_words = words.len().max(1) as f32;
        let total_chars: usize = words.iter().map(|w| w.len()).sum();
        let avg_word_len = total_chars as f32 / total_words;

        // Lexicon-based sentiment heuristic
        let positive_words = ["light", "joy", "sun", "gold", "bloom", "fly", "bright", "sweet", "love", "rise", "glow", "warm", "star", "sing", "dance", "sky"];
        let negative_words = ["dark", "shadow", "fall", "cold", "night", "die", "grief", "grey", "gray", "tear", "alone", "fade", "silent", "stone", "dust", "void"];

        let mut pos_score = 0;
        let mut neg_score = 0;

        for word in &words {
            let clean = word.to_lowercase().chars().filter(|c| c.is_alphabetic()).collect::<String>();
            if positive_words.contains(&clean.as_str()) {
                pos_score += 1;
            }
            if negative_words.contains(&clean.as_str()) {
                neg_score += 1;
            }
        }

        let sentiment = if pos_score + neg_score == 0 {
            0.0
        } else {
            (pos_score as f32 - neg_score as f32) / (pos_score + neg_score) as f32
        };

        // Cadence variance: measure fluctuation in line lengths
        let line_lengths: Vec<f32> = lines.iter().map(|l| l.split_whitespace().count() as f32).collect();
        let mean_len = line_lengths.iter().sum::<f32>() / lines.len() as f32;
        let variance = line_lengths.iter().map(|&len| (len - mean_len).powi(2)).sum::<f32>() / lines.len() as f32;
        let cadence = (variance.sqrt() / (mean_len + 1.0)).clamp(0.0, 1.0);

        let density = (avg_word_len / 10.0).clamp(0.1, 1.0);
        let complexity = (lines.len() as u32 + 3).clamp(3, 8);

        Self {
            sentiment,
            cadence,
            density,
            complexity,
        }
    }
}

// RGB Color with smooth interpolation and palette generation
#[derive(Debug, Clone, Copy)]
struct Color {
    r: u8,
    g: u8,
    b: u8,
}

impl Color {
    fn lerp(self, other: Self, t: f32) -> Self {
        let t = t.clamp(0.0, 1.0);
        Self {
            r: (self.r as f32 + t * (other.r as f32 - self.r as f32)) as u8,
            g: (self.g as f32 + t * (other.g as f32 - self.g as f32)) as u8,
            b: (self.b as f32 + t * (other.b as f32 - self.b as f32)) as u8,
        }
    }
}

// Simple PPM Image Buffer (No external crate dependencies needed)
struct Canvas {
    width: usize,
    height: usize,
    pixels: Vec<Color>,
}

impl Canvas {
    fn new(width: usize, height: usize, bg: Color) -> Self {
        Self {
            width,
            height,
            pixels: vec![bg; width * height],
        }
    }

    fn draw_line(&mut self, x0: f32, y0: f32, x1: f32, y1: f32, color: Color, thickness: f32) {
        let dx = x1 - x0;
        let dy = y1 - y0;
        let steps = (dx.hypot(dy) * 2.0).ceil() as usize;
        
        for i in 0..=steps {
            let t = if steps == 0 { 0.0 } else { i as f32 / steps as f32 };
            let cx = x0 + t * dx;
            let cy = y0 + t * dy;

            let r = (thickness / 2.0).max(0.5);
            let min_x = ((cx - r).floor() as isize).max(0) as usize;
            let max_x = ((cx + r).ceil() as isize).min(self.width as isize - 1) as usize;
            let min_y = ((cy - r).floor() as isize).max(0) as usize;
            let max_y = ((cy + r).ceil() as isize).min(self.height as isize - 1) as usize;

            for y in min_y..=max_y {
                for x in min_x..=max_x {
                    let dist_sq = (x as f32 - cx).powi(2) + (y as f32 - cy).powi(2);
                    if dist_sq <= r * r {
                        let idx = y * self.width + x;
                        if idx < self.pixels.len() {
                            // Simple alpha blending based on edge closeness
                            let factor = 1.0 - (dist_sq.sqrt() / r).powi(2);
                            self.pixels[idx] = self.pixels[idx].lerp(color, factor * 0.8);
                        }
                    }
                }
            }
        }
    }

    fn save_ppm(&self, path: &str) -> std::io::Result<()> {
        use std::io::Write;
        let mut file = std::fs::File::create(path)?;
        writeln!(file, "P3\n{} {}\n255", self.width, self.height)?;
        for pixel in &self.pixels {
            writeln!(file, "{} {} {}", pixel.r, pixel.g, pixel.b)?;
        }
        Ok(())
    }
}

// Dynamic Palette mapping driven by poetic sentiment
struct Palette {
    trunk: Color,
    mid: Color,
    tip: Color,
}

impl Palette {
    fn from_sentiment(sentiment: f32) -> Self {
        if sentiment > 0.3 {
            // Bright, vibrant, joyful tones
            Self {
                trunk: Color { r: 60, g: 35, b: 20 },
                mid: Color { r: 210, g: 140, b: 40 },
                tip: Color { r: 255, g: 105, b: 180 },
            }
        } else if sentiment < -0.3 {
            // Dark, eerie, melancholic tones
            Self {
                trunk: Color { r: 20, g: 20, b: 35 },
                mid: Color { r: 70, g: 80, b: 120 },
                tip: Color { r: 140, g: 180, b: 210 },
            }
        } else {
            // Balanced, organic nature tones
            Self {
                trunk: Color { r: 45, g: 30, b: 15 },
                mid: Color { r: 40, g: 120, b: 50 },
                tip: Color { r: 160, g: 220, b: 90 },
            }
        }
    }

    fn sample(&self, depth_ratio: f32) -> Color {
        if depth_ratio < 0.5 {
            self.trunk.lerp(self.mid, depth_ratio * 2.0)
        } else {
            self.mid.lerp(self.tip, (depth_ratio - 0.5) * 2.0)
        }
    }
}

// Generative Fractal Tree Engine
struct FractalRenderer {
    metrics: PoemMetrics,
    palette: Palette,
}

impl FractalRenderer {
    fn new(poem: &str) -> Self {
        let metrics = PoemMetrics::parse(poem);
        let palette = Palette::from_sentiment(metrics.sentiment);
        Self { metrics, palette }
    }

    fn render_branch(
        &self,
        canvas: &mut Canvas,
        x: f32,
        y: f32,
        length: f32,
        angle: f32,
        thickness: f32,
        current_depth: u32,
        max_depth: u32,
    ) {
        if current_depth >= max_depth || length < 2.0 {
            return;
        }

        // Endpoint of current branch segment
        let x_end = x + angle.cos() * length;
        let y_end = y + angle.sin() * length;

        // Color based on progression through depth layers
        let depth_ratio = current_depth as f32 / max_depth as f32;
        let color = self.palette.sample(depth_ratio);

        canvas.draw_line(x, y, x_end, y_end, color, thickness);

        // Branching parameters modulated by cadence and sentiment
        let base_angle_spread = PI / (4.0 + self.metrics.sentiment * 1.5);
        let asymmetric_bias = self.metrics.cadence * 0.3;
        let length_decay = 0.72 - (self.metrics.density * 0.15);

        let branches = if self.metrics.cadence > 0.6 { 3 } else { 2 };

        for i in 0..branches {
            let offset = match branches {
                3 => (i as f32 - 1.0) * base_angle_spread,
                _ => if i == 0 { -base_angle_spread + asymmetric_bias } else { base_angle_spread + asymmetric_bias },
            };

            // Dynamic growth speed multiplier modulating length
            let growth_mod = 1.0 + (i as f32 * self.metrics.cadence * 0.2);
            let next_length = length * length_decay * growth_mod;
            let next_angle = angle + offset;
            let next_thickness = (thickness * 0.68).max(0.8);

            self.render_branch(
                canvas,
                x_end,
                y_end,
                next_length,
                next_angle,
                next_thickness,
                current_depth + 1,
                max_depth,
            );
        }
    }

    fn generate(&self, width: usize, height: usize, output_path: &str) -> std::io::Result<()> {
        let bg_color = if self.metrics.sentiment < -0.3 {
            Color { r: 8, g: 10, b: 18 }
        } else {
            Color { r: 245, g: 245, b: 240 }
        };

        let mut canvas = Canvas::new(width, height, bg_color);
        let start_x = width as f32 / 2.0;
        let start_y = height as f32 * 0.88;
        let initial_length = height as f32 * (0.18 + self.metrics.density * 0.05);
        let initial_angle = -PI / 2.0; // Upward orientation
        let initial_thickness = 12.0 * (1.0 + self.metrics.density);

        self.render_branch(
            &mut canvas,
            start_x,
            start_y,
            initial_length,
            initial_angle,
            initial_thickness,
            0,
            self.metrics.complexity,
        );

        canvas.save_ppm(output_path)
    }
}

fn main() {
    let poem = "
        I wandered lonely as a cloud
        That floats on high o'er vales and hills,
        When all at once I saw a crowd,
        A host, of golden daffodils;
        Beside the lake, beneath the trees,
        Fluttering and dancing in the breeze.
        Continuous as the stars that shine
        And twinkle on the milky way,
        They stretched in never-ending line
        Along the margin of a bay.
    ";

    println!("Parsing poetic cadence and sentiment...");
    let renderer = FractalRenderer::new(poem);

    println!("Metrics Extracted: {:?}", renderer.metrics);
    println!("Rendering fractal geometry to 'poetic_fractal.ppm'...");

    match renderer.generate(1024, 1024, "poetic_fractal.ppm") {
        Ok(_) => println!("Success! Visual fractal rendered to poetic_fractal.ppm"),
        Err(e) => eprintln!("Failed to render fractal: {}", e),
    }
}