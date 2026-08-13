// Git Repository to Baroque Harpsichord Score Transcriber
//
// This program parses git commit history (or generates a fallback sequence if not in a git repo),
// extracts tempo from commit frequencies, and transforms diff complexity (insertions/deletions)
// into polyphonic Baroque counterpoint (Treble & Bass voices) in D Minor.
// The output is an interactive SVG file containing sheet music and an embedded Web Audio API
// Harpsichord Synthesizer with real-time playback and dynamic visual note highlighting.

use std::env;
use std::fs::File;
use std::io::Write;
use std::process::Command;

/// Represents extracted metrics from a git commit.
#[derive(Debug, Clone)]
struct CommitMetrics {
    hash: String,
    timestamp: i64,
    insertions: usize,
    deletions: usize,
    files_changed: usize,
    summary: String,
}

/// Represents a single musical note in the score.
#[derive(Debug, Clone)]
struct Note {
    pitch_midi: u8,
    duration: f32, // in quarter-note units
    voice: usize,  // 0: Treble (Subject/Counterpoint), 1: Bass (Basso Continuo)
    time_offset: f32,
    commit_hash: String,
}

/// Harmonic scale definition for Baroque D Minor (Harmonic Minor)
const D_MINOR_SCALE: &[u8] = &[60, 62, 63, 65, 67, 68, 71, 72, 74, 75, 77, 79, 81, 83, 84]; // C4 to C6 octave range

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let repo_path = env::args().nth(1).unwrap_or_else(|| ".".to_string());
    let commits = fetch_git_commits(&repo_path);

    println!("Transcribing {} commits into Baroque counterpoint...", commits.len());

    let (tempo_bpm, notes) = generate_baroque_score(&commits);
    let svg_content = render_interactive_svg(tempo_bpm, &notes, &commits);

    let output_file = "harpsichord_score.svg";
    let mut file = File::create(output_file)?;
    file.write_all(svg_content.as_bytes())?;

    println!("Successfully rendered interactive score to '{}'", output_file);
    Ok(())
}

/// Fetches git history using git CLI, falling back to procedural mock commits if git is unavailable.
fn fetch_git_commits(path: &str) -> Vec<CommitMetrics> {
    let output = Command::new("git")
        .args(["-C", path, "log", "--pretty=format:%h|%at|%s", "--shortstat", "-n", "32"])
        .output();

    if let Ok(out) = output {
        if out.status.success() {
            let text = String::from_utf8_lossy(&out.stdout);
            let parsed = parse_git_log(&text);
            if !parsed.is_empty() {
                return parsed;
            }
        }
    }

    // Fallback procedural commit history for standalone execution without a git repo
    generate_fallback_commits()
}

fn parse_git_log(text: &str) -> Vec<CommitMetrics> {
    let mut commits = Vec::new();
    let lines: Vec<&str> = text.lines().collect();
    let mut i = 0;

    while i < lines.len() {
        let line = lines[i].trim();
        if line.contains('|') {
            let parts: Vec<&str> = line.splitn(3, '|').collect();
            if parts.len() == 3 {
                let hash = parts[0].to_string();
                let timestamp = parts[1].parse::<i64>().unwrap_or(1600000000);
                let summary = parts[2].to_string();

                let mut insertions = 5;
                let mut deletions = 2;
                let mut files_changed = 1;

                if i + 1 < lines.len() && lines[i + 1].contains("changed") {
                    let stat = lines[i + 1];
                    for token in stat.split(',') {
                        let token = token.trim();
                        if token.contains("insertion") {
                            insertions = token.split_whitespace().next().and_then(|s| s.parse().ok()).unwrap_or(5);
                        } else if token.contains("deletion") {
                            deletions = token.split_whitespace().next().and_then(|s| s.parse().ok()).unwrap_or(2);
                        } else if token.contains("file") {
                            files_changed = token.split_whitespace().next().and_then(|s| s.parse().ok()).unwrap_or(1);
                        }
                    }
                    i += 1;
                }

                commits.push(CommitMetrics {
                    hash,
                    timestamp,
                    insertions,
                    deletions,
                    files_changed,
                    summary,
                });
            }
        }
        i += 1;
    }

    commits
}

fn generate_fallback_commits() -> Vec<CommitMetrics> {
    let mut mock = Vec::new();
    let mut base_time = 1700000000i64;

    let templates = [
        ("a1b2c3d", "refactor: optimize core memory allocation", 45, 12, 3),
        ("e4f5g6h", "feat: add polyphonic counterpoint engine", 120, 5, 8),
        ("i7j8k9l", "fix: mitigate harmonic dissonance in bass line", 8, 30, 2),
        ("m0n1o2p", "style: format Bach-style ornamentations", 15, 15, 4),
        ("q3r4s5t", "docs: update harpsichord registration instructions", 3, 0, 1),
        ("u6v7w8x", "perf: accelerate Fourier transform synthesizer", 88, 42, 6),
        ("y9z0a1b", "chore: tune temperaments to Kirnberger III", 22, 19, 5),
    ];

    for (idx, (hash, msg, ins, del, files)) in templates.iter().cycle().take(16).enumerate() {
        base_time += (idx as i64 * 3600) + 1800;
        mock.push(CommitMetrics {
            hash: hash.to_string(),
            timestamp: base_time,
            insertions: *ins,
            deletions: *del,
            files_changed: *files,
            summary: msg.to_string(),
        });
    }

    mock
}

