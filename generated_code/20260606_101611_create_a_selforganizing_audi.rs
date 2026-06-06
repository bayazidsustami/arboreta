use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use egui::{Color32, Pos2, Vec2};
use egui_wgpu::wgpu;
use wgpu::util::DeviceExt;

// ---------- Stub neural network for aesthetic fitness ----------
fn aesthetic_fitness(_image: &[u8]) -> f32 {
    // In a real implementation this would run a trained NN.
    rand::random::<f32>()
}

// ---------- Genetic algorithm to mutate shader source ----------
fn mutate_shader(source: &str) -> String {
    // Very naive mutation: randomly flip a character.
    let mut chars: Vec<char> = source.chars().collect();
    if !chars.is_empty() {
        let idx = rand::random::<usize>() % chars.len();
        chars[idx] = if rand::random() { '0' } else { '1' };
    }
    chars.iter().collect()
}

// ---------- Simple L‑system generation ----------
fn generate_lsystem(iterations: usize, angle: f32) -> Vec<(f32, f32, f32)> {
    // Returns a list of 3D points (the “tips”).
    let mut points = vec![(0.0, 0.0, 0.0)];
    let mut dir = (0.0, 1.0, 0.0);
    for i in 0..iterations {
        let mut new_points = Vec::new();
        for &(x, y, z) in &points {
            let rad = angle * i as f32;
            let (sx, sy) = (rad.sin(), rad.cos());
            let nx = x + dir.0 * sx;
            let ny = y + dir.1 * sy;
            let nz = z + dir.2 * rad;
            new_points.push((nx, ny, nz));
        }
        points.extend(new_points);
    }
    points
}

// ---------- Audio capture ----------
fn start_audio_thread(bands: Arc<Mutex<Vec<f32>>>) {
    std::thread::spawn(move || {
        let host = cpal::default_host();
        let device = host
            .default_input_device()
            .expect("no input device available");
        let config = device.default_input_config().unwrap();
        let sample_rate = config.sample_rate().0 as f32;
        let bands_clone = bands.clone();

        let err_fn = |err| eprintln!("audio error: {}", err);
        let stream = match config.sample_format() {
            cpal::SampleFormat::F32 => device.build_input_stream(
                &config.into(),
                move |data: &[f32], _: &_| process_audio(data, sample_rate, &bands_clone),
                err_fn,
                None,
            ),
            cpal::SampleFormat::I16 => device.build_input_stream(
                &config.into(),
                move |data: &[i16], _: &_| {
                    let data_f: Vec<f32> = data.iter().map(|s| *s as f32 / i16::MAX as f32).collect();
                    process_audio(&data_f, sample_rate, &bands_clone)
                },
                err_fn,
                None,
            ),
            cpal::SampleFormat::U16 => device.build_input_stream(
                &config.into(),
                move |data: &[u16], _: &_| {
                    let data_f: Vec<f32> = data.iter().map(|s| *s as f32 / u16::MAX as f32).collect();
                    process_audio(&data_f, sample_rate, &bands_clone)
                },
                err_fn,
                None,
            ),
        }
        .expect("failed to build stream");
        stream.play().expect("failed to start stream");
        // keep thread alive
        loop {
            std::thread::sleep(Duration::from_millis(100));
        }
    });
}

fn process_audio(data: &[f32], sample_rate: f32, bands: &Arc<Mutex<Vec<f32>>>) {
    // Very crude band extraction: compute RMS for low / mid / high.
    let low = data.iter().take(data.len() / 3).map(|v| v * v).sum::<f32>();
    let mid = data.iter().skip(data.len() / 3).take(data.len() / 3).map(|v| v * v).sum::<f32>();
    let high = data.iter().skip(2 * data.len() / 3).map(|v| v * v).sum::<f32>();
    let mut guard = bands.lock().unwrap();
    guard.clear();
    guard.push(low.sqrt());
    guard.push(mid.sqrt());
    guard.push(high.sqrt());
}

