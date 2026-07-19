package main

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"io/ioutil"
	"math/rand"
	"os"
	"os/exec"
	"strings"
	"time"
)

// The template for the self-modifying Python script.
// It reads its own git log, scores emotion based on keywords, updates its own internal state,
// and regenerates an HTML/CSS digital quilt that evolves over time.
const pythonScriptTemplate = `import os
import sys
import subprocess
import re

# --- EMOTIONAL STATE ---
# This dictionary is algorithmically updated by the Go orchestrator and the script itself.
# CURRENT_MOOD: %s
# GENERATION: %d
# LAST_UPDATED: "%s"

MOOD_VECTORS = {
    "joy": ["feature", "achieve", "solve", "good", "love", "fix", "clean", "optimize", "speed"],
    "anxiety": ["bug", "error", "fail", "broken", "issue", "panic", "warn", "hotfix", "crash"],
    "boredom": ["refactor", "docs", "typo", "cleanup", "merge", "chore", "update", "lint"],
    "anger": ["stupid", "damn", "hate", "wtf", "crazy", "stupid", "revert", "stop", "bad"]
}

def analyze_git_history():
    try:
        # Extract the commit messages from git history
        log_output = subprocess.check_output(["git", "log", "--pretty=format:%%s"], stderr=subprocess.DEVNULL).decode("utf-8")
        messages = log_output.lower().split("\n")
    except Exception:
        # Fallback if not in a git repo
        messages = ["initial commit", "fix bug", "refactor code for elegance", "chaos and anxiety rule"]

    scores = {"joy": 1, "anxiety": 1, "boredom": 1, "anger": 1}
    for msg in messages:
        for mood, keywords in MOOD_VECTORS.items():
            for kw in keywords:
                if kw in msg:
                    scores[mood] += 1
    
    total = sum(scores.values())
    return {k: v / total for k, v in scores.items()}

def generate_quilt_css(moods):
    # Map moods to CSS gradient structures, animations, and color palettes
    # Joy = Vibrant Gold/Warm tones, Anxiety = Fractured Purples/Deep Blues, Boredom = Grays/Muted Teals, Anger = Harsh Reds/Orange
    
    j_weight = int(moods["joy"] * 100)
    a_weight = int(moods["anxiety"] * 100)
    b_weight = int(moods["boredom"] * 100)
    an_weight = int(moods["anger"] * 100)

    css = f"""/* Evolving Digital Quilt CSS - Generated dynamically from Git Sentiment */
:root {{
    --joy-color: hsla(45, 100%%, 50%%, {moods["joy"]});
    --anxiety-color: hsla(270, 70%%, 40%%, {moods["anxiety"]});
    --boredom-color: hsla(190, 20%%, 50%%, {moods["boredom"]});
    --anger-color: hsla(0, 85%%, 45%%, {moods["anger"]});
}}

body {{
    margin: 0;
    background: #0d0d11;
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100vh;
    overflow: hidden;
    font-family: 'Courier New', monospace;
}}

.quilt-container {{
    display: grid;
    grid-template-columns: repeat(8, 1fr);
    grid-template-rows: repeat(8, 1fr);
    width: 80vmin;
    height: 80vmin;
    gap: 4px;
    perspective: 1000px;
}}

.patch {{
    width: 100%%;
    height: 100%%;
    transition: all 1.5s ease-in-out;
    animation: pulse 6s infinite ease-in-out alternate;
}}

/* Dynamic blending matching the code's emotional balance */
.patch:nth-child(3n) {{
    background: linear-gradient({j_weight}deg, var(--joy-color), var(--boredom-color));
    clip-path: polygon(0 0, 100%% 0, 80%% 100%%, 0 100%%);
}}
.patch:nth-child(3n+1) {{
    background: radial-gradient(circle, var(--anxiety-color) {a_weight}%%, var(--anger-color));
    transform: rotate({an_weight}deg);
}}
.patch:nth-child(3n+2) {{
    background: linear-gradient({b_weight}deg, var(--boredom-color), var(--joy-color), var(--anxiety-color));
    border-radius: {j_weight}%% {an_weight}%% {b_weight}%% {a_weight}%%;
}}

@keyframes pulse {{
    0%% {{ transform: scale(0.95) translateZ(0px); filter: saturate(0.8); }}
    100%% {{ transform: scale(1.05) translateZ({an_weight}px); filter: saturate(1.5); }}
}}
"""
    return css

def self_modify(dominant_mood):
    with open(__file__, "r") as f:
        content = f.read()

    # Find the current generation and increment it
    gen_match = re.search(r"# GENERATION: (\d+)", content)
    generation = int(gen_match.group(1)) + 1 if gen_match else 1

    # Mutate the header meta-state lines
    content = re.sub(r"# CURRENT_MOOD: .*", f"# CURRENT_MOOD: {dominant_mood}", content)
    content = re.sub(r"# GENERATION: .*", f"# GENERATION: {generation}", content)
    content = re.sub(r'# LAST_UPDATED: ".*"', f'# LAST_UPDATED: "{subprocess.check_output(["date"]).decode("utf-8").strip()}"', content)

    # Introduce minor functional mutations to its own behavior over time based on mood
    if dominant_mood == "anger" and "chaos" not in content:
        content += "\n# Added in a fit of rage: chaos factor engaged.\n"

    with open(__file__, "w") as f:
        f.write(content)

def main():
    moods = analyze_git_history()
    dominant_mood = max(moods, key=moods.get)
    
    # Render the quilt interface
    css_content = generate_quilt_css(moods)
    
    html = f"""<!DOCTYPE html>
<html>
<head>
    <title>The Inner Life of Code - Gen</title>
    <style>
        {css_content}
    </style>
</head>
<body>
    <div class="quilt-container">
        {"".join(['<div class="patch"></div>' for _ in range(64)])}
    </div>
    <div style="position: absolute; bottom: 20px; color: #fff; text-shadow: 0 2px 4px #000; font-size: 0.9em; text-align: center; width: 100%%;">
        <strong>Dominant Sentiment:</strong> {dominant_mood.upper()} | 
        Joy: {moods["joy"]:.2f} | Anxiety: {moods["anxiety"]:.2f} | Boredom: {moods["boredom"]:.2f} | Anger: {moods["anger"]:.2f}
    </div>
</body>
</html>"""

    with open("quilt.html", "w") as f:
        f.write(html)
    
    # Evolve its own source code
    self_modify(dominant_mood)
    print(f"[Quilt Evolved] Dominant Mood: {dominant_mood.upper()} | Quilt saved to quilt.html")

if __name__ == "__main__":
    main()
`

