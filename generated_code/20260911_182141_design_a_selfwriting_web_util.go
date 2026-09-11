package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// CommitData represents a single star in our git constellation.
type CommitData struct {
	Hash      string   `json:"hash"`
	Author    string   `json:"author"`
	Message   string   `json:"message"`
	Date      string   `json:"date"`
	Branch    string   `json:"branch"`
	Additions int      `json:"additions"`
	Deletions int      `json:"deletions"`
	Parents   []string `json:"parents"`
}

func main() {
	http.HandleFunc("/", handleIndex)
	http.HandleFunc("/api/constellation", handleConstellation)

	fmt.Println("GALAXY GIT VISUALIZER ONLINE")
	fmt.Println("Observe your constellation at: http://localhost:8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}

// handleConstellation extracts git log history and converts commits into celestial data
func handleConstellation(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	// Extract commits with graph details using git log
	cmd := exec.Command("git", "log", "--all", "--pretty=format:%H|%an|%s|%ad|%D|%P", "--date=iso-strict", "--numstat")
	out, err := cmd.Output()
	if err != nil {
		// Fallback empty array if not in a git repo
		json.NewEncoder(w).Encode([]CommitData{})
		return
	}

	commits := parseGitLog(string(out))
	json.NewEncoder(w).Encode(commits)
}

func parseGitLog(output string) []CommitData {
	var commits []CommitData
	lines := strings.Split(output, "\n")

	var currentCommit *CommitData

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		parts := strings.Split(line, "|")
		if len(parts) >= 6 {
			if currentCommit != nil {
				commits = append(commits, *currentCommit)
			}

			parents := []string{}
			if parts[5] != "" {
				parents = strings.Split(parts[5], " ")
			}

			branch := "main"
			if parts[4] != "" {
				refParts := strings.Split(parts[4], ",")
				for _, ref := range refParts {
					ref = strings.TrimSpace(ref)
					if strings.HasPrefix(ref, "HEAD -> ") {
						branch = strings.TrimPrefix(ref, "HEAD -> ")
					} else if ref != "" && !strings.Contains(ref, "tag:") {
						branch = ref
						break
					}
				}
			}

			currentCommit = &CommitData{
				Hash:    parts[0],
				Author:  parts[1],
				Message: parts[2],
				Date:    parts[3],
				Branch:  branch,
				Parents: parents,
			}
		} else if currentCommit != nil {
			// Parse numstat line: additions deletions filename
			statParts := strings.Fields(line)
			if len(statParts) >= 2 {
				adds, _ := strconv.Atoi(statParts[0])
				dels, _ := strconv.Atoi(statParts[1])
				currentCommit.Additions += adds
				currentCommit.Deletions += dels
			}
		}
	}

	if currentCommit != nil {
		commits = append(commits, *currentCommit)
	}

	return commits
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/html")
	fmt.Fprint(w, htmlCanvasApp)
}

const htmlCanvasApp = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Git Constellation Engine</title>
    <style>
        body, html { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #030308; color: #fff; font-family: monospace; }
        #canvas { width: 100vw; height: 100vh; display: block; }
        #overlay { position: absolute; top: 20px; left: 20px; pointer-events: none; text-shadow: 0 0 10px rgba(0,255,255,0.8); }
        h1 { margin: 0; font-size: 1.5rem; letter-spacing: 2px; }
        p { margin: 5px 0 0 0; opacity: 0.7; font-size: 0.8rem; }
        #info { position: absolute; bottom: 20px; left: 20px; background: rgba(5,10,25,0.8); padding: 15px; border-radius: 8px; border: 1px solid #00f0ff; max-width: 400px; display: none; backdrop-filter: blur(5px); }
    </style>
</head>
<body>
    <div id="overlay">
        <h1>GIT CONSTELLATION</h1>
        <p>Interactive Gravitational Commit Map • Click a Star to Sonify</p>
    </div>
    <div id="info"></div>
    <canvas id="canvas"></canvas>

    <script>
        const canvas = document.getElementById('canvas');
        const ctx = canvas.getContext('2d');
        const info = document.getElementById('info');

        let width, height;
        let stars = [];
        let orbits = {};
        let selectedStar = null;

        // Audio Context Setup for Sonification
        const audioCtx = new (window.AudioContext || window.webkitAudioContext)();

        function resize() {
            width = canvas.width = window.innerWidth;
            height = canvas.height = window.innerHeight;
        }
        window.addEventListener('resize', resize);
        resize();

        // Sonify a commit starburst
        function sonifyCommit(star) {
            if (audioCtx.state === 'suspended') {
                audioCtx.resume();
            }

            const totalChanges = Math.max(1, star.additions + star.deletions);
            const baseFreq = 150 + (star.branchIndex * 120) % 600;
            const duration = Math.min(2.0, 0.2 + totalChanges * 0.02);

            const osc = audioCtx.createOscillator();
            const gain = audioCtx.createGain();

            // Frequency shifts with changes
            osc.type = star.additions > star.deletions ? 'sine' : 'sawtooth';
            osc.frequency.setValueAtTime(baseFreq, audioCtx.currentTime);
            osc.frequency.exponentialRampToValueAtTime(baseFreq * (1 + star.additions/100), audioCtx.currentTime + duration);

            gain.gain.setValueAtTime(0.3, audioCtx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration);

            osc.connect(gain);
            gain.connect(audioCtx.destination);

            osc.start();
            osc.stop(audioCtx.currentTime + duration);
        }

        async function fetchConstellation() {
            const res = await fetch('/api/constellation');
            const data = await res.json();
            buildSystem(data);
        }

        function buildSystem(data) {
            const branchMap = {};
            let branchCount = 0;

            // Map unique branches to gravitational orbits
            data.forEach(c => {
                if (!(c.branch in branchMap)) {
                    branchMap[c.branch] = branchCount++;
                }
            });

            const totalCommits = data.length || 1;
            stars = data.map((c, i) => {
                const bIdx = branchMap[c.branch];
                const orbitRadius = 120 + bIdx * 80;
                const angle = (i / totalCommits) * Math.PI * 2 + (bIdx * 0.5);

                return {
                    ...c,
                    branchIndex: bIdx,
                    orbitRadius: orbitRadius,
                    angle: angle,
                    speed: 0.001 + (bIdx + 1) * 0.0005,
                    size: Math.min(12, Math.max(3, Math.sqrt(c.additions + c.deletions))),
                    color: `hsl(${ (bIdx * 137.5) % 360 }, 80%, 60%)`,
                    pulse: 0
                };
            });
        }

        function draw() {
            ctx.fillStyle = 'rgba(3, 3, 8, 0.2)';
            ctx.fillRect(0, 0, width, height);

            const cx = width / 2;
            const cy = height / 2;

            // Draw gravitational orbit paths
            const uniqueRadii = [...new Set(stars.map(s => s.orbitRadius))];
            uniqueRadii.forEach(r => {
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.strokeStyle = 'rgba(0, 240, 255, 0.08)';
                ctx.lineWidth = 1;
                ctx.stroke();
            });

            // Update & Render Stars
            stars.forEach(star => {
                star.angle += star.speed;
                const x = cx + Math.cos(star.angle) * star.orbitRadius;
                const y = cy + Math.sin(star.angle) * star.orbitRadius;

                star.x = x;
                star.y = y;

                // Starburst radiance effect
                if (star.pulse > 0) {
                    ctx.beginPath();
                    ctx.arc(x, y, star.size + star.pulse, 0, Math.PI * 2);
                    ctx.fillStyle = star.color;
                    ctx.globalAlpha = star.pulse / 20;
                    ctx.fill();
                    ctx.globalAlpha = 1.0;
                    star.pulse *= 0.92;
                }

                // Core Star
                ctx.beginPath();
                ctx.arc(x, y, star.size, 0, Math.PI * 2);
                ctx.fillStyle = star == selectedStar ? '#ffffff' : star.color;
                ctx.shadowBlur = 15;
                ctx.shadowColor = star.color;
                ctx.fill();
                ctx.shadowBlur = 0;
            });

            requestAnimationFrame(draw);
        }

        canvas.addEventListener('click', (e) => {
            const rect = canvas.getBoundingClientRect();
            const mx = e.clientX - rect.left;
            const my = e.clientY - rect.top;

            let found = null;
            stars.forEach(star => {
                const dist = Math.hypot(star.x - mx, star.y - my);
                if (dist < star.size + 5) {
                    found = star;
                }
            });

            if (found) {
                selectedStar = found;
                found.pulse = 30;
                sonifyCommit(found);

                info.style.display = 'block';
                info.innerHTML = `
                    <div style="color:${found.color}; font-weight:bold; margin-bottom:5px;">${found.branch}</div>
                    <div><strong>Hash:</strong> ${found.Hash ? found.Hash.substring(0, 7) : 'head'}</div>
                    <div><strong>Author:</strong> ${found.author}</div>
                    <div><strong>Message:</strong> ${found.message}</div>
                    <div style="margin-top:5px; color:#00ff88;">+${found.additions} <span style="color:#ff4444;">-${found.deletions}</span></div>
                `;
            }
        });

        fetchConstellation();
        draw();
    </script>
</body>
</html>`