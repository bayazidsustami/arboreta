import mido
from mido import Message, MidiFile, MidiTrack

def text_to_midi(input_file, output_file, tempo=500000):
    """
    Converts a text file to a MIDI file.
    Maps ASCII values to MIDI notes (range 21-108).
    Maps character frequency/position to duration.
    """
    mid = MidiFile()
    track = MidiTrack()
    mid.tracks.append(track)

    # Set tempo (microseconds per beat)
    # Note: mido handles tempo via meta messages
    from mido import MetaMessage
    track.append(MetaMessage('set_tempo', tempo=tempo))

    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: {input_file} not found. Creating a dummy file for demonstration.")
        content = "Hello World!"
        with open(input_file, 'w', encoding='utf-8') as f:
            f.write(content)

    # MIDI pitch range is 0-127. 
    # We map ASCII (0-255) to a musical range (e.g., 48-84) to avoid extreme highs/lows.
    # Offset 48 is C3. 
    OFFSET = 48
    MAX_PITCH = 108 # C8
    
    for char in content:
        ascii_val = ord(char)
        
        # Map ASCII to a pitch within a reasonable musical range
        # Using modulo to keep it within 0-127 range
        pitch = (ascii_val + OFFSET) % (MAX_PITCH - OFFSET + 1) + OFFSET
        
        # Duration: vary duration based on whether it's a space or alphanumeric
        # This creates a rhythmic pattern
        if char == ' ':
            duration = 480  # Quarter note equivalent
        elif char.isspace():
            duration = 240  # Eighth note
        else:
            duration = 120  # Sixteenth note

        # Note On
        track.append(Message('note_on', note=pitch, velocity=64, time=0))
        # Note Off (time is delta time since last event)
        track.append(Message('note_off', note=pitch, velocity=64, time=duration))

    mid.save(output_file)
    print(f"Successfully converted '{input_file}' to '{output_file}'")

if __name__ == "__main__":
    # Configuration
    INPUT_TXT = "input.txt"
    OUTPUT_MIDI = "output.mid"

    # Create a sample input file if it doesn't exist
    with open(INPUT_TXT, "w") as f:
        f.write("Python to MIDI conversion algorithm!")

    # Run the conversion
    text_to_midi(INPUT_TXT, OUTPUT_MIDI)