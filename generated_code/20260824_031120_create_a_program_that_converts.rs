use gix::Repository;
use rodio::{OutputStream, Sink, source::SignalGenerator};
use std::collections::{HashMap, HashSet};
use std::path::Path;
use std::time::Duration;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 1. Open the Git repository at the current directory
    let repo = gix::open(Path::new("."))?;

    // 2. Traversal settings: Walk backwards from HEAD to build the commit topology graph
    let head_commit = repo.head()?.peel_to_commit_in_place()?;
    let revwalk = repo.revwalk([head_commit.id]);

    let mut commit_records = Vec::new();

    // 3. Extract topological properties and churn metrics from commit history
    for item in revwalk.all()? {
        let info = item?;
        let commit = info.object()?;
        let parent_ids: Vec<_> = commit.parent_ids().map(|p| p.detach()).collect();

        // Calculate Churn (insertions + deletions) compared to primary parent
        let churn = if let Some(parent_id) = parent_ids.first() {
            let parent_tree = repo.find_object(*parent_id)?.peel_to_tree()?;
            let commit_tree = commit.tree()?;
            let diff = repo.diff_tree_to_tree(&parent_tree, &commit_tree)?;
            diff.len() as f32
        } else {
            100.0 // Initial commit baseline churn
        };

        commit_records.push((commit.id.detach(), parent_ids, churn));
    }

    // Reverse to replay history chronologically from root to HEAD
    commit_records.reverse();

    // Track active branch lanes to detect rebases/lineage offsets
    let mut lineage_lanes: HashMap<gix::ObjectId, usize> = HashMap::new();
    let mut active_heads: HashSet<gix::ObjectId> = HashSet::new();

    // 4. Initialize Audio Output Stream
    let (_stream, stream_handle) = OutputStream::try_default()?;
    let sink = Sink::try_new(&stream_handle)?;

    println!("Playing Git repository soundscape...");

    for (idx, (id, parents, churn)) in commit_records.iter().enumerate() {
        let parent_count = parents.len();
        
        // Determine Pitch Shift: Base pitch depends on lane index (detecting rebased branch shifts)
        let lane = *lineage_lanes.get(id).unwrap_or(&0);
        let pitch_offset = (lane as f32 * 2.0).sin() * 200.0; // Dynamic semitone shift
        let base_freq = 220.0 + pitch_offset + ((idx % 12) as f32 * 15.0);

        // Code Churn controls Reverb Delay / Temporal Resonance duration
        let reverb_duration = (churn / 20.0).clamp(0.05, 1.5);
        let note_duration = Duration::from_secs_f32(0.15 + reverb_duration * 0.1);

        if parent_count > 1 {
            // MERGE COMMIT: Polyphonic Chord
            // Combine frequencies from fundamental, 5th, and major/minor 3rd based on parent count
            let frequencies = vec![base_freq, base_freq * 1.25, base_freq * 1.5];
            
            for &freq in &frequencies {
                let source = SignalGenerator::sine(freq)
                    .take_duration(note_duration)
                    .amplify(0.15 / (frequencies.len() as f32));
                sink.append(source);
            }
        } else {
            // LINEAR COMMIT: Monophonic Tone with Churn Modulation
            let source = SignalGenerator::sine(base_freq)
                .take_duration(note_duration)
                .amplify(0.1);
            sink.append(source);
        }

        // Update lineage tracking
        for (p_idx, parent) in parents.iter().enumerate() {
            lineage_lanes.entry(*parent).or_insert(lane + p_idx);
            active_heads.insert(*parent);
        }

        // Small pause to sequence commit tones evenly in time
        std::thread::sleep(Duration::from_millis(120));
    }

    sink.sleep_until_end();
    Ok(())
}