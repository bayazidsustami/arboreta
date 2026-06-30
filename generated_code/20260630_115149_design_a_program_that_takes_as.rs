use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

// External crates (add to Cargo.toml):
// cpal = "0.15"          // audio input
// rustfft = "6.0"       // FFT
// image = "0.24"        // simple image buffer
// opencv = { version = "0.71", features = ["contrib"] } // webcam + gestures
// nalgebra = "0.32"     // 3D math
// glium = "0.32"        // OpenGL rendering
// pest = "2.7"          // simple Lisp parser for self‑modifying macro

// ---- Audio capture and spectrum analysis ----
fn audio_thread(spectrum: Arc<Mutex<Vec<f32>>>) {
    let host = cpal::default_host();
    let device = host
        .default_input_device()
        .expect("No input audio device");
    let config = device.default_input_config().unwrap();

    let err_fn = |err| eprintln!("Audio error: {}", err);
    let stream = match config.sample_format() {
        cpal::SampleFormat::F32 => device.build_input_stream(
            &config.into(),
            move |data: &[f32], _: &_| process_audio(data, &spectrum),
            err_fn,
            None,
        ),
        cpal::SampleFormat::I16 => device.build_input_stream(
            &config.into(),
            move |data: &[i16], _: &_| {
                let data_f32: Vec<f32> = data.iter().map(|x| *x as f32 / i16::MAX as f32).collect();
                process_audio(&data_f32, &spectrum)
            },
            err_fn,
            None,
        ),
        cpal::SampleFormat::U16 => device.build_input_stream(
            &config.into(),
            move |data: &[u16], _: &_| {
                let data_f32: Vec<f32> = data.iter().map(|x| *x as f32 / u16::MAX as f32 - 1.0).collect();
                process_audio(&data_f32, &spectrum)
            },
            err_fn,
            None,
        ),
    }
    .unwrap();

    stream.play().unwrap();
    loop {
        thread::sleep(Duration::from_millis(100));
    }
}

fn process_audio(input: &[f32], spectrum: &Arc<Mutex<Vec<f32>>>) {
    // Simple fixed‑size FFT (next power of two)
    const N: usize = 1024;
    let mut buf = vec![rustfft::num_complex::Complex::new(0.0, 0.0); N];
    for (i, &sample) in input.iter().take(N).enumerate() {
        buf[i].re = sample;
    }

    let mut planner = rustfft::FftPlanner::new();
    let fft = planner.plan_fft_forward(N);
    fft.process(&mut buf);

    // magnitude per frequency bin
    let mags: Vec<f32> = buf.iter().map(|c| c.norm()).collect();

    // store smoothed version
    let mut spec = spectrum.lock().unwrap();
    *spec = mags;
}

// ---- Webcam gesture detection (very simple motion detection) ----
fn webcam_thread(gesture: Arc<Mutex<Option<nalgebra::Vector3<f32>>>>) {
    let mut cam = opencv::videoio::VideoCapture::new(0, opencv::videoio::CAP_ANY).unwrap();
    cam.set(opencv::videoio::CAP_PROP_FRAME_WIDTH, 320.0).unwrap();
    cam.set(opencv::videoio::CAP_PROP_FRAME_HEIGHT, 240.0).unwrap();

    let mut prev = opencv::core::Mat::default();
    loop {
        let mut frame = opencv::core::Mat::default();
        if !cam.read(&mut frame).unwrap() {
            continue;
        }

        // Convert to grayscale & blur
        let mut gray = opencv::core::Mat::default();
        opencv::imgproc::cvt_color(
            &frame,
            &mut gray,
            opencv::imgproc::COLOR_BGR2GRAY,
            0,
        )
        .unwrap();
        opencv::imgproc::gaussian_blur(
            &gray,
            &mut gray,
            opencv::core::Size::new(9, 9),
            0.0,
            0.0,
            opencv::core::BorderTypes::BORDER_DEFAULT as i32,
        )
        .unwrap();

        // Simple frame differencing
        let mut diff = opencv::core::Mat::default();
        if !prev.empty().unwrap() {
            opencv::core::absdiff(&gray, &prev, &mut diff).unwrap();
            let mut thresh = opencv::core::Mat::default();
            opencv::imgproc::threshold(
                &diff,
                &mut thresh,
                30.0,
                255.0,
                opencv::imgproc::THRESH_BINARY,
            )
            .unwrap();

            // Find centroid of motion
            let mut moments = opencv::imgproc::moments(&thresh, false).unwrap();
            if moments.m00 > 0.0 {
                let cx = (moments.m10 / moments.m00) as f32;
                let cy = (moments.m01 / moments.m00) as f32;
                // Map screen coords to [-1,1] range for 3D interaction
                let nx = (cx / 320.0) * 2.0 - 1.0;
                let ny = (cy / 240.0) * 2.0 - 1.0;
                let mut g = gesture.lock().unwrap();
                *g = Some(nalgebra::Vector3::new(nx, ny, 0.0));
            }
        }
        prev = gray;
        thread::sleep(Duration::from_millis(30));
    }
}

