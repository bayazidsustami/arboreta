#!/bin/bash

# Dependencies Check: Requires 'fluidsynth' or 'timidity' and 'mididings' or 'python3' with 'mido'
# To ensure maximum portability and zero-dependency on complex MIDI libraries, 
# this script generates a Standard MIDI File (SMF) using a Python helper 
# embedded within the Bash script.

# Check if python3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required to generate the MIDI file."
    exit 1
fi

# Check if input file is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <input_text_file>"
    exit 1
fi

INPUT_FILE="$1"

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

OUTPUT_FILE="${INPUT_FILE%.*}.mid"

# Embedded Python script to handle MIDI binary construction
# It maps ASCII (0-255) to MIDI notes (0-127) using modulo to stay in range
# Velocity is mapped to the ASCII value scaled to 0-127
PYTHON_SCRIPT=$(cat << 'EOF'
import sys
import struct

def create_midi(input_path, output_path):
    try:
        with open(input_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading file: {e}")
        sys.exit(1)

    # MIDI Header: MThd, length 6, format 0, 1 track, 480 ticks per quarter note
    header = b'MThd' + struct.pack('>IHHH', 6, 0, 1, 480)
    
    # MIDI Track Data
    track_data = bytearray()
    
    # Delta-time for each note (constant 480 ticks = quarter notes)
    # Note On: 0x90 [Note] [Velocity]
    # Note Off: 0x80 [Note] [Velocity]
    
    for char in content:
        ascii_val = ord(char)
        
        # Map ASCII to MIDI Note (0-127 range)
        # We use modulo 128 to ensure it fits MIDI standards
        note = ascii_val % 128
        
        # Map ASCII to Velocity (0-127 range)
        velocity = min(ascii_val % 128, 127)
        
        # Delta time 480 (0x01 0x80 in variable length quantity)
        # Note On event
        track_data.extend(b'\x80\x01\x90' + struct.pack('BB', note, velocity))
        
        # Delta time 480 (Note Off)
        # Note Off event
        track_data.extend(b'\x80\x01\x80' + struct.pack('BB', note, 0))

    # End of Track event
    track_data.extend(b'\x00\xFF\x2F\x00')

    # Track Header: MTrk, length
    track_header = b'MTrk' + struct.pack('>I', len(track_data))
    
    with open(output_path, 'wb') as f:
        f.write(header)
        f.write(track_header)
        f.write(track_data)

if __name__ == "__main__":
    create_midi(sys.argv[1], sys.argv[2])
EOF
)

# Execute the embedded Python script
echo "Converting '$INPUT_FILE' to '$OUTPUT_FILE'..."
python3 -c "$PYTHON_SCRIPT" "$INPUT_FILE" "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "Success! MIDI file created: $OUTPUT_FILE"
    echo "You can play it using: mpg123, timidity, or any DAW."
else
    echo "Conversion failed."
    exit 1
fi