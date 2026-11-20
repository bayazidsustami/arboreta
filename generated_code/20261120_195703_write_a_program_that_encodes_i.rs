use std::alloc::{GlobalAlloc, Layout, System};
use std::cell::Cell;
use std::fs::File;
use std::io::{self, Write};
use std::sync::Mutex;
use std::time::Instant;

// Track whether we are inside trace recording so MIDI/log allocations do not recurse.
thread_local! {
    static IN_TRACE: Cell<bool> = const { Cell::new(false) };
    static STACK_DEPTH: Cell<usize> = const { Cell::new(0) };
}

struct TraceEvent {
    elapsed_ms: u64,
    depth: usize,
    size: usize,
    kind: EventKind,
}

#[derive(Clone, Copy)]
enum EventKind {
    Alloc,
    Realloc,
    CallEnter,
    CallExit,
}

static TRACE_LOG: Mutex<Option<Vec<TraceEvent>>> = Mutex::new(None);
static START_TIME: Mutex<Option<Instant>> = Mutex::new(None);

// Custom global allocator that plucks a dissonant string on every heap allocation.
struct SymphonyAllocator;

fn record_event(size: usize, kind: EventKind) {
    IN_TRACE.with(|in_trace| {
        if in_trace.get() {
            return;
        }
        in_trace.set(true);

        let depth = STACK_DEPTH.with(|d| d.get());
        let elapsed_ms = {
            let mut start_guard = START_TIME.lock().unwrap_or_else(|e| e.into_inner());
            let start = *start_guard.get_or_insert_with(Instant::now);
            start.elapsed().as_millis() as u64
        };

        if let Ok(mut guard) = TRACE_LOG.lock() {
            if let Some(vec) = guard.as_mut() {
                vec.push(TraceEvent {
                    elapsed_ms,
                    depth,
                    size,
                    kind,
                });
            }
        }

        in_trace.set(false);
    });
}

unsafe impl GlobalAlloc for SymphonyAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let ptr = unsafe { System.alloc(layout) };
        if !ptr.is_null() {
            record_event(layout.size(), EventKind::Alloc);
        }
        ptr
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        unsafe { System.dealloc(ptr, layout) };
    }

    unsafe fn realloc(&self, ptr: *mut u8, layout: Layout, new_size: usize) -> *mut u8 {
        let new_ptr = unsafe { System.realloc(ptr, layout, new_size) };
        if !new_ptr.is_null() {
            record_event(new_size, EventKind::Realloc);
        }
        new_ptr
    }
}

#[global_allocator]
static GLOBAL: SymphonyAllocator = SymphonyAllocator;

// RAII guard that increments call stack depth on entry and decrements on drop.
struct FrameGuard;

impl FrameGuard {
    fn enter() -> Self {
        let next_depth = STACK_DEPTH.with(|d| {
            let v = d.get() + 1;
            d.set(v);
            v
        });
        record_event(next_depth, EventKind::CallEnter);
        FrameGuard
    }
}

impl Drop for FrameGuard {
    fn drop(&mut self) {
        let prev_depth = STACK_DEPTH.with(|d| {
            let v = d.get().saturating_sub(1);
            d.set(v);
            v
        });
        record_event(prev_depth, EventKind::CallExit);
    }
}

macro_rules! trace_fn {
    ($body:block) => {{
        let _guard = FrameGuard::enter();
        $body
    }};
}

// MIDI helpers for building a valid Standard MIDI File (SMF Format 0) from scratch.
fn write_varlen(out: &mut Vec<u8>, mut value: u32) {
    let mut buf = [(value & 0x7F) as u8];
    value >>= 7;
    while value > 0 {
        buf.push(((value & 0x7F) as u8) | 0x80);
        value >>= 7;
    }
    for &b in buf.iter().rev() {
        out.push(b);
    }
}

fn push_midi_event(track: &mut Vec<u8>, delta_ticks: u32, status: u8, data1: u8, data2: u8) {
    write_varlen(track, delta_ticks);
    track.push(status);
    track.push(data1 & 0x7F);
    track.push(data2 & 0x7F);
}

fn push_program_change(track: &mut Vec<u8>, delta_ticks: u32, channel: u8, program: u8) {
    write_varlen(track, delta_ticks);
    track.push(0xC0 | (channel & 0x0F));
    track.push(program & 0x7F);
}

fn push_key_signature(track: &mut Vec<u8>, delta_ticks: u32, sharps_or_flats: i8, minor: bool) {
    // Meta event FF 59 02 sf mi
    write_varlen(track, delta_ticks);
    track.extend_from_slice(&[0xFF, 0x59, 0x02, sharps_or_flats as u8, u8::from(minor)]);
}

