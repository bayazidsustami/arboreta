use std::env;
use std::fs::File;
use std::io::{self, Read, Write};

/// Simple sentiment analysis: positive words increase speed, negative decrease.
fn sentiment_score(word: &str) -> i32 {
    let positives = ["joy", "love", "happy", "bright", "sun", "smile"];
    let negatives = ["sad", "dark", "pain", "cry", "storm", "gloom"];
    if positives.iter().any(|&w| w == word) {
        1
    } else if negatives.iter().any(|&w| w == word) {
        -1
    } else {
        0
    }
}

/// Convert a word into an SVG <g> element with CSS animation.
fn word_to_svg(id: usize, word: &str, y: f32, sentiment: i32) -> String {
    // speed: base 5s, modified by sentiment
    let base_duration = 5.0;
    let duration = if sentiment > 0 {
        base_duration / (1.0 + sentiment as f32 * 0.3)
    } else if sentiment < 0 {
        base_duration * (1.0 - sentiment as f32 * 0.2)
    } else {
        base_duration
    };
    // random-ish motion parameters
    let dx = (id as f32 * 37.0).fract() * 200.0 - 100.0;
    let dy = (id as f32 * 53.0).fract() * 30.0 - 15.0;
    format!(
        r#"<g id="w{id}" transform="translate(0,{y})">
    <text x="0" y="0" font-family="sans-serif" font-size="14">{word}</text>
    <style>
        #w{id} {{
            animation: walk{id} {duration:.2}s linear infinite alternate;
        }}
        @keyframes walk{id} {{
            from {{ transform: translate(0,{y}); }}
            to {{ transform: translate({dx:.2},{y}{dy:+.2}); }}
        }}
    </style>
</g>"#
    )
}

fn main() -> io::Result<()> {
    // read whole stdin or first argument file
    let mut input = String::new();
    if let Some(arg) = env::args().nth(1) {
        let mut f = File::open(arg)?;
        f.read_to_string(&mut input)?;
    } else {
        io::stdin().read_to_string(&mut input)?;
    }

    // split into words, keep line breaks for vertical positioning
    let mut words = Vec::new();
    for (line_idx, line) in input.lines().enumerate() {
        for w in line.split_whitespace() {
            words.push((line_idx, w.trim_matches(|c: char| !c.is_alphanumeric())));
        }
    }

    // start SVG
    let mut out = String::new();
    out.push_str(r#"<?xml version="1.0" encoding="UTF-8"?>
<svg width="800" height="600" xmlns="http://www.w3.org/2000/svg">
<style>
    text { fill: #333; }
</style>
"#);

    // generate each word
    for (i, (line, word)) in words.iter().enumerate() {
        let y = 30.0 + (*line as f32) * 30.0;
        let sentiment = sentiment_score(word);
        out.push_str(&word_to_svg(i, word, y, sentiment));
        out.push('\n');
    }

    out.push_str("</svg>\n");

    // write to stdout
    let stdout = io::stdout();
    let mut handle = stdout.lock();
    handle.write_all(out.as_bytes())?;
    Ok(())
}