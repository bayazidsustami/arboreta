import os
import sys
import math
import wave
import struct
import tempfile
import subprocess
from pathlib import Path

def get_git_data(repo_path="."):
    """Extract branch tips, commit history, branch assignments, churn, and merge conflict status."""
    def run_git(cmd):
        res = subprocess.run(
            ["git", "-C", repo_path] + cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return res.stdout.strip()

    if run_git(["rev-parse", "--is-inside-work-tree"]) != "true":
        raise ValueError("Not a valid Git repository.")

    # Identify distinct branches/heads
    branches_raw = run_git(["for-each-ref", "--format=%(refname:short)", "refs/heads/"]).splitlines()
    branches = branches_raw if branches_raw else ["HEAD"]

    # Collect commits across branches
    commit_log = run_run_log = run_git(["log", "--all", "--topo-order", "--reverse", "--parents", "--format=%H %P"])
    commits = [line.split() for line in commit_log.splitlines() if line]

    # Map each branch to its recent commits
    branch_commits = {}
    for b in branches:
        b_hashes = set(run_git(["log", b, "--format=%H"]).splitlines())
        branch_commits[b] = b_hashes

    # Compute churn and detect merge conflicts per commit
    score_events = []
    for c in commits:
        c_hash = c[0]
        parents = c[1:]
        
        # Branch topology: assign voice channel based on branch ownership
        voice_id = 0
        for idx, b in enumerate(branches):
            if c_hash in branch_commits[b]:
                voice_id = idx % 4  # Polyphony limit of 4 voices
                break

        # Calculate code churn (additions + deletions)
        stats = run_git(["show", "--stat", "--oneline", c_hash]).splitlines()
        churn = 0
        if stats and "files changed" in stats[-1]:
            parts = stats[-1].split(",")
            for part in parts:
                nums = [int(s) for s in part.split() if s.isdigit()]
                if nums:
                    churn += nums[0]
        churn = max(1, churn)

        # Merge conflict indicator (3+ parents or specific conflict markers in commit msg)
        msg = run_git(["log", "-1", "--format=%B", c_hash])
        is_conflict = len(parents) > 1 and ("conflict" in msg.lower() or "fixup!" in msg.lower() or len(parents) > 2)

        score_events.append({
            "hash": c_hash,
            "voice": voice_id,
            "churn": churn,
            "is_merge": len(parents) > 1,
            "is_conflict": is_conflict,
        })

    return score_events

def synthesize_microtonal_score(events, sample_rate=44100):
    """
    Translates repository topology into a microtonal audio score:
    - Polyphony: Branches map to separate harmonic voices with 19-TET microtonal tuning.
    - Tempo: Code churn dictates note duration and tempo pacing.
    - Dissonant Chords: Merge conflicts trigger cluster chords and frequency modulation dissonance.
    """
    # 19-TET (19 Tone Equal Temperament) Base Frequencies for microtonal harmony
    base_freq = 220.0  # A3
    tet19_ratio = 2.0 ** (1.0 / 19.0)
    
    # Map voice IDs to distinct microtonal modes
    voice_modes = {
        0: [0, 3, 6, 9, 12, 15, 18],   # Pentatonic-ish 19-TET
        1: [1, 4, 7, 10, 13, 16],      # Shifted voice
        2: [2, 5, 8, 11, 14, 17],      # Counterpoint voice
        3: [0, 2, 5, 7, 11, 14, 16]    # Sub-bass voice
    }

    pcm_data = []
    
    for i, ev in enumerate(events):
        voice = ev["voice"]
        churn = ev["churn"]
        is_conflict = ev["is_conflict"]
        is_merge = ev["is_merge"]

        # Code churn dictates tempo (higher churn = shorter, intense duration)
        duration = max(0.08, min(0.6, 2.0 / math.sqrt(churn + 1)))
        num_samples = int(sample_rate * duration)

        # Base microtonal frequency derived from hash value and 19-TET scale
        hash_val = int(ev["hash"][:4], 16)
        scale = voice_modes[voice]
        step = scale[hash_val % len(scale)]
        octave = (hash_val % 3)
        freq = base_freq * (2 ** octave) * (tet19_ratio ** step)

        # Merge conflicts generate extreme dissonant clusters (tritones + microtonal shifts)
        if is_conflict:
            chord_freqs = [freq, freq * (tet19_ratio ** 1), freq * (tet19_ratio ** 5), freq * 1.414]
        elif is_merge:
            chord_freqs = [freq, freq * (tet19_ratio ** 6), freq * (tet19_ratio ** 12)]
        else:
            chord_freqs = [freq]

        for t_idx in range(num_samples):
            t = t_idx / sample_rate
            
            # Envelope generator (Attack-Decay)
            env = math.exp(-3.0 * (t / duration))
            
            # Synthesize polyphonic voice sample
            sample_val = 0.0
            for f in chord_freqs:
                # Add slight ring modulation on merge conflicts for harsh dissonance
                mod = 1.0 + (0.5 * math.sin(2 * math.pi * 50 * t)) if is_conflict else 1.0
                sample_val += math.sin(2 * math.pi * f * t) * mod

            # Normalize and smooth tone
            sample_val = (sample_val / len(chord_freqs)) * env * 0.4
            
            # Convert to 16-bit PCM integer
            int_val = int(max(-32768, min(32767, sample_val * 32767)))
            pcm_data.append(struct.pack('<h', int_val))

    return b"".join(pcm_data)

def render_wav(raw_pcm, output_path="git_polyphony.wav", sample_rate=44100):
    """Writes the PCM audio buffer to a playable WAV file."""
    with wave.open(output_path, "wb") as wav_file:
        wav_file.setnchannels(1)       # Mono synthesis
        wav_file.setsampwidth(2)       # 16-bit PCM
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(raw_pcm)

if __name__ == "__main__":
    repo = sys.argv[1] if len(sys.argv) > 1 else "."
    print(f"Ingesting Git history from: {os.path.abspath(repo)}")
    try:
        events = get_git_data(repo)
        print(f"Processed {len(events)} commits across branch topology.")
        print("Translating churn and topology to 19-TET microtonal score...")
        pcm_audio = synthesize_microtonal_score(events)
        out_file = "repository_topology.wav"
        render_wav(pcm_audio, out_file)
        print(f"Composition rendered successfully: {os.path.abspath(out_file)}")
    except Exception as e:
        print(f"Error generating musical score: {e}")