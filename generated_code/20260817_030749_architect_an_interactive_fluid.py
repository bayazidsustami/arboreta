import os
import webbrowser

# Architect a pure CSS + HTML checkbox interactive fluid-dynamics and cellular automaton simulator.
# Python serves as the meta-architect generating the complex CSS spatial propagation matrix.

def build_fluid_automaton_html(grid_size=15):
    """
    Generates a standalone HTML/CSS file that implements fluid wave dynamics and 
    cellular propagation entirely via CSS custom properties, keyframe physics, 
    and HTML checkbox state interactions (zero JS runtime).
    """
    
    # Generate spatial distance wave propagation CSS rules for every checkbox cell
    propagation_rules = []
    for r in range(grid_size):
        for c in range(grid_size):
            cell_id = f"c_{r}_{c}"
            
            # CSS selector triggering ripple waves across the grid upon checking a box
            propagation_rules.append(f"""
            #{cell_id}:checked ~ .viewport .grid .cell {{
                --dist: calc(abs(var(--r) - {r}) + abs(var(--c) - {c}));
                animation: fluidRipple 3s cubic-bezier(0.2, 0.8, 0.2, 1) infinite;
                animation-delay: calc(var(--dist) * 0.07s);
            }}
            #{cell_id}:checked ~ .viewport .grid label[for="{cell_id}"] {{
                background: #00ffff !important;
                box-shadow: 0 0 25px #00ffff, inset 0 0 10px #ffffff;
                transform: translateZ(30px) scale(1.2);
            }}
            """)

    css_matrix = "\n".join(propagation_rules)

    # HTML/CSS document containing cellular automaton layout & visual engine
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pure CSS Fluid Automaton</title>
    <style>
        :root {{
            --grid-size: {grid_size};
            --cell-dim: min(32px, 5vw);
            --primary-hue: 195deg;
            --bg: #030712;
        }}

        * {{ box-sizing: border-box; margin: 0; padding: 0; }}

        body {{
            background-color: var(--bg);
            color: #f1f5f9;
            font-family: system-ui, -apple-system, sans-serif;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            overflow: hidden;
            perspective: 1000px;
        }}

        .header {{
            text-align: center;
            margin-bottom: 20px;
            z-index: 10;
        }}

        h1 {{
            font-weight: 300;
            letter-spacing: 3px;
            font-size: 1.6rem;
            color: #38bdf8;
            text-shadow: 0 0 20px rgba(56, 189, 248, 0.4);
        }}

        p {{
            font-size: 0.85rem;
            color: #64748b;
            margin-top: 4px;
        }}

        /* Hidden Checkboxes Acting as Automaton State Nodes */
        .node-check {{ display: none; }}

        /* Pure CSS Fluid Palette Controls */
        .controls {{
            display: flex;
            gap: 12px;
            margin-bottom: 25px;
            z-index: 10;
        }}

        .theme-btn {{
            padding: 6px 14px;
            background: rgba(15, 23, 42, 0.8);
            border: 1px solid #1e293b;
            border-radius: 20px;
            font-size: 0.75rem;
            color: #94a3b8;
            cursor: pointer;
            transition: all 0.3s;
            user-select: none;
        }}

        .theme-btn:hover {{
            border-color: #38bdf8;
            color: #f8fafc;
            box-shadow: 0 0 12px rgba(56, 189, 248, 0.3);
        }}

        /* Viewport & Grid Canvas */
        .viewport {{
            position: relative;
            padding: 24px;
            background: rgba(15, 23, 42, 0.5);
            border-radius: 20px;
            border: 1px solid rgba(56, 189, 248, 0.15);
            backdrop-filter: blur(12px);
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7);
            transform-style: preserve-3d;
            transform: rotateX(20deg) rotateZ(0deg);
            transition: transform 0.5s ease;
        }}

        .viewport:hover {{
            transform: rotateX(0deg) rotateZ(0deg);
        }}

        .grid {{
            display: grid;
            grid-template-columns: repeat(var(--grid-size), var(--cell-dim));
            grid-template-rows: repeat(var(--grid-size), var(--cell-dim));
            gap: 5px;
            transform-style: preserve-3d;
        }}

        /* Cellular Automaton Render Nodes */
        .cell {{
            width: var(--cell-dim);
            height: var(--cell-dim);
            background: rgba(15, 23, 42, 0.9);
            border: 1px solid rgba(56, 189, 248, 0.1);
            border-radius: 6px;
            cursor: pointer;
            transition: background 0.4s, transform 0.3s, box-shadow 0.4s;
            transform-style: preserve-3d;
        }}

        .cell:hover {{
            border-color: #38bdf8;
            transform: translateZ(15px) scale(1.15);
            box-shadow: 0 0 15px rgba(56, 189, 248, 0.5);
            z-index: 20;
        }}

        /* Generative Fluid Wave Motion Dynamics */
        @keyframes fluidRipple {{
            0% {{
                transform: translateZ(0px) scale(1);
                background: rgba(15, 23, 42, 0.9);
            }}
            30% {{
                transform: translateZ(28px) scale(1.18);
                background: hsl(calc(var(--primary-hue) + (var(--dist) * 8deg)), 95%, 60%);
                box-shadow: 0 0 18px hsl(calc(var(--primary-hue) + (var(--dist) * 8deg)), 95%, 60%);
                border-radius: 45%;
            }}
            60% {{
                transform: translateZ(-10px) scale(0.92);
                background: hsl(calc(var(--primary-hue) + 60deg), 80%, 45%);
                box-shadow: 0 0 8px hsl(calc(var(--primary-hue) + 60deg), 80%, 45%);
            }}
            100% {{
                transform: translateZ(0px) scale(1);
                background: rgba(15, 23, 42, 0.9);
            }}
        }}

        /* Theme Switches via Checked Radio Siblings */
        #t-bioluminescence:checked ~ .viewport {{ --primary-hue: 170deg; }}
        #t-plasma:checked ~ .viewport {{ --primary-hue: 320deg; }}
        #t-solar:checked ~ .viewport {{ --primary-hue: 35deg; }}

        /* Dynamically Generated CSS Spatial Interactions */
        {css_matrix}
    </style>
