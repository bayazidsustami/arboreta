import math
import random
import sys

def generate_svg_stained_glass():
    # Simulate system error logs translating into visual motifs
    logs = [
        "2026-06-06 10:00:01 INFO System boot sequence initiated",
        "2026-06-06 10:01:15 WARNING Memory usage exceeds 85%",
        "2026-06-06 10:02:44 ERROR Null pointer exception in module core",
        "2026-06-06 10:03:10 SEGMENTATION FAULT (core dumped) at 0x7fff5fbff800",
        "2026-06-06 10:03:11 CRITICAL Process terminated unexpectedly",
        "2026-06-06 10:05:22 WARNING Disk latency high",
        "2026-06-06 10:06:00 SEGMENTATION FAULT memory corruption detected",
        "2026-06-06 10:07:12 INFO Recovery protocol engaged"
    ]
    
    # Analyze log severity metrics
    seg_fault_count = sum(1 for line in logs if "SEGMENTATION FAULT" in line)
    
    width, height = 800, 800
    cx, cy = width / 2, height / 2
    
    # Initialize SVG structure with dark cathedral lead framework
    svg = [f'<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 {width} {height}" width="{width}" height="{height}">']
    svg.append(f'<rect width="{width}" height="{height}" fill="#0a0a0c"/>')
    svg.append(f'<circle cx="{cx}" cy="{cy}" r="380" fill="#151518" stroke="#000000" stroke-width="14"/>')
    
    # Generate concentric geometric rosette layers
    layers = 6
    base_radius = 360
    
    for layer in range(layers, 0, -1):
        r = base_radius * (layer / layers)
        num_petals = layer * 8
        for i in range(num_petals):
            angle1 = (i / num_petals) * 2 * math.pi
            angle2 = ((i + 1) / num_petals) * 2 * math.pi
            
            x1 = cx + r * math.cos(angle1)
            y1 = cy + r * math.sin(angle1)
            x2 = cx + r * math.cos(angle2)
            y2 = cy + r * math.sin(angle2)
            
            prev_r = base_radius * ((layer - 1) / layers)
            px1 = cx + prev_r * math.cos(angle1)
            py1 = cy + prev_r * math.sin(angle1)
            px2 = cx + prev_r * math.cos(angle2)
            py2 = cy + prev_r * math.sin(angle2)
            
            # Map log states to stained glass jewel tones
            seed_val = (layer * i) % len(logs)
            log_line = logs[seed_val]
            
            if "SEGMENTATION FAULT" in log_line:
                fill_color, opacity = "#8b0000", "0.85" # Crimson glass
            elif "ERROR" in log_line or "CRITICAL" in log_line:
                fill_color, opacity = "#b8520b", "0.8"  # Amber glass
            elif "WARNING" in log_line:
                fill_color, opacity = "#b8970b", "0.75" # Gold glass
            else:
                fill_color, opacity = "#1f3a60", "0.7"  # Deep sapphire glass
            
            if layer == 1:
                path_data = f"M {cx} {cy} L {x1} {y1} L {x2} {y2} Z"
            else:
                path_data = f"M {px1} {py1} L {x1} {y1} L {x2} {y2} L {px2} {py2} Z"
            
            svg.append(f'<path d="{path_data}" fill="{fill_color}" fill-opacity="{opacity}" stroke="#050505" stroke-width="4"/>')

    # Bloom crimson roses explicitly where segmentation faults occurred
    for sf_idx in range(seg_fault_count):
        rose_angle = (sf_idx / max(1, seg_fault_count)) * 2 * math.pi + (math.pi / 4)
        rose_r = 180
        rx = cx + rose_r * math.cos(rose_angle)
        ry = cy + rose_r * math.sin(rose_angle)
        
        # Interlocking crimson rose petal structures
        for petal in range(6):
            p_angle = (petal / 6) * 2 * math.pi
            pr = 32
            px = rx + pr * math.cos(p_angle)
            py = ry + pr * math.sin(p_angle)
            svg.append(f'<circle cx="{px}" cy="{py}" r="20" fill="#ff0a2f" fill-opacity="0.9" stroke="#220005" stroke-width="2"/>')
        
        svg.append(f'<circle cx="{rx}" cy="{ry}" r="14" fill="#380006" stroke="#000" stroke-width="3"/>')

    # Central altar core
    svg.append(f'<circle cx="{cx}" cy="{cy}" r="35" fill="#1a0013" stroke="#000" stroke-width="5"/>')
    svg.append(f'<circle cx="{cx}" cy="{cy}" r="15" fill="#ffcc00" fill-opacity="0.95" stroke="#000" stroke-width="2"/>')
    
    svg.append('</svg>')
    
    # Save output to vector SVG file format
    filename = "stained_glass_window.svg"
    with open(filename, "w") as f:
        f.write("\n".join(svg))
    print(f"Generative stained glass window successfully rendered to {filename}")

if __name__ == "__main__":
    generate_svg_stained_glass()