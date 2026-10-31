import subprocess
import sys
import time
import random
import os

def get_git_history():
    """Extracts git commit history or generates mock data if not in a git repo."""
    try:
        result = subprocess.run(
            ['git', 'log', '--pretty=format:%h|%p|%s', '-n', '20'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
        lines = result.stdout.strip().split('\n')
        commits = []
        for line in lines:
            if not line:
                continue
            parts = line.split('|', 2)
            if len(parts) == 3:
                h, p, s = parts
                parents = p.split()
                is_merge = len(parents) > 1 or 'merge' in s.lower()
                commits.append({'hash': h, 'is_merge': is_merge, 'msg': s})
        if commits:
            return list(reversed(commits))
    except Exception:
        pass
    
    # Fallback mock commit history if git fails or isn't present
    return [
        {'hash': 'a1b2c3d', 'is_merge': False, 'msg': 'Initial spore release'},
        {'hash': 'e4f5g6h', 'is_merge': False, 'msg': 'Mycelium network expansion'},
        {'hash': 'i7j8k9l', 'is_merge': True,  'msg': 'Merge branch feature/luminescent-caps'},
        {'hash': 'm0n1o2p', 'is_merge': False, 'msg': 'Deep soil nutrient absorption'},
        {'hash': 'q3r4s5t', 'is_merge': True,  'msg': 'Merge conflict resolution in root system'},
    ]

def render_colony(commits):
    """Renders the subterranean mushroom colony in the terminal with bioluminescent flickering."""
    # Mushroom ASCII templates
    mushroom_cap = [
        "     ___      ",
        "    / * \\     ",
        "   | * * |    ",
        "    \\___/     "
    ]
    mushroom_stem = [
        "     |||      ",
        "     |||      "
    ]
    
    # ANSI Color codes
    RESET = "\033[0m"
    DIM_BLUE = "\033[38;5;33m"
    BRIGHT_CYAN = "\033[1;38;5;51m"
    PULSE_GREEN = "\033[1;38;5;82m"
    ALERT_RED = "\033[1;38;5;196m"
    
    try:
        for i in range(15):  # Animation loop representing cycles of bioluminescence
            os.system('cls' if os.name == 'nt' else 'clear')
            print("==================================================")
            print("    SUBTERRANEAN MUSHROOM COLONY: GIT MATRIX     ")
            print("==================================================\n")
            print(f"Mycelium network active. Tracking {len(commits)} commits...\n")
            
            for idx, commit in enumerate(commits):
                is_merge = commit['is_merge']
                
                # Merge commits flicker intensely between red (conflict warning) and bright cyan
                if is_merge:
                    glow = ALERT_RED if (i % 2 == 0) else BRIGHT_CYAN
                    status_tag = f"{ALERT_RED}[MERGE CONFLICT / FUSION]{RESET}"
                else:
                    glow = PULSE_GREEN if (i % 3 == 0) else DIM_BLUE
                    status_tag = f"{DIM_BLUE}[Stable Spore]{RESET}"
                
                print(f"Commit {commit['hash']} {status_tag}: {commit['msg']}")
                for row in mushroom_cap:
                    styled_row = row.replace('*', f"{glow}*")
                    print(f"{glow}{styled_row}{RESET}")
                for row in mushroom_stem:
                    print(f"\033[38;5;94m{row}{RESET}")
                print("-" * 50)
            
            print(f"\n[Bioluminescence Cycle {i+1}/15] Press Ctrl+C to exit colony view.")
            time.sleep(0.7)
    except KeyboardInterrupt:
        print(f"\n{RESET}Colony hibernation mode activated. Goodbye!")

if __name__ == '__main__':
    commits = get_git_history()
    render_colony(commits)