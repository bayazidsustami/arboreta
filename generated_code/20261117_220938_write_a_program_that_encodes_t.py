import math
import random

def generate_stained_glass_svg(text, width=800, height=800):
    """
    Encodes a text message into a procedural stained glass window SVG.
    Vowels map to unique refraction indices (hues/opacities) and lead line thicknesses.
    """
    # Seed random generator based on the text message for deterministic, unique patterns
    random.seed(hash(text))
    
    # Map vowels to unique visual properties (refraction index -> hue/opacity, lead thickness -> stroke)
    vowel_properties = {
        'a': {'hue': 15,  'stroke': 2.5, 'opacity': 0.85}, # Ruby Red
        'e': {'hue': 50,  'stroke': 3.5, 'opacity': 0.80}, # Amber Gold
        'i': {'hue': 190, 'stroke': 4.5, 'opacity': 0.90}, # Cobalt Cyan
        'o': {'hue': 270, 'stroke': 5.5, 'opacity': 0.75}, # Amethyst Purple
        'u': {'hue': 320, 'stroke': 3.0, 'opacity': 0.85}  # Rose Magenta
    }
    
    default_property = {'hue': 210, 'stroke': 3.0, 'opacity': 0.80} # Cool Grey-Blue for consonants
    
    # Generate geometric seed points using a golden ratio spiral distribution
    points = []
    styles = []
    for i, char in enumerate(text.lower()):
        angle = i * 137.5 * (math.pi / 180)
        r = min(width, height) * 0.42 * math.sqrt(i / max(len(text), 1))
        x = width / 2 + r * math.cos(angle)
        y = height / 2 + r * math.sin(angle)
        points.append((x, y))
        
        prop = vowel_properties.get(char, default_property)
        styles.append(prop)
        
    # Pad points if the message is short to ensure a rich stained glass window texture
    while len(points) < 50:
        points.append((random.uniform(40, width - 40), random.uniform(40, height - 40)))
        styles.append(default_property)
        
    # Initialize SVG document container with a dark lead backing
    svg_elements = [
        f'<svg xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" viewBox="0 0 {width} {height}" width="100%" height="100%">',
        '  <defs>',
        '    <filter id="glow">',
        '      <feGaussianBlur stdDeviation="2" result="coloredBlur"/>',
        '      <feMerge>',
        '        <feMergeNode in="coloredBlur"/>',
        '        <feMergeNode in="SourceGraphic"/>',
        '      </feMerge>',
        '    </filter>',
        '  </defs>',
        '  <rect width="100%" height="100%" fill="#0a0a0a"/>'
    ]
    
    # Render procedural stained glass shards (polygons) around each encoded character point
    for idx, (x, y) in enumerate(points):
        prop = styles[idx % len(styles)]
        hue = prop['hue'] + random.uniform(-10, 10) # Slight refractive variance
        stroke_width = prop['stroke']
        opacity = prop['opacity']
        
        # Generate organic, jittered polygon vertices
        num_vertices = random.randint(5, 8)
        polygon_points = []
        base_radius = random.uniform(40, 100)
        
        for v in range(num_vertices):
            vertex_angle = (v / num_vertices) * 2 * math.pi + random.uniform(-0.3, 0.3)
            radius_jitter = base_radius * random.uniform(0.65, 1.35)
            px = max(10, min(width - 10, x + radius_jitter * math.cos(vertex_angle)))
            py = max(10, min(height - 10, y + radius_jitter * math.sin(vertex_angle)))
            polygon_points.append(f"{px:.1f},{py:.1f}")
            
        points_str = " ".join(polygon_points)
        fill_color = f"hsla({hue:.1f}, 75%, 48%, {opacity:.2f})"
        lead_color = "#111111"
        
        svg_elements.append(
            f'  <polygon points="{points_str}" fill="{fill_color}" '
            f'stroke="{lead_color}" stroke-width="{stroke_width}" '
            f'stroke-linejoin="round" filter="url(#glow)" />'
        )
        
    svg_elements.append('</svg>')
    return "\n".join(svg_elements)

if __name__ == "__main__":
    message_to_encode = "Procedural Stained Glass Window Encoding Algorithm"
    svg_output = generate_stained_glass_svg(message_to_encode)
    
    output_filename = "stained_glass_window.svg"
    with open(output_filename, "w", encoding="utf-8") as f:
        f.write(svg_output)
        
    print(f"Successfully encoded message into '{output_filename}'")