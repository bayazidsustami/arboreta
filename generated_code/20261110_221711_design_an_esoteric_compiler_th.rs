use std::thread;
use std::time::Duration;

// Ancient Meteorological Log Corpus
const METEO_LOGS: &str = "\
EPOCH 0x01 // BARO: 1013.2hPa | TEMP: +14.5C | WIND: 12kn SSE | HYGRO: 84%
EPOCH 0x02 // BARO: 0998.4hPa | TEMP: -02.1C | WIND: 48kn NNE | HYGRO: 96%
EPOCH 0x03 // BARO: 1025.8hPa | TEMP: +22.0C | WIND: 04kn CALM | HYGRO: 32%
EPOCH 0x04 // BARO: 1005.1hPa | TEMP: +08.3C | WIND: 22kn WNW | HYGRO: 71%
";

#[derive(Debug)]
struct SoundNode {
    frequency: usize,
    amplitude: f32,
    timbre_char: char,
}

// Esoteric compiler: translates archaic meteorological logs into soundwave tokens
fn compile_logs(source: &str) -> Vec<SoundNode> {
    let mut nodes = Vec::new();
    for line in source.lines() {
        if line.starts_with("EPOCH") {
            let mut freq = 150;
            let mut amp = 0.4;
            let mut timbre = '~';

            for b in line.bytes() {
                freq = freq.wrapping_add((b as usize) * 7) % 880 + 100;
                amp = (amp + (b as f32 % 3.0) * 0.1).min(1.0);
                if b.is_ascii_punctuation() {
                    timbre = b as char;
                }
            }
            nodes.push(SoundNode { frequency: freq, amplitude: amp, timbre_char: timbre });
        }
    }
    nodes
}

// Renders a decaying ASCII brass clock visualization
fn render_clock_frame(tick: usize, corruption: f32) {
    print!("\x1B[H\x1B[2J"); // Clear terminal screen
    println!("=== AETHO-CHRONOMETER v2.4 [DECAY: {:.1}%] ===", corruption * 100.0);
    
    let clock_frame = [
        r#"       _..._"       ,
     r#"     .'     '."      ,
    r#"    /  {gear1}   \     "#,
    r#"   |  {gear2} O   |    "#,
    r#"    \         /     "#,
    r#"     '.     .'      "#,
    r#"       '---'       "#,
    ];

    let g1 = if tick % 2 == 0 { '*' } else { 'o' };
    let g2 = if corruption > 0.6 { 'X' } else { '#' };

    for row in &clock_frame {
        let rendered = row
            .replace("{gear1}", &g1.to_string())
            .replace("{gear2}", &g2.to_string());
        println!("{}", rendered);
    }
}

fn main() {
    let soundscape = compile_logs(METEO_LOGS);
    println!("Compiled {} meteorological tokens into generative soundscape.", soundscape.len());
    thread::sleep(Duration::from_millis(800));

    let total_ticks = 12;
    for tick in 0..total_ticks {
        let decay = tick as f32 / total_ticks as f32;
        render_clock_frame(tick, decay);

        if let Some(node) = soundscape.get(tick % soundscape.len()) {
            let wave_width = (node.amplitude * 24.0) as usize;
            let wave_form: String = std::iter::repeat(node.timbre_char).take(wave_width).collect();
            println!("\n[SOUND] Freq: {}Hz | Amp: {:.2} | Wave: [{}]", node.frequency, node.amplitude, wave_form);
            
            // Emit terminal bell as acoustic resonance simulation
            if tick % 3 == 0 {
                print!("\x07");
            }
        }

        thread::sleep(Duration::from_millis(350));
    }
    println!("\n[COMPILER HALTED: Chronometer completely oxidized.]");
}