// Circle-of-fifths tonal shifts indexed by call stack depth.
fn key_center_for_depth(depth: usize) -> (u8, i8, bool) {
    // (root MIDI note around middle C, sharps(+)/flats(-), minor mode)
    const KEYS: [(u8, i8, bool); 12] = [
        (60, 0, false),  // Depth 0/12: C major
        (67, 1, false),  // Depth 1/13: G major
        (62, 2, false),  // Depth 2/14: D major
        (69, 3, false),  // Depth 3/15: A major
        (64, 4, false),  // Depth 4/16: E major
        (71, 5, false),  // Depth 5/17: B major
        (66, 6, false),  // Depth 6/18: F# major (tritone shift)
        (63, -3, true),  // Depth 7/19: C minor
        (65, -1, false), // Depth 8/20: F major
        (58, -2, false), // Depth 9/21: Bb major
        (68, -4, false), // Depth 10/22: Ab major
        (61, -5, false), // Depth 11/23: Db major
    ];
    KEYS[depth % KEYS.len()]
}

fn scale_note(root: u8, degree: usize, minor: bool) -> u8 {
    let major_steps = [0, 2, 4, 5, 7, 9, 11, 12];
    let minor_steps = [0, 2, 3, 5, 7, 8, 10, 12];
    let steps = if minor { &minor_steps } else { &major_steps };
    let octave = (degree / 7) as u8 * 12;
    let step = steps[degree % 7];
    (root + octave + step).min(127)
}

// Dissonant intervals (minor 2nd = +1, tritone = +6, major 7th = +11) for plucked heap strings.
fn dissonant_string_note(root: u8, size: usize, depth: usize) -> u8 {
    const DISSONANCES: [u8; 4] = [1, 6, 11, 13];
    let interval = DISSONANCES[(size + depth) % DISSONANCES.len()];
    let register_shift = ((depth % 3) as u8) * 12;
    (root.saturating_sub(12) + register_shift + interval).min(127)
}

struct ScheduledNote {
    tick: u32,
    duration_ticks: u32,
    channel: u8,
    note: u8,
    velocity: u8,
    key_meta: Option<(i8, bool)>,
}

