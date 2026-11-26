// Self-contained Rust program (`rustc landscape_cfg.rs -O && ./landscape_cfg <source_file> [output.ppm]`)
// Parses any source file into control-flow constructs (loops -> weeping willows,
// conditionals -> river deltas, statements -> tall grass) and renders an animated
// sequence of watercolor PPM frames where wind/execution ripples across the scene.

use std::env;
use std::f64::consts::PI;
use std::fs::{self, File};
use std::io::{BufWriter, Write};
use std::process;

#[derive(Clone, Copy, Debug, PartialEq)]
enum NodeKind {
    Grass,
    Delta,
    Willow,
}

#[derive(Clone, Debug)]
struct CfgNode {
    kind: NodeKind,
    depth: usize,
    anchor_x: f64,
    anchor_y: f64,
    phase: f64,
}

struct Canvas {
    w: usize,
    h: usize,
    pixels: Vec<(f64, f64, f64)>,
}

impl Canvas {
    fn new(w: usize, h: usize, sky_top: (f64, f64, f64), horizon: (f64, f64, f64)) -> Self {
        let mut pixels = vec![(0.0, 0.0, 0.0); w * h];
        for y in 0..h {
            let t = (y as f64 / (h.max(1) - 1) as f64).clamp(0.0, 1.0);
            let wash = t * t * (3.0 - 2.0 * t);
            let r = sky_top.0 + (horizon.0 - sky_top.0) * wash;
            let g = sky_top.1 + (horizon.1 - sky_top.1) * wash;
            let b = sky_top.2 + (horizon.2 - sky_top.2) * wash;
            for x in 0..w {
                // Subtle watercolor paper grain and pigment bloom
                let grain = ((x * 374761393 + y * 668265263) ^ (x * 1274126177)) as f64;
                let n = ((grain.sin() * 43758.5453).fract() - 0.5) * 6.0;
                pixels[y * w + x] = (
                    (r + n).clamp(0.0, 255.0),
                    (g + n).clamp(0.0, 255.0),
                    (b + n).clamp(0.0, 255.0),
                );
            }
        }
        Self { w, h, pixels }
    }

    // Translucent watercolor glaze with soft radial edge pooling
    fn glaze(&mut self, cx: f64, cy: f64, radius: f64, color: (f64, f64, f64), alpha: f64) {
        if radius <= 0.5 || alpha <= 0.001 {
            return;
        }
        let min_x = ((cx - radius * 1.4).floor() as isize).max(0) as usize;
        let max_x = ((cx + radius * 1.4).ceil() as isize).min(self.w as isize - 1) as usize;
        let min_y = ((cy - radius * 1.4).floor() as isize).max(0) as usize;
        let max_y = ((cy + radius * 1.4).ceil() as isize).min(self.h as isize - 1) as usize;

        for y in min_y..=max_y {
            for x in min_x..=max_x {
                let dx = x as f64 - cx;
                let dy = y as f64 - cy;
                let dist = (dx * dx + dy * dy).sqrt();
                let norm = dist / radius;
                if norm <= 1.35 {
                    let edge_pool = if norm > 0.75 {
                        1.0 + 0.35 * ((norm - 0.75) / 0.6)
                    } else {
                        1.0 - 0.25 * norm
                    };
                    let falloff = (1.0 - (norm / 1.35).powi(2)).max(0.0);
                    let a = (alpha * falloff * edge_pool).clamp(0.0, 0.85);
                    let idx = y * self.w + x;
                    let (br, bg, bb) = self.pixels[idx];
                    self.pixels[idx] = (
                        br * (1.0 - a) + color.0 * a,
                        bg * (1.0 - a) + color.1 * a,
                        bb * (1.0 - a) + color.2 * a,
                    );
                }
            }
        }
    }

    fn stroke_brush(&mut self, x0: f64, y0: f64, x1: f64, y1: f64, width: f64, color: (f64, f64, f64), alpha: f64) {
        let dx = x1 - x0;
        let dy = y1 - y0;
        let len = (dx * dx + dy * dy).sqrt();
        let steps = ((len / (width * 0.35).max(1.0)).ceil() as usize).max(1);
        for i in 0..=steps {
            let t = i as f64 / steps as f64;
            let px = x0 + dx * t;
            let py = y0 + dy * t;
            self.glaze(px, py, width * 0.5, color, alpha);
        }
    }

    fn write_ppm(&self, path: &str) -> std::io::Result<()> {
        let file = File::create(path)?;
        let mut out = BufWriter::new(file);
        writeln!(out, "P6\n{} {}\n255", self.w, self.h)?;
        for &(r, g, b) in &self.pixels {
            out.write_all(&[
                r.round().clamp(0.0, 255.0) as u8,
                g.round().clamp(0.0, 255.0) as u8,
                b.round().clamp(0.0, 255.0) as u8,
            ])?;
        }
        out.flush()
    }
}

