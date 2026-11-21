use std::collections::HashMap;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Clone, Debug)]
struct CommitNode {
    hash: String,
    subject: String,
    age_days: f64,
    churn: usize,
    decay_score: f64,
}

#[derive(Clone, Debug)]
enum TrophicRole {
    ApexPredator, // e.g. main / master / release: absorbs & prunes rival branches
    Opportunist,  // e.g. feature/*: feeds on compost & occasional smaller prey
    Decomposer,   // e.g. chore/*, refactor/*, fix/*: accelerates decay into compost
}

#[derive(Clone, Debug)]
struct BranchOrganism {
    name: String,
    role: TrophicRole,
    biomass: f64,
    stamina: f64,
    tip_age_days: f64,
}

#[derive(Default, Debug)]
struct CompostPool {
    nitrogen: f64,   // fuels rapid new feature shoots
    phosphorus: f64, // fuels structural/API roots
    humus: f64,      // stabilizes long-term repository health
}

impl CompostPool {
    fn total(&self) -> f64 {
        self.nitrogen + self.phosphorus + self.humus
    }

    fn absorb_decay(&mut self, amount: f64, churn: usize) {
        let factor = 1.0 + (churn.min(20) as f64) * 0.05;
        self.nitrogen += amount * 0.45 * factor;
        self.phosphorus += amount * 0.30 * factor;
        self.humus += amount * 0.25;
    }

    fn feed_feature(&mut self, demand: f64) -> f64 {
        let available = self.total();
        let drawn = demand.min(available * 0.65);
        if available > 0.0 {
            let ratio = drawn / available;
            self.nitrogen -= self.nitrogen * ratio;
            self.phosphorus -= self.phosphorus * ratio;
            self.humus -= self.humus * ratio;
        }
        drawn
    }
}

fn now_epoch_secs() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs_f64())
        .unwrap_or(1_700_000_000.0)
}

// Queries real git log if available; falls back to a realistic sample ecology so it always runs.
fn load_git_history() -> (Vec<CommitNode>, Vec<String>) {
    let now = now_epoch_secs();
    let log_out = Command::new("git")
        .args(["log", "-n", "60", "--pretty=format:%h|%at|%s", "--shortstat"])
        .output();

    let branches_out = Command::new("git")
        .args(["for-each-ref", "--format=%(refname:short)", "refs/heads/"])
        .output();

    let mut branches: Vec<String> = branches_out
        .ok()
        .filter(|o| o.status.success())
        .map(|o| {
            String::from_utf8_lossy(&o.stdout)
                .lines()
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect()
        })
        .unwrap_or_default();

    if branches.is_empty() {
        branches = vec![
            "main".into(),
            "feat/ecological-scheduler".into(),
            "feat/compost-metrics".into(),
            "fix/stale-lock-leak".into(),
            "chore/prune-old-macros".into(),
        ];
    }

    let mut commits = Vec::new();
    if let Ok(out) = log_out {
        if out.status.success() {
            let text = String::from_utf8_lossy(&out.stdout);
            let mut current: Option<(String, f64, String)> = None;

            for line in text.lines() {
                let trimmed = line.trim();
                if trimmed.is_empty() {
                    continue;
                }
                let parts: Vec<&str> = trimmed.splitn(3, '|').collect();
                if parts.len() == 3 && parts[1].parse::<f64>().is_ok() {
                    if let Some((h, ts, subj)) = current.take() {
                        let age_days = ((now - ts) / 86_400.0).max(0.01);
                        commits.push(make_commit(h, subj, age_days, 3));
                    }
                    let ts = parts[1].parse::<f64>().unwrap_or(now);
                    current = Some((parts[0].to_string(), ts, parts[2].to_string()));
                } else if trimmed.contains("changed") {
                    let churn = trimmed
                        .split_whitespace()
                        .filter_map(|tok| tok.parse::<usize>().ok())
                        .sum::<usize>()
                        .max(1);
                    if let Some((h, ts, subj)) = current.take() {
                        let age_days = ((now - ts) / 86_400.0).max(0.01);
                        commits.push(make_commit(h, subj, age_days, churn));
                    }
                }
            }
            if let Some((h, ts, subj)) = current {
                let age_days = ((now - ts) / 86_400.0).max(0.01);
                commits.push(make_commit(h, subj, age_days, 3));
            }
        }
    }

    if commits.is_empty() {
        let sample = [
            ("a1b2c3d", 2.0, "feat: add photosynthetic energy loop", 14),
            ("e4f5g6h", 19.0, "wip: experimental branch hybrid", 9),
            ("9i8j7k6", 54.0, "refactor: legacy parser module", 22),
            ("5l4m3n2", 110.0, "chore: old temporary debug flag", 4),
            ("1o2p3q4", 185.0, "feat: forgotten prototype search", 18),
        ];
        for (h, age, subj, churn) in sample {
            commits.push(make_commit(h.into(), subj.into(), age, churn));
        }
    }

    (commits, branches)
}

fn make_commit(hash: String, subject: String, age_days: f64, churn: usize) -> CommitNode {
    // Commits older than ~21 days begin decomposing into rich humus & minerals.
    let staleness = ((age_days - 14.0) / 30.0).max(0.0);
    let decay_score = (staleness * (1.0 + (churn as f64).ln_1p())).min(25.0);
    CommitNode {
        hash,
        subject,
        age_days,
        churn,
        decay_score,
    }
}

fn classify_role(name: &str) -> TrophicRole {
    let lower = name.to_lowercase();
    if lower == "main" || lower == "master" || lower.starts_with("release") {
        TrophicRole::ApexPredator
    } else if lower.starts_with("fix")
        || lower.starts_with("chore")
        || lower.starts_with("refactor")
    {
        TrophicRole::Decomposer
    } else {
        TrophicRole::Opportunist
    }
}