// ---- Simple Lisp macro engine that rewrites its own source ----
mod lisp {
    use super::*;
    use pest::Parser;
    #[derive(pest_derive::Parser)]
    #[grammar = "lisp.pest"] // tiny grammar (see below)
    struct LispParser;

    // Very tiny AST
    #[derive(Debug, Clone)]
    pub enum Expr {
        Symbol(String),
        List(Vec<Expr>),
        Number(f64),
    }

    // Parse a string into Expr
    pub fn parse(src: &str) -> Result<Expr, pest::error::Error<Rule>> {
        let pairs = LispParser::parse(Rule::program, src)?;
        let mut iter = pairs.into_iter();
        Ok(build_expr(iter.next().unwrap()))
    }

    fn build_expr(pair: pest::iterators::Pair<Rule>) -> Expr {
        match pair.as_rule() {
            Rule::number => Expr::Number(pair.as_str().parse().unwrap()),
            Rule::symbol => Expr::Symbol(pair.as_str().to_string()),
            Rule::list => {
                let inner = pair.into_inner().map(build_expr).collect();
                Expr::List(inner)
            }
            _ => unreachable!(),
        }
    }

    // Macro that mutates a source file based on tempo (simplified)
    pub fn rewrite_self(tempo: f32) {
        use std::fs;
        let path = std::env::current_exe().unwrap();
        let src = fs::read_to_string(&path).unwrap_or_default();
        // Find placeholder comment and inject new color mapping
        let new_line = format!("// AUTOGEN tempo_factor = {:.3}", tempo);
        let new_src = if let Some(idx) = src.find("// AUTOGEN") {
            let (head, _) = src.split_at(idx);
            format!("{}{}\n", head, new_line)
        } else {
            src
        };
        // Overwrite the running binary (works only in debug builds)
        let _ = fs::write(&path, new_src);
    }
}