/// Generates Baroque counterpoint rules based on commit metrics.
fn generate_baroque_score(commits: &[CommitMetrics]) -> (u32, Vec<Note>) {
    // Determine Tempo (BPM) based on commit interval frequency (faster commits = allegro)
    let avg_interval = if commits.len() > 1 {
        let diffs: i64 = commits.windows(2).map(|w| (w[0].timestamp - w[1].timestamp).abs()).sum();
        (diffs as f64 / (commits.len() - 1) as f64) as u32
    } else {
        3600
    };

    // Clamp Tempo into traditional Baroque markings (80 BPM Adagio to 140 BPM Allegro)
    let tempo_bpm = (140 - (avg_interval / 300).min(60)) as u32;

    let mut notes = Vec::new();
    let mut current_time = 0.0f32;

    for commit in commits {
        let complexity = commit.insertions + commit.deletions + (commit.files_changed * 10);
        let duration = match complexity {
            0..=15 => 0.5,   // Eighth note (fast embellishment)
            16..=50 => 1.0,  // Quarter note
            51..=120 => 2.0, // Half note
            _ => 1.0,
        };

        // Treble Voice (Melodic subject driven by insertions)
        let scale_idx_treble = (commit.insertions + commit.hash.len()) % D_MINOR_SCALE.len();
        let treble_pitch = D_MINOR_SCALE[scale_idx_treble];

        notes.push(Note {
            pitch_midi: treble_pitch,
            duration,
            voice: 0,
            time_offset: current_time,
            commit_hash: commit.hash.clone(),
        });

        // Bass Voice (Basso continuo driven by deletions and conserved harmonic motion - 1 octave lower)
        let bass_degree = (commit.deletions) % 7;
        let bass_pitch = D_MINOR_SCALE[bass_degree] - 12; // Transpose down octave

        notes.push(Note {
            pitch_midi: bass_pitch,
            duration: duration * 2.0, // Stately longer bass notes
            voice: 1,
            time_offset: current_time,
            commit_hash: commit.hash.clone(),
        });

        current_time += duration;
    }

    (tempo_bpm, notes)
}

