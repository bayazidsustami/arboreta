import math
import random
import sys

# Requirements: Visual timeline generator rendering a Git commit history 
# as an evolving, mathematically generated digital bonsai tree where branches 
# reflect code structure and blossoms represent successful deployments.

def generate_mock_commit_history(count=30):
    """Generates synthetic commit data simulating a git log with branch structural depth and deployment tags."""
    commits = []
    files_pool = [
        "src/main.py", "src/utils.py", "src/core/engine.py", 
        "src/core/models.py", "tests/test_main.py", "docs/README.md",
        "src/ui/components.py", "src/api/routes.py"
    ]
    
    for i in range(count):
        num_files = random.randint(1, 4)
        modified_files = random.sample(files_pool, num_files)
        # Deployment tagged commits act as blossoms
        is_deployment = (i > 0 and i % 7 == 0) or (i == count - 1)
        
        commits.append({
            "hash": f"{random.getrandbits(24):06x}",
            "author": random.choice(["Alice", "Bob", "Charlie"]),
            "files": modified_files,
            "is_deployment": is_deployment,
            "message": f"Deployment release v1.{i//7}" if is_deployment else f"Refactor module iteration {i}"
        })
    return commits

def parse_code_depth(files):
    """Calculates structural depth based on file paths to determine branch complexity."""
    max_depth = 1
    for f in files:
        depth = f.count('/') + 1
        if depth > max_depth:
            max_depth = depth
    return max_depth

class Vector2D:
    def __init__(self, x, y):
        self.x = x
        self.y = y

class BonsaiNode:
    """Represents a structural segment/branch or blossom in the digital bonsai tree."""
    def __init__(self, start, angle, length, thickness, depth, is_blossom=False, commit_info=None):
        self.start = start
        self.angle = angle
        self.length = length
        self.thickness = thickness
        self.depth = depth
        self.is_blossom = is_blossom
        self.commit_info = commit_info
        
        # Calculate end point using trigonometric branching
        rad = math.radians(angle)
        self.end = Vector2D(
            start.x + length * math.cos(rad),
            start.y + length * math.sin(rad)
        )
        self.children = []

    def grow(self, commit):
        """Evolves the bonsai tree structure based on incoming Git commit attributes."""
        if self.depth <= 0:
            if commit["is_deployment"] and not self.children:
                # Add a blossom node for successful deployments
                blossom = BonsaiNode(
                    start=self.end,
                    angle=self.angle + random.uniform(-30, 30),
                    length=4,
                    thickness=1,
                    depth=0,
                    is_blossom=True,
                    commit_info=commit
                )
                self.children.append(blossom)
            return

        if not self.children:
            # Code complexity (file depth) dictates branching factor and variation
            struct_depth = parse_code_depth(commit["files"])
            num_branches = min(3, max(1, struct_depth))
            
            angle_spread = 25.0 * struct_depth
            start_angle = self.angle - (angle_spread / 2)
            
            for i in range(num_branches):
                branch_angle = start_angle + (i * (angle_spread / max(1, num_branches - 1))) if num_branches > 1 else self.angle + random.uniform(-15, 15)
                # Mathematical decay of length and thickness simulating organic growth
                new_length = self.length * random.uniform(0.7, 0.85)
                new_thickness = max(1, self.thickness - 1)
                
                child = BonsaiNode(
                    start=self.end,
                    angle=branch_angle,
                    length=new_length,
                    thickness=new_thickness,
                    depth=self.depth - 1,
                    is_blossom=False,
                    commit_info=commit
                )
                self.children.append(child)
        else:
            # Pass commit growth down to sub-branches
            for child in self.children:
                child.grow(commit)

class BonsaiCanvas:
    """ASCII canvas for rendering the mathematically generated bonsai tree timeline."""
    def __init__(self, width=80, height=40):
        self.width = width
        self.height = height
        self.grid = [[" " for _ in range(width)] for _ in range(height)]

    def draw_line(self, x0, y0, x1, y1, char="#"):
        """Bresenham's line algorithm for rendering branches on discrete grid."""
        dx = abs(x1 - x0)
        dy = abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy

        curr_x, curr_y = x0, y0
        while True:
            if 0 <= curr_x < self.width and 0 <= curr_y < self.height:
                self.grid[curr_y][curr_x] = char
            if curr_x == x1 and curr_y == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                curr_x += sx
            if e2 < dx:
                err += dx
                curr_y += sy

    def render_node(self, node):
        """Recursively draws branches and deployment blossoms."""
        x0, y0 = int(round(node.start.x)), int(round(node.start.y))
        x1, y1 = int(round(node.end.x)), int(round(node.end.y))

        if node.is_blossom:
            # Render blossom representing a deployment
            if 0 <= x1 < self.width and 0 <= y1 < self.height:
                self.grid[y1][x1] = "@"  # Deployment blossom symbol
        else:
            # Select branch character depending on orientation/depth
            char = "|" if abs(x1 - x0) < abs(y1 - y0) else "-"
            if node.depth > 3:
                char = "W" if node.thickness > 2 else "Y"
            self.draw_line(x0, y0, x1, y1, char=char)

        for child in node.children:
            self.render_node(child)

    def display(self):
        """Outputs the visual grid to stdout."""
        print("=" * self.width)
        for row in reversed(self.grid):  # Invert Y axis for natural tree rendering
            print("".join(row))
        print("=" * self.width)

def run_digital_bonsai_generator():
    print("Initializing Git Repository Commit History Analysis...")
    commits = generate_mock_commit_history(count=35)
    
    # Root trunk setup at bottom center (angle -90 pointing upward in canvas grid)
    root_start = Vector2D(40, 0)
    tree_root = BonsaiNode(
        start=root_start,
        angle=90,  # Points upward on canvas
        length=8,
        thickness=4,
        depth=5
    )

    canvas = BonsaiCanvas(width=80, height=35)

    print("\nSimulating Git Commit Timeline & Growing Digital Bonsai Tree...\n")
    for idx, commit in enumerate(commits):
        tree_root.grow(commit)
        
        # Intermediate snapshot on deployments
        if commit["is_deployment"]:
            print(f"[Commit {idx+1}/{len(commits)}] DEPLOYMENT DETECTED: {commit['message']} ({commit['hash']})")
            print("Blossom bloomed on the bonsai structure!\n")

    # Final rendering of the evolved bonsai tree
    canvas.render_node(tree_root)
    canvas.display()
    
    print("\nBonsai Tree Legend:")
    print("  'W', 'Y', '|', '-' : Branches representing code structure & commit topology")
    print("  '@'                : Blossoms representing successful deployments")

if __name__ == "__main__":
    run_digital_bonsai_generator()