// Extract a lightweight control-flow graph from arbitrary source text
fn extract_cfg(source: &str, w: usize, h: usize) -> Vec<CfgNode> {
    let mut nodes = Vec::new();
    let mut brace_depth: usize = 0;

    for (idx, raw_line) in source.lines().enumerate() {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with("//") || line.starts_with('#') {
            continue;
        }

        let opens = line.chars().filter(|&c| c == '{').count();
        let closes = line.chars().filter(|&c| c == '}').count();

        let is_loop = line.starts_with("for ")
            || line.starts_with("for(")
            || line.starts_with("while ")
            || line.starts_with("while(")
            || line == "loop"
            || line.starts_with("loop ")
            || line.contains(" for ");

        let is_cond = line.starts_with("if ")
            || line.starts_with("if(")
            || line.starts_with("else if")
            || line.starts_with("elif ")
            || line.starts_with("match ")
            || line.starts_with("switch ")
            || line.starts_with("case ");

        let kind = if is_loop {
            NodeKind::Willow
        } else if is_cond {
            NodeKind::Delta
        } else {
            NodeKind::Grass
        };

        let progress = (nodes.len() as f64 + 0.5) / (source.lines().count().max(1) as f64);
        let x_margin = w as f64 * 0.1;
        let usable_w = w as f64 * 0.8;
        let anchor_x = x_margin + ((idx as f64 * 0.61803398875).fract()) * usable_w * 0.5 + progress * usable_w * 0.5;
        let anchor_y = match kind {
            NodeKind::Willow => h as f64 * (0.44 + (brace_depth as f64 * 0.04).min(0.14)),
            NodeKind::Delta => h as f64 * (0.60 + (brace_depth as f64 * 0.05).min(0.22)),
            NodeKind::Grass => h as f64 * (0.68 + ((idx % 7) as f64) * 0.035),
        };

        nodes.push(CfgNode {
            kind,
            depth: brace_depth,
            anchor_x: anchor_x.clamp(x_margin, w as f64 - x_margin),
            anchor_y: anchor_y.clamp(h as f64 * 0.35, h as f64 * 0.94),
            phase: idx as f64 * 0.55,
        });

        brace_depth = (brace_depth + opens).saturating_sub(closes);
    }

    if nodes.is_empty() {
        for i in 0..16 {
            let t = i as f64 / 15.0;
            nodes.push(CfgNode {
                kind: if i % 5 == 0 {
                    NodeKind::Willow
                } else if i % 3 == 0 {
                    NodeKind::Delta
                } else {
                    NodeKind::Grass
                },
                depth: i % 3,
                anchor_x: w as f64 * (0.12 + 0.76 * t),
                anchor_y: h as f64 * (0.55 + 0.35 * ((i as f64 * 1.3).sin().abs())),
                phase: i as f64 * 0.7,
            });
        }
    }

    nodes
}

// Wind & runtime execution wave field across the canvas
fn wind_gust(x: f64, y: f64, t: f64, w: f64) -> f64 {
    let exec_wave = ((x / w) * 4.0 * PI - t * 3.4 + y * 0.012).sin();
    let cross_breeze = ((x * 0.015 + y * 0.02 - t * 1.7)).cos() * 0.45;
    exec_wave + cross_breeze
}

