import capstone
import numpy as np
import scipy.io.wavfile as wav
import os
import sys

# Define base mapping of x86 assembly groups to MIDI root notes and waveforms
INSTRUCTION_MAP = {
    'control_flow': {'midi': 60, 'wave': 'saw', 'color': 'jmp/call/ret'}, # C4
    'arithmetic':   {'midi': 64, 'wave': 'square', 'color': 'add/sub/mul'}, # E4
    'logic':        {'midi': 67, 'wave': 'triangle', 'color': 'and/or/xor'}, # G4
    'memory':       {'midi': 71, 'wave': 'sine', 'color': 'mov/push/pop'}, # B4
    'other':        {'midi': 55, 'wave': 'sine', 'color': 'misc'} # G3
}

def classify_instruction(mnemonic):
    """Categorize x86 instructions into functional musical types."""
    m = mnemonic.lower()
    if m in ['jmp', 'je', 'jne', 'jz', 'jnz', 'call', 'ret', 'loop']:
        return 'control_flow'
    elif m in ['add', 'sub', 'mul', 'imul', 'div', 'idiv', 'inc', 'dec']:
        return 'arithmetic'
    elif m in ['and', 'or', 'xor', 'not', 'shl', 'shr', 'sar', 'rol', 'ror']:
        return 'logic'
    elif m in ['mov', 'push', 'pop', 'lea', 'lodsb', 'stosb', 'movsb']:
        return 'memory'
    return 'other'

def generate_waveform(wave_type, freq, duration, sample_rate=44100):
    """Synthesize raw audio samples for a given waveform, pitch, and duration."""
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    if wave_type == 'sine':
        audio = np.sin(2 * np.pi * freq * t)
    elif wave_type == 'square':
        audio = np.sign(np.sin(2 * np.pi * freq * t))
    elif wave_type == 'saw':
        audio = 2 * (t * freq - np.floor(0.5 + t * freq))
    elif wave_type == 'triangle':
        audio = 2 * np.abs(2 * (t * freq - np.floor(0.5 + t * freq))) - 1
    else:
        audio = np.sin(2 * np.pi * freq * t)
    
    # Apply a quick ADSR envelope to prevent audio pops
    attack = int(0.01 * sample_rate)
    decay = int(0.02 * sample_rate)
    release = int(0.03 * sample_rate)
    sustain_len = max(0, len(t) - (attack + decay + release))
    
    envelope = np.concatenate([
        np.linspace(0, 1, attack),
        np.linspace(1, 0.7, decay),
        np.full(sustain_len, 0.7),
        np.linspace(0.7, 0, release)
    ])
    
    if len(envelope) > len(audio):
        envelope = envelope[:len(audio)]
    elif len(envelope) < len(audio):
        envelope = np.pad(envelope, (0, len(audio) - len(envelope)))
        
    return audio * envelope

def midi_to_freq(midi_note):
    """Convert MIDI note number to frequency in Hertz."""
    return 440.0 * (2.0 ** ((midi_note - 69) / 12.0))

def synthesize_binary(file_path, output_wav="binary_score.wav", max_instructions=200):
    """Disassemble binary machine code into assembly and generate polyphonic audio."""
    if not os.path.exists(file_path):
        print(f"File {file_path} not found. Generating audio from executable memory buffer.")
        # Fallback raw byte code sample if file is missing
        code_bytes = b"\x55\x48\x89\xe5\x48\x83\xec\x10\xc7\x45\xfc\x00\x00\x00\x00\x83\x45\xfc\x01\x8b\x45\xfc\x3d\x09\x00\x00\x00\x7e\xef\xb8\x00\x00\x00\x00\xc9\xc3"
    else:
        with open(file_path, "rb") as f:
            code_bytes = f.read(4096) # Process up to first 4KB of code

    # Initialize Capstone disassembler for x86 64-bit
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
    
    sample_rate = 44100
    timeline_duration = 0.0
    notes_events = []
    
    cursor_time = 0.0
    inst_count = 0

    print("Disassembling machine code and generating musical parameters...")
    for insn in md.disasm(code_bytes, 0x1000):
        if inst_count >= max_instructions:
            break
            
        category = classify_instruction(insn.mnemonic)
        inst_params = INSTRUCTION_MAP[category]
        
        # Micro-pitch modulation determined by instruction byte value variations
        byte_val = insn.bytes[0] if len(insn.bytes) > 0 else 0
        pitch_offset = (byte_val % 12) - 6
        final_midi = inst_params['midi'] + pitch_offset
        freq = midi_to_freq(final_midi)
        
        # Rhythm/Duration dynamically scaled by instruction byte size
        duration = max(0.05, len(insn.bytes) * 0.025)
        
        # Polyphonic voice offset determined by instruction address
        time_offset = (insn.address % 3) * 0.02
        start_time = cursor_time + time_offset
        
        notes_events.append({
            'start': start_time,
            'duration': duration,
            'freq': freq,
            'wave': inst_params['wave']
        })
        
        cursor_time += duration * 0.5 # Staggered polyphonic overlap
        inst_count += 1

    if not notes_events:
        print("No valid assembly instructions decoded.")
        return

    # Render combined polyphonic audio track
    total_duration = max(n['start'] + n['duration'] for n in notes_events) + 0.5
    master_buffer = np.zeros(int(sample_rate * total_duration))
    
    for note in notes_events:
        wave = generate_waveform(note['wave'], note['freq'], note['duration'], sample_rate)
        start_idx = int(note['start'] * sample_rate)
        end_idx = start_idx + len(wave)
        master_buffer[start_idx:end_idx] += wave * 0.25 # Mix attenuation
        
    # Normalize audio buffer to prevents clipping
    max_val = np.max(np.abs(master_buffer))
    if max_val > 0:
        master_buffer = master_buffer / max_val
        
    # Export 16-bit PCM WAV output file
    audio_int16 = (master_buffer * 32767).astype(np.int16)
    wav.write(output_wav, sample_rate, audio_int16)
    print(f"Synthesized {inst_count} instructions into polyphonic audio score saved to: {output_wav}")

if __name__ == "__main__":
    # Use executable path provided or execute standalone demonstration
    target_bin = sys.argv[1] if len(sys.argv) > 1 else sys.executable
    synthesize_binary(target_bin)