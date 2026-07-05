use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use egui::{Color32, Pos2, Stroke};
use eframe::{egui, epi};
use futures::FutureExt;
use reqwest::Client;
use serde::Deserialize;
use tokio::runtime::Runtime;

// ---------- Weather data structures ----------
#[derive(Deserialize, Debug, Default, Clone)]
struct WeatherMain {
    temp: f64,
    humidity: f64,
    pressure: f64,
}
#[derive(Deserialize, Debug, Default, Clone)]
struct WeatherWind {
    speed: f64,
    deg: f64,
}
#[derive(Deserialize, Debug, Default, Clone)]
struct WeatherAlert {
    event: String,
}
#[derive(Deserialize, Debug, Default, Clone)]
struct WeatherResponse {
    main: WeatherMain,
    wind: WeatherWind,
    alerts: Option<Vec<WeatherAlert>>,
}

// ---------- Simple L‑system ----------
#[derive(Clone)]
struct LSystem {
    axiom: String,
    rules: Vec<(char, String)>,
    angle: f32,
    step: f32,
    iterations: usize,
    // cached expanded string
    current: String,
}
impl LSystem {
    fn new(temp: f64, humidity: f64, wind_speed: f64) -> Self {
        // Map weather to parameters
        let angle = 25.0 + (humidity as f32 % 30.0);
        let step = 5.0 + (temp as f32 % 10.0);
        let iterations = 4 + ((wind_speed as usize) % 3);
        let axiom = "F".to_string();
        // simple deterministic rules influenced by temperature
        let mut rules = vec![];
        if temp > 20.0 {
            rules.push(('F', "F[+F]F[-F]F".to_string()));
        } else {
            rules.push(('F', "F[+F]F".to_string()));
        }
        let mut sys = Self {
            axiom,
            rules,
            angle,
            step,
            iterations,
            current: String::new(),
        };
        sys.expand();
        sys
    }
    fn expand(&mut self) {
        let mut cur = self.axiom.clone();
        for _ in 0..self.iterations {
            let mut next = String::new();
            for ch in cur.chars() {
                let mut replaced = false;
                for (src, dst) in &self.rules {
                    if *src == ch {
                        next.push_str(dst);
                        replaced = true;
                        break;
                    }
                }
                if !replaced {
                    next.push(ch);
                }
            }
            cur = next;
        }
        self.current = cur;
    }
}

// ---------- Application state ----------
struct WeatherApp {
    client: Client,
    rt: Runtime,
    last_update: Instant,
    weather: Arc<Mutex<WeatherResponse>>,
    lsystem: Arc<Mutex<LSystem>>,
    // audio cue toggles
    last_beep: Instant,
}
impl Default for WeatherApp {
    fn default() -> Self {
        let rt = Runtime::new().unwrap();
        let client = Client::new();
        let weather = Arc::new(Mutex::new(WeatherResponse::default()));
        let lsystem = Arc::new(Mutex::new(LSystem::new(0.0, 0.0, 0.0)));
        Self {
            client,
            rt,
            last_update: Instant::now() - Duration::from_secs(60),
            weather,
            lsystem,
            last_beep: Instant::now(),
        }
    }
}
impl epi::App for WeatherApp {
    fn name(&self) -> &str {
        "Weather L‑System SVG"
    }
    fn update(&mut self, ctx: &egui::Context, _: &mut epi::Frame) {
        // fetch weather every 30 seconds
        if self.last_update.elapsed() > Duration::from_secs(30) {
            let client = self.client.clone();
            let weather_arc = self.weather.clone();
            let lsys_arc = self.lsystem.clone();
            self.rt.spawn(async move {
                // free weather endpoint (wttr.in) returns json without API key
                let resp = client
                    .get("https://wttr.in/?format=j1")
                    .send()
                    .await
                    .ok()
                    .and_then(|r| r.json::<serde_json::Value>().await.ok());
                if let Some(json) = resp {
                    let main = json["current_condition"][0].clone();
                    let weather = WeatherResponse {
                        main: WeatherMain {
                            temp: main["temp_C"].as_str().unwrap_or("0").parse().unwrap_or(0.0),
                            humidity: main["humidity"]
                                .as_str()
                                .unwrap_or("0")
                                .parse()
                                .unwrap_or(0.0),
                            pressure: main["pressure"]
                                .as_str()
                                .unwrap_or("0")
                                .parse()
                                .unwrap_or(0.0),
                        },
                        wind: WeatherWind {
                            speed: main["windspeedKmph"]
                                .as_str()
                                .unwrap_or("0")
                                .parse()
                                .unwrap_or(0.0),
                            deg: main["winddirDegree"]
                                .as_str()
                                .unwrap_or("0")
                                .parse()
                                .unwrap_or(0.0),
                        },
                        alerts: None,
                    };
                    // update shared data
                    {
                        let mut w = weather_arc.lock().unwrap();
                        *w = weather.clone();
                    }
                    // rebuild L‑system
                    let mut ls = lsys_arc.lock().unwrap();
                    *ls = LSystem::new(
                        weather.main.temp,
                        weather.main.humidity,
                        weather.wind.speed,
                    );
                }
            });
            self.last_update = Instant::now();
        }

        // UI canvas
        egui::CentralPanel::default().show(ctx, |ui| {
            let (response, painter) =
                ui.allocate_painter(ui.available_size(), egui::Sense::drag());
            let rect = response.rect;
            let center = rect.center();

            // draw L‑system
            let ls = self.lsystem.lock().unwrap().clone();
            let mut stack: Vec<(Pos2, f32)> = Vec::new();
            let mut pos = center;
            let mut angle = -90.0_f32.to_radians(); // up
            for cmd in ls.current.chars() {
                match cmd {
                    'F' => {
                        let next = Pos2::new(
                            pos.x + ls.step * angle.cos(),
                            pos.y + ls.step * angle.sin(),
                        );
                        // stroke weight based on pressure
                        let pressure = self.weather.lock().unwrap().main.pressure as f32;
                        let weight = (pressure / 1013.0 * 4.0).max(0.5);
                        let stroke = Stroke::new(weight, Color32::from_rgb(
                            (pressure % 255.0) as u8,
                            ((255.0 - pressure) % 255.0) as u8,
                            150,
                        ));
                        painter.line_segment([pos, next], stroke);
                        pos = next;
                    }
                    '+' => {
                        angle += ls.angle.to_radians();
                    }
                    '-' => {
                        angle -= ls.angle.to_radians();
                    }
                    '[' => {
                        stack.push((pos, angle));
                    }
                    ']' => {
                        if let Some((p, a)) = stack.pop() {
                            pos = p;
                            angle = a;
                        }
                    }
                    _ => {}
                }
            }
        });

        // simple audio cue if pressure drops sharply (mocked)
        let now = Instant::now();
        if now.duration_since(self.last_beep) > Duration::from_secs(10) {
            // In a real app you'd play a sound; here we just print.
            println!("Beep! Pressure cue.");
            self.last_beep = now;
        }

        ctx.request_repaint(); // continuous animation
    }
}

// ---------- entry point ----------
fn main() {
    // enable async runtime for the app
    let native_options = eframe::NativeOptions::default();
    eframe::run_native(
        "Weather L‑System",
        native_options,
        Box::new(|_| Box::new(WeatherApp::default())),
    );
}