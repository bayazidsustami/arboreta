#!/usr/bin/env bash
# ==============================================================================
# WASM Polyphonic Sonifier
# Compiles WASM execution paths & memory allocations into an evolving MIDI score.
# ==============================================================================

set -euo pipefail

# --- Dependencies Check ---
for cmd in python3 xxd; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required command '$cmd' is not installed." >&2
        exit 1
    fi
done

# --- Embedded MIDI Generator Engine (Python script) ---
cat << 'EOF' > /tmp/wasm_sonifier.py
import sys, struct

def parse_wasm(filename):
    with open(filename, 'rb') as f:
        data = f.read()

    # Verify WASM header (\x00asm)
    if len(data) < 8 or data[:4] != b'\x00asm':
        raise ValueError("Invalid WASM binary header")

    opcodes, memory_events = [], []
    i = 8
    n = len(data)

    # Basic WASM Section & Bytecode Parser Loop
    while i < n:
        sec_id = data[i]
        i += 1
        # Read LEB128 section length
        sec_len, shift = 0, 0
        while True:
            if i >= n: break
            byte = data[i]
            i += 1
            sec_len |= (byte & 0x7F) << shift
            shift += 7
            if not (byte & 0x80): break

        sec_end = min(i + sec_len, n)
        if sec_id in (5, 11, 10):  # Memory, Data, or Code sections
            pos = i
            while pos < sec_end:
                op = data[pos]
                opcodes.append((pos, op))
                # Detect memory-related instructions:
                # 0x3F-0x40 (memory.grow/size), 0x28-0x3E (loads/stores)
                if 0x28 <= op <= 0x40:
                    memory_events.append((pos, op))
                pos += 1
        i = sec_end

    return opcodes, memory_events

def build_midi(opcodes, memory_events, output_midi):
    # MIDI File Header (Type 1 format, 4 tracks, 480 ticks/beat)
    ticks_per_beat = 480
    header = b'MThd' + struct.pack('>IHHH', 6, 1, 4, ticks_per_beat)

    def varlen(val):
        buf = bytearray()
        buf.append(val & 0x7F)
        val >>= 7
        while val > 0:
            buf.insert(0, (val & 0x7F) | 0x80)
            val >>= 7
        return bytes(buf)

    # Track 0: Conductor (Tempo & Time Signature)
    t0_events = bytearray()
    t0_events += b'\x00\xFF\x58\x04\x04\x02\x18\x08' # 4/4 Time Sig
    # Set tempo (120 BPM = 500,000 microseconds per beat)
    t0_events += b'\x00\xFF\x51\x03' + (500000).to_bytes(3, 'big')
    t0_events += b'\x00\xFF\x2F\x00' # End of Track
    track0 = b'MTrk' + struct.pack('>I', len(t0_events)) + t0_events

    def generate_track(events, channel, base_pitch, scale, program):
        trk = bytearray()
        # Program Change (Instrument select)
        trk += b'\x00' + bytes([0xC0 | channel, program])
        
        time_cursor = 0
        scale_len = len(scale)

        for pos, op in events:
            # Map byte position & opcode to scale pitches and dynamics
            pitch_idx = (op + pos) % scale_len
            pitch = base_pitch + scale[pitch_idx]
            velocity = 60 + (op % 60)
            duration = 120 * ((op % 4) + 1) # Note duration

            # Note On
            trk += varlen(0) + bytes([0x90 | channel, pitch, velocity])
            # Note Off
            trk += varlen(duration) + bytes([0x80 | channel, pitch, 0])

        trk += b'\x00\xFF\x2F\x00' # End of Track
        return b'MTrk' + struct.pack('>I', len(trk)) + trk

    # Harmonic scale (Pentatonic/Dorian mix for fluid musicality)
    scale = [0, 2, 3, 5, 7, 9, 10, 12, 14, 15, 17, 19]

    # Track 1: Melody (Control Flow & General Opcodes) -> Synth Lead (80)
    track1 = generate_track(opcodes[::3], channel=0, base_pitch=60, scale=scale, program=80)
    # Track 2: Harmony/Arpeggios (Execution Flow) -> Marimba (12)
    track2 = generate_track(opcodes[1::3], channel=1, base_pitch=48, scale=scale, program=12)
    # Track 3: Bassline (Heap & Memory Allocations) -> Synth Bass (38)
    track3 = generate_track(memory_events if memory_events else opcodes[2::5], channel=2, base_pitch=36, scale=scale, program=38)

    with open(output_midi, 'wb') as f:
        f.write(header + track0 + track1 + track2 + track3)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        sys.exit(1)
    ops, mems = parse_wasm(sys.argv[1])
    build_midi(ops, mems, sys.argv[2])
EOF

# --- Main Shell Logic ---

# Check if target WASM file is provided, otherwise generate a lightweight synthetic test WASM module
INPUT_WASM="${1:-}"
OUTPUT_MIDI="${2:-score.mid}"

if [[ -z "$INPUT_WASM" ]]; then
    INPUT_WASM="/tmp/sample_generated.wasm"
    echo "[+] No WASM input supplied. Generating synthetic WASM binary for sonification..."
    # WASM Binary Header + Vector sections (Type, Function, Export, Code with memory instructions)
    printf '\x00\x61\x73\x6d\x01\x00\x00\x00\x01\x05\x01\x60\x00\x01\x7f\x03' > "$INPUT_WASM"
    printf '\x02\x00\x00\x05\x03\x01\x00\x01\x07\x0a\x01\x06\x6d\x65\x6d\x6f\x72' >> "$INPUT_WASM"
    printf '\x79\x02\x00\x0a\x23\x01\x21\x00\x41\x00\x3f\x00\x21\x00\x41\x10\x36' >> "$INPUT_WASM"
    printf '\x02\x00\x20\x00\x28\x02\x00\x6a\x0f\x0b' >> "$INPUT_WASM"
fi

if [[ ! -f "$INPUT_WASM" ]]; then
    echo "Error: WASM file '$INPUT_WASM' not found." >&2
    exit 1
fi

echo "[+] Sonifying $INPUT_WASM -> $OUTPUT_MIDI..."
python3 /tmp/wasm_sonifier.py "$INPUT_WASM" "$OUTPUT_MIDI"

# Cleanup temporary generator script
rm -f /tmp/wasm_sonifier.py

echo "[✔] MIDI Score successfully generated: $OUTPUT_MIDI"
exit 0