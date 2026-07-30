// Quine ASCII Coral Reef: Renders its own source code as a dynamic ASCII coral reef,
// driven by real-time CPU thermal fluctuations and memory usage metrics.
use std::{fs, thread, time::Duration};

fn main() {
    let q = "// Quine ASCII Coral Reef: Renders its own source code as a dynamic ASCII coral reef,\n// driven by real-time CPU thermal fluctuations and memory usage metrics.\nuse std::{{fs, thread, time::Duration}};\n\nfn main() {{\n    let q = {:?};\n    let src = format!(q, q);\n\n    // Reads real-time system metrics (CPU temperature & RAM usage) with standard fallbacks\n    let get_metrics = || -> (f32, f32) {{\n        let temp = fs::read_to_string(\"/sys/class/thermal/thermal_zone0/temp\")\n            .ok()\n            .and_then(|s| s.trim().parse::<f32>().ok())\n            .map(|t| t / 1000.0)\n            .unwrap_or(48.5);\n        let mem = fs::read_to_string(\"/proc/meminfo\")\n            .ok()\n            .and_then(|s| {{\n                let mut total = 0.0;\n                let mut avail = 0.0;\n                for line in s.lines() {{\n                    if line.starts_with(\"MemTotal:\") {{\n                        total = line.split_whitespace().nth(1)?.parse().ok()?;\n                    }} else if line.starts_with(\"MemAvailable:\") {{\n                        avail = line.split_whitespace().nth(1)?.parse().ok()?;\n                    }}\n                }}\n                if total > 0.0 {{ Some((total - avail) / total) }} else {{ None }}\n            }})\n            .unwrap_or(0.42);\n        (temp, mem)\n    }};\n\n    print!(\"\\x1b[2J\\x1b[H\\x1b[?25l\"); // Clear screen & hide cursor\n    let chars: Vec<char> = src.chars().filter(|c| !c.is_whitespace()).collect();\n    let mut frame: u64 = 0;\n\n    loop {{\n        let (temp, mem) = get_metrics();\n        let mut out = String::from(\"\\x1b[H\");\n        let mut char_idx = 0;\n\n        for y in 0..22 {{\n            for x in 0..80 {{\n                let ch = chars[char_idx % chars.len()];\n                let wave = ((x as f32 * 0.15 + frame as f32 * 0.08).sin() * 2.5) as i32;\n                let thermal_growth = (temp / 12.0) as i32;\n                let reef_height = 16 - thermal_growth - wave;\n                let density_threshold = (7.0 - mem * 4.0).max(2.0) as usize;\n\n                if y as i32 >= reef_height && ((x * 7 + y * 3) % density_threshold == 0) {{\n                    char_idx += 1;\n                    // Dynamic RGB mutation based on CPU temp and RAM load\n                    let r = ((temp * 3.5 + x as f32 * 2.0).sin() * 127.0 + 128.0) as u8;\n                    let g = ((mem * 255.0 + y as f32 * 8.0).cos() * 100.0 + 130.0) as u8;\n                    let b = (150 + ((x + y) % 105)) as u8;\n                    out.push_str(&format!(\"\\x1b[38;2;{};{};{}m{}\x1b[0m\", r, g, b, ch));\n                }} else if y >= 20 {{\n                    out.push_str(\"\\x1b[38;2;110;90;50m~\x1b[0m\"); // Ocean floor bed\n                }} else {{\n                    out.push(' ');\n                }}\n            }}\n            out.push('\\n');\n        }}\n\n        out.push_str(&format!(\n            \"\\x1b[1;36m[CORAL QUINE REEF]\\x1b[0m Temp: \\x1b[31m{:.1}°C\\x1b[0m | Mem Usage: \\x1b[32m{:.1}%\\x1b[0m | Source Size: {} bytes\\n\",\n            temp, mem * 100.0, src.len()\n        ));\n\n        print!(\"{}\", out);\n        frame += 1;\n        thread::sleep(Duration::from_millis(90));\n    }}\n}}";
    let src = format!(q, q);

    // Reads real-time system metrics (CPU temperature & RAM usage) with standard fallbacks
    let get_metrics = || -> (f32, f32) {
        let temp = fs::read_to_string("/sys/class/thermal/thermal_zone0/temp")
            .ok()
            .and_then(|s| s.trim().parse::<f32>().ok())
            .map(|t| t / 1000.0)
            .unwrap_or(48.5);
        let mem = fs::read_to_string("/proc/meminfo")
            .ok()
            .and_then(|s| {
                let mut total = 0.0;
                let mut avail = 0.0;
                for line in s.lines() {
                    if line.starts_with("MemTotal:") {
                        total = line.split_whitespace().nth(1)?.parse().ok()?;
                    } else if line.starts_with("MemAvailable:") {
                        avail = line.split_whitespace().nth(1)?.parse().ok()?;
                    }
                }
                if total > 0.0 { Some((total - avail) / total) } else { None }
            })
            .unwrap_or(0.42);
        (temp, mem)
    };

    print!("\x1b[2J\x1b[H\x1b[?25l"); // Clear screen & hide cursor
    let chars: Vec<char> = src.chars().filter(|c| !c.is_whitespace()).collect();
    let mut frame: u64 = 0;

    loop {
        let (temp, mem) = get_metrics();
        let mut out = String::from("\x1b[H");
        let mut char_idx = 0;

        for y in 0..22 {
            for x in 0..80 {
                let ch = chars[char_idx % chars.len()];
                let wave = ((x as f32 * 0.15 + frame as f32 * 0.08).sin() * 2.5) as i32;
                let thermal_growth = (temp / 12.0) as i32;
                let reef_height = 16 - thermal_growth - wave;
                let density_threshold = (7.0 - mem * 4.0).max(2.0) as usize;

                if y as i32 >= reef_height && ((x * 7 + y * 3) % density_threshold == 0) {
                    char_idx += 1;
                    // Dynamic RGB mutation based on CPU temp and RAM load
                    let r = ((temp * 3.5 + x as f32 * 2.0).sin() * 127.0 + 128.0) as u8;
                    let g = ((mem * 255.0 + y as f32 * 8.0).cos() * 100.0 + 130.0) as u8;
                    let b = (150 + ((x + y) % 105)) as u8;
                    out.push_str(&format!("\x1b[38;2;{};{};{}m{}\x1b[0m", r, g, b, ch));
                } else if y >= 20 {
                    out.push_str("\x1b[38;2;110;90;50m~\x1b[0m"); // Ocean floor bed
                } else {
                    out.push(' ');
                }
            }
            out.push('\n');
        }

        out.push_str(&format!(
            "\x1b[1;36m[CORAL QUINE REEF]\x1b[0m Temp: \x1b[31m{:.1}°C\x1b[0m | Mem Usage: \x1b[32m{:.1}%\x1b[0m | Source Size: {} bytes\n",
            temp, mem * 100.0, src.len()
        ));

        print!("{}", out);
        frame += 1;
        thread::sleep(Duration::from_millis(90));
    }
}