// Dependencies required in Cargo.toml:
// [dependencies]
// tokio = { version = "1.0", features = ["full"] }
// warp = "0.3"
// reqwest = { version = "0.11", features = ["json"] }
// serde = { version = "1.0", features = ["derive"] }
// serde_json = "1.0"
// rand = "0.8"

use rand::seq::SliceRandom;
use serde::{Deserialize, Serialize};
use std::sync::{Arc, Mutex};
use warp::Filter;

// Global list of candidate cities with coordinates for pressure sampling
const CITIES: &[(&str, f64, f64)] = &[
    ("Tokyo", 35.6762, 139.6503),
    ("London", 51.5074, -0.1278),
    ("New York", 40.7128, -74.0060),
    ("Cairo", 30.0444, 31.2357),
    ("Sydney", -33.8688, 151.2093),
    ("Reykjavik", 64.1466, -21.9426),
    ("La Paz", -16.5000, -68.1500),
    ("Nairobi", -1.2921, 36.8219),
];

#[derive(Serialize, Deserialize, Clone, Debug)]
struct CityData {
    name: String,
    pressure_hpa: f32,
}

#[derive(Serialize, Deserialize, Debug)]
struct OpenMeteoResponse {
    current: CurrentWeather,
}

#[derive(Serialize, Deserialize, Debug)]
struct CurrentWeather {
    surface_pressure: Option<f32>,
}

#[derive(Clone, Default)]
struct AppState {
    cities: Arc<Mutex<Vec<CityData>>>,
}

// Generates poetic verses describing the execution logic and state of the tree based on atmospheric pressure
fn generate_rhyming_poetry(cities: &[CityData], depth: usize, angle: f32, scale: f32) -> Vec<String> {
    let p_avg = if cities.is_empty() {
        1013.25
    } else {
        cities.iter().map(|c| c.pressure_hpa).sum::<f32>() / cities.len() as f32
    };

    let city_names = if cities.len() == 3 {
        format!("{}, {}, and {}", cities[0].name, cities[1].name, cities[2].name)
    } else {
        "the distant lands".to_string()
    };

    vec![
        format!("I. THE ATMOSPHERIC ENGINE"),
        format!("From {}, the barometers call,", city_names),
        format!("A mean force of {:.1} hPa governs the fractal's tall.", p_avg),
        format!("High pressure tightens branches; low pressure makes them sprawl."),
        String::new(),
        format!("II. RECURSIVE RECURSION LOGIC"),
        format!("fn grow_tree(depth: {}, angle: {:.2} rads) {{", depth, angle),
        format!("    if depth == 0 {{ return; }} // The roots stay bound,"),
        format!("    let scaled_len = length * {:.3}; // Air weight upon the ground.", scale),
        format!("    draw_line(); // A wooden vein reaches outward without sound."),
        format!("    grow_tree(depth - 1, angle + pressure_delta);"),
        format!("    grow_tree(depth - 1, angle - pressure_delta);"),
        format!("}}"),
        String::new(),
        format!("III. EXECUTION METRICS"),
        format!("Calculated branch count: {} leaves in blooming flight,", 2_usize.pow(depth as u32) - 1),
        format!("Driven by heavy skies, transforming pressure into light."),
    ]
}

// Fetch live pressure data using Open-Meteo free API (no API key required)
async fn fetch_city_pressure(client: &reqwest::Client, name: &str, lat: f64, lon: f64) -> CityData {
    let url = format!(
        "[https://api.open-meteo.com/v1/forecast?latitude=](https://api.open-meteo.com/v1/forecast?latitude=){}&longitude={}&current=surface_pressure",
        lat, lon
    );
    let mut pressure = 1013.25; // Default standard atmosphere fallback
    
    if let Ok(res) = client.get(&url).send().await {
        if let Ok(parsed) = res.json::<OpenMeteoResponse>().await {
            if let Some(p) = parsed.current.surface_pressure {
                pressure = p;
            }
        }
    }

    CityData {
        name: name.to_string(),
        pressure_hpa: pressure,
    }
}

async fn update_pressures_periodically(state: AppState) {
    let client = reqwest::Client::new();
    let mut rng = rand::thread_rng();

    loop {
        // Randomly choose 3 distinct cities
        let mut chosen = CITIES.to_vec();
        chosen.shuffle(&mut rng);
        let selected = &chosen[..3];

        let mut fresh_data = Vec::new();
        for (name, lat, lon) in selected {
            fresh_data.push(fetch_city_pressure(&client, name, *lat, *lon).await);
        }

        if let Ok(mut lock) = state.cities.lock() {
            *lock = fresh_data;
        }

        // Refresh every 30 seconds
        tokio::time::sleep(tokio::time::Duration::from_secs(30)).await;
    }
}

