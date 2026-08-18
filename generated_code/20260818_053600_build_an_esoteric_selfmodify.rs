use std::fs::File;
use std::io::Write;

const OZYMANDIAS: &str = r#"I met a traveller from an antique land,
Who said—“Two vast and trunkless legs of stone
Stand in the desert... Near them, on the sand,
Half sunk a shattered visage lies, whose frown,
And wrinkled lip, and sneer of cold command,
Tell that its sculptor well those passions read
Which yet survive, stamped on these lifeless things,
The hand that mocked them, and the heart that fed;
And on the pedestal, these words appear:
My name is Ozymandias, King of Kings;
Look on my Works, ye Mighty, and despair!
Nothing beside remains. Round the decay
Of that colossal Wreck, boundless and bare
The lone and level sands stretch far away.”"#;

struct SimpleLcg {
    state: u64,
}

impl SimpleLcg {
    fn new(seed: u64) -> Self {
        Self { state: seed }
    }

    fn next(&mut self) -> u8 {
        self.state = self.state.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (self.state >> 32) as u8
    }
}

fn write_ppm_frame(filename: &str, width: usize, height: usize, pixels: &[u8]) {
    let mut file = File::create(filename).expect("Failed to create PPM file");
    let header = format!("P6\n{} {}\n255\n", width, height);
    file.write_all(header.as_bytes()).unwrap();
    file.write_all(pixels).unwrap();
}

fn main() {
    let width = 400;
    let height = 400;
    let total_pixels = width * height;
    let num_bytes = total_pixels * 3;
    let mut pixels = vec![0u8; num_bytes];

    // Generate a background gradient photo (a procedural sunset landscape)
    for y in 0..height {
        for x in 0..width {
            let idx = (y * width + x) * 3;
            let fx = x as f32 / width as f32;
            let fy = y as f32 / height as f32;
            
            // Sky to sand gradient with sun glow
            let sun_dist = ((fx - 0.5).powi(2) + (fy - 0.4).powi(2)).sqrt();
            let sun = (1.0 - sun_dist * 3.0).max(0.0).powi(2);

            let r = ((0.8 - fy * 0.4 + sun * 0.5).min(1.0) * 255.0) as u8;
            let g = ((0.4 - fy * 0.3 + sun * 0.4).min(1.0) * 255.0) as u8;
            let b = ((0.2 + fy * 0.2).min(1.0) * 255.0) as u8;

            pixels[idx] = r & 0xFE;
            pixels[idx + 1] = g & 0xFE;
            pixels[idx + 2] = b & 0xFE;
        }
    }

    // Step 1: Encode Ozymandias into the LSBs of RGB channels
    let text_bytes = OZYMANDIAS.as_bytes();
    let mut bit_idx = 0;
    for &byte in text_bytes {
        for bit_pos in (0..8).rev() {
            let bit = (byte >> bit_pos) & 1;
            if bit_idx < pixels.len() {
                pixels[bit_idx] = (pixels[bit_idx] & 0xFE) | bit;
                bit_idx += 1;
            }
        }
    }
    let encoded_bits_count = bit_idx;

    // Save initial frame 00
    write_ppm_frame("frame_000.ppm", width, height, &pixels);

    // Prepare entropy decay generator
    let mut rng = SimpleLcg::new(0xDEADBEEF_OZYMANDIAS);
    let total_frames = 20;
    let mut decoded_text = String::new();
    let chars_per_frame = (text_bytes.len() + total_frames - 1) / total_frames;

    let mut current_bit_offset = 0;

    println!("=== Beginning Decryption and Visual Entropy Decay ===");

    for frame in 1..=total_frames {
        // Decrypt a portion of text
        let start_char_idx = (frame - 1) * chars_per_frame;
        let end_char_idx = (frame * chars_per_frame).min(text_bytes.len());

        for _ in start_char_idx..end_char_idx {
            let mut char_val = 0u8;
            for _ in 0..8 {
                if current_bit_offset < encoded_bits_count {
                    let bit = pixels[current_bit_offset] & 1;
                    char_val = (char_val << 1) | bit;
                    current_bit_offset += 1;
                }
            }
            if char_val != 0 {
                decoded_text.push(char_val as char);
            }
        }

        // Apply progressive visual entropy decay to pixels
        let corruption_severity = (frame as f32 / total_frames as f32).powi(2);
        let pixels_to_corrupt = (num_bytes as f32 * corruption_severity * 0.15) as usize;

        for _ in 0..pixels_to_corrupt {
            let p_idx = (rng.next() as usize | ((rng.next() as usize) << 8) | ((rng.next() as usize) << 16)) % num_bytes;
            let noise = rng.next();
            
            // Esoteric self-modifying rule: blend with neighboring sand entropy
            let neighbor_idx = (p_idx + 3) % num_bytes;
            pixels[p_idx] = pixels[p_idx].wrapping_add(noise ^ pixels[neighbor_idx]);
        }

        // Save output frame
        let filename = format!("frame_{:03}.ppm", frame);
        write_ppm_frame(&filename, width, height, &pixels);

        println!("\n--- Frame {:02}/{} ---", frame, total_frames);
        println!("Decrypted Poem Fragment:\n{}", decoded_text);
    }

    println!("\nProcess complete. All frames written. Image consumed by sand.");
}