</head>
<body>

    <div class="header">
        <h1>PURE CSS FLUID DYNAMICS</h1>
        <p>Interactive Cellular Automaton Simulator • Driven by Click State Engine</p>
    </div>

    <!-- Theme Control Nodes -->
    <input type="radio" id="t-ocean" name="theme" class="node-check" checked>
    <input type="radio" id="t-bioluminescence" name="theme" class="node-check">
    <input type="radio" id="t-plasma" name="theme" class="node-check">
    <input type="radio" id="t-solar" name="theme" class="node-check">

    <div class="controls">
        <label for="t-ocean" class="theme-btn">Cyan Hydro</label>
        <label for="t-bioluminescence" class="theme-btn">Bio Luminescence</label>
        <label for="t-plasma" class="theme-btn">Plasma Flow</label>
        <label for="t-solar" class="theme-btn">Solar Flare</label>
    </div>

    <!-- Automaton Checkbox Drivers -->
    {''.join([f'<input type="checkbox" id="c_{r}_{c}" class="node-check">' for r in range(grid_size) for c in range(grid_size)])}

    <!-- Interactive Rendering Canvas -->
    <div class="viewport">
        <div class="grid">
            {''.join([f'<label for="c_{r}_{c}" class="cell" style="--r: {r}; --c: {c};"></label>' for r in range(grid_size) for c in range(grid_size)])}
        </div>
    </div>

</body>
</html>
"""
    return html_content

if __name__ == "__main__":
    # Export simulator HTML and launch in standard web browser
    filename = "fluid_automaton_simulator.html"
    with open(filename, "w", encoding="utf-8") as f:
        f.write(build_fluid_automaton_html(grid_size=15))
    
    file_path = os.path.abspath(filename)
    webbrowser.open(f"file://{file_path}")