#[tokio::main]
async fn main() {
    let state = AppState::default();

    // Spawn background task to periodically fetch atmospheric pressure
    let bg_state = state.clone();
    tokio::spawn(async move {
        update_pressures_periodically(bg_state).await;
    });

    let state_filter = warp::any().map(move || state.clone());

    // Serve API endpoint for interactive frontend
    let api_route = warp::path("api")
        .and(warp::path("data"))
        .and(state_filter)
        .map(|state: AppState| {
            let cities = state.cities.lock().unwrap().clone();
            
            // Map pressure parameters dynamically into tree dimensions
            let avg_p = if cities.is_empty() { 1013.25 } else { cities.iter().map(|c| c.pressure_hpa).sum::<f32>() / cities.len() as f32 };
            let depth = ((avg_p - 950.0) / 10.0).clamp(4.0, 10.0) as usize;
            let angle = ((avg_p % 30.0) / 30.0) * (std::f32::consts::PI / 3.0) + 0.2;
            let scale = 0.65 + ((avg_p % 10.0) / 100.0);

            let poetry = generate_rhyming_poetry(&cities, depth, angle, scale);

            warp::reply::json(&serde_json::json!({
                "cities": cities,
                "tree": {
                    "depth": depth,
                    "angle": angle,
                    "scale": scale
                },
                "poetry": poetry
            }))
        });

    // Embed the interactive HTML, WebGL Canvas, and live procedural rendering engine
    let html_route = warp::path::end().map(|| {
        warp::reply::html(r#"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Atmospheric Fractal Tree & Procedural Poetry</title>
    <style>
        body { margin: 0; background: #0b0d13; color: #d0d7de; font-family: 'Courier New', monospace; overflow: hidden; display: flex; }
        #canvas-container { width: 60vw; height: 100vh; position: relative; }
        canvas { width: 100%; height: 100%; display: block; }
        #sidebar { width: 40vw; height: 100vh; background: #12151e; box-sizing: border-box; padding: 20px; overflow-y: auto; border-left: 1px solid #2d3342; }
        h1 { font-size: 1.2rem; color: #58a6ff; margin-top: 0; }
        .city-card { background: #1c212e; padding: 10px; border-radius: 6px; margin-bottom: 10px; font-size: 0.9rem; }
        .pressure-val { color: #7ee787; font-weight: bold; }
        .poem-line { margin: 4px 0; font-size: 0.85rem; line-height: 1.4; color: #e6edf3; }
        .poem-header { color: #ffa657; font-weight: bold; margin-top: 15px; }
        .code-block { background: #0d1117; padding: 8px; border-radius: 4px; color: #79c0ff; }
    </style>
</head>
<body>
    <div id="canvas-container">
        <canvas id="treeCanvas"></canvas>
    </div>
    <div id="sidebar">
        <h1>Atmospheric Fractal Generator</h1>
        <div id="cities">Fetching live pressure data...</div>
        <hr style="border-color: #2d3342; margin: 15px 0;">
        <div id="poetry"></div>
    </div>

    <script>
        const canvas = document.getElementById('treeCanvas');
        const ctx = canvas.getContext('2d');
        let currentData = null;

        function resize() {
            canvas.width = canvas.clientWidth;
            canvas.height = canvas.clientHeight;
        }
        window.addEventListener('resize', resize);
        resize();

        async function fetchData() {
            try {
                const res = await fetch('/api/data');
                currentData = await res.json();
                renderSidebar();
            } catch(e) { console.error(e); }
        }

        function renderSidebar() {
            if (!currentData) return;
            const citiesDiv = document.getElementById('cities');
            citiesDiv.innerHTML = currentData.cities.map(c => 
                `<div class="city-card">📍 <b>${c.name}</b>: <span class="pressure-val">${c.pressure_hpa.toFixed(1)} hPa</span></div>`
            ).join('');

            const poetryDiv = document.getElementById('poetry');
            poetryDiv.innerHTML = currentData.poetry.map(line => {
                if (line.startsWith('I.') || line.startsWith('II.') || line.startsWith('III.')) {
                    return `<div class="poem-header">${line}</div>`;
                } else if (line.includes('fn ') || line.includes('let ') || line.includes('return')) {
                    return `<div class="poem-line code-block">${line}</div>`;
                }
                return `<div class="poem-line">${line}</div>`;
            }).join('');
        }

        function drawBranch(x, y, len, angle, depth, maxDepth, branchAngle, scale) {
            if (depth === 0) return;

            const x2 = x + len * Math.sin(angle);
            const y2 = y - len * Math.cos(angle);

            ctx.beginPath();
            ctx.moveTo(x, y);
            ctx.lineTo(x2, y2);
            ctx.lineWidth = Math.max(1, depth * 1.5);
            ctx.strokeStyle = `hsl(${180 + (maxDepth - depth) * 15}, 70%, ${50 + (depth / maxDepth) * 20}%)`;
            ctx.stroke();

            drawBranch(x2, y2, len * scale, angle + branchAngle, depth - 1, maxDepth, branchAngle, scale);
            drawBranch(x2, y2, len * scale, angle - branchAngle, depth - 1, maxDepth, branchAngle, scale);
        }

        let time = 0;
        function animate() {
            ctx.clearRect(0, 0, canvas.width, canvas.height);
            if (currentData) {
                const tree = currentData.tree;
                // Add a gentle atmospheric breeze animation based on time
                const dynamicAngle = tree.angle + Math.sin(time) * 0.03;
                const startX = canvas.width / 2;
                const startY = canvas.height - 50;
                const initialLength = canvas.height * 0.22;

                drawBranch(startX, startY, initialLength, 0, tree.depth, tree.depth, dynamicAngle, tree.scale);
            }
            time += 0.02;
            requestAnimationFrame(animate);
        }

        setInterval(fetchData, 5000);
        fetchData();
        animate();
    </script>
</body>
</html>
        "#)
    });

    let routes = html_route.or(api_route);

    println!("Server running on [http://127.0.0.1:3030](http://127.0.0.1:3030)");
    warp::serve(routes).run(([127, 0, 0, 1], 3030)).await;
}