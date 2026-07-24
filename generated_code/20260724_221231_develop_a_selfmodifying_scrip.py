import sys
import struct
import tracemalloc

# --- Minimal MIDI File Generator ---
def create_midi_file(events, filename="execution_trace.mid"):
    track_data = bytearray()
    for delta, status, d1, d2 in events:
        # Write Variable-Length Quantity for Delta Time
        val = delta
        buf = bytearray([val & 0x7F])
        while val >> 7:
            val >>= 7
            buf.insert(0, (val & 0x7F) | 0x80)
        track_data.extend(buf)
        track_data.append(status)
        track_data.append(d1 & 0x7F)
        if d2 is not None:
            track_data.append(d2 & 0x7F)
            
    # Meta Event: End of Track
    track_data.extend(b'\x00\xFF\x2F\x00')
    
    # Header Chunk (Format 0, 1 Track, 480 Ticks/QNote) + Track Chunk
    header = b'MThd' + struct.pack('>IHHH', 6, 0, 1, 480)
    track_header = b'MTrk' + struct.pack('>I', len(track_data))
    
    with open(filename, 'wb') as f:
        f.write(header + track_header + track_data)

# --- Execution Tracing & Musical Mapping ---
midi_events = []
tracemalloc.start()

def trace_execution(frame, event, arg):
    if event in ('call', 'line', 'return'):
        # Stack depth dictates tempo/duration scaling
        depth = 0
        curr = frame
        while curr:
            depth += 1
            curr = curr.f_back
            
        # Memory allocations dictate pitch mapping
        current_mem, _ = tracemalloc.get_traced_memory()
        
        # Pentatonic scale mapping based on current memory footprint
        pentatonic_offsets = [0, 2, 4, 7, 9]
        note_index = (current_mem // 64) % 35
        pitch = 36 + pentatonic_offsets[note_index % 5] + (12 * (note_index // 5))
        pitch = max(24, min(108, int(pitch)))
        
        # Call stack depth drives note duration (tempo dynamics) & velocity
        delta_ticks = max(20, 480 // max(1, depth))
        velocity = max(40, min(127, 40 + depth * 12))
        
        # Note On followed by Note Off
        midi_events.append((0, 0x90, pitch, velocity))
        midi_events.append((delta_ticks, 0x80, pitch, 0))
        
    return trace_execution

# --- Workload with Dynamic Memory & Recursive Call Stack ---
def recursive_workload(depth):
    if depth <= 0:
        return
    # Dynamic self-modification of data structures to alter memory trace
    data_block = [x ** 2 for x in range(depth * 150)]
    recursive_workload(depth - 1)
    del data_block

# Run execution trace
sys.settrace(trace_execution)
recursive_workload(10)
sys.settrace(None)
tracemalloc.stop()

# Generate the MIDI file from execution trace
create_midi_file(midi_events)