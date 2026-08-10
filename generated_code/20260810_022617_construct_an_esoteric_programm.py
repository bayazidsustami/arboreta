import xml.etree.ElementTree as ET
import sys

class SVGStackEsolang:
    """
    An interpreter for an esoteric programming language embedded entirely within SVG DOM elements.
    Every valid program is a valid SVG vector graphic. Executing the code mutates the document's
    own DOM, assembling a maze that visually maps the runtime call stack and memory state.
    """
    def __init__(self, svg_string=None):
        if svg_string:
            self.root = ET.fromstring(svg_string)
        else:
            self.root = self._generate_default_svg_program()
        
        # Runtime Stack State
        self.data_stack = []
        self.call_stack = [(12, 12)]  # Start stack maze at center of grid
        self.visited = {(12, 12)}
        self.ip = 0
        
        # Canvas grid mapping
        self.cell_size = 22
        self.maze_origin_x = 350
        self.maze_origin_y = 120
        
        # Extract or create DOM execution groups
        self.code_group = self.root.find(".//*[@id='code-ribbon']")
        self.maze_group = self.root.find(".//*[@id='runtime-maze']")
        
        if self.maze_group is None:
            self.maze_group = ET.SubElement(self.root, "g", {
                "id": "runtime-maze",
                "stroke-linecap": "round",
                "stroke-linejoin": "round"
            })

    def _generate_default_svg_program(self):
        """Builds a valid SVG file encoding an esoteric program inside SVG shapes."""
        svg = ET.Element("svg", {
            "xmlns": "[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)",
            "viewBox": "0 0 950 720",
            "width": "100%",
            "height": "100%",
            "style": "background: #0d1117; font-family: monospace;"
        })
        
        # Background Grid pattern
        defs = ET.SubElement(svg, "defs")
        pattern = ET.SubElement(defs, "pattern", {
            "id": "grid", "width": "22", "height": "22", "patternUnits": "userSpaceOnUse"
        })
        ET.SubElement(pattern, "path", {
            "d": "M 22 0 L 0 0 0 22", "fill": "none", "stroke": "#161b22", "stroke-width": "1"
        })
        
        ET.SubElement(svg, "rect", {"width": "100%", "height": "100%", "fill": "#0d1117"})
        ET.SubElement(svg, "rect", {
            "x": "320", "y": "90", "width": "580", "height": "580",
            "fill": "url(#grid)", "rx": "8", "stroke": "#30363d", "stroke-width": "2"
        })
        
        # UI Titles
        title = ET.SubElement(svg, "text", {
            "x": "30", "y": "45", "fill": "#58a6ff", "font-size": "20", "font-weight": "bold"
        })
        title.text = "SVG-DOM ESOLANG: SELF-ASSEMBLING MAZE STACK"
        
        subtitle = ET.SubElement(svg, "text", {
            "x": "30", "y": "70", "fill": "#8b949e", "font-size": "12"
        })
        subtitle.text = "Program instructions (Left) execute & mutate DOM to carve execution stack maze (Right)"
        
        # Code ribbon panel container
        ET.SubElement(svg, "rect", {
            "x": "30", "y": "90", "width": "260", "height": "580",
            "fill": "#161b22", "rx": "8", "stroke": "#30363d", "stroke-width": "2"
        })
        
        code_group = ET.SubElement(svg, "g", {"id": "code-ribbon"})
        
        # Build program instruction sequence: PUSH, CARVE, DUP, ADD, POP
        raw_ops = []
        directions = [0, 1, 2, 3, 1, 2, 3, 0, 2, 3, 0, 1, 3, 0, 1, 2]
        for loop in range(4):
            for d in directions:
                raw_ops.append(("PUSH", (d + loop) % 4))
                raw_ops.append(("CARVE", 0))
                raw_ops.append(("DUP", 0))
                raw_ops.append(("PUSH", 1))
                raw_ops.append(("ADD", 0))
                raw_ops.append(("CARVE", 0))
                raw_ops.append(("POP", 0))
            raw_ops.append(("POP", 0))
            raw_ops.append(("POP", 0))
            
        # Layout instruction DOM elements visually inside the SVG code ribbon
        y_pos = 110
        x_pos = 45
        col = 0
        for idx, (op, val) in enumerate(raw_ops):
            attrs = {
                "id": f"inst-{idx}",
                "data-op": op,
                "data-val": str(val),
                "stroke-width": "1.5"
            }
            
            # Map opcodes to vector shapes and hex colors
            if op == "PUSH":
                attrs.update({"cx": str(x_pos + 12), "cy": str(y_pos + 12), "r": "10", "fill": "#238636", "stroke": "#2ea043"})
                ET.SubElement(code_group, "circle", attrs)
            elif op == "CARVE":
                attrs.update({"x": str(x_pos), "y": str(y_pos), "width": "24", "height": "24", "rx": "4", "fill": "#8957e5", "stroke": "#a371f7"})
                ET.SubElement(code_group, "rect", attrs)
            elif op == "POP":
                attrs.update({"x": str(x_pos), "y": str(y_pos), "width": "24", "height": "24", "rx": "12", "fill": "#da3633", "stroke": "#f85149"})
                ET.SubElement(code_group, "rect", attrs)
            elif op == "DUP":
                points = f"{x_pos+12},{y_pos} {x_pos+24},{y_pos+24} {x_pos},{y_pos+24}"
                attrs.update({"points": points, "fill": "#1f6beb", "stroke": "#388bfd"})
                ET.SubElement(code_group, "polygon", attrs)
            elif op == "ADD":
                attrs.update({"x": str(x_pos), "y": str(y_pos), "width": "24", "height": "24", "rx": "2", "fill": "#9e6a03", "stroke": "#d29922"})
                ET.SubElement(code_group, "rect", attrs)

            x_pos += 32
            col += 1
            if col >= 7:
                col = 0
                x_pos = 45
                y_pos += 32
                
        return svg

    def grid_to_svg(self, gx, gy):
        """Translates maze grid coordinates to SVG pixel coordinates."""
        return (self.maze_origin_x + gx * self.cell_size + self.cell_size // 2,
                self.maze_origin_y + gy * self.cell_size + self.cell_size // 2)

    def run(self):
        """Executes the SVG program by directly mutating DOM elements during runtime."""
        if self.code_group is None:
            return
            
        instructions = list(self.code_group)
        dirs = [(0, -1), (1, 0), (0, 1), (-1, 0)] # North, East, South, West
        
        while 0 <= self.ip < len(instructions):
            elem = instructions[self.ip]
            op = elem.attrib.get("data-op", "")
            val = int(elem.attrib.get("data-val", "0"))
            
            # Mutate active instruction DOM element to show execution state
            elem.set("stroke", "#ffffff")
            elem.set("stroke-width", "3")
            
            if op == "PUSH":
                self.data_stack.append(val)
                
            elif op == "DUP":
                if self.data_stack:
                    self.data_stack.append(self.data_stack[-1])
                    
            elif op == "ADD":
                if len(self.data_stack) >= 2:
                    b, a = self.data_stack.pop(), self.data_stack.pop()
                    self.data_stack.append(a + b)
                    
            elif op == "CARVE":
                d_idx = (self.data_stack.pop() if self.data_stack else 0) % 4
                curr_x, curr_y = self.call_stack[-1]
                dx, dy = dirs[d_idx]
                nx, ny = curr_x + dx, curr_y + dy
                
                # Keep within 25x25 grid boundary
                if 0 <= nx < 24 and 0 <= ny < 24:
                    x1, y1 = self.grid_to_svg(curr_x, curr_y)
                    x2, y2 = self.grid_to_svg(nx, ny)
                    
                    # Calculate dynamic color derived from runtime stack depth
                    depth = len(self.call_stack)
                    hue = (depth * 18) % 360
                    color = f"hsl({hue}, 85%, 60%)"
                    
                    # Mutate SVG DOM: Append new maze corridor path
                    ET.SubElement(self.maze_group, "line", {
                        "x1": str(x1), "y1": str(y1),
                        "x2": str(x2), "y2": str(y2),
                        "stroke": color,
                        "stroke-width": "5",
                        "opacity": "0.9"
                    })
                    
                    # Mutate SVG DOM: Append call stack frame node
                    ET.SubElement(self.maze_group, "circle", {
                        "cx": str(x2), "cy": str(y2),
                        "r": "4",
                        "fill": color,
                        "id": f"stack-node-{depth}"
                    })
                    
                    self.call_stack.append((nx, ny))
                    self.visited.add((nx, ny))
                    
            elif op == "POP":
                if len(self.call_stack) > 1:
                    px, py = self.call_stack.pop()
                    cx, cy = self.call_stack[-1]
                    x1, y1 = self.grid_to_svg(px, py)
                    x2, y2 = self.grid_to_svg(cx, cy)
                    
                    # Mutate SVG DOM: Append stack unwind / backtrack line
                    ET.SubElement(self.maze_group, "line", {
                        "x1": str(x1), "y1": str(y1),
                        "x2": str(x2), "y2": str(y2),
                        "stroke": "#ffffff",
                        "stroke-width": "1.5",
                        "stroke-dasharray": "2,4",
                        "opacity": "0.35"
                    })

            self.ip += 1
            
        # Final DOM Mutation: Highlight final stack head marker
        if self.call_stack:
            hx, hy = self.grid_to_svg(*self.call_stack[-1])
            ET.SubElement(self.maze_group, "circle", {
                "cx": str(hx), "cy": str(hy),
                "r": "8",
                "fill": "#f78166",
                "stroke": "#ffffff",
                "stroke-width": "2"
            })
            
            # Append execution summary into SVG text
            info_text = ET.SubElement(self.root, "text", {
                "x": "330", "y": "690", "fill": "#7ee787", "font-size": "12"
            })
            info_text.text = f"Execution Complete: {len(instructions)} instructions executed. Final stack depth: {len(self.call_stack)}."

    def save(self, filename="svg_esolang_maze.svg"):
        """Serializes the mutated SVG DOM to an external vector file."""
        tree = ET.ElementTree(self.root)
        ET.indent(tree, space="  ")
        tree.write(filename, encoding="utf-8", xml_declaration=True)
        print(f"Successfully executed SVG esolang program. Output saved to: {filename}")

if __name__ == "__main__":
    interpreter = SVGStackEsolang()
    interpreter.run()
    interpreter.save()