/// Renders the complete interactive SVG sheet music with embedded JavaScript synth.
fn render_interactive_svg(tempo: u32, notes: &[Note], commits: &[CommitMetrics]) -> String {
    let width = 1200;
    let height = 750;
    let staff_x = 100;
    let mut svg = String::new();

    // SVG Header & Embedded Harpsichord Web Audio API Player Script
    svg.push_str(&format!(
        r#"<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 {width} {height}" width="100%" height="100%" style="background:#fdfbf7; font-family: 'Georgia', serif;">
<style>
    .staff-line {{ stroke: #2c221e; stroke-width: 1.5; }}
    .note-head {{ fill: #1a110b; cursor: pointer; transition: fill 0.2s, transform 0.2s; }}
    .note-head:hover {{ fill: #a8322d; transform: scale(1.2); }}
    .stem {{ stroke: #1a110b; stroke-width: 2; }}
    .title {{ font-size: 24px; font-weight: bold; fill: #2c221e; text-anchor: middle; }}
    .subtitle {{ font-size: 14px; font-style: italic; fill: #655243; text-anchor: middle; }}
    .btn {{ fill: #4a3525; cursor: pointer; rx: 6; ry: 6; }}
    .btn:hover {{ fill: #7a583e; }}
    .btn-text {{ fill: #ffffff; font-size: 14px; font-weight: bold; text-anchor: middle; pointer-events: none; }}
</style>
<script><![CDATA[
let audioCtx = null;
function initAudio() {{
    if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
}}

// Synthesize Harpsichord Sound (Plucked String model using bright harmonics and fast decay)
fnPlayHarpsichord = function(freq, duration) {{
    initAudio();
    let osc1 = audioCtx.createOscillator();
    let osc2 = audioCtx.createOscillator();
    let gain = audioCtx.createGain();

    osc1.type = 'sawtooth';
    osc2.type = 'triangle';

    osc1.frequency.setValueAtTime(freq, audioCtx.currentTime);
    osc2.frequency.setValueAtTime(freq * 2.003, audioCtx.currentTime); // Slight detuned octave for harpsichord bite

    // Sharp attack, decay characteristic of plucked quill
    gain.gain.setValueAtTime(0.3, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.0001, audioCtx.currentTime + duration + 0.5);

    osc1.connect(gain);
    osc2.connect(gain);
    gain.connect(audioCtx.destination);

    osc1.start();
    osc2.start();
    osc1.stop(audioCtx.currentTime + duration + 0.6);
    osc2.stop(audioCtx.currentTime + duration + 0.6);
}};

function midiToFreq(m) {{ return 440 * Math.pow(2, (m - 69) / 12); }}

let isPlaying = false;
function playScore() {{
    initAudio();
    if (isPlaying) return;
    isPlaying = true;
    const notes = {};
    let tempo = {tempo};
    let quarterSec = 60 / tempo;

    notes.forEach(n => {{
        setTimeout(() => {{
            fnPlayHarpsichord(midiToFreq(n.pitch), n.duration * quarterSec);
            let el = document.getElementById('note-' + n.id);
            if (el) {{
                el.style.fill = '#a8322d';
                setTimeout(() => el.style.fill = '#1a110b', n.duration * quarterSec * 1000);
            }}
        }}, n.time * quarterSec * 1000);
    }});

    let maxTime = Math.max(...notes.map(n => n.time + n.duration));
    setTimeout(() => isPlaying = false, maxTime * quarterSec * 1000 + 1000);
}}
]]></script>
"#,
        width = width,
        height = height,
        tempo = tempo
    ));

    // Title Block
    svg.push_str(&format!(
        r#"<text x="{}" y="45" class="title">CONCERTO IN GIT MINOR</text>
<text x="{}" y="70" class="subtitle">Transcribed Harpsichord Score for Git Repository History • Tempo: Tempo di Barocco ({} BPM)</text>
"#,
        width / 2,
        width / 2,
        tempo
    ));

    // Render Grand Staff (Treble + Bass Staves)
    let treble_y = 150;
    let bass_y = 320;

    // Treble Staff
    for i in 0..5 {
        let y = treble_y + i * 12;
        svg.push_str(&format!(
            r#"<line x1="{}" y1="{}" x2="{}" y2="{}" class="staff-line"/>"#,
            staff_x,
            y,
            width - 80,
            y
        ));
    }

    // Bass Staff
    for i in 0..5 {
        let y = bass_y + i * 12;
        svg.push_str(&format!(
            r#"<line x1="{}" y1="{}" x2="{}" y2="{}" class="staff-line"/>"#,
            staff_x,
            y,
            width - 80,
            y
        ));
    }

    // Clef Symbols & System Braces
    svg.push_str(&format!(
        r#"<text x="{}" y="{}" font-size="42" fill="#1a110b">𝄞</text>
<text x="{}" y="{}" font-size="38" fill="#1a110b">𝄢</text>
<line x1="{}" y1="{}" x2="{}" y2="{}" stroke="#1a110b" stroke-width="3"/>
"#,
        staff_x + 10,
        treble_y + 40,
        staff_x + 10,
        bass_y + 36,
        staff_x,
        treble_y,
        staff_x,
        bass_y + 48
    ));

    // Note Serialization for JS Playback Engine
    let mut js_note_array = String::from("const notes = [");

    // Render Notes on Staff
    for (idx, note) in notes.iter().enumerate() {
        let x = staff_x + 80 + (note.time_offset * 32.0) as i32;

        // Calculate Y position based on MIDI pitch relative to staff base
        let base_y = if note.voice == 0 { treble_y + 48 } else { bass_y + 48 };
        let pitch_diff = note.pitch_midi as i32 - if note.voice == 0 { 60 } else { 48 };
        let y = base_y - (pitch_diff * 6);

        js_note_array.push_str(&format!(
            "{{id:{}, pitch:{}, duration:{}, time:{}}},",
            idx, note.pitch_midi, note.duration, note.time_offset
        ));

        // Render Note Head and Stem
        svg.push_str(&format!(
            r#"<g id="note-{}" onclick="fnPlayHarpsichord(midiToFreq({}), {})">
    <ellipse cx="{}" cy="{}" rx="6" ry="4.5" transform="rotate(-20 {} {})" class="note-head">
        <title>Commit: {} | Pitch MIDI: {}</title>
    </ellipse>
    <line x1="{}" y1="{}" x2="{}" y2="{}" class="stem"/>
</g>
"#,
            idx,
            note.pitch_midi,
            note.duration,
            x,
            y,
            x,
            y,
            note.commit_hash,
            note.pitch_midi,
            x + 5,
            y,
            x + 5,
            y - 28
        ));
    }

    js_note_array.push_str("];");
    svg = svg.replace("const notes = {};", &js_note_array);

    // Interactive Play Control Button
    svg.push_str(&format!(
        r#"<g transform="translate({}, {})" onclick="playScore()">
    <rect width="180" height="40" class="btn"/>
    <text x="90" y="25" class="btn-text">▶ Play Harpsichord</text>
</g>
"#,
        width / 2 - 90,
        height - 100
    ));

    // Commit History Legend / Footer
    svg.push_str(&format!(
        r#"<text x="{}" y="{}" font-size="12" fill="#655243" text-anchor="middle">Rendered {} commits into interactive SVG • Click any note to pluck harpsichord quill</text>
</svg>"#,
        width / 2,
        height - 30,
        commits.len()
    ));

    svg
}