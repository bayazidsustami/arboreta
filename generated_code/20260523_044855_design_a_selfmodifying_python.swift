import Foundation

// MARK: - Paths
let tempDir = FileManager.default.temporaryDirectory
let pyPath = tempDir.appendingPathComponent("self_modifying.py")
let svgPath = tempDir.appendingPathComponent("mandala.svg")

// MARK: - Python script template with a DNA placeholder
let pythonTemplate = """
#!/usr/bin/env python3
import cv2, sys, numpy as np, base64, re, os

# ---------- DNA PLACEHOLDER ----------
DNA = "{{DNA}}"
# -------------------------------------

def dominant_palette(frame, k=4):
    pixels = frame.reshape(-1, 3).astype(np.float32)
    _, labels, centers = cv2.kmeans(pixels, k, None,
                                   (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 10, 1.0),
                                   10, cv2.KMEANS_RANDOM_CENTERS)
    return centers.astype(int)

def rle_encode(arr):
    flat = arr.flatten()
    res = []
    i = 0
    while i < len(flat):
        run = 1
        while i + run < len(flat) and flat[i] == flat[i+run] and run < 255:
            run += 1
        res.append(run)
        res.append(flat[i])
        i += run
    return bytes(res)

def dna_from_palette(palette):
    return base64.b64encode(rle_encode(palette)).decode()

def svg_from_dna(dna):
    data = base64.b64decode(dna)
    points = []
    angle = 0.0
    step = 2*np.pi/len(data)
    for i, b in enumerate(data):
        r = 50 + b
        x = 200 + r*np.cos(angle)
        y = 200 + r*np.sin(angle)
        points.append(f"{x:.2f},{y:.2f}")
        angle += step
    path = "M " + " L ".join(points) + " Z"
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="400" height="400">
<path d="{path}" fill="none" stroke="black"/>
</svg>'''

def update_source(new_dna):
    src = pathlib.Path(__file__).read_text()
    new_src = re.sub(r'DNA = ".*"', f'DNA = "{new_dna}"', src)
    pathlib.Path(__file__).write_text(new_src)

def main():
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        sys.exit(1)
    ret, frame = cap.read()
    cap.release()
    if not ret:
        sys.exit(1)
    palette = dominant_palette(frame)
    new_dna = dna_from_palette(palette)
    # Write new SVG
    with open("\(svgPath.path)", "w") as f:
        f.write(svg_from_dna(new_dna))
    # Self‑modify source
    update_source(new_dna)

if __name__ == "__main__":
    main()
"""

// MARK: - Write initial Python script (with empty DNA)
let initialPython = pythonTemplate.replacingOccurrences(of: "{{DNA}}", with: "")
try? initialPython.write(to: pyPath, atomically: true, encoding: .utf8)
try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: pyPath.path)

// MARK: - Execute the Python script
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["python3", pyPath.path]

let pipe = Pipe()
process.standardOutput = pipe
process.standardError = pipe

do {
    try process.run()
    process.waitUntilExit()
} catch {
    print("Failed to run Python script: \\(error)")
    exit(1)
}

// MARK: - Output results
print("SVG generated at: \\(svgPath.path)")
print("Self‑modified Python source at: \\(pyPath.path)")