fn render_midi_symphony(events: &[TraceEvent], path: &str) -> io::Result<()> {
    // 480 ticks per quarter note, 120 BPM => 500,000 us per quarter note => ~0.96 ticks per ms.
    const TICKS_PER_QUARTER: u16 = 480;
    let ms_to_ticks = |ms: u64| -> u32 { ((ms as f64) * 0.96).round() as u32 };

    let mut notes: Vec<ScheduledNote> = Vec::new();
    let mut current_depth: usize = 0;
    let mut last_key_sig: Option<(i8, bool)> = None;

    for (idx, ev) in events.iter().enumerate() {
        let tick = ms_to_ticks(ev.elapsed_ms) + (idx as u32) * 12;
        match ev.kind {
            EventKind::CallEnter | EventKind::CallExit => {
                current_depth = ev.depth;
                let (root, sf, minor) = key_center_for_depth(current_depth);
                let key_meta = if last_key_sig != Some((sf, minor)) {
                    last_key_sig = Some((sf, minor));
                    Some((sf, minor))
                } else {
                    None
                };

                // Polyphonic chord / harmonic voice on Channel 0 (Warm Pad / Electric Piano)
                let chord_degree = (current_depth * 2) % 7;
                let base_note = scale_note(root, chord_degree, minor);
                let fifth_note = scale_note(root, chord_degree + 4, minor);
                let vel = (58 + (current_depth as u8 * 5)).min(105);

                notes.push(ScheduledNote {
                    tick,
                    duration_ticks: 360,
                    channel: 0,
                    note: base_note,
                    velocity: vel,
                    key_meta,
                });
                notes.push(ScheduledNote {
                    tick: tick + 30,
                    duration_ticks: 330,
                    channel: 0,
                    note: fifth_note,
                    velocity: vel.saturating_sub(12),
                    key_meta: None,
                });
            }
            EventKind::Alloc | EventKind::Realloc => {
                let (root, _, _) = key_center_for_depth(current_depth);
                // Plucked string voice on Channel 1 (Pizzicato Strings = prog 45 / Acoustic Steel = prog 25)
                let pluck_note = dissonant_string_note(root, ev.size, current_depth);
                let vel = (75 + ((ev.size % 48) as u8)).min(127);
                let dur = if matches!(ev.kind, EventKind::Realloc) {
                    180
                } else {
                    120
                };

                notes.push(ScheduledNote {
                    tick,
                    duration_ticks: dur,
                    channel: 1,
                    note: pluck_note,
                    velocity: vel,
                    key_meta: None,
                });
            }
        }
    }

    // Expand notes into Note On / Note Off pairs sorted by tick.
    #[derive(Clone, Copy)]
    enum RawMsg {
        KeySig(i8, bool),
        NoteOn { ch: u8, note: u8, vel: u8 },
        NoteOff { ch: u8, note: u8 },
    }

    let mut timed: Vec<(u32, u8, RawMsg)> = Vec::with_capacity(notes.len() * 2 + 4);
    for n in &notes {
        if let Some((sf, minor)) = n.key_meta {
            timed.push((n.tick, 0, RawMsg::KeySig(sf, minor)));
        }
        timed.push((
            n.tick,
            1,
            RawMsg::NoteOn {
                ch: n.channel,
                note: n.note,
                vel: n.velocity,
            },
        ));
        timed.push((
            n.tick + n.duration_ticks,
            2,
            RawMsg::NoteOff {
                ch: n.channel,
                note: n.note,
            },
        ));
    }

    timed.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));

    let mut track: Vec<u8> = Vec::new();
    // Set tempo: 120 BPM (500,000 us/quarter)
    write_varlen(&mut track, 0);
    track.extend_from_slice(&[0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20]);

    // Channel 0: Electric Piano 1 (program 4); Channel 1: Pizzicato Strings (program 45)
    push_program_change(&mut track, 0, 0, 4);
    push_program_change(&mut track, 0, 1, 45);
    push_key_signature(&mut track, 0, 0, false);

    let mut prev_tick = 0u32;
    for (tick, _, msg) in timed {
        let delta = tick.saturating_sub(prev_tick);
        prev_tick = tick;
        match msg {
            RawMsg::KeySig(sf, minor) => push_key_signature(&mut track, delta, sf, minor),
            RawMsg::NoteOn { ch, note, vel } => {
                push_midi_event(&mut track, delta, 0x90 | (ch & 0x0F), note, vel);
            }
            RawMsg::NoteOff { ch, note } => {
                push_midi_event(&mut track, delta, 0x80 | (ch & 0x0F), note, 0);
            }
        }
    }

    // End of track meta event
    write_varlen(&mut track, 0);
    track.extend_from_slice(&[0xFF, 0x2F, 0x00]);

    // Assemble SMF Header ("MThd") + Track Chunk ("MTrk")
    let mut midi = Vec::with_capacity(track.len() + 24);
    midi.extend_from_slice(b"MThd");
    midi.extend_from_slice(&6u32.to_be_bytes());
    midi.extend_from_slice(&0u16.to_be_bytes()); // Format 0 single track
    midi.extend_from_slice(&1u16.to_be_bytes()); // 1 track
    midi.extend_from_slice(&TICKS_PER_QUARTER.to_be_bytes());

    midi.extend_from_slice(b"MTrk");
    midi.extend_from_slice(&(track.len() as u32).to_be_bytes());
    midi.extend_from_slice(&track);

    let mut file = File::create(path)?;
    file.write_all(&midi)?;
    Ok(())
}

// Recursive workload generating varied stack depths and heap allocations.
fn weave_symphony(depth_budget: usize, seed: usize) -> usize {
    trace_fn!({
        let mut heap_buf: Vec<u8> = Vec::with_capacity((seed % 64) + 8);
        for i in 0..(heap_buf.capacity()) {
            heap_buf.push(((i * 13 + seed) & 0xFF) as u8);
        }

        let mut acc = heap_buf.iter().map(|&b| b as usize).sum::<usize>();
        if depth_budget > 0 {
            let boxed_note = Box::new((seed ^ depth_budget, acc));
            acc += boxed_note.0 + boxed_note.1;
            acc += weave_symphony(depth_budget - 1, seed.wrapping_mul(31).wrapping_add(7));
            if depth_budget % 2 == 0 {
                acc += weave_symphony(depth_budget - 1, seed.wrapping_add(19));
            }
        }
        acc
    })
}

fn main() -> io::Result<()> {
    {
        let mut start_guard = START_TIME.lock().unwrap();
        *start_guard = Some(Instant::now());
        let mut log_guard = TRACE_LOG.lock().unwrap();
        *log_guard = Some(Vec::with_capacity(256));
    }

    let result = trace_fn!({
        let mut total = 0usize;
        for branch in 1..=3 {
            let phrase = Box::new(format!("movement-{branch}"));
            total += phrase.len();
            total += weave_symphony(4, branch * 17);
        }
        total
    });

    let events = {
        let mut log_guard = TRACE_LOG.lock().unwrap();
        log_guard.take().unwrap_or_default()
    };

    let output_path = "execution_symphony.mid";
    render_midi_symphony(&events, output_path)?;
    println!("Encoded {} trace events (checksum={}) into {}", events.len(), result, output_path);
    Ok(())
}