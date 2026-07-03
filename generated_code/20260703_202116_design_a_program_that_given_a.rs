use std::collections::HashMap;
use std::error::Error;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use reqwest::blocking::Client;
use serde::Deserialize;

// ---------- Data structures for GitHub API ----------
#[derive(Debug, Deserialize)]
struct CommitInfo {
    sha: String,
    commit: InnerCommit,
    author: Option<User>,
}

#[derive(Debug, Deserialize)]
struct InnerCommit {
    author: CommitAuthor,
    message: String,
}

#[derive(Debug, Deserialize)]
struct CommitAuthor {
    name: String,
    email: String,
    date: String, // ISO 8601
}

#[derive(Debug, Deserialize)]
struct User {
    login: String,
    contributions: Option<u32>, // not present in commit API; we compute ourselves
}

// ---------- Simple pentatonic scale ----------
static PENTATONIC: [f32; 5] = [261.63, 293.66, 329.63, 392.00, 440.00]; // C4,E4,G4,A4,B4

// ---------- Helper: parse ISO 8601 to timestamp ----------
fn iso_to_unix(ts: &str) -> u64 {
    chrono::DateTime::parse_from_rfc3339(ts)
        .unwrap()
        .timestamp() as u64
}

// ---------- Main logic ----------
fn main() -> Result<(), Box<dyn Error>> {
    // 1️⃣ Repository URL → owner / name
    let repo_url = std::env::args()
        .nth(1)
        .expect("Pass GitHub repo URL as first argument");
    let (owner, name) = parse_github_url(&repo_url)?;

    // 2️⃣ Fetch commits via GitHub API (no auth, limited to public)
    let commits = fetch_commits(&owner, &name)?;
    if commits.is_empty() {
        println!("No commits found");
        return Ok(());
    }

    // 3️⃣ Determine primary language (mocked as Rust for demo)
    let primary_lang = "Rust";
    // 4️⃣ Derive a character‑frequency based offset (simple example)
    let offset = language_offset(primary_lang);

    // 5️⃣ Build author contribution map
    let mut author_counts: HashMap<String, u32> = HashMap::new();
    for c in &commits {
        if let Some(user) = &c.author {
            *author_counts.entry(user.login.clone()).or_default() += 1;
        }
    }

    // 6️⃣ Map each commit to a note + visual params
    let mut notes = Vec::new();
    for commit in &commits {
        let ts = iso_to_unix(&commit.commit.author.date);
        let scale_idx = ((ts / 86400) as usize + offset) % PENTATONIC.len();
        let freq = PENTATONIC[scale_idx];

        let author = commit.author.as_ref().map(|u| u.login.clone()).unwrap_or_else(|| "unknown".into());
        let contrib = *author_counts.get(&author).unwrap_or(&0);
        let color = contribution_to_color(contrib);

        notes.push(Note {
            frequency: freq,
            duration: Duration::from_millis(500),
            color,
            author,
        });
    }

    // 7️⃣ Play notes (blocking) while printing a placeholder for animation
    for note in notes {
        println!("Playing {:.2} Hz for {} ms – author: {} – color: #{:06x}",
            note.frequency,
            note.duration.as_millis(),
            note.author,
            note.color);
        play_sine(note.frequency, note.duration);
        // Here you would trigger a fractal bloom with the given color.
    }

    Ok(())
}

// ---------- Simple data holder ----------
struct Note {
    frequency: f32,
    duration: Duration,
    color: u32,      // 0xRRGGBB
    author: String,
}

// ---------- Parse repo URL ----------
fn parse_github_url(url: &str) -> Result<(String, String), Box<dyn Error>> {
    // Accept forms like https://github.com/owner/repo or git@github.com:owner/repo.git
    let stripped = url.trim_end_matches(".git");
    let parts: Vec<&str> = if stripped.contains("github.com/") {
        stripped.split("github.com/").nth(1).unwrap().split('/').collect()
    } else if stripped.contains(':') {
        stripped.split(':').nth(1).unwrap().split('/').collect()
    } else {
        return Err("Unrecognised GitHub URL".into());
    };
    if parts.len() < 2 {
        return Err("Could not extract owner/repo".into());
    }
    Ok((parts[0].to_string(), parts[1].to_string()))
}

// ---------- Fetch commits (first 100) ----------
fn fetch_commits(owner: &str, repo: &str) -> Result<Vec<CommitInfo>, Box<dyn Error>> {
    let client = Client::new();
    let url = format!(
        "https://api.github.com/repos/{}/{}/commits?per_page=100",
        owner, repo
    );
    let resp = client
        .get(&url)
        .header("User-Agent", "rust-git-visualizer")
        .send()?;
    if !resp.status().is_success() {
        return Err(format!("GitHub API error: {}", resp.status()).into());
    }
    let commits: Vec<CommitInfo> = resp.json()?;
    Ok(commits)
}

// ---------- Language offset (simple sum of char codes modulo scale length) ----------
fn language_offset(lang: &str) -> usize {
    lang.bytes().map(|b| b as usize).sum::<usize>() % PENTATONIC.len()
}

// ---------- Map contribution count to a colour (more contributions → warmer) ----------
fn contribution_to_color(count: u32) -> u32 {
    // Clamp to [0,255] for red channel, green fixed, blue inverse
    let r = (count.min(255)) as u8;
    let g = 100u8;
    let b = 255u8.saturating_sub(r);
    ((r as u32) << 16) | ((g as u32) << 8) | (b as u32)
}

// ---------- Play a sine wave using rodio ----------
fn play_sine(freq: f32, dur: Duration) {
    use rodio::{OutputStream, Sink, source::SineWave};
    if let Ok((_stream, stream_handle)) = OutputStream::try_default() {
        let sink = Sink::try_new(&stream_handle).unwrap();
        let source = SineWave::new(freq as u32).take_duration(dur).amplify(0.20);
        sink.append(source);
        sink.sleep_until_end();
    }
}