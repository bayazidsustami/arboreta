import math
import random
import time
import json
import urllib.request
import xml.etree.ElementTree as ET

# Fetch real-time GOES X-ray solar flux data from NOAA SWPC
def fetch_solar_flux():
    url = "[https://services.swpc.noaa.gov/json/goes/primary/xrays-6-hour.json](https://services.swpc.noaa.gov/json/goes/primary/xrays-6-hour.json)"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=4) as resp:
            data = json.loads(resp.read().decode())
            # Extract latest long-wavelength X-ray flux (0.1-0.8 nm)
            latest_flux = next((item['flux'] for item in reversed(data) if item.get('energy') == '0.1-0.8nm'), 1e-6)
            return max(latest_flux, 1e-9)
    except Exception:
        # Fallback to a simulated dynamic flux if network/API fails
        t = time.time() / 10.0
        return 1e-6 * (10 ** (math.sin(t) * 2.5 + 1.5))

# Basic vector glyph contours defined as normalized coordinate loops (0.0 - 1.0)
GLYPH_PATTERNS = {
    'S': [[(0.8,0.2),(0.3,0.1),(0.1,0.3),(0.3,0.5),(0.7,0.5),(0.9,0.7),(0.7,0.9),(0.2,0.8)]],
    'O': [[(0.5,0.1),(0.85,0.25),(0.85,0.75),(0.5,0.9),(0.15,0.75),(0.15,0.25)]],
    'L': [[(0.2,0.1),(0.2,0.9),(0.8,0.9)]],
    'A': [[(0.1,0.9),(0.5,0.1),(0.9,0.9)], [(0.3,0.6),(0.7,0.6)]],
    'R': [[(0.2,0.9),(0.2,0.1),(0.7,0.1),(0.8,0.3),(0.6,0.5),(0.2,0.5)], [(0.5,0.5),(0.85,0.9)]]
}

