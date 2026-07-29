// A self-rewriting memory allocator whose state mutates its own audio synthesis algorithm.
// Heap fragmentation controls microtonal pitch offsets, while un-freed memory leaks act as 
// harmonic accumulators driving resolving pitch class chord progressions.

use std::alloc::{GlobalAlloc, Layout, System};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::thread;
use std::time::Duration;

// --- Self-Rewriting Microtonal Audio Engine & Memory Allocator ---

const SAMPLE_RATE: usize = 44100;
const HEAP_CAPACITY: usize = 1024 * 1024; // 1 MB heap space for tracking

static ALLOC_COUNT: AtomicUsize = AtomicUsize::new(0);
static FREE_COUNT: AtomicUsize = AtomicUsize::new(0);
static ACTIVE_BYTES: AtomicUsize = AtomicUsize::new(0);
static FRAGMENTATION_INDEX: AtomicUsize = AtomicUsize::new(0);

// Global allocator wrapper that tracks fragmentation and leak metrics
pub struct AudioSensingAllocator;

unsafe impl GlobalAlloc for AudioSensingAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let ptr = System.alloc(layout);
        if !ptr.is_null() {
            let count = ALLOC_COUNT.fetch_add(1, Ordering::SeqCst);
            let active = ACTIVE_BYTES.fetch_add(layout.size(), Ordering::SeqCst) + layout.size();
            
            // Self-rewriting dynamic mutation of fragmentation state based on pointer spread
            let address_hash = (ptr as usize) ^ count;
            FRAGMENTATION_INDEX.fetch_xor(address_hash & 0xFFF, Ordering::SeqCst);
            
            // Self-modify audio synthesis state in real-time
            SYNTH_ENGINE.mutate_synthesis_code(active, count);
        }
        ptr
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        System.dealloc(ptr, layout);
        FREE_COUNT.fetch_add(1, Ordering::SeqCst);
        ACTIVE_BYTES.fetch_sub(layout.size(), Ordering::SeqCst);
        
        // Dynamic state update on deallocation
        FRAGMENTATION_INDEX.fetch_add(13, Ordering::SeqCst);
    }
}

#[global_allocator]
static GLOBAL_ALLOCATOR: AudioSensingAllocator = AudioSensingAllocator;

// Mutating Audio Synthesizer State
struct SynthEngine {
    // Phase accumulators for 4 microtonal polyphonic voices
    phases: [f32; 4],
    // Self-rewriting function bytecode / coefficients modified by memory mutations
    code_table: [f32; 8],
}

static mut SYNTH_ENGINE: SynthEngine = SynthEngine {
    phases: [0.0, 0.0, 0.0, 0.0],
    code_table: [220.0, 277.18, 329.63, 415.30, 1.0, 1.0, 1.0, 1.0], // Base Just Intonation A-major 7th
};

impl SynthEngine {
    // Translates dynamic allocation mechanics into modified audio algorithm parameters
    fn mutate_synthesis_code(&mut self, active_bytes: usize, alloc_count: usize) {
        let frag = FRAGMENTATION_INDEX.load(Ordering::Relaxed) as f32 / 4096.0;
        
        // Microtonal pitch shifting derived from heap fragmentation
        let microtonal_shift = (frag * 12.0).sin() * 15.0; // cents offset
        let ratio = 2.0f32.powf(microtonal_shift / 1200.0);

        // Memory leaks manifest as continuous resolving chord progressions
        let leaks = alloc_count.saturating_sub(FREE_COUNT.load(Ordering::Relaxed));
        let progression_step = (leaks % 5) as f32;
        
        // Base root frequency shifts dynamically based on memory pressure
        let base_freq = 110.0 * (1.0 + (active_bytes % 1000) as f32 / 2000.0);

        // Mutate dynamic synthesis parameters ("self-rewriting" DSP instructions)
        unsafe {
            let ptr = self.code_table.as_mut_ptr();
            *ptr.offset(0) = (base_freq * 1.0 * ratio) + (progression_step * 3.2);
            *ptr.offset(1) = (base_freq * 1.25 * ratio) + (progression_step * 5.1); // Just Major 3rd
            *ptr.offset(2) = (base_freq * 1.5 * ratio) - (progression_step * 2.4);  // Perfect 5th
            *ptr.offset(3) = (base_freq * 1.875 * ratio) + (progression_step * 7.3); // Harmonic 7th
            
            // Resonance/Timbre modulation based on fragmentation density
            *ptr.offset(4) = 0.2 + (frag * 0.3);
        }
    }