fn render_frame(nodes: &[CfgNode], w: usize, h: usize, t: f64) -> Canvas {
    // Warm parchment sky fading into misty sage-ivory meadow
    let mut canvas = Canvas::new(w, h, (245.0, 236.0, 214.0), (219.0, 226.0, 206.0));

    // Distant watercolor hills
    for hill in 0..3 {
        let base_y = h as f64 * (0.48 + hill as f64 * 0.07);
        let col = match hill {
            0 => (182.0, 198.0, 184.0),
            1 => (156.0, 182.0, 162.0),
            _ => (134.0, 166.0, 142.0),
        };
        let mut x = 0.0;
        while x <= w as f64 {
            let y = base_y
                + (x * 0.006 + hill as f64 * 2.1).sin() * 24.0
                + (x * 0.015 - t * 0.25).cos() * 8.0;
            canvas.glaze(x, y, 55.0, col, 0.08);
            x += 18.0;
        }
    }

    // Render river deltas (conditionals) first so willows and grass sit naturally over/beside them
    for node in nodes.iter().filter(|n| n.kind == NodeKind::Delta) {
        let gust = wind_gust(node.anchor_x, node.anchor_y, t, w as f64);
        let branches = 2 + (node.depth % 3);
        let water_col = (78.0, 142.0, 168.0);
        let foam_col = (185.0, 218.0, 228.0);

        for b in 0..branches {
            let spread = (b as f64 - (branches - 1) as f64 * 0.5) * 34.0 + gust * 7.0;
            let mut px = node.anchor_x;
            let mut py = node.anchor_y;
            let steps = 14;
            for s in 1..=steps {
                let frac = s as f64 / steps as f64;
                let ripple = (frac * 6.0 - t * 4.5 + node.phase).sin() * 5.0 * frac;
                let nx = node.anchor_x + spread * frac + ripple;
                let ny = node.anchor_y + frac * 95.0;
                let width = (12.0 * (1.0 - frac * 0.55)).max(3.0);
                canvas.stroke_brush(px, py, nx, ny, width, water_col, 0.14);
                if s % 3 == 0 {
                    canvas.glaze(nx, ny, width * 0.45, foam_col, 0.12);
                }
                px = nx;
                py = ny;
            }
        }
    }

    // Render weeping willows (loops) with arching trunks and swaying fronds
    for node in nodes.iter().filter(|n| n.kind == NodeKind::Willow) {
        let gust = wind_gust(node.anchor_x, node.anchor_y, t, w as f64);
        let trunk_h = 78.0 + (node.depth % 3) as f64 * 16.0;
        let sway = gust * 14.0 + (t * 1.4 + node.phase).sin() * 5.0;

        let top_x = node.anchor_x + sway * 0.65;
        let top_y = node.anchor_y - trunk_h;

        // Trunk & boughs in warm umber
        canvas.stroke_brush(
            node.anchor_x,
            node.anchor_y,
            top_x,
            top_y,
            9.5,
            (108.0, 82.0, 58.0),
            0.22,
        );

        let fronds = 18;
        for f in 0..fronds {
            let side = (f as f64 / (fronds - 1) as f64) * 2.0 - 1.0;
            let start_x = top_x + side * 18.0;
            let start_y = top_y + side.abs() * 10.0;
            let droop_len = 52.0 + ((f * 13) % 7) as f64 * 7.5;
            let frond_sway = gust * 22.0 + side * 26.0;

            let mut fx = start_x;
            let mut fy = start_y;
            let segs = 10;
            for seg in 1..=segs {
                let u = seg as f64 / segs as f64;
                let curve = u * u;
                let nx = start_x + frond_sway * curve + (u * 5.0 - t * 3.0 + f as f64).sin() * 3.5 * u;
                let ny = start_y + droop_len * u;
                let green_shift = ((f + seg) % 3) as f64 * 14.0;
                let frond_col = (
                    (82.0 + green_shift * 0.4).min(255.0),
                    (138.0 + green_shift).min(255.0),
                    (74.0 + green_shift * 0.3).min(255.0),
                );
                canvas.stroke_brush(fx, fy, nx, ny, 3.2 * (1.0 - u * 0.45), frond_col, 0.13);
                fx = nx;
                fy = ny;
            }
        }
    }

    // Render tall grass (statements) rippling like a runtime execution wave
    for node in nodes.iter().filter(|n| n.kind == NodeKind::Grass) {
        let gust = wind_gust(node.anchor_x, node.anchor_y, t, w as f64);
        let blade_h = 34.0 + ((node.phase * 7.0).sin().abs() * 24.0);
        let tip_x = node.anchor_x + gust * 18.0;
        let tip_y = node.anchor_y - blade_h;

        // Highlight sunlit crests as the execution ripple passes
        let crest = ((gust + 1.0) * 0.5).clamp(0.0, 1.0);
        let blade_col = (
            96.0 + crest * 88.0,
            152.0 + crest * 54.0,
            72.0 + crest * 22.0,
        );
        canvas.stroke_brush(
            node.anchor_x,
            node.anchor_y,
            tip_x,
            tip_y,
            3.0,
            blade_col,
            0.18 + crest * 0.12,
        );
    }

    canvas
}

fn main() {
    let mut args = env::args().skip(1);
    let Some(src_path) = args.next() else {
        eprintln!("Usage: landscape_cfg <source_file> [output_prefix] [frames]");
        process::exit(1);
    };
    let out_prefix = args.next().unwrap_or_else(|| "cfg_landscape".to_string());
    let frames: usize = args
        .next()
        .and_then(|s| s.parse().ok())
        .unwrap_or(6)
        .clamp(1, 60);

    let source = match fs::read_to_string(&src_path) {
        Ok(content) => content,
        Err(err) => {
            eprintln!("Failed to read '{}': {}", src_path, err);
            process::exit(1);
        }
    };

    let width = 960;
    let height = 540;
    let cfg = extract_cfg(&source, width, height);

    for f in 0..frames {
        let t = (f as f64 / frames as f64) * 2.0 * PI;
        let canvas = render_frame(&cfg, width, height, t);
        let filename = if frames == 1 {
            format!("{}.ppm", out_prefix)
        } else {
            format!("{}_{:02}.ppm", out_prefix, f)
        };
        if let Err(err) = canvas.write_ppm(&filename) {
            eprintln!("Failed to write '{}': {}", filename, err);
            process::exit(1);
        }
    }
}