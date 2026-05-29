use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use opencv::{
    core::{self, Mat, Scalar, Vec3b},
    imgproc,
    prelude::*,
    videoio,
};
use palette::{FromColor, Hsv, Srgb};
use rand::Rng;
use rodio::{source::SineWave, OutputStream, Sink, Source};
use winit::{
    event::{Event, WindowEvent},
    event_loop::{ControlFlow, EventLoop},
    window::WindowBuilder,
};
use pixels::{Pixels, SurfaceTexture};

/// Number of colors to extract per frame
const PALETTE_SIZE: usize = 5;
/// Number of nodes in the lattice
const NODE_COUNT: usize = 128;
/// Size of the window
const WIDTH: u32 = 640;
const HEIGHT: u32 = 480;

/// Simple mapping from hue (0‑360) to a musical chord (root note in Hz)
fn hue_to_freq(hue: f32) -> f32 {
    // map hue to a scale degree (C major) and use equal temperament
    let degree = ((hue / 360.0) * 7.0).floor() as i32;
    let base_c = 261.63; // middle C
    let semitone = [0, 2, 4, 5, 7, 9, 11][degree as usize % 7];
    base_c * 2_f32.powf(semitone as f32 / 12.0)
}

/// Generate a sine wave source for a chord (root + major third + perfect fifth)
fn chord_source(root_hz: f32) -> impl Source<Item = f32> + Send {
    let third = root_hz * 2_f32.powf(4.0 / 12.0);
    let fifth = root_hz * 2_f32.powf(7.0 / 12.0);
    let s_root = SineWave::new(root_hz);
    let s_third = SineWave::new(third);
    let s_fifth = SineWave::new(fifth);
    // mix and fade out slowly
    s_root
        .amplify(0.3)
        .mix(s_third.amplify(0.2))
        .mix(s_fifth.amplify(0.2))
        .repeat_infinite()
        .take_duration(Duration::from_millis(400))
}

/// Extract dominant colors using k‑means (very coarse but fast)
fn dominant_palette(frame: &Mat) -> Vec<Srgb<u8>> {
    let mut samples = core::Mat::default();
    // reshape to Nx3 float matrix
    let reshaped = frame
        .reshape(1, frame.total() as i32)
        .unwrap()
        .convert_to(&mut samples, core::CV_32F, 1.0, 0.0)
        .unwrap();

    let criteria = core::TermCriteria::new(core::TermCriteria_Type::MAX_ITER + core::TermCriteria_Type::EPS, 10, 1.0).unwrap();
    let mut labels = core::Mat::default();
    let mut centers = core::Mat::default();
    core::kmeans(
        &samples,
        PALETTE_SIZE as i32,
        &mut labels,
        criteria,
        3,
        core::KMEANS_PP_CENTERS,
        &mut centers,
    )
    .unwrap();

    // convert centers back to u8 colors
    let mut palette = Vec::with_capacity(PALETTE_SIZE);
    for i in 0..PALETTE_SIZE {
        let b = centers.at_2d::<f32>(i as i32, 0).unwrap().round() as u8;
        let g = centers.at_2d::<f32>(i as i32, 1).unwrap().round() as u8;
        let r = centers.at_2d::<f32>(i as i32, 2).unwrap().round() as u8;
        palette.push(Srgb::new(r, g, b));
    }
    palette
}

/// Lattice node representation
#[derive(Clone)]
struct Node {
    pos: [f32; 2],
    vel: [f32; 2],
    hue: f32,
}

