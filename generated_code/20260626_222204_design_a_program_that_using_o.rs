use std::error::Error;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use midir::{MidiInput, MidiInputConnection};
use rand::Rng;
use nalgebra::{Point3, Vector3};
use kiss3d::window::Window;
use kiss3d::scene::SceneNode;
use kiss3d::resource::Mesh;
use image::{RgbImage, Rgb};

/// Simple cellular automaton: each cell is a point in 3‑D space.
/// The state (alive/dead) evolves based on neighbours count.
fn ca_step(points: &mut Vec<Point3<f32>>, alive: &mut Vec<bool>) {
    let mut rng = rand::thread_rng();
    // Randomly toggle some points to simulate CA dynamics.
    for (i, p) in points.iter_mut().enumerate() {
        let neigh = alive.iter().filter(|&&a| a).count();
        let survive = (neigh % 5) == 0;
        alive[i] = if survive {
            rng.gen_bool(0.9)
        } else {
            rng.gen_bool(0.1)
        };
        // Slightly move alive points to create fractal drift.
        if alive[i] {
            p.x += rng.gen_range(-0.01..0.01);
            p.y += rng.gen_range(-0.01..0.01);
            p.z += rng.gen_range(-0.01..0.01);
        }
    }
}

/// Translate MIDI velocity and note into colour and density modifiers.
fn midi_to_params(note: u8, velocity: u8) -> (nalgebra::Vector3<f32>, f32) {
    // harmonic interval → hue, velocity → brightness, density → scale
    let hue = (note as f32 % 12.0) / 12.0;
    let brightness = velocity as f32 / 127.0;
    let color = Vector3::new(
        hue,
        brightness,
        1.0 - hue,
    );
    let density = 0.5 + (velocity as f32 / 127.0) * 2.0;
    (color, density)
}

/// Capture live MIDI input and push notes into a thread‑safe queue.
fn spawn_midi_listener() -> Arc<Mutex<Vec<(u8, u8)>>> {
    let notes = Arc::new(Mutex::new(Vec::new()));
    let notes_clone = Arc::clone(&notes);

    thread::spawn(move || {
        let midi_in = MidiInput::new("rust-midi").unwrap();
        let in_ports = midi_in.ports();
        if in_ports.is_empty() {
            eprintln!("No MIDI input ports found");
            return;
        }
        let port = &in_ports[0];
        let conn_in: MidiInputConnection<()> = midi_in
            .connect(
                port,
                "midir-read-input",
                move |_, message, _| {
                    // MIDI note on: 0x90, note, velocity
                    if message.len() >= 3 && (message[0] & 0xF0) == 0x90 && message[2] > 0 {
                        let note = message[1];
                        let velocity = message[2];
                        let mut q = notes_clone.lock().unwrap();
                        q.push((note, velocity));
                    }
                },
                (),
            )
            .unwrap();

        // Keep the connection alive.
        loop {
            thread::sleep(Duration::from_millis(100));
        }
        // conn_in is dropped on thread exit.
        let _ = conn_in;
    });

    notes
}

/// Render a frame to an image buffer.
fn render_frame(
    window: &mut Window,
    mesh: &mut SceneNode,
    points: &Vec<Point3<f32>>,
    colors: &Vec<Vector3<f32>>,
) -> RgbImage {
    // Update mesh vertices.
    let vertices: Vec<Point3<f32>> = points.clone();
    let indices: Vec<[u32; 3]> = (0..points.len() as u32)
        .step_by(3)
        .map(|i| [i, i + 1, i + 2])
        .collect();
    mesh.set_vertices(vertices);
    mesh.set_surface_from_triangles(&indices);

    // Simple colour pass – not physically accurate.
    // kiss3d uses material colour per object, so we average.
    let avg_color = colors.iter().fold(Vector3::zeros(), |a, b| a + b) / colors.len() as f32;
    mesh.set_color(avg_color.x, avg_color.y, avg_color.z);

    // Render to off‑screen buffer.
    let size = window.size();
    window.render();
    let mut img = RgbImage::new(size.0, size.1);
    for (x, y, pixel) in img.enumerate_pixels_mut() {
        let (r, g, b, _) = window.get_framebuffer()[((y * size.0 + x) as usize) * 4..][..4]
            .try_into()
            .unwrap();
        *pixel = Rgb([r, g, b]);
    }
    img
}

fn main() -> Result<(), Box<dyn Error>> {
    // initialise point cloud
    let mut points: Vec<Point3<f32>> = (0..5000)
        .map(|_| Point3::new(rand::random::<f32>(), rand::random::<f32>(), rand::random::<f32>()))
        .collect();
    let mut alive = vec![true; points.len()];
    let mut colors: Vec<Vector3<f32>> = vec![Vector3::new(1.0, 1.0, 1.0); points.len()];

    // spawn MIDI listener
    let midi_queue = spawn_midi_listener();

    // create 3‑D window
    let mut window = Window::new("Cellular Fractal + MIDI");
    window.set_framerate_limit(30);
    let mut mesh_node = window.add_mesh(Mesh::new(
        points.clone(),
        vec![[0u32, 1, 2]],
        None,
        None,
        false,
    ));

    // frame capture
    let mut frames: Vec<RgbImage> = Vec::new();
    let start = Instant::now();

    while window.render_with_scene(&mut |_, _| {}) && start.elapsed().as_secs() < 20 {
        // ingest pending MIDI events
        {
            let mut q = midi_queue.lock().unwrap();
            for (note, vel) in q.drain(..) {
                let (col, scale) = midi_to_params(note, vel);
                // apply colour and density influence
                for c in colors.iter_mut() {
                    *c = (*c + col) * 0.5;
                }
                // bias CA density by scaling point positions outward/inward
                for p in points.iter_mut() {
                    *p *= scale;
                }
            }
        }

        // advance cellular automaton
        ca_step(&mut points, &mut alive);

        // update mesh colours per point (approximate)
        render_frame(&mut window, &mut mesh_node, &points, &colors);

        // capture frame for video
        let img = render_frame(&mut window, &mut mesh_node, &points, &colors);
        frames.push(img);
    }

    // write frames to a temporary folder
    std::fs::create_dir_all("frames")?;
    for (i, img) in frames.iter().enumerate() {
        img.save(format!("frames/frame_{:05}.png", i))?;
    }

    // invoke ffmpeg to turn PNG sequence into 4K video (3840x2160)
    // Requires ffmpeg installed on the system.
    let ffmpeg_status = std::process::Command::new("ffmpeg")
        .args(&[
            "-y",
            "-framerate",
            "30",
            "-i",
            "frames/frame_%05d.png",
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-vf",
            "scale=3840:2160",
            "output.mp4",
        ])
        .status()?;

    if !ffmpeg_status.success() {
        eprintln!("ffmpeg failed");
    }

    Ok(())
}