// ---------- Rendering ----------
#[tokio::main]
async fn main() {
    // Init window & GPU
    let event_loop = winit::event_loop::EventLoop::new();
    let window = winit::window::WindowBuilder::new()
        .with_title("Audio‑reactive L‑system sculpture")
        .build(&event_loop)
        .unwrap();

    let size = window.inner_size();
    let instance = wgpu::Instance::new(wgpu::Backends::all());
    let surface = unsafe { instance.create_surface(&window) };
    let adapter = instance
        .request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::HighPerformance,
            compatible_surface: Some(&surface),
            force_fallback_adapter: false,
        })
        .await
        .unwrap();
    let (device, queue) = adapter
        .request_device(
            &wgpu::DeviceDescriptor {
                label: None,
                features: wgpu::Features::empty(),
                limits: wgpu::Limits::default(),
            },
            None,
        )
        .await
        .unwrap();

    let surface_format = surface.get_capabilities(&adapter).formats[0];
    let config = wgpu::SurfaceConfiguration {
        usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
        format: surface_format,
        width: size.width,
        height: size.height,
        present_mode: wgpu::PresentMode::Fifo,
        alpha_mode: wgpu::CompositeAlphaMode::Auto,
        view_formats: vec![],
    };
    surface.configure(&device, &config);

    // Initial simple fragment shader (color based on position)
    let mut shader_src = r#"
        @fragment
        fn fs(@location(0) in_pos: vec4<f32>) -> @location(0) vec4<f32> {
            let c = 0.5 + 0.5 * sin(in_pos.xyz * 10.0);
            return vec4<f32>(c, 1.0);
        }
    "#.to_string();

    // Compile initial shader module
    let mut shader_module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: Some("dynamic"),
        source: wgpu::ShaderSource::Wgsl(shader_src.clone().into()),
    });

    // Simple pipeline
    let pipeline_layout = device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
        label: Some("pipeline_layout"),
        bind_group_layouts: &[],
        push_constant_ranges: &[],
    });
    let render_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
        label: Some("render_pipeline"),
        layout: Some(&pipeline_layout),
        vertex: wgpu::VertexState {
            module: &shader_module,
            entry_point: "vs_main", // we'll provide a trivial vert shader later
            buffers: &[],
        },
        fragment: Some(wgpu::FragmentState {
            module: &shader_module,
            entry_point: "fs",
            targets: &[Some(wgpu::ColorTargetState {
                format: surface_format,
                blend: Some(wgpu::BlendState::ALPHA_BLENDING),
                write_mask: wgpu::ColorWrites::ALL,
            })],
        }),
        primitive: wgpu::PrimitiveState::default(),
        depth_stencil: None,
        multisample: wgpu::MultisampleState::default(),
        multiview: None,
    });

    // Dummy vertex shader (full‑screen triangle)
    let vs_src = r#"
        @vertex
        fn vs_main(@builtin(vertex_index) idx: u32) -> @builtin(position) vec4<f32> {
            var pos = array<vec2<f32>, 3>(vec2<f32>(-1.0, -3.0), vec2<f32>(3.0, 1.0), vec2<f32>(-1.0, 1.0));
            let p = pos[idx];
            return vec4<f32>(p, 0.0, 1.0);
        }
    "#;
    let vs_module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: Some("vs"),
        source: wgpu::ShaderSource::Wgsl(vs_src.into()),
    });

    // Re‑create pipeline with proper vertex shader
    let render_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
        label: Some("pipeline"),
        layout: Some(&pipeline_layout),
        vertex: wgpu::VertexState {
            module: &vs_module,
            entry_point: "vs_main",
            buffers: &[],
        },
        fragment: Some(wgpu::FragmentState {
            module: &shader_module,
            entry_point: "fs",
            targets: &[Some(wgpu::ColorTargetState {
                format: surface_format,
                blend: Some(wgpu::BlendState::ALPHA_BLENDING),
                write_mask: wgpu::ColorWrites::ALL,
            })],
        }),
        primitive: wgpu::PrimitiveState::default(),
        depth_stencil: None,
        multisample: wgpu::MultisampleState::default(),
        multiview: None,
    });

    // Audio data container
    let audio_bands = Arc::new(Mutex::new(vec![0.0_f32; 3]));
    start_audio_thread(audio_bands.clone());

    // Main loop
    let mut last_update = Instant::now();
    event_loop.run(move |event, _, control_flow| {
        *control_flow = winit::event_loop::ControlFlow::Poll;
        match event {
            winit::event::Event::RedrawRequested(_) => {
                // Update L‑system based on audio
                let bands = audio_bands.lock().unwrap().clone();
                let iter = (bands[0] * 10.0) as usize + 1;
                let angle = bands[1] * std::f32::consts::PI;
                let points = generate_lsystem(iter.min(10), angle);

                // Here we would upload points to a GPU buffer and draw them.
                // For brevity we just clear the screen.

                let frame = match surface.get_current_texture() {
                    Ok(f) => f,
                    Err(_) => {
                        surface.configure(&device, &config);
                        surface.get_current_texture().unwrap()
                    }
                };
                let view = frame
                    .texture
                    .create_view(&wgpu::TextureViewDescriptor::default());

                let mut encoder =
                    device.create_command_encoder(&wgpu::CommandEncoderDescriptor { label: None });
                {
                    let _rpass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                        label: None,
                        color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                            view: &view,
                            resolve_target: None,
                            ops: wgpu::Operations {
                                load: wgpu::LoadOp::Clear(wgpu::Color::BLACK),
                                store: true,
                            },
                        })],
                        depth_stencil_attachment: None,
                    });
                }
                queue.submit(Some(encoder.finish()));
                frame.present();

                // Genetic mutation of shader every half second
                if last_update.elapsed() > Duration::from_millis(500) {
                    let mutated = mutate_shader(&shader_src);
                    // compile new fragment shader
                    shader_module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
                        label: Some("dynamic_mutated"),
                        source: wgpu::ShaderSource::Wgsl(mutated.clone().into()),
                    });
                    // re‑create pipeline with new fragment module
                    let new_pipeline = device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
                        label: Some("pipeline_mutated"),
                        layout: Some(&pipeline_layout),
                        vertex: wgpu::VertexState {
                            module: &vs_module,
                            entry_point: "vs_main",
                            buffers: &[],
                        },
                        fragment: Some(wgpu::FragmentState {
                            module: &shader_module,
                            entry_point: "fs",
                            targets: &[Some(wgpu::ColorTargetState {
                                format: surface_format,
                                blend: Some(wgpu::BlendState::ALPHA_BLENDING),
                                write_mask: wgpu::ColorWrites::ALL,
                            })],
                        }),
                        primitive: wgpu::PrimitiveState::default(),
                        depth_stencil: None,
                        multisample: wgpu::MultisampleState::default(),
                        multiview: None,
                    });
                    // replace pipeline (in reality you would store it; here we ignore)
                    let _ = new_pipeline;
                    shader_src = mutated;
                    // Evaluate aesthetic fitness (placeholder)
                    let _fit = aesthetic_fitness(&[]);
                    // reset timer
                    last_update = Instant::now();
                }
            }
            winit::event::Event::MainEventsCleared => {
                window.request_redraw();
            }
            winit::event::Event::WindowEvent { event, .. } => match event {
                winit::event::WindowEvent::CloseRequested => *control_flow = winit::event_loop::ControlFlow::Exit,
                _ => {}
            },
            _ => {}
        }
    });
}