func main() {
	rand.Seed(time.Now().UnixNano())
	pyFileName := "evolving_quilt.py"

	fmt.Println("⚡ Initializing Self-Modifying Sentiment Quilt Architecture...")

	// 1. Ensure a dummy git repo exists if not already present so we have history to analyze
	if _, err := os.Stat(".git"); os.IsNotExist(err) {
		fmt.Println("📦 No git repository discovered. Initiating ephemeral repository for emotional tracking...")
		exec.Command("git", "init").Run()
		exec.Command("git", "config", "user.name", "Emotional Architect").Run()
		exec.Command("git", "config", "user.email", "quilt@neurosis.ai").Run()
	}

	// 2. Generate seed emotional commits to simulate developmental history
	moodSeeds := []string{
		"Initial commit: boilerplate scaffolding",
		"Fix devastating bug that caused endless loop and panic!",
		"Refactor beautifully, optimized performance and layout logic",
		"Stupid typo, hate dealing with undocumented legacy scripts",
		"Clean up documentation, chore/lint alignment",
		"Wrote elegant self-assembly module, pure joy",
	}

	// 3. Populate the initial Python file
	initialMood := "serene"
	initialGen := 1
	initialTimestamp := time.Now().Format(time.RFC1123)
	pyCode := fmt.Sprintf(pythonScriptTemplate, initialMood, initialGen, initialTimestamp)

	err := ioutil.WriteFile(pyFileName, []byte(pyCode), 0755)
	if err != nil {
		fmt.Printf("❌ Failed to write Python seed file: %v\n", err)
		return
	}

	// 4. Commit the initial state and some random synthetic history to feed the sentiment engine
	exec.Command("git", "add", pyFileName).Run()
	for _, commitMsg := range moodSeeds {
		// Append a subtle comment to mutate file hash to allow consecutive commits
		f, _ := os.OpenFile(pyFileName, os.O_APPEND|os.O_WRONLY, 0644)
		h := md5.New()
		h.Write([]byte(commitMsg))
		f.WriteString(fmt.Sprintf("\n# Entropy Token: %s\n", hex.EncodeToString(h.Sum(nil))[:8]))
		f.Close()

		exec.Command("git", "commit", "-am", commitMsg).Run()
	}

	fmt.Printf("🧬 Formulated self-modifying script: %s\n", pyFileName)
	fmt.Println("🎨 Triggering Python generative canvas processing...")

	// 5. Execute the self-modifying Python script
	cmd := exec.Command("python3", pyFileName)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Run()
	if err != nil {
		// Fallback to python if python3 alias isn't standard
		cmd = exec.Command("python", pyFileName)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		_ = cmd.Run()
	}

	fmt.Println("\n✨ Evolution successful. Inspect 'quilt.html' to observe the localized visual mood matrix.")
	fmt.Println("🚀 Run 'python3 evolving_quilt.py' continuously to witness further self-contained mutations.")
}