// ---- Rendering ----
fn render_loop(
    spectrum: Arc<Mutex<Vec<f32>>>,
    gesture: Arc<Mutex<Option<nalgebra::Vector3<f32>>>>,
) {
    use glium::{glutin, Surface};

    // window
    let event_loop = glutin::event_loop::EventLoop::new();
    let wb = glutin::window::WindowBuilder::new()
        .with_title("Audio‑mandala")
        .with_inner_size(glutin::dpi::LogicalSize::new(800.0, 600.0));
    let cb = glutin::ContextBuilder::new().with_depth_buffer(24);
    let display = glium::Display::new(wb, cb, &event_loop).unwrap();

    // simple shader (color depends on frequency magnitude)
    let vertex_shader_src = r#"
        #version 140
        in vec3 position;
        in vec3 color;
        uniform mat4 model;
        uniform mat4 view;
        uniform mat4 proj;
        out vec3 vColor;
        void main() {
            vColor = color;
            gl_Position = proj * view * model * vec4(position, 1.0);
        }
    "#;

    let fragment_shader_src = r#"
        #version 140
        in vec3 vColor;
        out vec4 f_color;
        void main() {
            f_color = vec4(vColor, 1.0);
        }
    "#;

    let program =
        glium::Program::from_source(&display, vertex_shader_src, fragment_shader_src, None).unwrap();

    // generate geometry from spectrum
    fn build_vertices(spec: &[f32]) -> (Vec<(glium::vertex::VertexBufferAny)>, Vec<u32>) {
        // map each bin to a radial arm with a primitive (cube)
        // we will just create a flat circle of points for brevity
        let mut verts = Vec::new();
        let mut idx = 0u32;
        let mut indices = Vec::new();
        let n = spec.len();
        for (i, &mag) in spec.iter().enumerate() {
            let angle = i as f32 / n as f32 * std::f32::consts::TAU;
            let radius = 0.2 + mag * 5.0;
            let x = radius * angle.cos();
            let y = radius * angle.sin();
            let z = 0.0;
            // color gradient from blue (low) to red (high)
            let c = [
                mag.min(1.0),
                0.2,
                1.0 - mag.min(1.0),
            ];
            verts.push((x, y, z, c[0], c[1], c[2]));
            if i > 0 {
                indices.push(idx - 1);
                indices.push(idx);
            }
            idx += 1;
        }
        // convert to glium buffers
        #[derive(Copy, Clone)]
        struct Vertex {
            position: [f32; 3],
            color: [f32; 3],
        }
        implement_vertex!(Vertex, position, color);
        let vertex_data: Vec<Vertex> = verts
            .into_iter()
            .map(|(x, y, z, r, g, b)| Vertex {
                position: [x, y, z],
                color: [r, g, b],
            })
            .collect();
        let vb = glium::VertexBuffer::new(&display, &vertex_data).unwrap().into_vertex_buffer_any();
        (vec![vb], indices)
    }

    let mut last_spec = vec![0.0f32; 512];
    let mut rotation = 0.0f32;

    event_loop.run(move |ev, _, control_flow| {
        // update rotation based on gesture
        if let Some(g) = *gesture.lock().unwrap() {
            rotation += g.x * 0.05;
        }

        // fetch latest spectrum
        let spec = {
            let s = spectrum.lock().unwrap();
            s.clone()
        };
        if spec != last_spec {
            last_spec = spec.clone();
        }

        // build geometry
        let (vbs, idx) = build_vertices(&last_spec);
        let vertex_buffer = &vbs[0];
        let index_buffer = glium::IndexBuffer::new(
            &display,
            glium::index::PrimitiveType::LineStrip,
            &idx,
        )
        .unwrap();

        // clear & draw
        let mut target = display.draw();
        target.clear_color_and_depth((0.0, 0.0, 0.0, 1.0), 1.0);
        let model = nalgebra::Matrix4::new_rotation(nalgebra::Vector3::new(0.0, 0.0, rotation));
        let view = nalgebra::Matrix4::look_at_rh(
            &nalgebra::Point3::new(0.0, 0.0, 2.0),
            &nalgebra::Point3::origin(),
            &nalgebra::Vector3::y_axis(),
        );
        let proj = nalgebra::Perspective3::new(4.0 / 3.0, std::f32::consts::FRAC_PI_3, 0.1, 100.0).to_homogeneous();

        let uniforms = uniform! {
            model: *model.as_ref(),
            view: *view.as_ref(),
            proj: *proj.as_ref(),
        };

        target
            .draw(
                vertex_buffer,
                &index_buffer,
                &program,
                &uniforms,
                &Default::default(),
            )
            .unwrap();
        target.finish().unwrap();

        // simple event handling
        match ev {
            glutin::event::Event::WindowEvent { event, .. } => match event {
                glutin::event::WindowEvent::CloseRequested => *control_flow = glutin::event_loop::ControlFlow::Exit,
                _ => (),
            },
            glutin::event::Event::MainEventsCleared => {
                // ask for redraw
                display.gl_window().window().request_redraw();
            }
            _ => (),
        }

        // tempo estimation (peak detection) and self‑modification
        // extremely naive: average magnitude as tempo proxy
        let tempo = last_spec.iter().copied().sum::<f32>() / last_spec.len() as f32 * 120.0;
        lisp::rewrite_self(tempo);
    });
}

// ---- Main entry point ----
fn main() {
    // shared state
    let spectrum = Arc::new(Mutex::new(vec![0.0f32; 512]));
    let gesture = Arc::new(Mutex::new(None));

    // spawn audio and webcam threads
    {
        let sp = spectrum.clone();
        thread::spawn(move || audio_thread(sp));
    }
    {
        let gt = gesture.clone();
        thread::spawn(move || webcam_thread(gt));
    }

    // start rendering loop (blocks)
    render_loop(spectrum, gesture);
}