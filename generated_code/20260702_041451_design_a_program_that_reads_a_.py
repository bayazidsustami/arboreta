import threading, time, math, random, json, os, sys
from datetime import datetime
try:
    import requests
    import numpy as np
    import trimesh
    from trimesh.creation import tube
    from trimesh.visual import ColorVisuals
    from pygltflib import GLTF2, Buffer, BufferView, Accessor, Mesh, Primitive, Node, Scene, Asset
except ImportError:
    print("Required packages: requests numpy trimesh pygltflib")
    sys.exit(1)

# --------------------------------------------------------------
# Configuration
# --------------------------------------------------------------
API_URL = "https://api.citytransport.example.com/live"   # placeholder
UPDATE_INTERVAL = 2.0   # seconds between API polls
EXPORT_GLB = "sculpture.glb"
EXPORT_STL = "sculpture.stl"
TORUS_R_MAJOR = 50.0    # big radius
TORUS_R_MINOR = 10.0    # tube radius (base)
TEMP_SCALE = 0.05       # how much temperature affects radius

# --------------------------------------------------------------
# Helper functions
# --------------------------------------------------------------
def hue_to_rgb(h):
    """Convert hue (0-1) to RGB tuple (0-255)."""
    i = int(h * 6)
    f = h * 6 - i
    p, q, t = 0, int(255 * (1 - f)), int(255 * f)
    i %= 6
    if i == 0:   return (255, t, 0)
    if i == 1:   return (q, 255, 0)
    if i == 2:   return (0, 255, t)
    if i == 3:   return (0, q, 255)
    if i == 4:   return (t, 0, 255)
    return (255, 0, q)

def get_ambient_temperature():
    """Simple stub: return a pseudo‑real temperature based on day of year."""
    day = datetime.utcnow().timetuple().tm_yday
    # sinusoidal variation between 5°C and 25°C
    return 15 + 10 * math.sin(2 * math.pi * day / 365)

def fetch_live_data():
    """Retrieve live vehicle data; fallback to simulated data."""
    try:
        resp = requests.get(API_URL, timeout=5)
        resp.raise_for_status()
        return resp.json()
    except Exception:
        # Simulated payload: list of vehicles with id, lat, lon, speed, passengers, delay
        data = []
        for vid in range(10):
            data.append({
                "id": f"veh{vid}",
                "lat": random.uniform(-0.01, 0.01),
                "lon": random.uniform(-0.01, 0.01),
                "speed": random.uniform(0, 80),          # km/h
                "passengers": random.randint(0, 100),
                "delay": random.uniform(-5, 30)          # minutes
            })
        return {"vehicles": data}

def torus_path(theta, phi):
    """Parametric equation of a torus."""
    x = (TORUS_R_MAJOR + TORUS_R_MINOR * math.cos(phi)) * math.cos(theta)
    y = (TORUS_R_MAJOR + TORUS_R_MINOR * math.cos(phi)) * math.sin(theta)
    z = TORUS_R_MINOR * math.sin(phi)
    return np.array([x, y, z])

def generate_filament(vehicle, ambient_temp):
    """Create a tube mesh representing one vehicle."""
    # Map vehicle location to torus angles (simple projection)
    theta = (vehicle["lon"] + 0.01) / 0.02 * 2 * math.pi
    phi   = (vehicle["lat"] + 0.01) / 0.02 * 2 * math.pi

    # Build a short curve along the torus surface
    points = []
    length = 5.0  # base filament length
    for t in np.linspace(0, 2*math.pi, 30):
        # oscillation based on delay
        offset = 0.2 * math.sin(vehicle["delay"] * 0.1 + t*3)
        pt = torus_path(theta + offset, phi + t * 0.2)
        points.append(pt)
    points = np.array(points)

    # Thickness encodes passenger count (scaled)
    radius = 0.2 + 0.003 * vehicle["passengers"]
    # Temperature morphs radius globally
    radius *= (1 + (ambient_temp - 15) * TEMP_SCALE)

    # Create tube
    mesh = tube(points, radius=radius, sections=12)

    # Color hue encodes speed (0-80 km/h → 0-0.7 hue)
    hue = min(max(vehicle["speed"] / 80.0 * 0.7, 0.0), 0.7)
    rgb = hue_to_rgb(hue)
    mesh.visual = ColorVisuals(mesh, vertex_colors=np.tile(rgb + (255,), (len(mesh.vertices), 1)))
    return mesh

def assemble_scene(vehicles):
    """Create a combined mesh from all vehicle filaments."""
    ambient_temp = get_ambient_temperature()
    parts = [generate_filament(v, ambient_temp) for v in vehicles]
    combined = trimesh.util.concatenate(parts)
    return combined

def export_gltf(mesh, filename):
    """Export mesh as GLB (binary glTF) using trimesh."""
    mesh.export(file_type='glb', file_obj=filename)

def export_stl(mesh, filename):
    """Export mesh as STL."""
    mesh.export(file_type='stl', file_obj=filename)

# --------------------------------------------------------------
# Main loop (runs in background)
# --------------------------------------------------------------
def live_loop():
    while True:
        data = fetch_live_data()
        vehicles = data.get("vehicles", [])
        scene_mesh = assemble_scene(vehicles)
        export_gltf(scene_mesh, EXPORT_GLB)
        export_stl(scene_mesh, EXPORT_STL)
        print(f"[{datetime.utcnow().isoformat()}] Updated exports ({len(vehicles)} vehicles)")
        time.sleep(UPDATE_INTERVAL)

if __name__ == "__main__":
    thread = threading.Thread(target=live_loop, daemon=True)
    thread.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nStopping.")