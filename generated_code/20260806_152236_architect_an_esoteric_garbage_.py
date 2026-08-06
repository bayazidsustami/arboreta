import sys
import os
import gc
import math
import struct
import wave
import io
import subprocess
import platform
import weakref
import time

class RequiemAudioPlayer:
    """Cross-platform audio generator and player for raw WAV byte buffers."""
    
    @staticmethod
    def play_wav(wav_bytes):
        system = platform.system()
        try:
            if system == "Windows":
                import winsound
                winsound.PlaySound(wav_bytes, winsound.SND_MEMORY)
            elif system == "Darwin": # macOS
                proc = subprocess.Popen(['afplay', '-'], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
                proc.communicate(input=wav_bytes)
            else: # Linux / Unix
                try:
                    proc = subprocess.Popen(['paplay'], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
                    proc.communicate(input=wav_bytes)
                except FileNotFoundError:
                    proc = subprocess.Popen(['aplay', '-q'], stdin=subprocess.PIPE, stderr=subprocess.DEVNULL)
                    proc.communicate(input=wav_bytes)
        except Exception:
            # Fallback gracefully if system audio is headless/unavailable
            pass


class EsotericFuneralGC:
    """
    An esoteric garbage collector that registers dying heap allocations,
    maps their memory addresses (id) to a chromatic C-minor dirge scale,
    and synthesizes a polyphonic funeral song upon garbage collection.
    """
    
    # Funeral Dirge Chromatic Scale (C Natural Minor / Phrygian for dark funeral aesthetic)
    DIRGE_CHROMATIC_SCALE = [0, 1, 3, 5, 7, 8, 10]
    BASE_FREQ = 65.41  # C2 (Deep pipe organ fundamental pitch)
    
    def __init__(self, sample_rate=22050):
        self.sample_rate = sample_rate
        self.dead_pool = []
        self._install_gc_hook()
        
    def track(self, obj):
        """Monitors an object, capturing its memory address upon death."""
        obj_id = id(obj)
        size = sys.getsizeof(obj)
        weakref.ref(obj, lambda ref, oid=obj_id, sz=size: self._on_object_reaped(oid, sz))
        return obj

    def _on_object_reaped(self, obj_id, size):
        """Callback invoked when an object reference count drops to zero."""
        self.dead_pool.append((obj_id, size))

    def _install_gc_hook(self):
        """Attaches the esoteric callback directly to Python's internal GC cycle."""
        gc.callbacks.append(self._gc_cycle_callback)

    def _gc_cycle_callback(self, phase, info):
        """Invoked automatically whenever Python's GC sweeps the heap."""
        if phase == "stop" and (info['collected'] > 0 or self.dead_pool):
            self.play_dirge(info['collected'])

    def _address_to_frequency(self, obj_id):
        """Maps a dead object's 64-bit memory address to a chromatic dirge frequency."""
        scale_idx = obj_id % len(self.DIRGE_CHROMATIC_SCALE)
        octave = (obj_id >> 8) % 3  # Spans 3 octaves (C2 to C5)
        semitones = self.DIRGE_CHROMATIC_SCALE[scale_idx] + (octave * 12)
        return self.BASE_FREQ * (2 ** (semitones / 12.0))

    def play_dirge(self, collected_count):
        """Generates and streams a minor-key funeral dirge for dead allocations."""
        notes = []
        while self.dead_pool:
            oid, _ = self.dead_pool.pop(0)
            notes.append(self._address_to_frequency(oid))
            
        if not notes:
            # Fallback notes generated directly from GC collected object counts
            notes = [self._address_to_frequency(hash(time.time() + i)) for i in range(min(collected_count, 8))]

        # Audio synthesis parameters
        duration = min(2.5, 0.5 + len(notes) * 0.15)
        num_samples = int(self.sample_rate * duration)
        audio_buffer = [0.0] * num_samples
        
        # Synthesize polyphonic organ/bell harmonics for each fallen object
        for idx, freq in enumerate(notes[:12]):
            stagger = int((idx / max(len(notes), 1)) * (num_samples * 0.35))
            for i in range(stagger, num_samples):
                t = (i - stagger) / self.sample_rate
                # Bell/Organ Envelope: sharp attack, slow exponential dirge decay
                envelope = math.exp(-2.2 * t)
                # Chromatic harmonics (Fundamental + Diminished Fifth + Octave)
                tone = (
                    0.6 * math.sin(2 * math.pi * freq * t) +
                    0.3 * math.sin(2 * math.pi * freq * 1.414 * t) +
                    0.1 * math.sin(2 * math.pi * freq * 2.0 * t)
                )
                audio_buffer[i] += tone * envelope

        # Normalize audio peak to prevent clipping
        max_val = max(max(abs(s) for s in audio_buffer), 1.0)
        pcm_bytes = bytearray()
        for sample in audio_buffer:
            normalized = int((sample / max_val) * 0.75 * 32767)
            pcm_bytes.extend(struct.pack('<h', max(-32768, min(32767, normalized))))

        # Package raw audio into binary WAV stream
        wav_io = io.BytesIO()
        with wave.open(wav_io, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(self.sample_rate)
            wf.writeframes(pcm_bytes)
            
        print(f"─── ⚰️ FUNERAL DIRGE PLAYED FOR {collected_count} DEAD ALLOCATIONS ⚰️ ───")
        RequiemAudioPlayer.play_wav(wav_io.getvalue())


# Demonstration of the Esoteric GC in action
if __name__ == "__main__":
    dirge_collector = EsotericFuneralGC()

    print("Allocating mortal objects on the heap...")
    class HeapNode:
        def __init__(self, name):
            self.name = name
            self.cyclic_link = None

    # Create cyclic reference structures to force explicit GC reclamation
    for i in range(6):
        node_a = dirge_collector.track(HeapNode(f"DeadAllocation_{i}_A"))
        node_b = dirge_collector.track(HeapNode(f"DeadAllocation_{i}_B"))
        node_a.cyclic_link = node_b
        node_b.cyclic_link = node_a
        del node_a, node_b

    print("Executing heap collection to reap unreferenced memory...")
    time.sleep(0.2)
    gc.collect()  # Triggers the GC hook, rendering the chromatic funeral dirge
    time.sleep(1.0)