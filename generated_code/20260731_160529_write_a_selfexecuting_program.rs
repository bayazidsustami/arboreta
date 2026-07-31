// Self-executing mirror program with dynamic GC rhyming sonnet rewriting.
// 1. Simulates a mark-and-sweep garbage collector tracking dynamic allocations.
// 2. Maps heap address layout into a symmetrical physical ASCII mirror layout.
// 3. Synthesizes a 14-line rhyming sonnet reflecting real-time GC state.

use std::alloc::{alloc, dealloc, Layout};

struct HeapNode {
    id: usize,
    marked: bool,
    size: usize,
    ptr: *mut u8,
}

struct GarbageCollector {
    heap: Vec<HeapNode>,
    total_bytes: usize,
    reclaimed_bytes: usize,
}

impl GarbageCollector {
    fn new() -> Self {
        Self {
            heap: Vec::new(),
            total_bytes: 0,
            reclaimed_bytes: 0,
        }
    }

    fn allocate(&mut self, id: usize, size: usize) {
        let layout = Layout::from_size_align(size, 8).unwrap();
        let ptr = unsafe { alloc(layout) };
        self.heap.push(HeapNode {
            id,
            marked: false,
            size,
            ptr,
        });
        self.total_bytes += size;
    }

    fn mark(&mut self, root_ids: &[usize]) {
        for node in &mut self.heap {
            if root_ids.contains(&node.id) {
                node.marked = true;
            }
        }
    }

    fn sweep(&mut self) {
        let mut i = 0;
        while i < self.heap.len() {
            if !self.heap[i].marked {
                let node = self.heap.remove(i);
                let layout = Layout::from_size_align(node.size, 8).unwrap();
                unsafe { dealloc(node.ptr, layout) };
                self.reclaimed_bytes += node.size;
            } else {
                i += 1;
            }
        }
    }
}

fn build_sonnet(live_cnt: usize, swept_cnt: usize, total_bytes: usize, reclaimed: usize) -> String {
    format!(
"/*
  The silent heap awakes in muted light,
  Where allocations cluster in the shade,
  Some pointers reach across the growing night,
  While orphaned bytes prepare to slowly fade.

  The marker travels through the graph with care,
  Flags live objects ({live_cnt} remain in space),
  While unreachable souls ({swept_cnt}) lie bare,
  Awaiting sweep to leave without a trace.

  Full bytes allocated: {total_bytes} in all,
  Reclaimed memory measured: {reclaimed} retrieved,
  The garbage collector responds to call,
  Restoring freedom that was lost and grieved.

  In balanced heap and mirrored code we see,
  A cycle born of pure efficiency.
*/"
    )
}

fn mirror_layout(heap: &[HeapNode]) -> String {
    let mut left = String::new();
    for node in heap {
        let symbol = if node.marked { "[#]" } else { "[_]" };
        left.push_str(symbol);
    }
    let right: String = left.chars().rev().collect();
    format!("// Memory Mirror Layout: {} || {}", left, right)
}

fn main() {
    let mut gc = GarbageCollector::new();

    // Allocate heap nodes mirroring source structure
    gc.allocate(1, 64);
    gc.allocate(2, 128);
    gc.allocate(3, 32);
    gc.allocate(4, 256);

    // Mark reachable roots
    gc.mark(&[1, 3]);

    let initial_count = gc.heap.len();
    gc.sweep();
    let live_count = gc.heap.len();
    let swept_count = initial_count - live_count;

    let mirror = mirror_layout(&gc.heap);
    let sonnet = build_sonnet(live_count, swept_count, gc.total_bytes, gc.reclaimed_bytes);

    println!("{}\n{}", sonnet, mirror);

    // Clean up surviving allocations
    for node in gc.heap.drain(..) {
        let layout = Layout::from_size_align(node.size, 8).unwrap();
        unsafe { dealloc(node.ptr, layout) };
    }
}