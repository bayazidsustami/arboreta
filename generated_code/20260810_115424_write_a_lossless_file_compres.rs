use std::collections::HashMap;

// A lossless Gothic Novel compressor/decompressor.
// Encodes each byte (8 bits) into a Victorian gothic sentence composed of 4 narrative elements (2 bits each):
// - Protagonist (bits 7-6)
// - Atmospheric Location (bits 5-4)
// - Emotional Arc (bits 3-2)
// - Plot Twist (bits 1-0)

const PROTAGONISTS: [&str; 4] = [
    "Lady Eleanora",
    "Lord Malachi",
    "The brooding orphan Clara",
    "Doctor Bartholomew",
];

const LOCATIONS: [&str; 4] = [
    "in the desolate ruins of Blackwood Manor",
    "beneath the fog-shrouded spires of Ravencrest",
    "within the damp, subterranean vaults",
    "inside the dilapidated estate on the moors",
];

const EMOTIONAL_ARCS: [&str; 4] = [
    "succumbed to overwhelming dread",
    "harbored a haunting, bittersweet sorrow",
    "felt a surge of unholy triumph",
    "shivered with an agonizing presentiment",
];

const PLOT_TWISTS: [&str; 4] = [
    "as a sinister family secret was laid bare",
    "when the cursed ancestral portrait began to weep blood",
    "upon realizing the spectral apparition was their twin",
    "just as the ancient grandfather clock struck the forbidden hour",
];

/// Encodes binary data into a Gothic Novel.
pub fn compress(bytes: &[u8]) -> String {
    let mut novel = String::from("CHAPTER I: THE CURSED CHRONICLES\n\n");
    for (i, &byte) in bytes.iter().enumerate() {
        let p_idx = ((byte >> 6) & 0x03) as usize;
        let l_idx = ((byte >> 4) & 0x03) as usize;
        let e_idx = ((byte >> 2) & 0x03) as usize;
        let t_idx = (byte & 0x03) as usize;

        let sentence = format!(
            "{} {}, {} {}.\n",
            PROTAGONISTS[p_idx], LOCATIONS[l_idx], EMOTIONAL_ARCS[e_idx], PLOT_TWISTS[t_idx]
        );
        novel.push_str(&sentence);

        // Add dramatic chapter breaks every 4 bytes for literary atmosphere
        if (i + 1) % 4 == 0 && i + 1 < bytes.len() {
            novel.push_str(&format!("\nCHAPTER {}: DARKER OMENS\n\n", (i / 4) + 2));
        }
    }
    novel
}

/// Decodes a Gothic Novel back into original binary data by parsing narrative elements.
pub fn decompress(novel: &str) -> Result<Vec<u8>, String> {
    let p_map: HashMap<&str, u8> = PROTAGONISTS.iter().enumerate().map(|(i, &s)| (s, i as u8)).collect();
    let l_map: HashMap<&str, u8> = LOCATIONS.iter().enumerate().map(|(i, &s)| (s, i as u8)).collect();
    let e_map: HashMap<&str, u8> = EMOTIONAL_ARCS.iter().enumerate().map(|(i, &s)| (s, i as u8)).collect();
    let t_map: HashMap<&str, u8> = PLOT_TWISTS.iter().enumerate().map(|(i, &s)| (s, i as u8)).collect();

    let mut bytes = Vec::new();

    for line in novel.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with("CHAPTER") {
            continue; // Skip titles and empty spacing
        }

        let sentence = line.trim_end_matches('.');
        
        // Match narrative elements from the sentence
        let p_idx = p_map.iter().find(|(&p, _)| sentence.starts_with(p))
            .map(|(_, &v)| v)
            .ok_ok_or_else(|| "Failed to parse Protagonist".to_string())?;

        let l_idx = l_map.iter().find(|(&l, _)| sentence.contains(l))
            .map(|(_, &v)| v)
            .ok_ok_or_else(|| "Failed to parse Location".to_string())?;

        let e_idx = e_map.iter().find(|(&e, _)| sentence.contains(e))
            .map(|(_, &v)| v)
            .ok_ok_or_else(|| "Failed to parse Emotional Arc".to_string())?;

        let t_idx = t_map.iter().find(|(&t, _)| sentence.ends_with(t))
            .map(|(_, &v)| v)
            .ok_ok_or_else(|| "Failed to parse Plot Twist".to_string())?;

        let byte = (p_idx << 6) | (l_idx << 4) | (e_idx << 2) | t_idx;
        bytes.push(byte);
    }

    Ok(bytes)
}

fn main() {
    let original_data = b"Gothic Rust!";
    println!("Original Data: {:?}", String::from_utf8_lossy(original_data));

    // Compress binary to Gothic Novel
    let gothic_novel = compress(original_data);
    println!("\n=== GENERATED GOTHIC NOVEL ===\n");
    println!("{}", gothic_novel);

    // Decompress Gothic Novel back to binary
    match decompress(&gothic_novel) {
        Ok(restored_data) => {
            println!("=== DECOMPRESSION RESULT ===");
            println!("Restored Data: {:?}", String::from_utf8_lossy(&restored_data));
            assert_eq!(original_data.to_vec(), restored_data);
            println!("\nLossless verification: PERFECT MATCH!");
        }
        Err(e) => println!("Error during decompression: {}", e),
    }
}