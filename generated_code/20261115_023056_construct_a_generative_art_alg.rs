// Generative art algorithm: The decay of forgotten browser tabs
// Visualizes idle browser memory allocation as a breathing Voronoi landscape
// whose color spectrum shifts dynamically based on atmospheric pressure.
// Outputs a self-contained PPM image file: 'forgotten_tabs_voronoi.ppm'.

use std::fs::File;
use std::io::Write;
use std::f64::consts::PI;

#[derive(Clone, Copy)]
struct TabNode {
    x: f64,
    y: f64,
    decay_age: f64, // 0.0 = active memory, 1.0 = deep zombie state
    base_hue: f64,
}

fn main() -> std::io::Result<()> {
    let width = 1000;
    let height = 750;

    // Simulate real-time atmospheric pressure (in hPa, e.g., varying around standard 1013.25)
    // Low pressure brings stormy, desaturated palettes; high pressure brings crisp, vibrant hues.
    let simulated_pressure = 1012.8;
    let pressure_anomaly = (simulated_pressure - 1013.25) / 25.0;

    let num_tabs = 24;
    let mut tabs = Vec::with_capacity(num_tabs);

    // Initialize forgotten tabs with organic scattering and varying decay levels
    for i in 0..num_tabs {
        let angle = (i as f64) * (2.0 * PI / (num_tabs as f64));
        let dist_factor = 80.0 + ((i * 47) % 220) as f64;
        let x = (width as f64) / 2.0 + dist_factor * angle.cos() * 1.2;
        let y = (height as f64) / 2.0 + dist_factor * angle.sin() * 0.9;
        
        // Decay age increases with index and pseudo-random entropy
        let decay_age = (((i * 31) % 100) as f64) / 100.0;
        let base_hue = (i as f64 * 15.0 + pressure_anomaly * 45.0) % 360.0;
        
        tabs.push(TabNode { x, y, decay_age, base_hue });
    }

    let mut img_buffer = vec![0u8; width * height * 3];
    let time_breath = 2.4; // Breathing oscillation phase

    // Render Voronoi landscape pixel by pixel
    for y in 0..height {
        for x in 0..width {
            let px = x as f64;
            let py = y as f64;

            let mut d1 = f64::MAX;
            let mut d2 = f64::MAX;
            let mut closest_idx = 0;

            for (idx, tab) in tabs.iter().enumerate() {
                // Breathing pulsation based on decay state (zombie tabs breathe slower, heavier)
                let breath_freq = 1.0 - tab.decay_age * 0.5;
                let bx = tab.x + (time_breath * breath_freq + tab.decay_age * 10.0).sin() * (12.0 * (1.0 - tab.decay_age));
                let by = tab.y + (time_breath * 0.7 * breath_freq + tab.decay_age * 7.0).cos() * (12.0 * (1.0 - tab.decay_age));

                // Distance metric warped by tab memory corruption (decay_age)
                let dx = px - bx;
                let dy = py - by;
                let dist = (dx * dx + dy * dy).sqrt() * (1.0 + tab.decay_age * 0.35);

                if dist < d1 {
                    d2 = d1;
                    d1 = dist;
                    closest_idx = idx;
                } else if dist < d2 {
                    d2 = dist;
                }
            }

            let tab = &tabs[closest_idx];

            // Calculate cellular border edges (Voronoi crackle / neural pathways)
            let edge_distance = d2 - d1;
            let border_glow = if edge_distance < 4.0 { 1.0 - (edge_distance / 4.0) } else { 0.0 };

            // Color shading influenced by atmospheric pressure and memory decay
            let hue = (tab.base_hue + pressure_anomaly * 30.0 + d1 * 0.03) % 360.0;
            let saturation = 0.65 - tab.decay_age * 0.45;
            let lightness = 0.22 + (1.0 - tab.decay_age) * 0.35 + border_glow * 0.3;

            let (r, g, b) = hsl_to_rgb(hue / 360.0, saturation, lightness);

            let pixel_idx = (y * width + x) * 3;
            img_buffer[pixel_idx]     = (r * 255.0).clamp(0.0, 255.0) as u8;
            img_buffer[pixel_idx + 1] = (g * 255.0).clamp(0.0, 255.0) as u8;
            img_buffer[pixel_idx + 2] = (b * 255.0).clamp(0.0, 255.0) as u8;
        }
    }

    // Export image as binary PPM (P6)
    let mut file = File::create("forgotten_tabs_voronoi.ppm")?;
    write!(file, "P6\n{} {}\n255\n", width, height)?;
    file.write_all(&img_buffer)?;

    println!("Forgotten tabs landscape generated successfully: forgotten_tabs_voronoi.ppm");
    Ok(())
}

fn hsl_to_rgb(h: f64, s: f64, l: f64) -> (f64, f64, f64) {
    let q = if l < 0.5 { l * (1.0 + s) } else { l + s - l * s };
    let p = 2.0 * l - q;
    let r = hue_to_rgb(p, q, h + 1.0 / 3.0);
    let g = hue_to_rgb(p, q, h);
    let b = hue_to_rgb(p, q, h - 1.0 / 3.0);
    (r, g, b)
}

fn hue_to_rgb(p: f64, q: f64, mut t: f64) -> f64 {
    if t < 0.0 { t += 1.0; }
    if t > 1.0 { t -= 1.0; }
    if t < 1.0 / 6.0 { return p + (q - p) * 6.0 * t; }
    if t < 1.0 / 2.0 { return q; }
    if t < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - t) * 6.0; }
    p
}