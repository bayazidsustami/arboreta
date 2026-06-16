use bevy::prelude::*;
use bevy::render::camera::ScalingMode;
use bevy_kira_audio::{Audio, AudioChannel, AudioPlugin, AudioSource};

// ---- Constants --------------------------------------------------------------

const POEM: &str = "\
Two roads diverged in a yellow wood,\n\
And sorry I could not travel both\n\
—\n\
To infinity, where symbols sing.\n";

const CAMERA_RADIUS: f32 = 5.0;
const CAMERA_HEIGHT: f32 = 2.5;

// ---- Resources --------------------------------------------------------------

#[derive(Resource)]
struct SynthConfig {
    // tempo in beats per minute, derived from line count
    bpm: f32,
    // current line index for camera shaping
    line_idx: usize,
    // total lines
    line_cnt: usize,
}

// simple struct for per‑character particle emitters
#[derive(Component)]
struct CharEmitter {
    // timer controls birth rate
    timer: Timer,
    // color of emitted particles
    color: Color,
    // audio to play when a particle is spawned
    sound: Handle<AudioSource>,
}

// ---- Helper functions -------------------------------------------------------

fn unicode_block(c: char) -> &'static str {
    // Very small mapping, enough for a demo
    let cp = c as u32;
    match cp {
        0x0000..=0x007F => "Basic Latin",
        0x0400..=0x04FF => "Cyrillic",
        0x4E00..=0x9FFF => "CJK Unified Ideographs",
        _ => "Other",
    }
}

// map a block name to a particle color
fn block_to_color(block: &str) -> Color {
    match block {
        "Basic Latin" => Color::srgb(0.9, 0.2, 0.2),
        "Cyrillic" => Color::srgb(0.2, 0.9, 0.2),
        "CJK Unified Ideographs" => Color::srgb(0.2, 0.2, 0.9),
        _ => Color::srgb(0.8, 0.8, 0.2),
    }
}

// map a block name to a short beep sound (embedded wav)
fn block_to_sound(block: &str, audio: &Res<AssetServer>) -> Handle<AudioSource> {
    match block {
        "Basic Latin" => audio.load("beep1.wav"),
        "Cyrillic" => audio.load("beep2.wav"),
        "CJK Unified Ideographs" => audio.load("beep3.wav"),
        _ => audio.load("beep4.wav"),
    }
}

// ---- Bevy setup --------------------------------------------------------------

fn main() {
    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                title: "Poem Synthesizer".into(),
                ..default()
            }),
            ..default()
        }))
        .add_plugin(AudioPlugin)
        .insert_resource(SynthConfig {
            bpm: 60.0,
            line_idx: 0,
            line_cnt: POEM.matches('\n').count() + 1,
        })
        .add_startup_system(setup_camera)
        .add_startup_system(setup_emitters)
        .add_system(spawn_particles)
        .add_system(orbit_camera)
        .add_system(drum_pattern)
        .run();
}

// camera looks at origin and orbits around it
fn setup_camera(mut commands: Commands) {
    commands.spawn(Camera3dBundle {
        transform: Transform::from_xyz(CAMERA_RADIUS, CAMERA_HEIGHT, CAMERA_RADIUS)
            .looking_at(Vec3::ZERO, Vec3::Y),
        projection: PerspectiveProjection {
            fov: std::f32::consts::FRAC_PI_4,
            near: 0.1,
            far: 100.0,
            ..default()
        }
        .into(),
        ..default()
    });
}

// create an emitter for every character in the poem
fn setup_emitters(mut commands: Commands, audio: Res<AssetServer>) {
    for (i, ch) in POEM.chars().enumerate() {
        // skip line breaks – they drive camera/tempo elsewhere
        if ch == '\n' {
            continue;
        }
        let block = unicode_block(ch);
        let color = block_to_color(block);
        let sound = block_to_sound(block, &audio);
        // birth rate: faster for higher code points
        let rate = ((ch as u32) % 30 + 5) as f32;
        commands.spawn((
            CharEmitter {
                timer: Timer::from_seconds(1.0 / rate, TimerMode::Repeating),
                color,
                sound,
            },
            Transform::from_translation(Vec3::new(
                (i as f32 % 10.0) - 5.0,
                ((i as f32) / 10.0).sin(),
                0.0,
            )),
            GlobalTransform::default(),
        ));
    }
}

// particle is a simple sphere that fades out
fn spawn_particles(
    mut commands: Commands,
    time: Res<Time>,
    audio: Res<Audio>,
    mut query: Query<(Entity, &mut CharEmitter, &Transform)>,
) {
    for (ent, mut emitter, trans) in query.iter_mut() {
        emitter.timer.tick(time.delta());
        if emitter.timer.finished() {
            // play sound on this channel
            audio.play(emitter.sound.clone());

            // spawn a tiny sphere that lives briefly
            commands.spawn((
                PbrBundle {
                    mesh: bevy::prelude::shape::Icosphere { radius: 0.05, subdivisions: 2 }
                        .into(),
                    material: ColorMaterial::from(emitter.color).into(),
                    transform: Transform::from_translation(trans.translation),
                    ..default()
                },
                Lifetime {
                    timer: Timer::from_seconds(0.8, TimerMode::Once),
                },
            ));
        }
    }
}

// simple component to remove entities after a time
#[derive(Component)]
struct Lifetime {
    timer: Timer,
}

// cleanup dead particles
fn cleanup_particles(mut commands: Commands, time: Res<Time>, query: Query<(Entity, &mut Lifetime)>) {
    for (ent, mut lt) in query.iter_mut() {
        lt.timer.tick(time.delta());
        if lt.timer.finished() {
            commands.entity(ent).despawn_recursive();
        }
    }
}

// camera orbits; speed varies with current line index
fn orbit_camera(
    time: Res<Time>,
    mut cfg: ResMut<SynthConfig>,
    mut query: Query<&mut Transform, With<Camera>>,
) {
    let mut cam_transform = query.single_mut();
    // each line adds a slight speed delta
    let speed = 0.3 + cfg.line_idx as f32 * 0.05;
    let angle = time.elapsed_seconds() * speed;
    cam_transform.translation = Vec3::new(
        CAMERA_RADIUS * angle.cos(),
        CAMERA_HEIGHT,
        CAMERA_RADIUS * angle.sin(),
    );
    cam_transform.look_at(Vec3::ZERO, Vec3::Y);
}

// very simple drum pattern driven by BPM
fn drum_pattern(
    time: Res<Time>,
    audio: Res<Audio>,
    cfg: Res<SynthConfig>,
    mut drum_timer: Local<Timer>,
) {
    // initialise local timer on first call
    if drum_timer.duration().as_secs_f32() == 0.0 {
        *drum_timer = Timer::from_seconds(60.0 / cfg.bpm, TimerMode::Repeating);
    }
    drum_timer.tick(time.delta());
    if drum_timer.finished() {
        // play a generic kick sample (embedded)
        audio.play(audio.load("kick.wav"));
    }
}

// -----------------------------------------------------------------------------
// Embedded placeholder wav files (very short silence + beep). In a real program
// replace them with actual audio assets placed in the assets folder.
use bevy::asset::HandleId;
use bevy::asset::AssetPath;
use bevy::asset::LoadState;
use bevy::utils::HashMap;

fn _dummy_assets() {
    // This function exists only to silence unused‑code warnings.
    // The actual wav files (beep1.wav … kick.wav) should reside in the
    // `assets/` directory next to the executable.
}