def interpolate_polygon(points, num_samples=60):
    """Resample continuous path into evenly distributed coordinates for granular particle/path mutation."""
    resampled = []
    total_segments = len(points) - 1
    for i in range(total_segments):
        p1, p2 = points[i], points[i+1]
        steps = max(1, num_samples // total_segments)
        for s in range(steps):
            t = s / steps
            resampled.append((p1[0] + (p2[0]-p1[0])*t, p1[1] + (p2[1]-p1[1])*t))
    resampled.append(points[-1])
    return resampled

def generate_solar_typography(text="SOLAR", output_file="solar_flare_typography.svg"):
    flux = fetch_solar_flux()
    
    # Calculate magnetic turbulence & intensity factors based on logarithmic X-ray scale (A, B, C, M, X class)
    log_flux = math.log10(flux)
    intensity = max(0.1, min(1.0, (log_flux + 8) / 4.0)) # Normalized 0 to 1
    turbulence = intensity * 45.0
    burn_decay = max(0.05, 1.0 - (intensity * 0.85))
    
    # Base SVG document setup
    width, height = 1200, 500
    svg = ET.Element('svg', {
        'xmlns': '[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)',
        'viewBox': f'0 0 {width} {height}',
        'style': 'background: #030206;'
    })
    
    # Dynamic SVG Filters: Thermal turbulence and plasma bloom
    defs = ET.SubElement(svg, 'defs')
    
    filter_elem = ET.SubElement(defs, 'filter', {'id': 'solar-plasma', 'x': '-50%', 'y': '-50%', 'width': '200%', 'height': '200%'})
    ET.SubElement(filter_elem, 'feTurbulence', {
        'type': 'fractalNoise',
        'baseFrequency': f'{0.02 + intensity*0.05} {0.05 + intensity*0.1}',
        'numOctaves': '4',
        'result': 'noise'
    })
    ET.SubElement(filter_elem, 'feDisplacementMap', {
        'in': 'SourceGraphic',
        'in2': 'noise',
        'scale': str(turbulence),
        'xChannelSelector': 'R',
        'yChannelSelector': 'G'
    })
    
    glow_filter = ET.SubElement(defs, 'filter', {'id': 'corona-glow'})
    ET.SubElement(glow_filter, 'feGaussianBlur', {'stdDeviation': str(3 + intensity * 8), 'result': 'coloredBlur'})
    merge = ET.SubElement(glow_filter, 'feMerge')
    ET.SubElement(merge, 'feMergeNode', {'in': 'coloredBlur'})
    ET.SubElement(merge, 'feMergeNode', {'in': 'SourceGraphic'})

    # Render mutating, burning typography
    glyph_width = 180
    start_x = (width - (len(text) * glyph_width)) / 2
    random.seed(int(time.time() // 10)) # Coherent noise sequence
    
    main_group = ET.SubElement(svg, 'g', {'filter': 'url(#solar-plasma)'})

    for char_idx, char in enumerate(text):
        if char not in GLYPH_PATTERNS: continue
        offset_x = start_x + char_idx * glyph_width
        offset_y = 120
        scale = 260

        for path_data in GLYPH_PATTERNS[char]:
            pts = [(offset_x + x * scale, offset_y + y * scale) for x, y in path_data]
            sampled_pts = interpolate_polygon(pts, num_samples=80)
            
            # Mutate path points based on simulated coronal mass displacement
            mutated_path = []
            for px, py in sampled_pts:
                angle = random.uniform(0, math.pi * 2)
                mag = random.gauss(0, turbulence * 0.6)
                
                # Magnetic burn: shift points outwards proportional to solar flux
                dx = math.cos(angle) * mag
                dy = math.sin(angle) * mag - (intensity * 15.0) # Thermal upward drift
                mutated_path.append((px + dx, py + dy))

            # Render magnetic flux arcs / erupting filaments
            path_import random
import math
import xml.etree.ElementTree as ET
from xml.dom import minidom

# Simulated real-time NOAA Solar Flare GOES Satellite Data
def fetch_solar_flare_data():
    """Simulates real-time magnetic flux intensity (Watts/m²) and flare class."""
    flux = random.uniform(1e-7, 1e-3) # X-ray flux range (A-class to X-class)
    if flux >= 1e-4:
        flare_class = f"X{(flux / 1e-4):.1f}"
    elif flux >= 1e-5:
        flare_class = f"M{(flux / 1e-5):.1f}"
    elif flux >= 1e-6:
        flare_class = f"C{(flux / 1e-6):.1f}"
    elif flux >= 1e-7:
        flare_class = f"B{(flux / 1e-7):.1f}"
    else:
        flare_class = "A0.0"
    return flux, flare_class

# Basic vector glyph control points [x, y, line_type]
LETTER_PATHS = {
    'S': [(80, 20), (20, 20), (20, 50), (80, 50), (80, 80), (20, 80)],
    'O': [(20, 20), (80, 20), (80, 80), (20, 80), (20, 20)],
    'L': [(20, 20), (20, 80), (80, 80)],
    'A': [(20, 80), (50, 20), (80, 80), (65, 50), (35, 50)],
    'R': [(20, 80), (20, 20), (70, 20), (70, 50), (20, 50), (80, 80)]
}

def interpolate_path(points, num_samples=60):
    """Interpolates a course vector path into dense, evenly spaced node points."""
    dense_points = []
    for i in range(len(points) - 1):
        p1, p2 = points[i], points[i+1]
        for t in range(num_samples // (len(points) - 1)):
            alpha = t / (num_samples // (len(points) - 1))
            x = p1[0] + (p2[0] - p1[0]) * alpha
            y = p1[1] + (p2[1] - p1[1]) * alpha
            dense_points.append((x, y))
    return dense_points

def generate_solar_typography_svg(text="SOLAR", filename="solar_flare_typography.svg"):
    flux, flare_class = fetch_solar_flare_data()
    
    # Normalized flux intensity (0.0 = calm, 1.0 = extreme X-class flare)
    intensity = min(1.0, max(0.0, (math.log10(flux) + 7) / 4.0))
    
    # Canvas parameters
    char_width = 100
    svg_width = len(text) * char_width + 100
    svg_height = 200
    
    # Root SVG Setup
    svg = ET.Element('svg', xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)", 
                     viewBox=f"0 0 {svg_width} {svg_height}",
                     style="background-color: #05020a;")
    
    # Dynamic Flare Filters & Gradients
    defs = ET.SubElement(svg, 'defs')
    
    # Glow filter reflecting magnetic disturbance
    filter_glow = ET.SubElement(defs, 'filter', id="solarGlow", x="-50%", y="-50%", width="200%", height="200%")
    blur_std = 2 + intensity * 12
    ET.SubElement(filter_glow, 'feGaussianBlur', stdDeviation=str(blur_std), result="blur")
    fe_merge = ET.SubElement(filter_glow, 'feMerge')
    ET.SubElement(fe_merge, 'feMergeNode', in="blur")
    ET.SubElement(fe_merge, 'feMergeNode', in="SourceGraphic")
    
    # Dynamic Color Gradient based on flare heat
    grad = ET.SubElement(defs, 'linearGradient', id="flareGrad", x1="0%", y1="100%", x2="0%", y2="0%")
    ET.SubElement(grad, 'stop', offset="0%", **{'stop-color': '#ff1a00', 'stop-opacity': '0.9'})
    ET.SubElement(grad, 'stop', offset=f"{int(30 + intensity*40)}%", **{'stop-color': '#ff7700'})
    ET.SubElement(grad, 'stop', offset="100%", **{'stop-color': '#ffffcc' if intensity > 0.5 else '#ffcc00'})

    # Metadata display
    meta_text = ET.SubElement(svg, 'text', x="20", y="30", fill="#ff5500", 
                               font_family="monospace", font_size="12", opacity="0.8")
    meta_text.text = f"GOES-XRAY MAG_FLUX: {flux:.2e} W/m² | CLASS: {flare_class}"

    # Render mutating typography
    group = ET.SubElement(svg, 'g', transform="translate(50, 50)", filter="url(#solarGlow)")
    
    for char_idx, char in enumerate(text):
        if char not in LETTER_PATHS:
            continue
            
        base_points = LETTER_PATHS[char]
        dense_pts = interpolate_path(base_points)
        x_offset = char_idx * char_width

        # Generate magnetic erosion and arc field filaments
        path_data = []
        for i, (px, py) in enumerate(dense_pts):
            # Heat deformation displacement (coronal erosion)
            mag_noise = math.sin(i * 0.5 + intensity * 10) * (intensity * 18)
            thermal_decay = random.uniform(-1, 1) * (intensity * 12)
            
            # Displace points along magnetic flux lines
            nx = px + x_offset + mag_noise
            ny = py + thermal_decay
            
            # Ejection threshold: high flux burns away glyph segments completely
            if random.random() < (intensity * 0.35):
                # Flare tendril / Prominence loop arc
                arc_x = nx + random.uniform(-40, 40) * intensity
                arc_y = ny - random.uniform(20, 80) * intensity
                ET.SubElement(group, 'path', d=f"M {nx},{ny} Q {arc_x},{arc_y} {nx + random.uniform(-10,10)},{ny}", 
                              stroke="#ffaa00", stroke_width=str(0.5 + intensity * 1.5), fill="none", opacity=str(random.uniform(0.3, 0.8)))
                path_data.append(f"M {nx},{ny}")
            else:
                path_data.append(f"{'M' if i == 0 else 'L'} {nx},{ny}")

        # Render base mutating character skeleton
        ET.SubElement(group, 'path', d=" ".join(path_data), 
                      fill="none", stroke="url(#flareGrad)", 
                      stroke_width=str(4 + intensity * 6),
                      stroke_linecap="round", stroke_linejoin="round")

        # Particle field: Burning plasma detaching from letters
        num_particles = int(20 + intensity * 100)
        for _ in range(num_particles):
            rx, ry = random.choice(dense_pts)
            # Ejection vector pointing upwards (solar wind)
            part_x = rx + x_offset + random.gauss(0, 5 + intensity * 15)
            part_y = ry - random.uniform(0, 30 + intensity * 70)
            part_r = random.uniform(0.5, 2.0 + intensity * 2)
            
            ET.SubElement(group, 'circle', cx=str(part_x), cy=str(part_y), r=str(part_r),
                          fill="#ffffff" if random.random() > 0.5 else "#ff4400",
                          opacity=str(random.uniform(0.2, 0.9)))

    # Beautify XML and Save
    rough_string = ET.tostring(svg, 'utf-8')
    reparsed = minidom.parseString(rough_string)
    pretty_xml = reparsed.toprettyxml(indent="  ")
    
    with open(filename, "w") as f:
        f.write(pretty_xml)

    print(f"Generative Solar SVG generated successfully: {filename} (Intensity: {flare_class})")

if __name__ == "__main__":
    generate_solar_typography_svg()