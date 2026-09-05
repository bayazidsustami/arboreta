import random
import math
import struct
from typing import List, Tuple, Dict

class VariableStarLullabyCompiler:
    """
    Esoteric compiler translating stellar light curves, periods, magnitudes,
    and spectral classes into polyphonic MIDI lullabies.
    """
    
    # MIDI Program numbers mapped to Spectral Classes (Synthesizer Timbres)
    SPECTRAL_TIMBRES: Dict[str, int] = {
        'O': 89,  # Pad 2 (warm)
        'B': 90,  # Pad 3 (polysynth)
        'A': 88,  # Pad 1 (new age)
        'F': 98,  # FX 3 (crystal/celesta-like)
        'G': 11,  # Music Box
        'K': 9,   # Celesta
        'M': 12,  # Marimba/Kalimba soft timbre
    }

    # Lullaby Scale Degrees (Pentatonic / Lydian Soft Mix for dreamy feel)
    PENTATONIC_SCALE: List[int] = [0, 2, 4, 7, 9]  # C, D, E, G, A
    
    def __init__(self, star_name: str, spectral_class: str, pulsation_period_days: float, 
                 light_curve_magnitudes: List[float]):
        self.star_name = star_name
        self.spectral_class = spectral_class.upper()[0]
        self.period = max(0.1, pulsation_period_days)
        self.magnitudes = light_curve_magnitudes
        
    def _map_period_to_tempo(self) -> int:
        """Derives a slow, soothing lullaby tempo (40 - 75 BPM) from pulsation period."""
        # Logarithmic mapping: short periods -> slower/gentler, long periods -> steady calm
        base_bpm = 40 + (math.log(self.period + 1) * 8)
        return int(max(40, min(75, base_bpm)))

    def _magnitude_to_pitch(self, mag: float, min_mag: float, max_mag: float, octave_offset: int = 60) -> int:
        """
        Inverts magnitude (brighter star/lower mag = higher/clearer pitch)
        and quantizes to the dreamy lullaby scale.
        """
        if max_mag == min_mag:
            normalized = 0.5
        else:
            # Lower magnitude means higher brightness -> higher pitch
            normalized = (max_mag - mag) / (max_mag - min_mag)
            
        scale_length = len(self.PENTATONIC_SCALE)
        total_semitones = int(normalized * 24)  # 2 octave range
        
        octave = total_semitones // 12
        degree = total_semitones % 12
        
        # Snap to nearest pentatonic note
        closest_note = min(self.PENTATONIC_SCALE, key=lambda x: abs(x - degree))
        midi_note = octave_offset + (octave * 12) + closest_note
        return max(0, min(127, midi_note))

    def _create_var_len(self, value: int) -> bytes:
        """Converts an integer to MIDI Variable Length Quantity format."""
        buffer = value & 0x7F
        while value >> 7:
            value >>= 7
            buffer <<= 8
            buffer |= (value & 0x7F) | 0x80
        res = bytearray()
        while True:
            res.append(buffer & 0xFF)
            if buffer & 0x80:
                buffer >>= 8
            else:
                break
        return bytes(res)

    def _generate_track(self, channel: int, program: int, notes: List[Tuple[int, int, int]]) -> bytes:
        """
        Generates a MIDI Track byte chunk.
        notes format: list of (delta_ticks, midi_note, velocity)
        """
        track_data = bytearray()
        
        # Track Name Event
        name_bytes = f"{self.star_name} - Track {channel}".encode('ascii')
        track_data.extend(b'\x00\xFF\x03' + self._create_var_len(len(name_bytes)) + name_bytes)
        
        # Program Change Event (Set instrument timbre)
        track_data.extend(b'\x00' + bytes([0xC0 | channel, program]))
        
        # Generate Note On / Note Off events
        for delta_ticks, note, vel in notes:
            # Note On
            track_data.extend(self._create_var_len(delta_ticks))
            track_data.extend(bytes([0x90 | channel, note, vel]))
            
            # Duration (Sustained soft lullaby notes)
            duration = 192  # Quarter note duration
            track_data.extend(self._create_var_len(duration))
            track_data.extend(bytes([0x80 | channel, note, 0]))

        # End of Track Event
        track_data.extend(b'\x00\xFF\x2F\x00')
        
        # Header for the Track chunk
        track_header = b'MTrk' + struct.pack('>I', len(track_data))
        return track_header + track_data

    def compile_to_midi(self, output_filename: str = "stellar_lullaby.mid"):
        """Compiles the stellar light curve data into a multi-track MIDI file."""
        ticks_per_beat = 192
        tempo_bpm = self._map_period_to_tempo()
        microseconds_per_beat = int(60_000_000 / tempo_bpm)
        
        min_mag = min(self.magnitudes)
        max_mag = max(self.magnitudes)
        
        # Channel 0: Lead Melodic Track (Direct light curve mapping)
        program_lead = self.SPECTRAL_TIMBRES.get(self.spectral_class, 11)
        lead_notes = []
        for i, mag in enumerate(self.magnitudes):
            pitch = self._magnitude_to_pitch(mag, min_mag, max_mag, octave_offset=60)
            velocity = int(45 + 35 * ((max_mag - mag) / (max_mag - min_mag or 1))) # Dynamic softness
            delta = 96 if i > 0 else 0
            lead_notes.append((delta, pitch, velocity))
            
        # Channel 1: Harmonic Pad / Arpeggio Track (Derived inverted progression)
        program_pad = self.SPECTRAL_TIMBRES.get('O', 89) # Deep background pad
        harmony_notes = []
        for i, mag in enumerate(reversed(self.magnitudes)):
            pitch = self._magnitude_to_pitch(mag, min_mag, max_mag, octave_offset=36)
            velocity = 40  # Soft constant background volume
            delta = 192 if i > 0 else 0
            harmony_notes.append((delta, pitch, velocity))

        # Build Conductor Track (Tempo header)
        conductor_data = bytearray()
        # Set Tempo Event
        tempo_bytes = struct.pack('>I', microseconds_per_beat)[1:] # 3-byte uint
        conductor_data.extend(b'\x00\xFF\x51\x03' + tempo_bytes)
        conductor_data.extend(b'\x00\xFF\x2F\x00')
        conductor_track = b'MTrk' + struct.pack('>I', len(conductor_data)) + conductor_data

        # Build Instruments Tracks
        track1 = self._generate_track(channel=0, program=program_lead, notes=lead_notes)
        track2 = self._generate_track(channel=1, program=program_pad, notes=harmony_notes)

        # Header Chunk Format: Format Type 1 (multi-track), 3 tracks, Ticks Per Beat
        midi_header = b'MThd' + struct.pack('>HHH', 6, 1, 3, ticks_per_beat)

        # Write MIDI file
        with open(output_filename, 'wb') as f:
            f.write(midi_header + conductor_track + track1 + track2)
            
        print(f"Successfully compiled stellar lullaby for '{self.star_name}' -> '{output_filename}'")
        print(f"Specs: Spectral Class {self.spectral_class} | Period: {self.period}d | Tempo: {tempo_bpm} BPM")


# --- Execution Example ---
if __name__ == "__main__":
    # Simulated Light Curve for Delta Cephei (Classic Cepheid Variable Star)
    # Period = 5.366 days, Spectral Class F5Ib - G2Ib (Mapped as 'F')
    # Magnitudes oscillate smoothly between ~3.48 and 4.37
    delta_cephei_magnitudes = [
        3.48, 3.55, 3.68, 3.82, 3.98, 4.12, 4.25, 4.35, 
        4.37, 4.30, 4.18, 4.02, 3.85, 3.65, 3.52, 3.48
    ] * 2  # Repeat sequence to double lullaby length

    compiler = VariableStarLullabyCompiler(
        star_name="Delta Cephei",
        spectral_class="F",
        pulsation_period_days=5.366,
        light_curve_magnitudes=delta_cephei_magnitudes
    )
    
    compiler.compile_to_midi("delta_cephei_lullaby.mid")