fn main() -> opencv::Result<()> {
    // ---- audio setup ---------------------------------------------------------
    let (_stream, stream_handle) = OutputStream::try_default().unwrap();
    let sink = Arc::new(Mutex::new(Sink::try_new(&stream_handle).unwrap()));

    // ---- video capture -------------------------------------------------------
    let mut cam = videoio::VideoCapture::new(0, videoio::CAP_ANY)?; // default camera
    cam.set(videoio::CAP_PROP_FRAME_WIDTH, WIDTH as f64)?;
    cam.set(videoio::CAP_PROP_FRAME_HEIGHT, HEIGHT as f64)?;
    if !cam.is_opened()? {
        panic!("Unable to open default camera");
    }

    // ---- window / pixel buffer ------------------------------------------------
    let event_loop = EventLoop::new();
    let window = WindowBuilder::new()
        .with_title("Synesthetic Lattice")
        .with_inner_size(winit::dpi::LogicalSize::new(WIDTH, HEIGHT))
        .build(&event_loop)
        .unwrap();
    let surface_texture = SurfaceTexture::new(WIDTH, HEIGHT, &window);
    let mut pixels = Pixels::new(WIDTH, HEIGHT, surface_texture).unwrap();

    // ---- initialise lattice ---------------------------------------------------
    let mut rng = rand::thread_rng();
    let mut nodes: Vec<Node> = (0..NODE_COUNT)
        .map(|_| Node {
            pos: [
                rng.gen_range(0.0..WIDTH as f32),
                rng.gen_range(0.0..HEIGHT as f32),
            ],
            vel: [0.0, 0.0],
            hue: rng.gen_range(0.0..360.0),
        })
        .collect();

    // ---- main loop ------------------------------------------------------------
    event_loop.run(move |event, _, control_flow| {
        *control_flow = ControlFlow::Poll;
        match event {
            Event::RedrawRequested(_) => {
                // capture frame
                let mut frame = Mat::default();
                if cam.read(&mut frame).unwrap() && !frame.empty().unwrap() {
                    // convert to RGB
                    imgproc::cvt_color(&frame, &mut frame, imgproc::COLOR_BGR2RGB, 0).unwrap();

                    // extract palette
                    let palette = dominant_palette(&frame);
                    // pick first colour as driver
                    let driver = palette[0];
                    // convert to HSV to obtain hue
                    let hsv: Hsv = Hsv::from_color(Srgb::new(
                        driver.red as f32 / 255.0,
                        driver.green as f32 / 255.0,
                        driver.blue as f32 / 255.0,
                    ));

                    // map hue to chord and play
                    let freq = hue_to_freq(hsv.hue.to_degrees());
                    let chord = chord_source(freq);
                    {
                        let mut s = sink.lock().unwrap();
                        s.append(chord);
                    }

                    // update lattice geometry based on hue
                    for node in nodes.iter_mut() {
                        // simple attraction towards centre modulated by hue
                        let dx = (WIDTH as f32 / 2.0) - node.pos[0];
                        let dy = (HEIGHT as f32 / 2.0) - node.pos[1];
                        let dist = (dx * dx + dy * dy).sqrt() + 1.0;
                        let force = (hsv.hue.to_degrees() / 360.0) * 0.5;
                        node.vel[0] += force * dx / dist;
                        node.vel[1] += force * dy / dist;

                        // damping
                        node.vel[0] *= 0.95;
                        node.vel[1] *= 0.95;

                        node.pos[0] = (node.pos[0] + node.vel[0]).rem_euclid(WIDTH as f32);
                        node.pos[1] = (node.pos[1] + node.vel[1]).rem_euclid(HEIGHT as f32);

                        // hue fades towards driver hue
                        let dh = hsv.hue.to_degrees() - node.hue;
                        node.hue += dh * 0.02;
                    }

                    // render lattice onto pixel buffer
                    let frame_buf = pixels.get_frame();
                    // clear
                    for pixel in frame_buf.chunks_exact_mut(4) {
                        pixel[0] = 0;
                        pixel[1] = 0;
                        pixel[2] = 0;
                        pixel[3] = 0xff;
                    }
                    // draw nodes
                    for node in &nodes {
                        let x = node.pos[0] as i32;
                        let y = node.pos[1] as i32;
                        let color = Srgb::from_hsv(Hsv::new(node.hue, 1.0, 1.0));
                        let r = (color.red * 255.0) as u8;
                        let g = (color.green * 255.0) as u8;
                        let b = (color.blue * 255.0) as u8;
                        // simple point rasterisation
                        if x >= 0 && x < WIDTH as i32 && y >= 0 && y < HEIGHT as i32 {
                            let idx = ((y as u32) * WIDTH + (x as u32)) as usize * 4;
                            frame_buf[idx] = r;
                            frame_buf[idx + 1] = g;
                            frame_buf[idx + 2] = b;
                            frame_buf[idx + 3] = 0xff;
                        }
                    }
                }

                // present
                if pixels.render().is_err() {
                    *control_flow = ControlFlow::Exit;
                }
            }
            Event::MainEventsCleared => {
                window.request_redraw();
            }
            Event::WindowEvent { event, .. } => match event {
                WindowEvent::CloseRequested => *control_flow = ControlFlow::Exit,
                _ => {}
            },
            _ => {}
        }
    });
}