    // Process a single sample of ambient microtonal synth output
    fn render_sample(&mut self) -> f32 {
        let mut mix = 0.0;
        let dt = 1.0 / SAMPLE_RATE as f32;

        unsafe {
            let base_vol = self.code_table[4];
            for i in 0..4 {
                let freq = self.code_table[i];
                self.phases[i] = (self.phases[i] + freq * dt) % 1.0;
                
                // Pure sine wave synthesis with dynamic microtonal phase modulation
                let wave = (self.phases[i] * 2.0 * std::f32::consts::PI).sin();
                mix += wave * base_vol * 0.25;
            }
        }
        mix
    }
}

// Simulated PCM Audio Sink rendering sound textually/statistically for demonstration
fn render_live_ambient_stream(duration_ms: u64) {
    let samples_to_render = (SAMPLE_RATE as u64 * duration_ms / 1000) as usize;
    let mut buffer_peak = 0.0f32;

    for _ in 0..samples_to_render {
        let sample = unsafe { SYNTH_ENGINE.render_sample() };
        buffer_peak = buffer_peak.max(sample.abs());
    }

    let allocs = ALLOC_COUNT.load(Ordering::Relaxed);
    let frees = FREE_COUNT.load(Ordering::Relaxed);
    let leaks = allocs.saturating_sub(frees);
    let frag = FRAGMENTATION_INDEX.load(Ordering::Relaxed);

    println!(
        "[AUDIO DSP] Peak Amplitude: {:.4} | Heap Allocations: {} | Frees: {} | Active Leaks (Chord Progression State): {} | Frag Offset: {}",
        buffer_peak, allocs, frees, leaks, frag
    );
}

// --- Main Program: Dynamic Allocations & Memory Leaks as Music ---

fn main() {
    println!("=== Self-Rewriting Memory Allocator Audio Synthesizer ===");
    println!("Triggering dynamic heap operations & memory leaks to drive microtonal ambient composition...\n");

    // Phase 1: Rapid allocations creating heap fragmentation (Microtonal shimmer)
    let mut fragmented_ptrs = Vec::new();
    for i in 0..50 {
        let mut data = vec![0u8; (i * 128) % 2048 + 16]; // Variable sizing
        data[0] = (i & 0xFF) as u8;
        fragmented_ptrs.push(data);
    }
    
    render_live_ambient_stream(200);

    // Freeing alternating blocks to increase physical fragmentation
    for i in (0..fragmented_ptrs.len()).rev() {
        if i % 2 == 0 {
            fragmented_ptrs.remove(i);
        }
    }
    
    println!("\n--> Fragmentation induced. Rendering updated audio state...");
    render_live_ambient_stream(300);

    // Phase 2: Simulating Intentional Memory Leaks (Resolving Chord Progressions)
    println!("\n--> Inducing controlled heap memory leaks...");
    for step in 1..=4 {
        // Deliberately leak memory using Box::leak to trigger chord resolution shifts
        let leaked_block = Box::new(vec![0u64; 1024 * step]);
        let _ = Box::leak(leaked_block);

        thread::sleep(Duration::from_millis(50));
        render_live_ambient_stream(250);
    }

    // Phase 3: High-throughput dynamic allocation stream
    println!("\n--> Executing streaming memory allocation loop...");
    for _ in 0..1000 {
        let temp = Box::new(42);
        let _ = *temp;
    }

    println!("\n--> Final Ambient Microtonal Composition State:");
    render_live_ambient_stream(500);
}