fn build_food_web(commits: &[CommitNode], branches: &[String]) -> (Vec<BranchOrganism>, CompostPool) {
    let mut compost = CompostPool::default();
    for c in commits {
        if c.decay_score > 0.2 {
            compost.absorb_decay(c.decay_score, c.churn);
        }
    }

    let avg_age = if commits.is_empty() {
        15.0
    } else {
        commits.iter().map(|c| c.age_days).sum::<f64>() / (commits.len() as f64)
    };

    let organisms = branches
        .iter()
        .enumerate()
        .map(|(idx, name)| {
            let role = classify_role(name);
            let base_biomass = match role {
                TrophicRole::ApexPredator => 45.0,
                TrophicRole::Opportunist => 22.0 + ((idx % 4) as f64) * 4.0,
                TrophicRole::Decomposer => 18.0,
            };
            let tip_age_days = (avg_age * (0.4 + ((idx * 7) % 11) as f64 * 0.15)).max(0.5);
            BranchOrganism {
                name: name.clone(),
                role,
                biomass: base_biomass,
                stamina: 100.0,
                tip_age_days,
            }
        })
        .collect();

    (organisms, compost)
}

fn simulate_ecology(organisms: &mut [BranchOrganism], compost: &mut CompostPool, ticks: usize) {
    let mut events: Vec<String> = Vec::new();

    for tick in 1..=ticks {
        // 1. Stale branch tips shed organic matter into compost.
        for org in organisms.iter_mut() {
            org.tip_age_days += 3.0;
            if org.tip_age_days > 30.0 {
                let shed = ((org.tip_age_days - 30.0) * 0.25).min(org.biomass * 0.15);
                org.biomass = (org.biomass - shed).max(5.0);
                compost.absorb_decay(shed, 4);
                if tick == 1 || tick == ticks {
                    events.push(format!(
                        "[Day {}] {} shed {:.1}u stale matter -> compost",
                        tick * 3,
                        org.name,
                        shed
                    ));
                }
            }
        }

        // 2. Predation: ApexPredator absorbs smaller/staler branches (simulating merges/rebases).
        let apex_indices: Vec<usize> = organisms
            .iter()
            .enumerate()
            .filter(|(_, o)| matches!(o.role, TrophicRole::ApexPredator))
            .map(|(i, _)| i)
            .collect();

        for &apex_idx in &apex_indices {
            for prey_idx in 0..organisms.len() {
                if apex_idx == prey_idx {
                    continue;
                }
                let prey_stale_or_small =
                    organisms[prey_idx].tip_age_days > 25.0 || organisms[prey_idx].biomass < 16.0;
                if prey_stale_or_small && organisms[prey_idx].biomass > 6.0 {
                    let harvested = organisms[prey_idx].biomass * 0.22;
                    organisms[prey_idx].biomass -= harvested;
                    organisms[prey_idx].stamina = (organisms[prey_idx].stamina - 12.0).max(10.0);
                    organisms[apex_idx].biomass += harvested * 0.75;
                    compost.absorb_decay(harvested * 0.25, 2);
                    if tick <= 2 {
                        events.push(format!(
                            "[Day {}] {} preyed on {} (+{:.1}u absorbed)",
                            tick * 3,
                            organisms[apex_idx].name,
                            organisms[prey_idx].name,
                            harvested * 0.75
                        ));
                    }
                }
            }
        }

        // 3. Feature blooms: Opportunists draw nutrients from compost to grow new features.
        for org in organisms.iter_mut() {
            if matches!(org.role, TrophicRole::Opportunist) && compost.total() > 2.0 {
                let uptake = compost.feed_feature(8.0);
                org.biomass += uptake * 1.2;
                org.tip_age_days = (org.tip_age_days - 4.0).max(0.5);
                if tick == ticks {
                    events.push(format!(
                        "[Day {}] {} sprouted from compost (+{:.1}u biomass)",
                        tick * 3,
                        org.name,
                        uptake * 1.2
                    ));
                }
            }
        }
    }

    println!("=== GIT ECOLOGICAL FOOD WEB ===");
    println!(
        "Compost Pool -> N: {:.1} | P: {:.1} | Humus: {:.1} (Total: {:.1})\n",
        compost.nitrogen,
        compost.phosphorus,
        compost.humus,
        compost.total()
    );

    println!("--- Living Organisms ---");
    for org in organisms.iter() {
        let bar_len = ((org.biomass / 4.0).round() as usize).clamp(1, 24);
        let bar = "#".repeat(bar_len);
        println!(
            "{:<28} [{:<12}] Biomass {:>5.1} | TipAge {:>4.1}d | {}",
            org.name,
            role_label(&org.role),
            org.biomass,
            org.tip_age_days,
            bar
        );
    }

    if !events.is_empty() {
        println!("\n--- Ecological Interactions ---");
        for ev in events.into_iter().take(10) {
            println!("  * {}", ev);
        }
    }
}

fn role_label(role: &TrophicRole) -> &'static str {
    match role {
        TrophicRole::ApexPredator => "ApexPredator",
        TrophicRole::Opportunist => "Opportunist",
        TrophicRole::Decomposer => "Decomposer",
    }
}

fn main() {
    let (commits, branches) = load_git_history();
    let mut role_counts: HashMap<&'static str, usize> = HashMap::new();
    for b in &branches {
        *role_counts.entry(role_label(&classify_role(b))).or_insert(0) += 1;
    }

    let (mut organisms, mut compost) = build_food_web(&commits, &branches);
    simulate_ecology(&mut organisms, &mut compost, 4);
}