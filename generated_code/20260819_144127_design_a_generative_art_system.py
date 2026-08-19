import math
import random
import subprocess
import tkinter as tk
from dataclasses import dataclass, field
from typing import List, Dict, Tuple, Optional

# --- Data Structures & Git Parser ---

@dataclass
class Commit:
    hash_str: str
    author: str
    timestamp: int
    is_merge: bool
    files_changed: int

def parse_git_history(max_commits: int = 150) -> List[Commit]:
    """Extracts git history from the local repository or generates synthetic history as fallback."""
    commits = []
    try:
        cmd = ["git", "log", f"-n{max_commits}", "--pretty=format:%H|%an|%at|%p", "--numstat"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines = result.stdout.strip().split('\n')
        
        current_commit = None
        for line in lines:
            if '|' in line and len(line.split('|')) == 4:
                if current_commit:
                    commits.append(current_commit)
                parts = line.split('|')
                h, author, ts, parents = parts[0], parts[1], int(parts[2]), parts[3].split()
                is_merge = len(parents) > 1
                current_commit = Commit(h, author, ts, is_merge, 0)
            elif current_commit and line.strip():
                # Accumulate file change metrics from numstat
                parts = line.split()
                if len(parts) >= 2 and parts[0].isdigit():
                    current_commit.files_changed += int(parts[0]) + int(parts[1])
                else:
                    current_commit.files_changed += 1
        if current_commit:
            commits.append(current_commit)
    except Exception:
        # Synthetic git history generator if executed outside a git repository
        authors = ["Alice (Core)", "Bob (Refactor)", "Charlie (Docs)", "Dave (Optimization)"]
        base_time = 1600000000
        for i in range(max_commits):
            h = f"{random.getrandbits(160):040x}"
            author = random.choice(authors)
            is_merge = (i > 0 and random.random() < 0.15)
            files = random.randint(1, 40)
            commits.append(Commit(h, author, base_time + i * 3600, is_merge, files))

    return list(reversed(commits))  # Chronological order

# --- Mathematical Palette & Species System ---

def author_to_color_palette(author: str) -> List[str]:
    """Generates a deterministic color palette (hex) derived from an author's name hash."""
    seed = sum(ord(c) for c in author)
    rnd = random.Random(seed)
    base_hue = rnd.uniform(0, 360)
    
    colors = []
    for shift in [0, 25, -25]:
        h = (base_hue + shift) % 360
        # Convert HSL to RGB hex
        c = 0.8 * 0.9  # S=0.8, L=0.5ish
        x = c * (1 - abs((h / 60) % 2 - 1))
        m = 0.1
        if h < 60: r, g, b = c, x, 0
        elif h < 120: r, g, b = x, c, 0
        elif h < 180: r, g, b = 0, c, x
        elif h < 240: r, g, b = 0, x, c
        elif h < 300: r, g, b = x, 0, c
        else: r, g, b = c, 0, x
        hex_c = f"#{int((r+m)*255):02x}{int((g+m)*255):02x}{int((b+m)*255):02x}"
        colors.append(hex_c)
    return colors

@dataclass
class BranchNode:
    x: float
    y: float
    angle: float
    length: float
    width: float
    depth: int
    color: str
    children: List['BranchNode'] = field(default_factory=list)

class CoralPolypery:
    """Represents a growing coral colony whose morphogenesis is tuned by an author's commit metrics."""
    def __init__(self, x: float, y: float, author: str, commit_hash: str):
        self.x = x
        self.y = y
        self.author = author
        self.palette = author_to_color_palette(author)
        self.root: Optional[BranchNode] = None
        self.growth_energy = 0.0
        
        # Seed deterministic parameters from hash
        val = int(commit_hash[:8], 16)
        self.branch_angle = 0.2 + (val % 100) / 300.0  # Angle spread
        self.curviness = ((val >> 8) % 100) / 500.0
        self.max_depth = 4 + (val % 4)

    def grow(self, files_changed: int):
        """Triggers differential growth based on file volume."""
        self.growth_energy += max(1.0, math.log10(files_changed + 1) * 3)
        self.root = self._build_tree(self.x, self.y, -math.pi / 2, self.growth_energy, 12.0, 0)

    def _build_tree(self, x: float, y: float, angle: float, length: float, width: float, depth: int) -> BranchNode:
        nx = x + math.cos(angle) * length
        ny = y + math.sin(angle) * length
        color = self.palette[depth % len(self.palette)]
        node = BranchNode(x, y, angle, length, width, depth, color)

        if depth < self.max_depth and length > 2.0:
            # Fork into 2 or 3 branches deterministically
            split_count = 2 if (depth + int(self.x)) % 2 == 0 else 3
            for i in range(split_count):
                spread = (i - (split_count - 1) / 2) * self.branch_angle
                child_angle = angle + spread + math.sin(depth + length) * self.curviness
                child_node = self._build_tree(
                    nx, ny, child_angle,
                    length * 0.72,
                    max(1.0, width * 0.68),
                    depth + 1
                )
                node.children.append(child_node)
        return node

# --- Speciation / Particle Burst ---

class MutationParticle:
    def __init__(self, x: float, y: float, color: str):
        self.x = x
        self.y = y
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(2, 8)
        self.vx = math.cos(angle) * speed
        self.vy = math.sin(angle) * speed
        self.life = 1.0
        self.decay = random.uniform(0.02, 0.05)
        self.color = color

    def update(self):
        self.x += self.vx
        self.y += self.vy
        self.vx *= 0.95
        self.vy *= 0.95
        self.life -= self.decay

# --- Main Simulation Canvas ---

class CoralReefSimulation:
    def __init__(self, root: tk.Tk, commits: List[Commit]):
        self.root = root
        self.root.title("Evolving Git Coral Reef Ecosystem")
        self.width = 1100
        self.height = 700
        
        self.canvas = tk.Canvas(root, width=self.width, height=self.height, bg="#050d1a")
        self.canvas.pack(fill=tk.BOTH, expand=True)

        self.commits = commits
        self.commit_index = 0
        self.corals: Dict[str, CoralPolypery] = {}
        self.particles: List[MutationParticle] = []
        
        # UI overlays
        self.info_text = self.canvas.create_text(20, 20, anchor="nw", fill="#4af6c6", 
                                                 font=("Courier", 11, "bold"), text="Initializing Reef...")
        
        self._setup_ambient_ocean()
        self.animate()

    def _setup_ambient_ocean(self):
        """Draws subtle background bioluminescent gradients and ocean floor."""
        self.canvas.create_rectangle(0, self.height - 40, self.width, self.height, fill="#02060d", outline="")
        for _ in range(40):
            rx = random.uniform(0, self.width)
            ry = random.uniform(0, self.height)
            size = random.uniform(1, 3)
            self.canvas.create_oval(rx, ry, rx+size, ry+size, fill="#1c3d5a", outline="")

    def trigger_speciation_event(self, x: float, y: float):
        """Violent speciation burst triggered by merge commits."""
        flash_colors = ["#ff0055", "#00ffff", "#ffff00", "#ffffff"]
        for _ in range(60):
            p = MutationParticle(x, y, random.choice(flash_colors))
            self.particles.append(p)
            
        # Draw shockwave pulse
        for r in range(10, 80, 15):
            self.canvas.create_oval(x-r, y-r, x+r, y+r, outline="#ff2a6d", width=2, tags="transient")

    def step_simulation(self):
        """Process the next git commit, altering the ecosystem balance."""
        if self.commit_index >= len(self.commits):
            return

        commit = self.commits[self.commit_index]
        self.commit_index += 1

        # Map author to a position on the reef floor
        if commit.author not in self.corals:
            # Deterministic anchor position based on author name
            slot = sum(ord(c) for c in commit.author) % 8
            cx = (slot + 1) * (self.width / 9) + random.uniform(-20, 20)
            cy = self.height - 40
            self.corals[commit.author] = CoralPolypery(cx, cy, commit.author, commit.hash_str)

        coral = self.corals[commit.author]
        coral.grow(commit.files_changed)

        if commit.is_merge:
            # Merge commit triggers violent mutation/speciation event across species
            self.trigger_speciation_event(coral.x, coral.y - 50)
            # Mutation modifies existing species parameters
            coral.branch_angle *= random.uniform(0.8, 1.25)
            coral.palette.reverse()

        # Update status UI
        msg = (f"Commit: {commit.hash_str[:7]} | Author: {commit.author}\n"
               f"Files Changed: {commit.files_changed} | Event: {'[MERGE SPECIATION]' if commit.is_merge else 'Growth'}\n"
               f"Ecosystem Biodiversity: {len(self.corals)} Active Species")
        self.canvas.itemconfig(self.info_text, text=msg)

    def _render_tree(self, node: BranchNode):
        """Recursively renders coral branches."""
        for child in node.children:
            self.canvas.create_line(
                node.x, node.y, child.x, child.y,
                fill=node.color, width=int(node.width), capstyle=tk.ROUND, tags="coral"
            )
            self._render_tree(child)

    def draw(self):
        """Render frame."""
        self.canvas.delete("coral")
        self.canvas.delete("transient")

        # Render Corals
        for coral in self.corals.values():
            if coral.root:
                self._render_tree(coral.root)

        # Render Particles
        active_particles = []
        for p in self.particles:
            p.update()
            if p.life > 0:
                active_particles.append(p)
                r = 3 * p.life
                self.canvas.create_oval(p.x-r, p.y-r, p.x+r, p.y+r, fill=p.color, outline="", tags="transient")
        self.particles = active_particles

    def animate(self):
        """Main simulation loop."""
        self.step_simulation()
        self.draw()
        self.root.after(80, self.animate)


# --- Application Entry Point ---

def main():
    commits = parse_git_history(max_commits=120)
    root = tk.Tk()
    app = CoralReefSimulation(root, commits)
    root.mainloop()

if __name__ == "__main__":
    main()