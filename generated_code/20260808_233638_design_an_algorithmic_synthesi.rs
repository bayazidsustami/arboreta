// Git-to-Knitting Pattern Algorithmic Synthesizer
//
// Translates Git commit histories into continuous printable knitting patterns:
// - Branch merges synthesize lace eyelets using Yarn-Over (O) and K2tog (/) combinations.
// - Commit message byte distributions drive color gradient outputs via ANSI RGB styling.
// - Sequence ordering models knit row symmetry and stitch dynamics (Knit 'v' vs Purl '-').

use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq)]
enum Stitch {
    Knit,     // Standard knit stitch (v)
    Purl,     // Purl stitch (-)
    YarnOver, // Lace eyelet open stitch (O) from branch merges
    K2Tog,    // Paired decrease stitch (/) completing lace eyelet
}

impl fmt::Display for Stitch {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let symbol = match self {
            Stitch::Knit => "v",
            Stitch::Purl => "-",
            Stitch::YarnOver => "O",
            Stitch::K2Tog => "/",
        };
        write!(f, "{}", symbol)
    }
}

#[derive(Debug, Clone)]
struct Color {
    r: u8,
    g: u8,
    b: u8,
}

impl Color {
    // Computes dynamic RGB color palette directly from commit message byte values
    fn from_message_bytes(bytes: &[u8]) -> Self {
        if bytes.is_empty() {
            return Color { r: 160, g: 160, b: 160 };
        }
        let sum: usize = bytes.iter().map(|&b| b as usize).sum();
        let avg = (sum / bytes.len()) as u8;
        let xor_checksum = bytes.iter().fold(0u8, |acc, &b| acc ^ b);
        let spread = ((bytes.len() * 17) % 255) as u8;

        Color {
            r: avg.saturating_add(50),
            g: xor_checksum,
            b: spread.saturating_add(90),
        }
    }

    fn apply_ansi(&self, text: &str) -> String {
        format!("\x1b[38;2;{};{};{}m{}\x1b[0m", self.r, self.g, self.b, text)
    }
}

#[derive(Debug, Clone)]
struct Commit {
    hash: String,
    message: String,
    parents: Vec<String>,
}

struct PatternRow {
    row_number: usize,
    commit_hash: String,
    message: String,
    is_merge: bool,
    color: Color,
    stitches: Vec<Stitch>,
}

struct KnittingPattern {
    width: usize,
    rows: Vec<PatternRow>,
}

impl KnittingPattern {
    fn new(width: usize) -> Self {
        Self {
            width,
            rows: Vec::new(),
        }
    }

    // Algorithmic synthesis pipeline converting commits into textured pattern rows
    fn synthesize(&mut self, commits: &[Commit]) {
        for (idx, commit) in commits.iter().enumerate() {
            let is_merge = commit.parents.len() > 1;
            let color = Color::from_message_bytes(commit.message.as_bytes());
            let mut stitches = Vec::with_capacity(self.width);
            let msg_bytes = commit.message.as_bytes();

            if is_merge {
                // Synthesize lace eyelets for merge commits
                let center = self.width / 2;
                for col in 0..self.width {
                    if col == center - 1 {
                        stitches.push(Stitch::YarnOver);
                    } else if col == center {
                        stitches.push(Stitch::K2Tog);
                    } else if (col + idx) % 3 == 0 {
                        stitches.push(Stitch::Purl);
                    } else {
                        stitches.push(Stitch::Knit);
                    }
                }
            } else {
                // Map commit message byte modulation into Knit vs Purl stitch texture
                for col in 0..self.width {
                    let byte_val = msg_bytes.get(col % msg_bytes.len()).copied().unwrap_or(0);
                    if (byte_val as usize + col + idx) % 2 == 0 {
                        stitches.push(Stitch::Knit);
                    } else {
                        stitches.push(Stitch::Purl);
                    }
                }
            }

            self.rows.push(PatternRow {
                row_number: idx + 1,
                commit_hash: commit.hash.clone(),
                message: commit.message.clone(),
                is_merge,
                color,
                stitches,
            });
        }
    }

    // Prints the complete synthesized pattern (rendered bottom-up like physical knitting)
    fn print_pattern(&self) {
        println!("{}", "=".repeat(78));
        println!("       GIT COMMIT HISTORY -> CONTINUOUS KNITTING PATTERN SYNTHESIZER");
        println!("{}", "=".repeat(78));
        println!("STITCH KEY: [v] Knit | [-] Purl | [O] Lace Eyelet (Merge) | [/] K2tog Decrease");
        println!("{}", "-".repeat(78));

        for row in self.rows.iter().rev() {
            let mut stitch_str = String::new();
            for stitch in &row.stitches {
                stitch_str.push_str(&stitch.to_string());
                stitch_str.push(' ');
            }

            let colored_stitches = row.color.apply_ansi(&stitch_str);
            let merge_flag = if row.is_merge { " <-- [LACE MERGE EYELET]" } else { "" };
            let hash_short = &row.commit_hash[..7.min(row.commit_hash.len())];

            println!(
                "Row {:02} | {} | {} | {}{}",
                row.row_number,
                colored_stitches,
                hash_short,
                row.message,
                merge_flag
            );
        }
        println!("{}", "=".repeat(78));
    }
}

fn generate_mock_git_history() -> Vec<Commit> {
    vec![
        Commit {
            hash: "a1b2c3d4e5".into(),
            message: "Initial commit: scaffold core engine architecture".into(),
            parents: vec![],
        },
        Commit {
            hash: "f4e5d6c7b8".into(),
            message: "Add parser pipeline for git commit graph".into(),
            parents: vec!["a1b2c3d4e5".into()],
        },
        Commit {
            hash: "7a8b9c0d1e".into(),
            message: "Feature: implement byte-gradient RGB generator".into(),
            parents: vec!["f4e5d6c7b8".into()],
        },
        Commit {
            hash: "1d2e3f4a5b".into(),
            message: "Merge branch 'feature/color-gradients' into main".into(),
            parents: vec!["f4e5d6c7b8".into(), "7a8b9c0d1e".into()],
        },
        Commit {
            hash: "9x8y7z6w5v".into(),
            message: "Refactor stitch transformation math".into(),
            parents: vec!["1d2e3f4a5b".into()],
        },
        Commit {
            hash: "3k4l5m6n7o".into(),
            message: "Merge pull request #12 from feature/lace-eyelets".into(),
            parents: vec!["9x8y7z6w5v".into(), "8p9q0r1s2t".into()],
        },
        Commit {
            hash: "8p9q0r1s2t".into(),
            message: "Finalize continuous printable pattern layout".into(),
            parents: vec!["3k4l5m6n7o".into()],
        },
    ]
}

fn main() {
    let commits = generate_mock_git_history();
    let mut pattern = KnittingPattern::new(22);
    pattern.synthesize(&commits);
    pattern.print_pattern();
}